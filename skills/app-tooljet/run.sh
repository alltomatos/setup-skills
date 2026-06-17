#!/bin/bash
# =============================================================================
# skills/app-tooljet/run.sh
# Skill: Instalacao do ToolJet via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="tooljet"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Verificar postgres
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then
    echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"
    exit 1
fi

# Verificar redis
if ! docker service ls --format "{{.Name}}" | grep -q "^redis$"; then
    echo -e "\e[31mErro: infra-redis nao instalado.\e[0m"
    exit 1
fi
# Ler ou gerar segredos (idempotência)
LOCKBOX_MASTER_KEY=$(read_data "app-tooljet" | grep -oP '(?<=- LOCKBOX_MASTER_KEY: ).*' || openssl rand -hex 16)
SECRET_KEY_BASE=$(read_data "app-tooljet" | grep -oP '(?<=- SECRET_KEY_BASE: ).*' || openssl rand -hex 16)

echo -e "${amarelo}Instalando ToolJet no dominio $DOMAIN_TOOLJET...${reset}"

docker volume create tooljet_data > /dev/null 2>&1
docker volume create tooljet_chroma > /dev/null 2>&1

cat > tooljet.yaml <<'YAML'
version: "3.7"
services:
  tooljet_app:
    image: tooljet/tooljet:ee-lts-latest
    command: npm run start:prod
    volumes:
      - tooljet_data:/app/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - TOOLJET_HOST=https://$DOMAIN_TOOLJET
      - SERVE_CLIENT=true
      - LANGUAGE=pt
      - LOCKBOX_MASTER_KEY=$LOCKBOX_MASTER_KEY
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - DATABASE_URL=postgres://postgres:$POSTGRES_PASSWORD@postgres:5432/tooljet?sslmode=disable
      - REDIS_HOST=redis
    deploy:

      - REDIS_PORT=6379
      - DEFAULT_FROM_EMAIL=$SMTP_FROM_EMAIL
      - SMTP_USERNAME=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_DOMAIN=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - DISABLE_TOOLJET_TELEMETRY=true
      - CHECK_FOR_UPDATES=false
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.tooljet.rule=Host(`$DOMAIN_TOOLJET`)
        - traefik.http.routers.tooljet.entrypoints=websecure
        - traefik.http.routers.tooljet.tls.certresolver=letsencrypt
        - traefik.http.services.tooljet.loadbalancer.server.port=80
      resources:
        limits:
          cpus: "2"
          memory: 4096M

  tooljet_chroma:
    image: chromadb/chroma:latest
    volumes:
      - tooljet_chroma:/chroma
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  tooljet_data:
    external: true
  tooljet_chroma:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "tooljet.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-tooljet" "# ToolJet\n\n- Status: Instalado\n- URL: https://$DOMAIN_TOOLJET\n- LOCKBOX_MASTER_KEY: $LOCKBOX_MASTER_KEY\n- SECRET_KEY_BASE: $SECRET_KEY_BASE"
else
    exit 1
fi

rm -f tooljet.yaml
exit 0
