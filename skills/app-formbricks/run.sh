#!/bin/bash
# =============================================================================
# skills/app-formbricks/run.sh
# Skill: Instalação do Formbricks via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="formbricks"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Carregar credenciais do PgVector (ADR-001)
if [ -f "/root/dados_vps/infra-pgvector.md" ]; then
    PG_PASS=$(grep "Senha:" /root/dados_vps/infra-pgvector.md | awk '{print $2}')
else
    PG_PASS=$POSTGRES_PASSWORD
fi

# Carregar credenciais do MinIO (ADR-001)
if [ -f "/root/dados_vps/app-minio.md" ]; then
    S3_ACCESS_KEY=$(grep "Access Key:" /root/dados_vps/app-minio.md | awk '{print $3}')
    S3_SECRET_KEY=$(grep "Secret Key:" /root/dados_vps/app-minio.md | awk '{print $3}')
    S3_URL=$(grep "URL API:" /root/dados_vps/app-minio.md | awk '{print $3}' | sed 's/https:\/\///')
else
    echo -e "\e[31mErro: app-minio não encontrado em /root/dados_vps/\e[0m"
    exit 1
fi

# Geração de segredos (ADR-002)
ENCRYPTION_KEY=$(openssl rand -hex 32)
NEXTAUTH_SECRET=$(openssl rand -hex 32)
CRON_SECRET=$(openssl rand -hex 32)

# SSL para SMTP
if [ "$SMTP_PORT" -eq 465 ] || [ "$SMTP_PORT" -eq 25 ]; then
    SMTP_SECURE=1
else
    SMTP_SECURE=0
fi

echo -e "${amarelo}Instalando Formbricks em $DOMAIN_FORMBRICKS...${reset}"

# Criar Bucket no MinIO (Simulado para o esqueleto, mas mantendo a lógica)
# minio-cli mb local/formbricks

docker volume create formbricks_data > /dev/null 2>&1
docker volume create formbricks_redis_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > formbricks${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: ghcr.io/formbricks/formbricks:latest
    volumes:
      - formbricks_data:/home/nextjs/apps/web/uploads/
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - WEBAPP_URL=https://$DOMAIN_FORMBRICKS
      - NEXTAUTH_URL=https://$DOMAIN_FORMBRICKS
      - DATABASE_URL=postgresql://postgres:$PG_PASS@pgvector:5432/formbricks?schema=public
      - ENCRYPTION_KEY=$ENCRYPTION_KEY
      - NEXTAUTH_SECRET=$NEXTAUTH_SECRET
      - CRON_SECRET=$CRON_SECRET
      - MAIL_FROM=$SMTP_EMAIL
      - SMTP_HOST=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_SECURE_ENABLED=$SMTP_SECURE
      - SMTP_USER=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASSWORD
      - S3_ACCESS_KEY=$S3_ACCESS_KEY
      - S3_SECRET_KEY=$S3_SECRET_KEY
      - S3_REGION=us-east-1
      - S3_BUCKET_NAME=formbricks
      - S3_ENDPOINT_URL=https://$S3_URL
      - S3_FORCE_PATH_STYLE=1
      - REDIS_URL=redis://redis:6379
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
        - traefik.http.routers.formbricks.rule=Host(\`$DOMAIN_FORMBRICKS\`)
        - traefik.http.services.formbricks.loadbalancer.server.port=3000
        - traefik.http.routers.formbricks.service=formbricks
        - traefik.http.routers.formbricks.tls.certresolver=letsencrypt
        - traefik.http.routers.formbricks.entrypoints=websecure
        - traefik.http.routers.formbricks.tls=true

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - formbricks_redis_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  formbricks_data:
    external: true
  formbricks_redis_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

docker stack deploy --prune --resolve-image always -c formbricks${SUFFIX}.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-formbricks" "# Formbricks\n\n- Status: Instalado\n- URL: https://$DOMAIN_FORMBRICKS"
else
    exit 1
fi

rm -f formbricks${SUFFIX}.yaml
exit 0
