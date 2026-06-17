#!/bin/bash
# =============================================================================
# skills/app-nocodb/run.sh
# Skill: Instalacao do NocoDB via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="nocodb"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Verificar postgres
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then
    echo -e "\e[31mErro: infra-postgres nao instalado. Execute /devops primeiro.\e[0m"
    exit 1
fi

# Gerar segredo (ADR-002)
JWT_SECRET=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando NocoDB no dominio $DOMAIN_NOCODB...${reset}"

docker volume create nocodb_data > /dev/null 2>&1
docker volume create nocodb_redis > /dev/null 2>&1

cat > nocodb.yaml <<'YAML'
version: "3.7"
services:
  nocodb_app:
    image: nocodb/nocodb:latest
    volumes:
      - nocodb_data:/usr/app/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NC_PUBLIC_URL=https://$DOMAIN_NOCODB
      - NC_DB=pg://postgres:5432?u=postgres&p=$POSTGRES_PASSWORD&d=nocodb
      - NC_REDIS_URL=redis://nocodb_redis:6379
      - NC_DISABLE_TELE=true
      - NC_AUTH_JWT_SECRET=$JWT_SECRET
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.nocodb_app.rule=Host(`$DOMAIN_NOCODB`)
        - traefik.http.routers.nocodb_app.entrypoints=websecure
        - traefik.http.routers.nocodb_app.tls.certresolver=letsencrypt
        - traefik.http.services.nocodb_app.loadbalancer.server.port=8080
        - traefik.http.routers.nocodb_app.service=nocodb_app
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  nocodb_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - nocodb_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  nocodb_data:
    external: true
  nocodb_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "nocodb.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-nocodb" "# NocoDB\n\n- Status: Instalado\n- URL: https://$DOMAIN_NOCODB"
else
    exit 1
fi

rm -f nocodb.yaml
exit 0
