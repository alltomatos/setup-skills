#!/bin/bash
# =============================================================================
# skills/app-browserless/run.sh
# Skill: Deploy do Browserless via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias:
#   URL_BROWSERLESS    — domínio para o serviço (ex: browserless.seudominio.com.br)
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
    [ -z "${URL_BROWSERLESS:-}" ]   && echo -e "${vermelho}[ERRO] URL_BROWSERLESS não informado.${reset}"   && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        echo -e "${amarelo}Uso: URL_BROWSERLESS=x NOME_REDE_INTERNA=y ./run.sh${reset}"
        exit 1
    fi
}

generate_yaml() {
    echo -e "${amarelo}[1/3] Gerando /root/browserless.yaml...${reset}"
    cat > /root/browserless.yaml << YAML
version: "3.7"
services:
  browserless:
    image: browserless/chrome:latest
    networks:
      - ${NOME_REDE_INTERNA}
    environment:
      - MAX_CONCURRENT_SESSIONS=20
      - MAX_QUEUE_LENGTH=40
      - CONNECTION_TIMEOUT=60000
      - WORKSPACE_DELETE_EXPIRED=1
      - WORKSPACE_EXPIRE_DAYS=1
      - PREBOOT_CHROME=1
      - KEEP_ALIVE=1
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M
      labels:
        - traefik.enable=true
        - traefik.http.routers.browserless.rule=Host(\`${URL_BROWSERLESS}\`)
        - traefik.http.routers.browserless.entrypoints=websecure
        - traefik.http.routers.browserless.tls.certresolver=letsencryptresolver
        - traefik.http.services.browserless.loadbalancer.server.port=3000
        - traefik.http.routers.browserless.service=browserless
        - traefik.docker.network=${NOME_REDE_INTERNA}

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML
    echo -e "${verde}      browserless.yaml gerado.${reset}"
}

deploy_stack() {
    echo -e "${amarelo}[2/3] Executando deploy da stack browserless...${reset}"
    if deploy_via_portainer "browserless" "/root/browserless.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack browserless deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy da stack browserless.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

persist_data() {
    echo -e "${amarelo}[3/3] Salvando metadados em /root/dados_vps/browserless.md...${reset}"
    save_data "browserless" "# Browserless

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **URL**: https://${URL_BROWSERLESS}
- **Rede**: ${NOME_REDE_INTERNA}
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

> Browserless é um serviço que fornece instâncias do Chrome headless prontas para uso via APIs (Puppeteer, Playwright, etc)."
    echo -e "${verde}      Metadados salvos.${reset}"
}

clear
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}       ORION DESIGN — Deploy Browserless                    ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
generate_yaml
deploy_stack
persist_data

exit $ERRORS
