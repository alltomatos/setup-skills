#!/bin/bash
# =============================================================================
# skills/app-outline/run.sh
# Skill: Instalacao do Outline Wiki via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="outline"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Verificar postgres
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then
    echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"
    exit 1
fi

# Persistencia de Segredos (ADR-001)
if service_exists "app-outline"; then
    EXISTING_DATA=$(read_data "app-outline")
    SECRET_KEY=$(echo "$EXISTING_DATA" | grep "Secret Key: " | sed 's/.*Secret Key: //')
    UTILS_SECRET=$(echo "$EXISTING_DATA" | grep "Utils Secret: " | sed 's/.*Utils Secret: //')
fi

# Gerar segredos se nao existirem
[ -z "$SECRET_KEY" ] && SECRET_KEY=$(openssl rand -hex 32)
[ -z "$UTILS_SECRET" ] && UTILS_SECRET=$(openssl rand -hex 32)

# TLS SMTP
SMTP_SSL="false"
if [ "$SMTP_PORT" -eq 465 ]; then
    SMTP_SSL="true"
fi

echo -e "${amarelo}Instalando Outline no dominio $DOMAIN_OUTLINE...${reset}"

docker volume create outline_uploads > /dev/null 2>&1
docker volume create outline_redis > /dev/null 2>&1

cat > outline.yaml <<'YAML'
version: "3.7"
services:
  outline_app:
    image: outlinewiki/outline:latest
    volumes:
      - outline_uploads:/var/lib/outline/uploads
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - URL=https://$DOMAIN_OUTLINE
      - PORT=3000
      - ENABLE_EMAIL_SIGNIN=true
      - FORCE_HTTPS=true
      - SECRET_KEY=$SECRET_KEY
      - UTILS_SECRET=$UTILS_SECRET
      - DATABASE_URL=postgres://postgres:$POSTGRES_PASSWORD@postgres:5432/outline?sslmode=disable
      - REDIS_URL=redis://outline_redis:6379
      - FILE_STORAGE_UPLOAD_LOCAL=true
      - SMTP_FROM_EMAIL=$SMTP_FROM_EMAIL
      - SMTP_USERNAME=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_HOST=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - MAIL_SSL_ENABLE=$SMTP_SSL
      - DEFAULT_LANGUAGE=pt_BR
      - WEB_CONCURRENCY=2
      - OIDC_CLIENT_ID=$OUTLINE_GOOGLE_CLIENT_ID
      - OIDC_CLIENT_SECRET=$OUTLINE_GOOGLE_CLIENT_SECRET
      - OIDC_AUTH_URI=https://accounts.google.com/o/oauth2/auth
      - OIDC_TOKEN_URI=https://oauth2.googleapis.com/token
      - OIDC_USERINFO_URI=https://www.googleapis.com/oauth2/v3/userinfo
      - OIDC_USERNAME_CLAIM=preferred_username
      - OIDC_DISPLAY_NAME=Google
      - OIDC_SCOPES=email profile openid
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.outline.rule=Host(`$DOMAIN_OUTLINE`)
        - traefik.http.routers.outline.entrypoints=websecure
        - traefik.http.routers.outline.tls.certresolver=letsencryptresolver
        - traefik.http.services.outline.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  outline_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - outline_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  outline_uploads:
    external: true
  outline_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "outline.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-outline" "[ OUTLINE ]

Dominio: https://$DOMAIN_OUTLINE

Host: outline_app

Port: 3000

Secret Key: $SECRET_KEY

Utils Secret: $UTILS_SECRET

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f outline.yaml
exit 0
