#!/bin/bash
# =============================================================================
# skills/infra-redis/run.sh
# Skill: Instalação do Redis via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
reset="\e[0m"

# Variáveis
STACK_NAME="redis"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Redis via Docker Swarm...${reset}"

docker volume create redis_data > /dev/null 2>&1

cat > redis.yaml <<EOL
version: "3.7"
services:
  redis:
    image: redis:latest
    command: [
        "redis-server",
        "--appendonly",
        "yes",
        "--port",
        "6379"
      ]
    volumes:
      - redis_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 2048M

volumes:
  redis_data:
    external: true
    name: redis_data

networks:
  $NOME_REDE_INTERNA:
    external: true
    name: $NOME_REDE_INTERNA
EOL

deploy_via_portainer "$STACK_NAME" "redis.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    
    CONTENT="# Redis (Infra/Cache)

- **Status**: Instalado
- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **Host**: redis
- **Porta**: 6379
- **Rede**: $NOME_REDE_INTERNA
- **Persistência (AOF)**: Ativado
"
    save_data "infra-redis" "$CONTENT"
else
    echo -e "${vermelho}Erro ao fazer o deploy da stack Redis.${reset}"
    exit 1
fi

rm redis.yaml
exit 0
