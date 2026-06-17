#!/bin/bash
# skills/app-authentik/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="authentik"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi

# Persistencia de Segredos (ADR-001)
if service_exists "app-authentik"; then
    SECRET_KEY=$(read_data "app-authentik" | grep "Secret Key: " | sed 's/.*Secret Key: //')
fi
[ -z "$SECRET_KEY" ] && SECRET_KEY=$(openssl rand -hex 32)

echo -e "${amarelo}Instalando Authentik...${reset}"
docker volume create authentik_media > /dev/null 2>&1
docker volume create authentik_templates > /dev/null 2>&1
docker volume create authentik_certs > /dev/null 2>&1
cat > authentik.yaml <<'YAML'
version: "3.7"
services:
  authentik_server:
    image: ghcr.io/goauthentik/server:latest
    command: server
    volumes:
      - authentik_media:/data/media
      - authentik_templates:/templates
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - AUTHENTIK_BOOTSTRAP_EMAIL=$AUTHENTIK_EMAIL
      - AUTHENTIK_BOOTSTRAP_PASSWORD=$AUTHENTIK_PASS
      - AUTHENTIK_POSTGRESQL__HOST=postgres
      - AUTHENTIK_POSTGRESQL__NAME=authentik
      - AUTHENTIK_POSTGRESQL__PASSWORD=$POSTGRES_PASSWORD
      - AUTHENTIK_POSTGRESQL__USER=postgres
      - AUTHENTIK_REDIS__HOST=authentik_redis
      - AUTHENTIK_REDIS__PORT=6379
      - AUTHENTIK_SECRET_KEY=$SECRET_KEY
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.authentik.rule=Host(`$DOMAIN_AUTHENTIK`)
        - traefik.http.routers.authentik.entrypoints=websecure
        - traefik.http.routers.authentik.tls.certresolver=letsencrypt
        - traefik.http.services.authentik.loadbalancer.server.port=9000
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  authentik_worker:
    image: ghcr.io/goauthentik/server:latest
    command: worker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - authentik_media:/data/media
      - authentik_certs:/certs
      - authentik_templates:/templates
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - AUTHENTIK_BOOTSTRAP_EMAIL=$AUTHENTIK_EMAIL
      - AUTHENTIK_BOOTSTRAP_PASSWORD=$AUTHENTIK_PASS
      - AUTHENTIK_POSTGRESQL__HOST=postgres
      - AUTHENTIK_POSTGRESQL__NAME=authentik
      - AUTHENTIK_POSTGRESQL__PASSWORD=$POSTGRES_PASSWORD
      - AUTHENTIK_POSTGRESQL__USER=postgres
      - AUTHENTIK_REDIS__HOST=authentik_redis
      - AUTHENTIK_REDIS__PORT=6379
      - AUTHENTIK_SECRET_KEY=$SECRET_KEY
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  authentik_redis:
    image: redis:latest
    command: ["redis-server","--appendonly","yes"]
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  authentik_media:
    external: true
  authentik_templates:
    external: true
  authentik_certs:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "authentik.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-authentik" "# Authentik\n\n- Status: Instalado\n- URL: https://$DOMAIN_AUTHENTIK\n- Secret Key: $SECRET_KEY"
rm -f authentik.yaml; exit 0