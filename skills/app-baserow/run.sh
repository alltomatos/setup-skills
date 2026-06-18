#!/bin/bash
# =============================================================================
# skills/app-baserow/run.sh
# Skill: Instalacao do Baserow via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="baserow"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
# Ler ou gerar segredos (idempotência)
SECRET_KEY=$(read_data "app-baserow" | grep -oP '(?<=- SECRET_KEY: ).*' || openssl rand -hex 16)
BASEROW_JWT_SECRET_KEY=$(read_data "app-baserow" | grep -oP '(?<=- BASEROW_JWT_SECRET_KEY: ).*' || openssl rand -hex 16)

# TLS SMTP
SMTP_SECURE="false"
if [ "$SMTP_PORT" -eq 465 ]; then
    SMTP_SECURE="true"
fi

echo -e "${amarelo}Instalando Baserow no dominio $DOMAIN_BASEROW...${reset}"

docker volume create baserow_data > /dev/null 2>&1
docker volume create baserow_redis > /dev/null 2>&1

cat > baserow.yaml <<YAML
version: "3.7"
services:
  baserow_app:
    image: baserow/baserow:latest
    volumes:
      - baserow_data:/baserow/data
    networks:
      - \$NOME_REDE_INTERNA
    environment:
      - BASEROW_PUBLIC_URL=https://\$DOMAIN_BASEROW
      - SECRET_KEY=$SECRET_KEY
      - BASEROW_JWT_SIGNING_KEY=$BASEROW_JWT_SECRET_KEY
      - EMAIL_SMTP=true
      - FROM_EMAIL=\$SMTP_FROM_EMAIL
      - EMAIL_SMTP_USER=\$SMTP_USER
    deploy:

      - EMAIL_SMTP_PASSWORD=\$SMTP_PASS
      - EMAIL_SMTP_HOST=\$SMTP_HOST
      - EMAIL_SMTP_PORT=\$SMTP_PORT
      - EMAIL_SMTP_USE_SSL=$SMTP_SECURE
      - EMAIL_SMTP_USE_TLS=$([ "$SMTP_PORT" = "587" ] && echo "true" || echo "false")
      - MIGRATE_ON_STARTUP=true
      - REDIS_HOST=baserow_redis
      - REDIS_PORT=6379
      - REDIS_URL=redis://baserow_redis:6379/1
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.baserow.rule=Host(\`\$DOMAIN_BASEROW\`)
        - traefik.http.routers.baserow.entrypoints=websecure
        - traefik.http.routers.baserow.tls.certresolver=letsencryptresolver
        - traefik.http.services.baserow.loadbalancer.server.port=80
      resources:
        limits:
          cpus: "2"
          memory: 4096M

  baserow_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - baserow_redis:/data
    networks:
      - \$NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 2048M

volumes:
  baserow_data:
    external: true
  baserow_redis:
    external: true

networks:
  \$NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "baserow.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-baserow" "[ BASEROW ]

Dominio: https://$DOMAIN_BASEROW

Host: baserow_app

Port: 80

Secret Key: $SECRET_KEY

JWT Secret: $BASEROW_JWT_SECRET_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f baserow.yaml
exit 0
