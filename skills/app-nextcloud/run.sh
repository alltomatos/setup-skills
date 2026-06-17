#!/bin/bash
# =============================================================================
# skills/app-nextcloud/run.sh
# Skill: Instalacao do Nextcloud via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="nextcloud"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Verificar postgres
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then
    echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"
    exit 1
fi

# Verificar redis
if ! docker service ls --format "{{.Name}}" | grep -q "^redis$"; then
    echo -e "\e[31mErro: infra-redis nao instalado.\e[0m"
    exit 1
fi

echo -e "${amarelo}Instalando Nextcloud no dominio $DOMAIN_NEXTCLOUD...${reset}"

docker volume create nextcloud_data > /dev/null 2>&1
docker volume create nextcloud_redis > /dev/null 2>&1

cat > nextcloud.yaml <<'YAML'
version: "3.7"
services:
  nextcloud_app:
    image: nextcloud:latest
    volumes:
      - nextcloud_data:/var/www/html
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NEXTCLOUD_ADMIN_USER=$NEXTCLOUD_USER
      - NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_PASS
      - POSTGRES_HOST=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_DB=nextcloud
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
      - REDIS_HOST=nextcloud_redis
      - OVERWRITEPROTOCOL=https
      - TRUSTED_PROXIES=127.0.0.1
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.nextcloud.rule=Host(`$DOMAIN_NEXTCLOUD`)
        - traefik.http.routers.nextcloud.entrypoints=web,websecure
        - traefik.http.routers.nextcloud.tls.certresolver=letsencrypt
        - traefik.http.services.nextcloud.loadbalancer.server.port=80
        - traefik.http.routers.nextcloud.middlewares=nextcloud_redirect
        - traefik.http.middlewares.nextcloud_redirect.redirectregex.regex=https://(.*)/.well-known/(?:card|cal)dav
        - traefik.http.middlewares.nextcloud_redirect.redirectregex.replacement=https://$1/remote.php/dav
        - traefik.http.middlewares.nextcloud_redirect.redirectregex.permanent=true
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  nextcloud_cron:
    image: nextcloud:latest
    entrypoint: /cron.sh
    volumes:
      - nextcloud_data:/var/www/html
    deploy:
      restart_policy:
        condition: on-failure
        delay: 30s

  nextcloud_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - nextcloud_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 512M

volumes:
  nextcloud_data:
    external: true
  nextcloud_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "nextcloud.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-nextcloud" "# Nextcloud\n\n- Status: Instalado\n- URL: https://$DOMAIN_NEXTCLOUD\n- Admin: $NEXTCLOUD_USER"
else
    exit 1
fi

rm -f nextcloud.yaml
exit 0
