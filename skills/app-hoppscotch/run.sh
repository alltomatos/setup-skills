#!/bin/bash
# skills/app-hoppscotch/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="hoppscotch"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi
ENC_KEY=$(openssl rand -hex 16); JWT_KEY=$(openssl rand -hex 16); SESSION_KEY=$(openssl rand -hex 16)
echo -e "${amarelo}Instalando Hoppscotch...${reset}"
cat > hoppscotch.yaml <<'YAML'
version: "3.8"
services:
  hoppscotch_frontend:
    image: hoppscotch/hoppscotch-frontend:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - VITE_BASE_URL=https://$DOMAIN_HOPPSCOTCH
      - VITE_SHORTCODE_BASE_URL=https://$DOMAIN_HOPPSCOTCH
      - VITE_ADMIN_URL=https://$DOMAIN_HOPPSCOTCH_ADMIN
      - VITE_BACKEND_GQL_URL=https://$DOMAIN_HOPPSCOTCH_BACKEND/graphql
      - VITE_BACKEND_WS_URL=wss://$DOMAIN_HOPPSCOTCH_BACKEND/graphql
      - VITE_BACKEND_API_URL=https://$DOMAIN_HOPPSCOTCH_BACKEND/v1
      - VITE_ALLOWED_AUTH_PROVIDERS=EMAIL
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.hoppscotch_frontend.rule=Host(`$DOMAIN_HOPPSCOTCH`)
        - traefik.http.routers.hoppscotch_frontend.entrypoints=websecure
        - traefik.http.routers.hoppscotch_frontend.tls.certresolver=letsencrypt
        - traefik.http.services.hoppscotch_frontend.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

  hoppscotch_backend:
    image: hoppscotch/hoppscotch-backend:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - URL=https://$DOMAIN_HOPPSCOTCH
      - ADMIN_URL=https://$DOMAIN_HOPPSCOTCH_ADMIN
      - TOKEN_EXPIRY_TIME=2592000
      - SHORTCODE_URL=https://$DOMAIN_HOPPSCOTCH
      - ENCRYPTION_KEY=$ENC_KEY
      - JWT_SECRET=$JWT_KEY
      - SESSION_SECRET=$SESSION_KEY
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/hoppscotch?sslmode=disable
      - SMTP_HOST=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_USER=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_FROM=$SMTP_FROM_EMAIL
      - SMTP_SECURE=false
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.hoppscotch_backend.rule=Host(`$DOMAIN_HOPPSCOTCH_BACKEND`)
        - traefik.http.routers.hoppscotch_backend.entrypoints=websecure
        - traefik.http.routers.hoppscotch_backend.tls.certresolver=letsencrypt
        - traefik.http.services.hoppscotch_backend.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
docker stack deploy --prune --resolve-image always -c hoppscotch.yaml $STACK_NAME
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-hoppscotch" "# Hoppscotch\n\n- Status: Instalado\n- URL: https://$DOMAIN_HOPPSCOTCH"
rm -f hoppscotch.yaml; exit 0