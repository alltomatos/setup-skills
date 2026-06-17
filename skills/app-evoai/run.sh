#!/bin/bash
# =============================================================================
# skills/app-evoai/run.sh
# Skill: Instalação da EvoAI via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="evoai"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Configuração SSL/TLS para SMTP
SMTP_USE_SSL="false"
SMTP_USE_TLS="false"
if [ "$SMTP_PORT" -eq 465 ]; then
    SMTP_USE_SSL="true"
elif [ "$SMTP_PORT" -eq 587 ]; then
    SMTP_USE_TLS="true"
fi

# Recuperar ou gerar chaves de encriptação (idempotência)
if [ -z "$EVO_AI_ENCRYPTION_KEY" ]; then
    EVO_AI_ENCRYPTION_KEY=$(read_data "app-evoai" | grep -oP '(?<=- Encryption Key: ).*' || openssl rand -base64 32)
fi
if [ -z "$EVO_AI_JWT_SECRET_KEY" ]; then
    EVO_AI_JWT_SECRET_KEY=$(read_data "app-evoai" | grep -oP '(?<=- JWT Secret Key: ).*' || openssl rand -base64 32)
fi

echo -e "${amarelo}Instalando EvoAI (API: $DOMAIN_EVOAI_API, Front: $DOMAIN_EVOAI_FRONT)...${reset}"

# Criar volumes
docker volume create evoai_logs > /dev/null 2>&1
docker volume create evoai_static > /dev/null 2>&1
docker volume create evoai_redis > /dev/null 2>&1

cat > evoai.yaml <<EOL
version: "3.7"
services:
  evoai_api:
    image: evoapicloud/evo-ai:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - API_URL=https://$DOMAIN_EVOAI_API
      - APP_URL=https://$DOMAIN_EVOAI_FRONT
      - ADMIN_EMAIL=$ADMIN_EMAIL
      - ADMIN_INITIAL_PASSWORD=$ADMIN_PASSWORD
      - EMAIL_PROVIDER=smtp
      - SMTP_FROM=$SMTP_FROM
      - SMTP_USER=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_HOST=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_USE_TLS=$SMTP_USE_TLS
      - SMTP_USE_SSL=$SMTP_USE_SSL
      - POSTGRES_CONNECTION_STRING=postgresql://postgres:\$POSTGRES_PASSWORD@postgres:5432/evoai?sslmode=disable
      - REDIS_HOST=evoai_redis
      - REDIS_PORT=6379
      - REDIS_DB=9
      - ENCRYPTION_KEY=$EVO_AI_ENCRYPTION_KEY
      - JWT_SECRET_KEY=$EVO_AI_JWT_SECRET_KEY
    volumes:
      - evoai_logs:/app/logs
      - evoai_static:/app/static
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.evoai_api.rule=Host(\`$DOMAIN_EVOAI_API\`)"
        - "traefik.http.routers.evoai_api.entrypoints=websecure"
        - "traefik.http.routers.evoai_api.tls.certresolver=letsencrypt"
        - "traefik.http.services.evoai_api.loadbalancer.server.port=8000"

  evoai_frontend:
    image: evoapicloud/evo-ai-frontend:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NEXT_PUBLIC_API_URL=https://$DOMAIN_EVOAI_API
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.evoai_front.rule=Host(\`$DOMAIN_EVOAI_FRONT\`)"
        - "traefik.http.routers.evoai_front.entrypoints=websecure"
        - "traefik.http.routers.evoai_front.tls.certresolver=letsencrypt"
        - "traefik.http.services.evoai_front.loadbalancer.server.port=3000"

  evoai_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - evoai_redis:/data
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  evoai_logs:
    external: true
  evoai_static:
    external: true
  evoai_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "evoai.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-evoai" "# EvoAI\n\n- Status: Instalado\n- API: https://$DOMAIN_EVOAI_API\n- Painel: https://$DOMAIN_EVOAI_FRONT\n- Admin: $ADMIN_EMAIL\n- Encryption Key: $EVO_AI_ENCRYPTION_KEY\n- JWT Secret Key: $EVO_AI_JWT_SECRET_KEY"
else
    exit 1
fi

rm evoai.yaml
exit 0
