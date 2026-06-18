#!/bin/bash
# =============================================================================
# skills/app-evocrm/run.sh
# Skill: Instalação do EvoCRM (microservices AI) via Docker Swarm
# Porte fiel da config consolidada do Setup Orion (docs/SetupOrion.md).
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
vermelho="\e[91m"
reset="\e[0m"

STACK_NAME="evocrm"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Credenciais do pgvector (dependência) — env tem prioridade; senão lê do dados_pgvector
if [ ! -f "/root/dados_vps/dados_pgvector" ]; then
    echo -e "${vermelho}Erro: infra-pgvector não encontrado em /root/dados_vps/ (instale a dependência).${reset}"
    exit 1
fi
PGVECTOR_PASSWORD="${PGVECTOR_PASSWORD:-$(grep "Senha:" /root/dados_vps/dados_pgvector | awk -F"Senha:" '{print $2}' | xargs)}"
if [ -z "$PGVECTOR_PASSWORD" ]; then
    echo -e "${vermelho}Erro: senha do pgvector ausente em dados_pgvector.${reset}"
    exit 1
fi

# Domínio do SMTP (derivado do e-mail remetente)
SMTP_DOMAIN="${SMTP_FROM_EMAIL#*@}"

# Gerar segredos
SECRET_KEY_BASE=$(openssl rand -hex 64)
JWT_SECRET=$(openssl rand -hex 32)
API_TOKEN=$(openssl rand -hex 32)
DOORKEEPER_SECRET=$(openssl rand -hex 32)
BOT_RUNTIME_SECRET=$(openssl rand -hex 32)
# ENCRYPTION_KEY precisa ser uma chave Fernet válida (base64 urlsafe de 32 bytes)
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')

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
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}
      labels:
        - traefik.enable=1
        - traefik.docker.network=$NOME_REDE_INTERNA
        - traefik.http.routers.evocrm_gateway.rule=Host(\`$DOMAIN_EVOCRM_API\`)
        - traefik.http.routers.evocrm_gateway.entrypoints=websecure
        - traefik.http.routers.evocrm_gateway.priority=1
        - traefik.http.routers.evocrm_gateway.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evocrm_gateway.service=evocrm_gateway
        - traefik.http.services.evocrm_gateway.loadbalancer.server.port=3030
        - traefik.http.services.evocrm_gateway.loadbalancer.passHostHeader=true

  auth:
    image: evoapicloud/evo-auth-service-community:develop
    command: bash -c "bundle exec rails db:migrate 2>&1 || echo 'Migration had errors, continuing...'; bundle exec rails s -p 3001 -b 0.0.0.0"
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - RAILS_ENV=production
      - RAILS_MAX_THREADS=5
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - EVOAI_CRM_API_TOKEN=$API_TOKEN
      - POSTGRES_HOST=pgvector
      - POSTGRES_PORT=5432
      - POSTGRES_USERNAME=postgres
      - POSTGRES_PASSWORD=$PGVECTOR_PASSWORD
      - POSTGRES_DATABASE=evocrm
      - POSTGRES_SSLMODE=disable
      - REDIS_URL=redis://redis:6379/1
      - FRONTEND_URL=https://$DOMAIN_EVOCRM_FRONT
      - BACKEND_URL=https://$DOMAIN_EVOCRM_API
      - CORS_ORIGINS=https://$DOMAIN_EVOCRM_FRONT,https://$DOMAIN_EVOCRM_API
      - SMTP_DOMAIN=$SMTP_DOMAIN
      - MAILER_SENDER_EMAIL=$SMTP_FROM_EMAIL
      - SMTP_USERNAME=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_ADDRESS=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_AUTHENTICATION=plain
      - SMTP_ENABLE_STARTTLS_AUTO=true
      - DOORKEEPER_JWT_SECRET_KEY=$DOORKEEPER_SECRET
      - DOORKEEPER_JWT_ALGORITHM=hs256
      - DOORKEEPER_JWT_ISS=evo-auth-service
      - MFA_ISSUER=EvoCRM
      - SIDEKIQ_CONCURRENCY=10
      - OAUTH_TOKEN_EXPIRES_IN=28800
      - ACTIVE_STORAGE_SERVICE=local
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

  auth_sidekiq:
    image: evoapicloud/evo-auth-service-community:develop
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - EVOAI_CRM_API_TOKEN=$API_TOKEN
      - POSTGRES_HOST=pgvector
      - POSTGRES_PORT=5432
      - POSTGRES_USERNAME=postgres
      - POSTGRES_PASSWORD=$PGVECTOR_PASSWORD
      - POSTGRES_DATABASE=evocrm
      - POSTGRES_SSLMODE=disable
      - REDIS_URL=redis://redis:6379/1
      - DOORKEEPER_JWT_SECRET_KEY=$DOORKEEPER_SECRET
      - DOORKEEPER_JWT_ALGORITHM=hs256
      - DOORKEEPER_JWT_ISS=evo-auth-service
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

  crm:
    image: evoapicloud/evo-ai-crm-community:develop
    command: sh -c "until wget -qO- http://auth:3001/health >/dev/null 2>&1; do echo 'Waiting for auth...'; sleep 5; done; bundle exec rails db:migrate 2>&1 || echo 'Migration had errors, continuing...'; bundle exec rails s -p 3000 -b 0.0.0.0"
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - RAILS_ENV=production
      - RAILS_SERVE_STATIC_FILES=true
      - RAILS_LOG_TO_STDOUT=true
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - EVOAI_CRM_API_TOKEN=$API_TOKEN
      - POSTGRES_HOST=pgvector
      - POSTGRES_PORT=5432
      - POSTGRES_USERNAME=postgres
      - POSTGRES_PASSWORD=$PGVECTOR_PASSWORD
      - POSTGRES_DATABASE=evocrm
      - POSTGRES_SSLMODE=disable
      - REDIS_URL=redis://redis:6379/1
      - EVO_AUTH_SERVICE_URL=http://auth:3001
      - EVO_AI_CORE_SERVICE_URL=http://core:5555
      - BACKEND_URL=https://$DOMAIN_EVOCRM_API
      - FRONTEND_URL=https://$DOMAIN_EVOCRM_FRONT
      - CORS_ORIGINS=https://$DOMAIN_EVOCRM_FRONT,https://$DOMAIN_EVOCRM_API
      - DISABLE_TELEMETRY=true
      - LOG_LEVEL=info
      - ENABLE_ACCOUNT_SIGNUP=true
      - ENABLE_PUSH_RELAY_SERVER=true
      - ENABLE_INBOX_EVENTS=true
      - BOT_RUNTIME_URL=http://bot_runtime:8080
      - BOT_RUNTIME_SECRET=$BOT_RUNTIME_SECRET
      - BOT_RUNTIME_POSTBACK_BASE_URL=http://crm:3000
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

  crm_sidekiq:
    image: evoapicloud/evo-ai-crm-community:develop
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - EVOAI_CRM_API_TOKEN=$API_TOKEN
      - POSTGRES_HOST=pgvector
      - POSTGRES_PORT=5432
      - POSTGRES_USERNAME=postgres
      - POSTGRES_PASSWORD=$PGVECTOR_PASSWORD
      - POSTGRES_DATABASE=evocrm
      - POSTGRES_SSLMODE=disable
      - REDIS_URL=redis://redis:6379/1
      - EVO_AUTH_SERVICE_URL=http://auth:3001
      - EVO_AI_CORE_SERVICE_URL=http://core:5555
      - BACKEND_URL=https://$DOMAIN_EVOCRM_API
      - FRONTEND_URL=https://$DOMAIN_EVOCRM_FRONT
      - CORS_ORIGINS=https://$DOMAIN_EVOCRM_FRONT,https://$DOMAIN_EVOCRM_API
      - BOT_RUNTIME_URL=http://bot_runtime:8080
      - BOT_RUNTIME_SECRET=$BOT_RUNTIME_SECRET
      - BOT_RUNTIME_POSTBACK_BASE_URL=http://crm:3000
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

  core:
    image: evoapicloud/evo-ai-core-service-community:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DB_HOST=pgvector
      - DB_PORT=5432
      - DB_USER=postgres
      - DB_PASSWORD=$PGVECTOR_PASSWORD
      - DB_NAME=evocrm
      - DB_SSLMODE=disable
      - DB_MAX_IDLE_CONNS=10
      - DB_MAX_OPEN_CONNS=100
      - DB_CONN_MAX_LIFETIME=1h
      - DB_CONN_MAX_IDLE_TIME=30m
      - PORT=5555
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - JWT_SECRET_KEY=$JWT_SECRET
      - JWT_ALGORITHM=HS256
      - ENCRYPTION_KEY=$ENCRYPTION_KEY
      - EVOLUTION_BASE_URL=http://crm:3000
      - EVO_AUTH_BASE_URL=http://auth:3001
      - AI_PROCESSOR_URL=http://processor:8000
      - AI_PROCESSOR_VERSION=v1
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

  processor:
    image: evoapicloud/evo-ai-processor-community:develop
    command: sh -c "alembic upgrade head 2>&1 || echo 'Alembic migration had errors, continuing...'; python -m scripts.run_seeders; uvicorn src.main:app --host 0.0.0.0 --port 8000"
    volumes:
      - evocrm_processor_logs:/app/logs
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - POSTGRES_CONNECTION_STRING=postgresql://postgres:$PGVECTOR_PASSWORD@pgvector:5432/evocrm?sslmode=disable
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=
      - REDIS_SSL=false
      - REDIS_DB=1
      - REDIS_KEY_PREFIX=a2a_
      - REDIS_TTL=3600
      - HOST=0.0.0.0
      - PORT=8000
      - DEBUG=false
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - ENCRYPTION_KEY=$ENCRYPTION_KEY
      - JWT_SECRET_KEY=$JWT_SECRET
      - EVOAI_CRM_API_TOKEN=$API_TOKEN
      - EVO_AUTH_BASE_URL=http://auth:3001
      - EVO_AI_CRM_URL=http://crm:3000
      - CORE_SERVICE_URL=http://core:5555/api/v1
      - APP_URL=https://$DOMAIN_EVOCRM_API
      - API_URL=https://$DOMAIN_EVOCRM_API
      - API_TITLE=Agent Processor Community
      - API_DESCRIPTION=Agent Processor Community for Evo AI
      - API_VERSION=1.0.0
      - ORGANIZATION_NAME=Evo CRM
      - TOOLS_CACHE_ENABLED=true
      - TOOLS_CACHE_TTL=3600
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

  bot_runtime:
    image: evoapicloud/evo-bot-runtime:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - LISTEN_ADDR=0.0.0.0:8080
      - REDIS_URL=redis://redis:6379/1
      - AI_PROCESSOR_URL=http://processor:8000
      - BOT_RUNTIME_SECRET=$BOT_RUNTIME_SECRET
      - AI_CALL_TIMEOUT_SECONDS=30
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

  frontend:
    image: evoapicloud/evo-ai-frontend-community:develop
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - VITE_APP_ENV=production
      - VITE_API_URL=https://$DOMAIN_EVOCRM_API
      - VITE_AUTH_API_URL=https://$DOMAIN_EVOCRM_API
      - VITE_EVOAI_API_URL=https://$DOMAIN_EVOCRM_API
      - VITE_AGENT_PROCESSOR_URL=https://$DOMAIN_EVOCRM_API
      - VITE_WS_URL=https://$DOMAIN_EVOCRM_API
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}
      labels:
        - traefik.enable=1
        - traefik.docker.network=$NOME_REDE_INTERNA
        - traefik.http.routers.evocrm_frontend.rule=Host(\`$DOMAIN_EVOCRM_FRONT\`)
        - traefik.http.routers.evocrm_frontend.entrypoints=websecure
        - traefik.http.routers.evocrm_frontend.priority=1
        - traefik.http.routers.evocrm_frontend.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evocrm_frontend.service=evocrm_frontend
        - traefik.http.services.evocrm_frontend.loadbalancer.server.port=80
        - traefik.http.services.evocrm_frontend.loadbalancer.passHostHeader=true

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - evocrm_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints: [node.role == manager]
      resources:
        limits: {cpus: "1", memory: 1024M}

volumes:
  evocrm_redis:
    external: true
  evocrm_processor_logs:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

# Cria o banco 'evocrm' no pgvector (apps só rodam db:migrate, não criam o banco)
ensure_db "pgvector" "evocrm" || { echo -e "${vermelho}Erro ao preparar o banco no pgvector.${reset}"; exit 1; }

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
