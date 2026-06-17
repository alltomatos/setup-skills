#!/bin/bash
# =============================================================================
# skills/app-openproject/run.sh
# Skill: Instalação do OpenProject via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="openproject"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Geração de chaves (ADR-002)
SECRET_KEY=$(openssl rand -hex 16)
DB_PASSWORD=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando OpenProject em $DOMAIN_OPENPROJECT...${reset}"

docker volume create openproject_pgdata > /dev/null 2>&1
docker volume create openproject_assets > /dev/null 2>&1
docker volume create openproject_db_data > /dev/null 2>&1
docker volume create openproject_redis_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > openproject${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: openproject/openproject:16
    volumes:
      - openproject_pgdata:/var/openproject/pgdata
      - openproject_assets:/var/openproject/assets
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - OPENPROJECT_SECRET_KEY_BASE=$SECRET_KEY
      - OPENPROJECT_HOST__NAME=$DOMAIN_OPENPROJECT
      - OPENPROJECT_HTTPS=true
      - OPENPROJECT_RAILS__CACHE__STORE=redis
      - OPENPROJECT_CACHE_REDIS_URL=redis://redis:6379
      - OPENPROJECT_DATABASE_HOST=db
      - OPENPROJECT_DATABASE_PORT=5432
      - OPENPROJECT_DATABASE_NAME=openproject
      - OPENPROJECT_DATABASE_USERNAME=postgres
      - OPENPROJECT_DATABASE_PASSWORD=$DB_PASSWORD
      - OPENPROJECT_DEFAULT__LANGUAGE=pt-BR
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.openproject.rule=Host(\`$DOMAIN_OPENPROJECT\`)
        - traefik.http.routers.openproject.entrypoints=websecure
        - traefik.http.routers.openproject.tls.certresolver=letsencrypt
        - traefik.http.routers.openproject.service=openproject
        - traefik.http.services.openproject.loadbalancer.server.port=8080

  db:
    image: postgres:17
    command: ["postgres", "-c", "max_connections=500", "-c", "shared_buffers=512MB", "-c", "timezone=America/Sao_Paulo"]
    volumes:
      - openproject_db_data:/var/lib/postgresql/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - POSTGRES_DB=openproject
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - TZ=America/Sao_Paulo
    deploy:
      placement:
        constraints:
          - node.role == manager

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - openproject_redis_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  openproject_pgdata:
    external: true
  openproject_assets:
    external: true
  openproject_db_data:
    external: true
  openproject_redis_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

docker stack deploy --prune --resolve-image always -c openproject${SUFFIX}.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-openproject" "# OpenProject\n\n- Status: Instalado\n- URL: https://$DOMAIN_OPENPROJECT\n- Usuário: admin\n- Senha: admin"
else
    exit 1
fi

rm -f openproject${SUFFIX}.yaml
exit 0
