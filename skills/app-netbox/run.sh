#!/bin/bash
# =============================================================================
# skills/app-netbox/run.sh
# Skill: Instalação do NetBox via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="netbox"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Persistência de Segredos (ADR-001)
if service_exists "app-netbox"; then
    DB_PASSWORD=$(read_data "app-netbox" | grep "DB_PASSWORD:" | awk '{print $2}')
    SECRET_KEY=$(read_data "app-netbox" | grep "SECRET_KEY:" | awk '{print $2}')
    TOKEN_PEPPER=$(read_data "app-netbox" | grep "TOKEN_PEPPER:" | awk '{print $2}')
fi

# Geração de chaves se não existirem (ADR-002: runtime fallback)
DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -hex 16)}
SECRET_KEY=${SECRET_KEY:-$(openssl rand -hex 25)}
TOKEN_PEPPER=${TOKEN_PEPPER:-$(openssl rand -hex 16)}

echo -e "${amarelo}Instalando NetBox em $DOMAIN_NETBOX...${reset}"

# Criando volumes
docker volume create netbox_media_files > /dev/null 2>&1
docker volume create netbox_db_data > /dev/null 2>&1
docker volume create netbox_redis_data > /dev/null 2>&1
docker volume create netbox_redis_cache_data > /dev/null 2>&1
docker volume create netbox_reports_files > /dev/null 2>&1
docker volume create netbox_scripts_files > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > netbox${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: docker.io/netboxcommunity/netbox:v4.4-3.4.2
    volumes:
      - netbox_media_files:/opt/netbox/netbox/media:rw
      - netbox_reports_files:/opt/netbox/netbox/reports:rw
      - netbox_scripts_files:/opt/netbox/netbox/scripts:rw
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DB_HOST=db
      - DB_NAME=netbox
      - DB_PASSWORD=$DB_PASSWORD
      - DB_USER=postgres
      - REDIS_HOST=redis
      - REDIS_PASSWORD=
      - REDIS_DATABASE=0
      - REDIS_SSL=false
      - REDIS_CACHE_HOST=redis_cache
      - REDIS_CACHE_PASSWORD=
      - REDIS_CACHE_DATABASE=1
      - REDIS_CACHE_SSL=false
      - SECRET_KEY=$SECRET_KEY
      - API_TOKEN_PEPPER_1=$TOKEN_PEPPER
      - MEDIA_ROOT=/opt/netbox/netbox/media
      - CORS_ORIGIN_ALLOW_ALL=True
      - GRAPHQL_ENABLED=true
      - WEBHOOKS_ENABLED=true
      - METRICS_ENABLED=false
      - SKIP_SUPERUSER=false
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M
      labels:
        - traefik.enable=true
        - traefik.http.routers.netbox.rule=Host(\`$DOMAIN_NETBOX\`)
        - traefik.http.services.netbox.loadbalancer.server.port=8080
        - traefik.http.routers.netbox.service=netbox
        - traefik.http.routers.netbox.tls.certresolver=letsencrypt
        - traefik.http.routers.netbox.entrypoints=websecure
        - traefik.http.routers.netbox.tls=true

  worker:
    image: docker.io/netboxcommunity/netbox:v4.4-3.4.2
    command: ["/opt/netbox/venv/bin/python", "/opt/netbox/netbox/manage.py", "rqworker"]
    volumes:
      - netbox_media_files:/opt/netbox/netbox/media:rw
      - netbox_reports_files:/opt/netbox/netbox/reports:rw
      - netbox_scripts_files:/opt/netbox/netbox/scripts:rw
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DB_HOST=db
      - DB_NAME=netbox
      - DB_PASSWORD=$DB_PASSWORD
      - DB_USER=postgres
      - REDIS_HOST=redis
      - REDIS_DATABASE=0
      - REDIS_CACHE_HOST=redis_cache
      - REDIS_CACHE_DATABASE=1
      - SECRET_KEY=$SECRET_KEY
    deploy:
      placement:
        constraints:
          - node.role == manager

  db:
    image: docker.io/postgres:17-alpine
    volumes:
      - netbox_db_data:/var/lib/postgresql/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - POSTGRES_DB=netbox
      - POSTGRES_PASSWORD=$DB_PASSWORD
    deploy:
      placement:
        constraints:
          - node.role == manager

  redis:
    image: docker.io/valkey/valkey:8.1-alpine
    command: ["valkey-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - netbox_redis_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

  redis_cache:
    image: docker.io/valkey/valkey:8.1-alpine
    command: ["valkey-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - netbox_redis_cache_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  netbox_media_files:
    external: true
  netbox_db_data:
    external: true
  netbox_redis_data:
    external: true
  netbox_redis_cache_data:
    external: true
  netbox_reports_files:
    external: true
  netbox_scripts_files:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "netbox${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-netbox" "# NetBox\n\n- Status: Instalado\n- URL: https://$DOMAIN_NETBOX\n- Usuário: admin\n- Senha: admin\n- DB_PASSWORD: $DB_PASSWORD\n- SECRET_KEY: $SECRET_KEY\n- TOKEN_PEPPER: $TOKEN_PEPPER"
else
    exit 1
fi

rm -f netbox${SUFFIX}.yaml
exit 0
