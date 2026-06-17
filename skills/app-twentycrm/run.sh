#!/bin/bash
# =============================================================================
# skills/app-twentycrm/run.sh
# Skill: Instalação do Twenty CRM via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="twenty"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Gerar segredos
POSTGRES_PASSWORD=$(openssl rand -hex 16)
APP_SECRET=$(openssl rand -hex 32)

echo -e "${amarelo}Instalando Twenty CRM no domínio $DOMAIN_TWENTY...${reset}"

# Criar volumes
docker volume create twenty_data > /dev/null 2>&1
docker volume create twenty_docker > /dev/null 2>&1
docker volume create twenty_db > /dev/null 2>&1
docker volume create twenty_redis > /dev/null 2>&1

cat > twenty.yaml <<EOL
version: "3.7"
services:
  twenty_server:
    image: twentycrm/twenty:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - twenty_data:/app/packages/twenty-server/.local-storage
      - twenty_docker:/app/docker-data
    environment:
      - PORT=3000
      - SERVER_URL=https://$DOMAIN_TWENTY
      - REDIS_URL=redis://twenty_redis:6379
      - PG_DATABASE_URL=postgres://postgres:$POSTGRES_PASSWORD@twenty_db:5432/twenty
      - STORAGE_TYPE=local
      - APP_SECRET=$APP_SECRET
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.twenty.rule=Host(\`$DOMAIN_TWENTY\`)"
        - "traefik.http.routers.twenty.entrypoints=websecure"
        - "traefik.http.routers.twenty.tls.certresolver=letsencrypt"
        - "traefik.http.services.twenty.loadbalancer.server.port=3000"
      resources:
        limits:
          cpus: "1"
          memory: 2048M

  twenty_worker:
    image: twentycrm/twenty:latest
    command: ["yarn", "worker:prod"]
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - PORT=3000
      - SERVER_URL=https://$DOMAIN_TWENTY
      - REDIS_URL=redis://twenty_redis:6379
      - PG_DATABASE_URL=postgres://postgres:$POSTGRES_PASSWORD@twenty_db:5432/twenty
      - DISABLE_DB_MIGRATIONS=true
      - STORAGE_TYPE=local
      - APP_SECRET=$APP_SECRET
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

  twenty_db:
    image: twentycrm/twenty-postgres-spilo:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - twenty_db:/home/postgres/pgdata
    environment:
      - PGUSER_SUPERUSER=postgres
      - POSTGRES_DB=twenty
      - POSTGRESQL_PASSWORD=$POSTGRES_PASSWORD
      - PGPASSWORD_SUPERUSER=$POSTGRES_PASSWORD
      - ALLOW_NOSSL=true
      - SPILO_PROVIDER=local

  twenty_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - twenty_redis:/data

volumes:
  twenty_data:
    external: true
  twenty_docker:
    external: true
  twenty_db:
    external: true
  twenty_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "twenty.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-twentycrm" "# Twenty CRM\n\n- Status: Instalado\n- URL: https://$DOMAIN_TWENTY\n- DB: Spilo (Postgres)\n- Secret: $APP_SECRET"
else
    exit 1
fi

rm twenty.yaml
exit 0
