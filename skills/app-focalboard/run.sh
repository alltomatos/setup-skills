#!/bin/bash
# =============================================================================
# skills/app-focalboard/run.sh
# Skill: Deploy do Focalboard via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias:
#   URL_FOCALBOARD     — domínio para o serviço (ex: focalboard.seudominio.com.br)
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
    [ -z "${URL_FOCALBOARD:-}" ]    && echo -e "${vermelho}[ERRO] URL_FOCALBOARD não informado.${reset}"    && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        echo -e "${amarelo}Uso: URL_FOCALBOARD=x NOME_REDE_INTERNA=y ./run.sh${reset}"
        exit 1
    fi
}

setup_volumes() {
    echo -e "${amarelo}[1/4] Criando volumes persistentes...${reset}"
    if ! docker volume ls --format '{{.Name}}' | grep -q "^focalboard_data$"; then
        docker volume create focalboard_data > /dev/null 2>&1
        echo -e "${verde}      Volume criado: focalboard_data${reset}"
    else
        echo -e "${verde}      Volume existente: focalboard_data${reset}"
    fi
}

generate_yaml() {
    echo -e "${amarelo}[2/4] Gerando /root/focalboard.yaml...${reset}"
    cat > /root/focalboard.yaml << YAML
version: "3.8"
services:
  focalboard:
    image: mattermost/focalboard:latest
    volumes:
      - focalboard_data:/opt/focalboard/data
    networks:
      - ${NOME_REDE_INTERNA}
    environment:
      - VIRTUAL_HOST=${URL_FOCALBOARD}
      - VIRTUAL_PORT=8000
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
        - traefik.http.routers.focalboard.rule=Host(\`${URL_FOCALBOARD}\`)
        - traefik.http.routers.focalboard.entrypoints=websecure
        - traefik.http.routers.focalboard.tls.certresolver=letsencryptresolver
        - traefik.http.services.focalboard.loadbalancer.server.port=8000
        - traefik.http.routers.focalboard.service=focalboard
        - traefik.docker.network=${NOME_REDE_INTERNA}

volumes:
  focalboard_data:
    external: true
    name: focalboard_data

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML
    echo -e "${verde}      focalboard.yaml gerado.${reset}"
}

deploy_stack() {
    echo -e "${amarelo}[3/4] Executando deploy da stack focalboard...${reset}"
    if deploy_via_portainer "focalboard" "/root/focalboard.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack focalboard deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy da stack focalboard.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

persist_data() {
    echo -e "${amarelo}[4/4] Salvando metadados em /root/dados_vps/focalboard.md...${reset}"
    save_data "focalboard" "# Focalboard

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **URL**: https://${URL_FOCALBOARD}
- **Rede**: ${NOME_REDE_INTERNA}
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

> Focalboard é uma ferramenta de gerenciamento de projetos open source, alternativa ao Trello e Notion."
    echo -e "${verde}      Metadados salvos.${reset}"
}

clear
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}       ORION DESIGN — Deploy Focalboard                    ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
setup_volumes
generate_yaml
deploy_stack
persist_data

exit $ERRORS
