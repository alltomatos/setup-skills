#!/bin/bash
# =============================================================================
# skills/infra-clickhouse/run.sh
# Skill: Instalação do ClickHouse via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
reset="\e[0m"

# Variáveis
STACK_NAME="clickhouse"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

if [ -z "$CLICKHOUSE_PASSWORD" ]; then
    CLICKHOUSE_PASSWORD=$(openssl rand -hex 16)
    GEN_PWD=true
else
    GEN_PWD=false
fi

echo -e "${amarelo}Instalando ClickHouse via Docker Swarm...${reset}"

docker volume create clickhouse_data > /dev/null 2>&1

cat > clickhouse.yaml <<EOL
version: "3.7"
services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    volumes:
      - clickhouse_data:/var/lib/clickhouse
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - CLICKHOUSE_USER=default
      - CLICKHOUSE_PASSWORD=$CLICKHOUSE_PASSWORD
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2048M
EOL

docker stack deploy --prune --resolve-image always -c clickhouse.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "infra-clickhouse" "# ClickHouse (Analytics)\n\n- Status: Instalado\n- Host: clickhouse\n- Porta: 8123 (HTTP), 9000 (Native)\n- Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm clickhouse.yaml
exit 0
