#!/bin/bash
# =============================================================================
# skills/app-affine/run.sh
# Skill: Instalacao do AFFiNE via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="affine"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Verificar pgvector
if ! docker service ls --format "{{.Name}}" | grep -q "^pgvector$"; then
    echo -e "\e[31mErro: infra-pgvector nao instalado.\e[0m"
    exit 1
fi

echo -e "${amarelo}Instalando AFFiNE no dominio $DOMAIN_AFFINE...${reset}"

docker volume create affine_storage > /dev/null 2>&1
docker volume create affine_config > /dev/null 2>&1

cat > affine.yaml <<'YAML'
version: "3.7"
services:
  affine_app:
    image: ghcr.io/toeverything/affine:stable
    volumes:
      - affine_storage:/root/.affine/storage
      - affine_config:/root/.affine/config
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - AFFINE_SERVER_EXTERNAL_URL=https://$DOMAIN_AFFINE
      - AFFINE_SERVER_HTTPS=true
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@pgvector:5432/affine?sslmode=disable
      - REDIS_SERVER_HOST=affine_redis
      - REDIS_SERVER_PORT=6379
      - REDIS_SERVER_PASSWORD=
      - AFFINE_SERVER_HOST=0.0.0.0
      - AFFINE_SERVER_PORT=3010
      - NODE_ENV=production
      - STORAGE_PROVIDER=fs
      - AFFINE_INDEXER_ENABLED=true
      - AFFINE_ENABLE_OAUTH=false
      - COPILOT_ENABLED=false
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.affine.rule=Host(`$DOMAIN_AFFINE`)
        - traefik.http.routers.affine.entrypoints=websecure
        - traefik.http.routers.affine.tls.certresolver=letsencrypt
        - traefik.http.services.affine.loadbalancer.server.port=3010
        - traefik.frontend.headers.STSPreload=true
        - traefik.frontend.headers.STSSeconds=31536000
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  affine_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  affine_storage:
    external: true
  affine_config:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

docker stack deploy --prune --resolve-image always -c affine.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-affine" "# AFFiNE\n\n- Status: Instalado\n- URL: https://$DOMAIN_AFFINE"
else
    exit 1
fi

rm -f affine.yaml
exit 0
