#!/bin/bash
# =============================================================================
# skills/app-evocrm/run.sh
# Skill: Instalação do EvoCRM via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="evocrm"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Gerar segredos
SECRET_KEY_BASE=$(openssl rand -hex 64)
JWT_SECRET=$(openssl rand -hex 32)
API_TOKEN=$(openssl rand -hex 32)
DOORKEEPER_SECRET=$(openssl rand -hex 32)
BOT_RUNTIME_SECRET=$(openssl rand -hex 32)
# Simulação de geração de chave Fernet (requer python ou similar)
ENCRYPTION_KEY=$(openssl rand -base64 32)

echo -e "${amarelo}Instalando EvoCRM no domínio $DOMAIN_EVOCRM_FRONT...${reset}"

# Criar volumes
docker volume create evocrm_redis > /dev/null 2>&1
docker volume create evocrm_processor_logs > /dev/null 2>&1

cat > evocrm.yaml <<EOL
version: "3.7"
services:
  gateway:
    image: evoapicloud/evo-crm-gateway:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - AUTH_UPSTREAM=auth:3001
      - CRM_UPSTREAM=crm:3000
      - CORE_UPSTREAM=core:5555
      - PROCESSOR_UPSTREAM=processor:8000
      - BOT_RUNTIME_UPSTREAM=bot_runtime:8080
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.evocrm_api.rule=Host(\`$DOMAIN_EVOCRM_API\`)"
        - "traefik.http.routers.evocrm_api.entrypoints=websecure"
        - "traefik.http.routers.evocrm_api.tls.certresolver=letsencrypt"
        - "traefik.http.services.evocrm_api.loadbalancer.server.port=3030"

  auth:
    image: evoapicloud/evo-auth-service-community:develop
    command: bash -c "bundle exec rails db:migrate || true; bundle exec rails s -p 3001 -b 0.0.0.0"
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - EVOAI_CRM_API_TOKEN=$API_TOKEN
      - POSTGRES_HOST=pgvector
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=\$PGVECTOR_PASSWORD
      - POSTGRES_DATABASE=evocrm
      - REDIS_URL=redis://redis:6379/1
      - FRONTEND_URL=https://$DOMAIN_EVOCRM_FRONT
      - BACKEND_URL=https://$DOMAIN_EVOCRM_API
      - SMTP_ADDRESS=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_USERNAME=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - MAILER_SENDER_EMAIL=$SMTP_FROM_EMAIL
      - DOORKEEPER_JWT_SECRET_KEY=$DOORKEEPER_SECRET

  crm:
    image: evoapicloud/evo-ai-crm-community:develop
    command: bash -c "bundle exec rails db:migrate || true; bundle exec rails s -p 3000 -b 0.0.0.0"
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - EVOAI_CRM_API_TOKEN=$API_TOKEN
      - POSTGRES_HOST=pgvector
      - POSTGRES_PASSWORD=\$PGVECTOR_PASSWORD
      - POSTGRES_DATABASE=evocrm
      - REDIS_URL=redis://redis:6379/1
      - EVO_AUTH_SERVICE_URL=http://auth:3001
      - EVO_AI_CORE_SERVICE_URL=http://core:5555
      - BACKEND_URL=https://$DOMAIN_EVOCRM_API
      - FRONTEND_URL=https://$DOMAIN_EVOCRM_FRONT
      - BOT_RUNTIME_URL=http://bot_runtime:8080
      - BOT_RUNTIME_SECRET=$BOT_RUNTIME_SECRET

  core:
    image: evoapicloud/evo-ai-core-service-community:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DB_HOST=pgvector
      - DB_USER=postgres
      - DB_PASSWORD=\$PGVECTOR_PASSWORD
      - DB_NAME=evocrm
      - PORT=5555
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - ENCRYPTION_KEY=$ENCRYPTION_KEY

  processor:
    image: evoapicloud/evo-ai-processor-community:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - POSTGRES_CONNECTION_STRING=postgresql://postgres:\$PGVECTOR_PASSWORD@pgvector:5432/evocrm?sslmode=disable
      - REDIS_HOST=redis
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - ENCRYPTION_KEY=$ENCRYPTION_KEY
    volumes:
      - evocrm_processor_logs:/app/logs

  bot_runtime:
    image: evoapicloud/evo-bot-runtime:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - REDIS_URL=redis://redis:6379/1
      - AI_PROCESSOR_URL=http://processor:8000
      - BOT_RUNTIME_SECRET=$BOT_RUNTIME_SECRET

  frontend:
    image: evoapicloud/evo-ai-frontend-community:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - VITE_API_URL=https://$DOMAIN_EVOCRM_API
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.evocrm_front.rule=Host(\`$DOMAIN_EVOCRM_FRONT\`)"
        - "traefik.http.routers.evocrm_front.entrypoints=websecure"
        - "traefik.http.routers.evocrm_front.tls.certresolver=letsencrypt"
        - "traefik.http.services.evocrm_front.loadbalancer.server.port=80"

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - evocrm_redis:/data

volumes:
  evocrm_redis:
    external: true
  evocrm_processor_logs:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "evocrm.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-evocrm" "[ EVOCRM ]

Dominio: https://$DOMAIN_EVOCRM_FRONT

API: https://$DOMAIN_EVOCRM_API

Host: gateway

Port: 3030

Secret Key Base: $SECRET_KEY_BASE

JWT Secret: $JWT_SECRET

API Token: $API_TOKEN

Doorkeeper Secret: $DOORKEEPER_SECRET

Bot Runtime Secret: $BOT_RUNTIME_SECRET

Encryption Key: $ENCRYPTION_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm evocrm.yaml
exit 0
