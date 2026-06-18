#!/bin/bash
# =============================================================================
# skills/app-directus/run.sh
# Skill: Instalação do Directus via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="directus"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Ler ou gerar segredos (idempotência)
KEY=$(read_data "app-directus" | grep -oP '(?<=- KEY: ).*' || openssl rand -hex 16)
SECRET=$(read_data "app-directus" | grep -oP '(?<=- SECRET: ).*' || openssl rand -hex 16)

# Configuração SMTP
SMTP_SECURE="false"
if [ "$SMTP_PORT" -eq 465 ]; then
    SMTP_SECURE="true"
fi

echo -e "${amarelo}Instalando Directus no domínio $DOMAIN_DIRECTUS...${reset}"

# Criar volumes
docker volume create directus_uploads > /dev/null 2>&1
docker volume create directus_data > /dev/null 2>&1
docker volume create directus_redis > /dev/null 2>&1

cat > directus.yaml <<EOL
version: "3.7"
services:
  directus:
    image: directus/directus:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - directus_uploads:/directus/uploads
      - directus_data:/directus/database
    environment:
      - KEY=$KEY
      - SECRET=$SECRET
      - ADMIN_EMAIL=$ADMIN_EMAIL
      - ADMIN_PASSWORD=$ADMIN_PASSWORD
      - PUBLIC_URL=https://$DOMAIN_DIRECTUS
      - EMAIL_SMTP_HOST=$SMTP_HOST
      - EMAIL_SMTP_PORT=$SMTP_PORT
      - EMAIL_SMTP_USER=$SMTP_USER
      - EMAIL_SMTP_PASSWORD=$SMTP_PASS
      - EMAIL_SMTP_SECURE=$SMTP_SECURE
      - STORAGE_LOCATIONS=s3
      - STORAGE_S3_DRIVER=s3
      - STORAGE_S3_KEY=$S3_ACCESS_KEY
      - STORAGE_S3_SECRET=$S3_SECRET_KEY
      - STORAGE_S3_BUCKET=directus
      - STORAGE_S3_REGION=eu-south
      - STORAGE_S3_ENDPOINT=https://$S3_URL
      - STORAGE_S3_S3_FORCE_PATH_STYLE=true
      - CACHE_ENABLED=true
      - CACHE_STORE=redis
      - REDIS=redis://redis:6379
      - DB_CLIENT=pg
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=directus
      - DB_USER=postgres
      - DB_PASSWORD=\$POSTGRES_PASSWORD
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.directus.rule=Host(\`$DOMAIN_DIRECTUS\`)"
        - "traefik.http.routers.directus.entrypoints=websecure"
        - "traefik.http.routers.directus.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.directus.loadbalancer.server.port=8055"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  redis_directus:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - directus_redis:/data
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  directus_uploads:
    external: true
  directus_data:
    external: true
  directus_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

ensure_db "postgres" "directus" || { echo "Erro ao preparar o banco no postgres"; exit 1; }
deploy_via_portainer "$STACK_NAME" "directus.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-directus" "[ DIRECTUS ]

Dominio: https://$DOMAIN_DIRECTUS

Host: directus

Port: 8055

Usuario: $ADMIN_EMAIL

Senha: $ADMIN_PASSWORD

Key: $KEY

Secret: $SECRET

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm directus.yaml
exit 0
