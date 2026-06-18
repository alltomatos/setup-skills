#!/bin/bash
# =============================================================================
# skills/app-strapi/run.sh
# Skill: Instalação do Strapi via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="strapi"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Ler ou gerar segredos (idempotência)
APP_KEYS=$(read_data "app-strapi" | grep -oP '(?<=- APP_KEYS: ).*' || echo "$(openssl rand -hex 16),$(openssl rand -hex 16),$(openssl rand -hex 16),$(openssl rand -hex 16)")
API_TOKEN_SALT=$(read_data "app-strapi" | grep -oP '(?<=- API_TOKEN_SALT: ).*' || openssl rand -hex 16)
ADMIN_JWT_SECRET=$(read_data "app-strapi" | grep -oP '(?<=- ADMIN_JWT_SECRET: ).*' || openssl rand -hex 16)
TRANSFER_TOKEN_SALT=$(read_data "app-strapi" | grep -oP '(?<=- TRANSFER_TOKEN_SALT: ).*' || openssl rand -hex 16)
JWT_SECRET=$(read_data "app-strapi" | grep -oP '(?<=- JWT_SECRET: ).*' || openssl rand -hex 16)

echo -e "${amarelo}Instalando Strapi no domínio $DOMAIN_STRAPI...${reset}"

# Criar volume
docker volume create strapi_data > /dev/null 2>&1

cat > strapi.yaml <<EOL
version: "3.7"
services:
  strapi:
    image: strapi/strapi:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - strapi_data:/srv/app
    environment:
      - DATABASE_CLIENT=pg
      - DATABASE_HOST=postgres
      - DATABASE_NAME=strapi
      - DATABASE_PORT=5432
      - DATABASE_USERNAME=postgres
      - DATABASE_PASSWORD=\$POSTGRES_PASSWORD
      - JWT_SECRET=$JWT_SECRET
      - ADMIN_JWT_SECRET=$ADMIN_JWT_SECRET
      - APP_KEYS=$APP_KEYS
      - API_TOKEN_SALT=$API_TOKEN_SALT
      - TRANSFER_TOKEN_SALT=$TRANSFER_TOKEN_SALT
      - NODE_ENV=production
      - STRAPI_TELEMETRY_DISABLED=true
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.strapi.rule=Host(\`$DOMAIN_STRAPI\`)"
        - "traefik.http.routers.strapi.entrypoints=websecure"
        - "traefik.http.routers.strapi.tls.certresolver=letsencrypt"
        - "traefik.http.services.strapi.loadbalancer.server.port=1337"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  strapi_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "strapi.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-strapi" "[ STRAPI ]

Dominio: https://$DOMAIN_STRAPI

Host: strapi

Port: 1337

JWT Secret: $JWT_SECRET

Admin JWT Secret: $ADMIN_JWT_SECRET

App Keys: $APP_KEYS

API Token Salt: $API_TOKEN_SALT

Transfer Token Salt: $TRANSFER_TOKEN_SALT

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm strapi.yaml
exit 0
