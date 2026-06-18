#!/bin/bash
# =============================================================================
# skills/app-unoapi/run.sh
# Skill: Instalação da UnoAPI via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="unoapi"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Recuperar ou gerar Token da API (idempotência)
if [ -z "$UNOAPI_AUTH_TOKEN" ]; then
    UNOAPI_AUTH_TOKEN=$(read_data "app-unoapi" | grep -oP '(?<=- Token: ).*' || openssl rand -hex 16)
fi

echo -e "${amarelo}Instalando UnoAPI no domínio $DOMAIN_UNOAPI...${reset}"

# Criar volumes
docker volume create unoapi_data > /dev/null 2>&1
docker volume create unoapi_redis > /dev/null 2>&1

cat > unoapi.yaml <<EOL
version: "3.7"
services:
  unoapi_api:
    image: clairton/unoapi-cloud:latest
    entrypoint: yarn cloud
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - BASE_URL=https://$DOMAIN_UNOAPI
      - UNOAPI_AUTH_TOKEN=$UNOAPI_AUTH_TOKEN
      - CONFIG_SESSION_PHONE_CLIENT=OrionDesign
      - CONFIG_SESSION_PHONE_NAME=Chrome
      - STORAGE_ENDPOINT=https://$S3_URL
      - STORAGE_ACCESS_KEY_ID=$S3_ACCESS_KEY
      - STORAGE_SECRET_ACCESS_KEY=$S3_SECRET_KEY
      - STORAGE_BUCKET_NAME=unoapi
      - STORAGE_REGION=eu-south
      - STORAGE_FORCE_PATH_STYLE=true
      - AMQP_URL=amqp://$RABBITMQ_USER:$RABBITMQ_PASS@rabbitmq:5672/unoapi
      - REDIS_URL=redis://unoapi_redis:6379
      - LOG_LEVEL=info
    volumes:
      - unoapi_data:/home/u/app
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.unoapi.rule=Host(\`$DOMAIN_UNOAPI\`)"
        - "traefik.http.routers.unoapi.entrypoints=websecure"
        - "traefik.http.routers.unoapi.tls.certresolver=letsencrypt"
        - "traefik.http.services.unoapi.loadbalancer.server.port=9876"

  unoapi_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - unoapi_redis:/data
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  unoapi_data:
    external: true
  unoapi_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

# Tentativa de criar o vhost no RabbitMQ via API
# Nota: Isso requer que o RabbitMQ esteja acessível via rede interna Orion
# e que os comandos curl funcionem.
# O orquestrador deve garantir que o RabbitMQ esteja pronto.

deploy_via_portainer "$STACK_NAME" "unoapi.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-unoapi" "[ UNOAPI ]

Dominio: https://$DOMAIN_UNOAPI

Host: unoapi_api

Port: 9876

Token: $UNOAPI_AUTH_TOKEN

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm unoapi.yaml
exit 0
