#!/bin/bash
# =============================================================================
# skills/app-lowcoder/run.sh
# Skill: Instalacao do Lowcoder via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="lowcoder"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Verificar mongodb
if ! docker service ls --format "{{.Name}}" | grep -q "^mongodb$"; then
    echo -e "\e[31mErro: infra-mongodb nao instalado.\e[0m"
    exit 1
fi

# Verificar redis
if ! docker service ls --format "{{.Name}}" | grep -q "^redis$"; then
    echo -e "\e[31mErro: infra-redis nao instalado.\e[0m"
    exit 1
fi

# Gerar segredos (ADR-002)
ENC_KEY1=$(openssl rand -hex 16)
ENC_KEY2=$(openssl rand -hex 16)
API_SECRET=$(openssl rand -hex 32)
NODE_SECRET=$(openssl rand -hex 32)

# TLS SMTP
SMTP_SSL="false"
SMTP_TLS="false"
if [ "$SMTP_PORT" -eq 465 ]; then
    SMTP_SSL="true"
else
    SMTP_TLS="true"
fi

echo -e "${amarelo}Instalando Lowcoder no dominio $DOMAIN_LOWCODER...${reset}"

docker volume create lowcoder_assets > /dev/null 2>&1

cat > lowcoder.yaml <<'YAML'
version: "3.7"
services:
  lowcoder_api:
    image: lowcoderorg/lowcoder-ce-api-service:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - LOWCODER_SUPERUSER_USERNAME=$ADMIN_EMAIL
      - LOWCODER_SUPERUSER_PASSWORD=$ADMIN_PASSWORD
      - LOWCODER_PUBLIC_URL=https://$DOMAIN_LOWCODER/
      - LOWCODER_NODE_SERVICE_URL=http://lowcoder_node:6060
      - LOWCODER_MONGODB_URL=mongodb://mongodb:27017/lowcoder?authSource=admin
      - LOWCODER_REDIS_URL=redis://redis:6379
      - LOWCODER_ADMIN_SMTP_HOST=$SMTP_HOST
      - LOWCODER_ADMIN_SMTP_PORT=$SMTP_PORT
      - LOWCODER_ADMIN_SMTP_USERNAME=$SMTP_USER
      - LOWCODER_ADMIN_SMTP_PASSWORD=$SMTP_PASS
      - LOWCODER_ADMIN_SMTP_AUTH=true
      - LOWCODER_ADMIN_SMTP_SSL_ENABLED=$SMTP_SSL
      - LOWCODER_ADMIN_SMTP_STARTTLS_ENABLED=$SMTP_TLS
      - LOWCODER_EMAIL_NOTIFICATIONS_SENDER=$SMTP_FROM_EMAIL
      - LOWCODER_DB_ENCRYPTION_PASSWORD=$ENC_KEY1
      - LOWCODER_DB_ENCRYPTION_SALT=$ENC_KEY2
      - LOWCODER_API_KEY_SECRET=$API_SECRET
      - LOWCODER_NODE_SERVICE_SECRET=$NODE_SECRET
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.lowcoder_api.rule=Host(`$DOMAIN_LOWCODER`) && PathPrefix(`/api`)
        - traefik.http.routers.lowcoder_api.entrypoints=websecure
        - traefik.http.routers.lowcoder_api.tls.certresolver=letsencrypt
        - traefik.http.services.lowcoder_api.loadbalancer.server.port=8080
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  lowcoder_node:
    image: lowcoderorg/lowcoder-ce-node-service:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - LOWCODER_API_SERVICE_URL=http://lowcoder_api:8080
      - LOWCODER_NODE_SERVICE_SECRET=$NODE_SECRET
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 1024M

  lowcoder_frontend:
    image: lowcoderorg/lowcoder-ce-frontend:latest
    volumes:
      - lowcoder_assets:/lowcoder/assets
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - LOWCODER_API_SERVICE_URL=http://lowcoder_api:8080
      - LOWCODER_NODE_SERVICE_URL=http://lowcoder_node:6060
      - LOWCODER_NODE_SERVICE_SECRET=$NODE_SECRET
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.lowcoder_frontend.rule=Host(`$DOMAIN_LOWCODER`)
        - traefik.http.routers.lowcoder_frontend.entrypoints=websecure
        - traefik.http.routers.lowcoder_frontend.tls.certresolver=letsencrypt
        - traefik.http.services.lowcoder_frontend.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  lowcoder_assets:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "lowcoder.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-lowcoder" "# Lowcoder\n\n- Status: Instalado\n- URL: https://$DOMAIN_LOWCODER"
else
    exit 1
fi

rm -f lowcoder.yaml
exit 0
