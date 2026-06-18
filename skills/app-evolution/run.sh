#!/bin/bash
# =============================================================================
# skills/app-evolution/run.sh
# Skill: Deploy da Evolution API (WhatsApp) via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias (injetadas pelo Claude como variáveis de ambiente):
#   URL_EVOLUTION      — domínio da Evolution API (ex: api.seudominio.com.br)
#   SENHA_POSTGRES     — senha do PostgreSQL externo (SENSÍVEL, nunca persistida)
#   NOME_REDE_INTERNA  — rede overlay (ex: OrionNet, lida de traefik.md)
#
# Características da stack:
#   - Container único da Evolution API com Redis embutido
#   - PostgreSQL externo (host=postgres, user=postgres)
#   - AUTHENTICATION_API_KEY gerada via openssl rand -hex 16
#
# Padrão de persistência:
#   /root/evolution.yaml          — stack YAML (padrão Orion)
#   /root/dados_vps/dados_evolution  — metadados (NUNCA grava SENHA_POSTGRES)
# =============================================================================


SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/root/devops/skills/00-core/lib-persistence.sh
source "/root/devops/skills/00-core/lib-persistence.sh"

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

    [ -z "${URL_EVOLUTION:-}" ]     && echo -e "${vermelho}[ERRO] URL_EVOLUTION não informado.${reset}"     && missing=1
    [ -z "${SENHA_POSTGRES:-}" ]    && echo -e "${vermelho}[ERRO] SENHA_POSTGRES não informado.${reset}"    && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo -e "${amarelo}Uso: URL_EVOLUTION=x SENHA_POSTGRES=y NOME_REDE_INTERNA=z ./run.sh${reset}"
        exit 1
    fi
}

# =============================================================================
# GERAÇÃO DA API KEY (openssl rand -hex 16)
# =============================================================================
generate_api_key() {
    echo -e "${amarelo}[1/5] Gerando AUTHENTICATION_API_KEY...${reset}"
    API_KEY="$(openssl rand -hex 16)"
    echo -e "${verde}      API Key gerada (32 caracteres hex).${reset}"
}

# =============================================================================
# VOLUMES (idempotente)
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in evolution_instances evolution_redis; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

# =============================================================================
# GERAÇÃO DO YAML (arquivo salvo em /root/ — padrão Orion)
# =============================================================================
generate_evolution_yaml() {
    echo -e "${amarelo}[3/5] Gerando /root/evolution.yaml...${reset}"

    cat > /root/evolution.yaml << YAML
version: "3.7"
services:

## --------------------------- ORION --------------------------- ##

  evolution_redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - evolution_redis:/data
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]

## --------------------------- ORION --------------------------- ##

  evolution_api:
    image: atendai/evolution-api:latest
    volumes:
      - evolution_instances:/evolution/instances
    networks:
      - ${NOME_REDE_INTERNA}
    environment:
      - SERVER_URL=https://${URL_EVOLUTION}
      - AUTHENTICATION_API_KEY=${API_KEY}
      - AUTHENTICATION_TYPE=apikey
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:${SENHA_POSTGRES}@postgres:5432/evolution?schema=public
      - DATABASE_CONNECTION_CLIENT_NAME=evolution
      - DATABASE_SAVE_DATA_INSTANCE=true
      - DATABASE_SAVE_DATA_NEW_MESSAGE=true
      - DATABASE_SAVE_MESSAGE_UPDATE=true
      - DATABASE_SAVE_DATA_CONTACTS=true
      - DATABASE_SAVE_DATA_CHATS=true
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://evolution_redis:6379/6
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=true
      - CACHE_LOCAL_ENABLED=false
      - DEL_INSTANCE=false
      - LANGUAGE=pt-BR
      - LOG_LEVEL=ERROR
      - LOG_COLOR=true
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.evolution.rule=Host(\`${URL_EVOLUTION}\`)"
        - "traefik.http.routers.evolution.entrypoints=websecure"
        - "traefik.http.routers.evolution.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.evolution.service=evolution"
        - "traefik.http.services.evolution.loadbalancer.server.port=8080"
        - "traefik.http.services.evolution.loadbalancer.passHostHeader=true"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"
        - "traefik.http.routers.evolution.priority=1"

## --------------------------- ORION --------------------------- ##

volumes:
  evolution_instances:
    external: true
    name: evolution_instances
  evolution_redis:
    external: true
    name: evolution_redis

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    attachable: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      evolution.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY DA STACK
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack evolution...${reset}"

    ensure_db "postgres" "evolution" || { echo -e "${vermelho}      [FAIL] erro ao preparar banco evolution.${reset}"; ERRORS=$((ERRORS + 1)); return; }

    if deploy_via_portainer "evolution" "/root/evolution.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack evolution deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy da evolution.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA EM MARKDOWN (NUNCA grava SENHA_POSTGRES)
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Persistindo metadados em /root/dados_vps/dados_evolution...${reset}"

    save_data "evolution" "[ EVOLUTION ]

Dominio: https://$URL_EVOLUTION

Manager: https://$URL_EVOLUTION/manager

Host: evolution_api

Port: 8080

API Key: $API_KEY

Rede: $NOME_REDE_INTERNA"

    echo -e "${verde}      Metadados persistidos (sem senha do PostgreSQL).${reset}"
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
clear 2>/dev/null || true
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}         ORION DESIGN — Deploy Evolution API                ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
generate_api_key
setup_volumes
generate_evolution_yaml
deploy_stack
persist_data

echo ""
echo -e "${amarelo}============================================================${reset}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${verde}  Deploy concluído com sucesso.${reset}"
    echo -e "${branco}  Manager disponível em: https://$URL_EVOLUTION/manager${reset}"
    echo -e "${branco}  API Key salva em: /root/dados_vps/dados_evolution${reset}"
else
    echo -e "${vermelho}  Deploy concluído com $ERRORS erro(s).${reset}"
    echo -e "${branco}  Consulte os logs: docker service ls${reset}"
fi
echo -e "${amarelo}============================================================${reset}"
echo ""

exit $ERRORS
