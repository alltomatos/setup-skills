#!/bin/bash
# =============================================================================
# skills/app-activepieces/run.sh
# Skill: Instalação do ActivePieces via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="activepieces"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/dados_postgres" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/dados_postgres | awk '{print $2}')
else
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

# Geração ou recuperação de chaves (ADR-001/002)
AP_API_KEY=""
AP_ENCRYPTION_KEY=""
AP_JWT_SECRET=""

if service_exists "app-activepieces"; then
    DATA=$(read_data "app-activepieces")
    AP_API_KEY=$(echo "$DATA" | grep "\- API Key:" | cut -d ':' -f 2 | xargs)
    AP_ENCRYPTION_KEY=$(echo "$DATA" | grep "\- Encryption Key:" | cut -d ':' -f 2 | xargs)
    AP_JWT_SECRET=$(echo "$DATA" | grep "\- JWT Secret:" | cut -d ':' -f 2 | xargs)
fi

[ -z "$AP_API_KEY" ] && AP_API_KEY=$(openssl rand -hex 16)
[ -z "$AP_ENCRYPTION_KEY" ] && AP_ENCRYPTION_KEY=$(openssl rand -hex 16)
[ -z "$AP_JWT_SECRET" ] && AP_JWT_SECRET=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando ActivePieces em $DOMAIN_ACTIVEPIECES...${reset}"

docker volume create activepieces_cache > /dev/null 2>&1
docker volume create activepieces_redis > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > activepieces${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: activepieces/activepieces:latest
    volumes:
      - activepieces_cache:/usr/src/app/cache
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - AP_ENVIRONMENT=prod
      - AP_FRONTEND_URL=https://$DOMAIN_ACTIVEPIECES
      - AP_TEMPLATES_SOURCE_URL=https://cloud.activepieces.com/api/v1/flow-templates
      - AP_API_KEY=$AP_API_KEY
      - AP_ENCRYPTION_KEY=$AP_ENCRYPTION_KEY
      - AP_JWT_SECRET=$AP_JWT_SECRET
      - AP_POSTGRES_HOST=postgres
      - AP_POSTGRES_PORT=5432
      - AP_POSTGRES_DATABASE=activepieces
      - AP_POSTGRES_USERNAME=postgres
      - AP_POSTGRES_PASSWORD=$POSTGRES_PASS
      - AP_REDIS_HOST=redis
      - AP_REDIS_PORT=6379
      - AP_ENGINE_EXECUTABLE_PATH=dist/packages/engine/main.js
      - AP_EXECUTION_MODE=UNSANDBOXED
      - AP_FLOW_TIMEOUT_SECONDS=600
      - AP_TRIGGER_DEFAULT_POLL_INTERVAL=5
      - AP_WEBHOOK_TIMEOUT_SECONDS=30
      - AP_TELEMETRY_ENABLED=false
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M
      labels:
        - traefik.enable=true
        - traefik.http.routers.activepieces.rule=Host(\`$DOMAIN_ACTIVEPIECES\`)
        - traefik.http.services.activepieces.loadbalancer.server.port=80
        - traefik.http.routers.activepieces.service=activepieces
        - traefik.http.routers.activepieces.entrypoints=websecure
        - traefik.http.routers.activepieces.tls.certresolver=letsencryptresolver
        - traefik.http.routers.activepieces.tls=true

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - activepieces_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 2048M

volumes:
  activepieces_cache:
    external: true
  activepieces_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "activepieces${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-activepieces" "[ ACTIVEPIECES ]

Dominio: https://$DOMAIN_ACTIVEPIECES

Host: app

Port: 80

API Key: $AP_API_KEY

Encryption Key: $AP_ENCRYPTION_KEY

JWT Secret: $AP_JWT_SECRET

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f activepieces${SUFFIX}.yaml
exit 0
