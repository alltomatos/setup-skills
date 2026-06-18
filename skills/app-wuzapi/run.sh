#!/bin/bash
# =============================================================================
# skills/app-wuzapi/run.sh
# Skill: Instalação do Wuzapi via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="wuzapi"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Recuperar ou gerar chaves (idempotência)
if [ -z "$WUZAPI_ADMIN_TOKEN" ]; then
    WUZAPI_ADMIN_TOKEN=$(read_data "app-wuzapi" | grep -oP '(?<=- Admin Token: ).*' || openssl rand -hex 16)
fi
if [ -z "$SECRET_KEY" ]; then
    SECRET_KEY=$(read_data "app-wuzapi" | grep -oP '(?<=- Secret Key: ).*' || openssl rand -hex 16)
fi

echo -e "${amarelo}Instalando Wuzapi no domínio $DOMAIN_WUZAPI...${reset}"

docker volume create wuzapi_dbdata > /dev/null 2>&1
docker volume create wuzapi_files > /dev/null 2>&1

cat > wuzapi.yaml <<EOL
version: "3.7"
services:
  wuzapi:
    image: asternic/wuzapi:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - wuzapi_dbdata:/app/dbdata
      - wuzapi_files:/app/files
    environment:
      - WUZAPI_ADMIN_TOKEN=$WUZAPI_ADMIN_TOKEN
      - SECRET_KEY=$SECRET_KEY
      - DB_HOST=postgres
      - DB_USER=postgres
      - DB_PASSWORD=\$POSTGRES_PASSWORD
      - DB_NAME=wuzapi
      - DB_PORT=5432
      - DB_DRIVER=postgres
      - TZ=America/Sao_Paulo
      - WEBHOOK_FORMAT=json
      - SESSION_DEVICE_NAME=OrionDesign
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.wuzapi.rule=Host(\`$DOMAIN_WUZAPI\`)"
        - "traefik.http.routers.wuzapi.entrypoints=websecure"
        - "traefik.http.routers.wuzapi.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.wuzapi.loadbalancer.server.port=8080"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  wuzapi_dbdata:
    external: true
  wuzapi_files:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

ensure_db "postgres" "wuzapi" || { echo "Erro ao preparar o banco"; exit 1; }
deploy_via_portainer "$STACK_NAME" "wuzapi.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-wuzapi" "[ WUZAPI ]

Dominio: https://$DOMAIN_WUZAPI

Host: wuzapi

Port: 8080

Usuario: postgres

Token: $WUZAPI_ADMIN_TOKEN

Secret Key: $SECRET_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm wuzapi.yaml
exit 0
