#!/bin/bash
# skills/app-vaultwarden/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="vaultwarden"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi
ADMIN_TOKEN=$(openssl rand -hex 16)
SSL_MODE="starttls"; [ "$SMTP_PORT" -eq 465 ] && SSL_MODE="force_tls"
echo -e "${amarelo}Instalando Vaultwarden...${reset}"
docker volume create vaultwarden_data > /dev/null 2>&1
cat > vaultwarden.yaml <<'YAML'
version: "3.7"
services:
  vaultwarden:
    image: vaultwarden/server:latest
    volumes:
      - vaultwarden_data:/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - WEB_VAULT_ENABLED=true
      - DOMAIN=https://$DOMAIN_VAULTWARDEN
      - ADMIN_TOKEN=$ADMIN_TOKEN
      - ADMIN_SESSION_LIFETIME=5
      - SIGNUPS_ALLOWED=true
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/vaultwarden?sslmode=disable
      - SMTP_FROM=$SMTP_FROM_EMAIL
      - SMTP_USERNAME=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_HOST=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_SECURITY=$SSL_MODE
      - WEBSOCKET_ENABLED=true
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.vaultwarden.rule=Host(`$DOMAIN_VAULTWARDEN`)
        - traefik.http.routers.vaultwarden.entrypoints=websecure
        - traefik.http.routers.vaultwarden.tls.certresolver=letsencrypt
        - traefik.http.services.vaultwarden.loadbalancer.server.port=80
        - traefik.http.services.vaultwarden.loadbalancer.passHostHeader=true
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  vaultwarden_data:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
docker stack deploy --prune --resolve-image always -c vaultwarden.yaml $STACK_NAME
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-vaultwarden" "# Vaultwarden\n\n- Status: Instalado\n- URL: https://$DOMAIN_VAULTWARDEN\n- Admin: /admin"
rm -f vaultwarden.yaml; exit 0