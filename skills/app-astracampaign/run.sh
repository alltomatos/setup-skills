#!/bin/bash
# =============================================================================
# skills/app-astracampaign/run.sh
# Skill: Deploy do AstraCampaign via Docker Swarm (Padrão Orion)
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

# =============================================================================
# VALIDAÇÃO DE ENTRADAS
# =============================================================================
validate_inputs() {
    local missing=0

    [ -z "${URL_ASTRACAMPAIGN:-}" ] && echo -e "${vermelho}[ERRO] URL_ASTRACAMPAIGN não informado.${reset}" && missing=1
    [ -z "${SENHA_POSTGRES:-}" ]    && echo -e "${vermelho}[ERRO] SENHA_POSTGRES não informado.${reset}"    && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}

# =============================================================================
# PREPARAÇÃO
# =============================================================================
prepare() {
    echo -e "${amarelo}[1/5] Gerando JWT Secret...${reset}"

    JWTSECRET_ASTRACAMPAIGN=$(openssl rand -hex 16)

    echo -e "${verde}      JWT Secret gerado.${reset}"
}

# =============================================================================
# VOLUMES
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in astracampaign_contacts astracampaign_uploads astracampaign_backup; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

# =============================================================================
# GERAÇÃO DO YAML
# =============================================================================
generate_yaml() {
    echo -e "${amarelo}[3/5] Gerando /root/astracampaign.yaml...${reset}"

    cat > /root/astracampaign.yaml << YAML
version: "3.7"
services:
  astracampaign_backend:
    image: astraonline/astracampaignbackend:latest
    environment:
      - DATABASE_URL=postgresql://postgres:${SENHA_POSTGRES}@postgres:5432/astracampaign
      - REDIS_URL=redis://astracampaign_redis:6379
      - REDIS_PREFIX=work_app
      - PORT=3001
      - NODE_ENV=production
      - JWT_SECRET=${JWTSECRET_ASTRACAMPAIGN}
      - JWT_EXPIRES_IN=24h
      - DEFAULT_COMPANY_NAME=SetupOrion
      - DEFAULT_PAGE_TITLE=Sistema de Gestão de Contatos
      - ALLOWED_ORIGINS=https://${URL_ASTRACAMPAIGN},http://${URL_ASTRACAMPAIGN},http://astracampaign_frontend,http://astracampaign_frontend:80
    volumes:
      - astracampaign_contacts:/app/data
      - astracampaign_uploads:/app/uploads
      - astracampaign_backup:/app/backups
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.astracampaign-backend.rule=Host(\`${URL_ASTRACAMPAIGN}\`) && PathPrefix(\`/api\`)"
        - "traefik.http.routers.astracampaign-backend.entrypoints=websecure"
        - "traefik.http.routers.astracampaign-backend.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.astracampaign-backend.loadbalancer.server.port=3001"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

  astracampaign_frontend:
    image: astraonline/astracampaignfrontend:latest
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.astracampaign-frontend.rule=Host(\`${URL_ASTRACAMPAIGN}\`)"
        - "traefik.http.routers.astracampaign-frontend.entrypoints=websecure"
        - "traefik.http.routers.astracampaign-frontend.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.astracampaign-frontend.loadbalancer.server.port=80"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

  astracampaign_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager

volumes:
  astracampaign_contacts:
    external: true
    name: astracampaign_contacts
  astracampaign_uploads:
    external: true
    name: astracampaign_uploads
  astracampaign_backup:
    external: true
    name: astracampaign_backup

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      astracampaign.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack astracampaign...${reset}"

    if deploy_via_portainer "astracampaign" "/root/astracampaign.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack astracampaign deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy via Portainer. Tentando CLI direto...${reset}"
        docker stack deploy --prune --resolve-image always -c /root/astracampaign.yaml astracampaign || ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Salvando metadados em /root/dados_vps/astracampaign.md...${reset}"

    save_data "astracampaign" "# AstraCampaign

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **URL**: https://${URL_ASTRACAMPAIGN}
- **Backend**: https://${URL_ASTRACAMPAIGN}/api
- **Banco de Dados**: PostgreSQL (host: postgres, db: astracampaign)
- **Queue**: Redis (serviço interno: astracampaign_redis)
- **Rede**: ${NOME_REDE_INTERNA}
- **Stack YAML**: /root/astracampaign.yaml
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

## Nota de Segurança
> A senha do banco de dados não é armazenada aqui.
> O JWT_SECRET foi gerado automaticamente."

    echo -e "${verde}      Metadados salvos.${reset}"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================
validate_inputs
prepare
setup_volumes
generate_yaml
deploy_stack
persist_data

exit $ERRORS
