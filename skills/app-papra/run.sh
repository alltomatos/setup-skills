#!/bin/bash
# =============================================================================
# skills/app-papra/run.sh
# Skill: Deploy do Papra via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias:
#   URL_PAPRA          — domínio para o serviço (ex: papra.seudominio.com.br)
#   NOME_REDE_INTERNA  — nome da rede overlay Docker
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores padrão Orion Design
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
vermelho="\e[91m"
reset="\e[0m"

ERRORS=0

validate_inputs() {
    local missing=0
    [ -z "${URL_PAPRA:-}" ]         && echo -e "${vermelho}[ERRO] URL_PAPRA não informado.${reset}"         && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        echo -e "${amarelo}Uso: URL_PAPRA=x NOME_REDE_INTERNA=y ./run.sh${reset}"
        exit 1
    fi
}

setup_volumes() {
    echo -e "${amarelo}[1/5] Criando volumes persistentes...${reset}"
    for vol in papra_db papra_documents; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

generate_secrets() {
    echo -e "${amarelo}[2/5] Gerando AUTH_SECRET...${reset}"
    AUTH_SECRET="$(openssl rand -hex 48)"
    echo -e "${verde}      AUTH_SECRET gerado.${reset}"
}

generate_yaml() {
    echo -e "${amarelo}[3/5] Gerando /root/papra.yaml...${reset}"
    cat > /root/papra.yaml << YAML
version: "3.7"
services:
  papra:
    image: ghcr.io/papra-hq/papra:latest
    volumes:
      - papra_db:/app/app-data/db
      - papra_documents:/app/app-data/documents
    networks:
      - ${NOME_REDE_INTERNA}
    environment:
      - APP_BASE_URL=https://${URL_PAPRA}
      - PORT=1221
      - SERVER_HOSTNAME=0.0.0.0
      - SERVER_SERVE_PUBLIC_DIR=true
      - NODE_ENV=production
      - DATABASE_URL=file:./app-data/db/db.sqlite
      - DOCUMENT_STORAGE_DRIVER=filesystem
      - DOCUMENT_STORAGE_FILESYSTEM_ROOT=./app-data/documents
      - AUTH_SECRET=${AUTH_SECRET}
      - AUTH_IS_REGISTRATION_ENABLED=true
      - AUTH_IS_PASSWORD_RESET_ENABLED=true
      - AUTH_IS_EMAIL_VERIFICATION_REQUIRED=false
      - SERVER_CORS_ORIGINS=https://${URL_PAPRA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M
      labels:
        - traefik.enable=true
        - traefik.http.routers.papra.rule=Host(\`${URL_PAPRA}\`)
        - traefik.http.routers.papra.entrypoints=websecure
        - traefik.http.routers.papra.tls.certresolver=letsencryptresolver
        - traefik.http.services.papra.loadbalancer.server.port=1221
        - traefik.http.routers.papra.service=papra
        - traefik.docker.network=${NOME_REDE_INTERNA}

volumes:
  papra_db:
    external: true
    name: papra_db
  papra_documents:
    external: true
    name: papra_documents

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML
    echo -e "${verde}      papra.yaml gerado.${reset}"
}

deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack papra...${reset}"
    if deploy_via_portainer "papra" "/root/papra.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack papra deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy da stack papra.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

persist_data() {
    echo -e "${amarelo}[5/5] Salvando metadados em /root/dados_vps/papra.md...${reset}"
    save_data "papra" "# Papra

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **URL**: https://${URL_PAPRA}
- **Rede**: ${NOME_REDE_INTERNA}
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

> Papra é uma plataforma self-hosted para gerenciamento e assinatura de documentos."
    echo -e "${verde}      Metadados salvos.${reset}"
}

clear
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}       ORION DESIGN — Deploy Papra                         ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
setup_volumes
generate_secrets
generate_yaml
deploy_stack
persist_data

exit $ERRORS
