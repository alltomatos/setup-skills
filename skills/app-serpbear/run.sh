#!/bin/bash
# =============================================================================
# skills/app-serpbear/run.sh
# Skill: Deploy do SerpBear via Docker Swarm (Padrão Orion)
# =============================================================================


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

    [ -z "${URL_SERPBEAR:-}" ]    && echo -e "${vermelho}[ERRO] URL_SERPBEAR não informado.${reset}"    && missing=1
    [ -z "${USER_SERPBEAR:-}" ]   && echo -e "${vermelho}[ERRO] USER_SERPBEAR não informado.${reset}"   && missing=1
    [ -z "${PASS_SERPBEAR:-}" ]   && echo -e "${vermelho}[ERRO] PASS_SERPBEAR não informado.${reset}"   && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}

# =============================================================================
# PREPARAÇÃO
# =============================================================================
prepare() {
    echo -e "${amarelo}[1/5] Gerando chaves secretas...${reset}"

    SECRET_SERPBEAR=$(openssl rand -hex 32)
    APIKEY_SERPBEAR=$(openssl rand -hex 16)

    echo -e "${verde}      Chaves geradas.${reset}"
}

# =============================================================================
# VOLUMES
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in serpbear_appdata; do
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
    echo -e "${amarelo}[3/5] Gerando /root/serpbear.yaml...${reset}"

    cat > /root/serpbear.yaml << YAML
version: "3.7"
services:
  serpbear:
    image: towfiqi/serpbear:latest
    environment:
      - NEXT_PUBLIC_APP_URL=https://${URL_SERPBEAR}
      - USER=${USER_SERPBEAR}
      - PASSWORD=${PASS_SERPBEAR}
      - SECRET=${SECRET_SERPBEAR}
      - APIKEY=${APIKEY_SERPBEAR}
    volumes:
      - serpbear_appdata:/app/data
    networks:
      - ${NOME_REDE_INTERNA}
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
        - "traefik.enable=true"
        - "traefik.http.routers.serpbear.rule=Host(\`${URL_SERPBEAR}\`)"
        - "traefik.http.routers.serpbear.entrypoints=websecure"
        - "traefik.http.routers.serpbear.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.serpbear.loadbalancer.server.port=3000"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

volumes:
  serpbear_appdata:
    external: true
    name: serpbear_appdata

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      serpbear.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack serpbear...${reset}"

    if deploy_via_portainer "serpbear" "/root/serpbear.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack serpbear deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy via Portainer. Tentando CLI direto...${reset}"
        docker stack deploy --prune --resolve-image always -c /root/serpbear.yaml serpbear || ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Salvando metadados em /root/dados_vps/dados_serpbear...${reset}"

    save_data "serpbear" "[ SERPBEAR ]

Dominio: https://${URL_SERPBEAR}

Host: serpbear

Port: 3000

Usuario: ${USER_SERPBEAR}

Senha: ${PASS_SERPBEAR}

Secret: ${SECRET_SERPBEAR}

API Key: ${APIKEY_SERPBEAR}

Rede: ${NOME_REDE_INTERNA}"

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
