#!/bin/bash
# skills/app-docmost/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="docmost"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi

# Persistencia de Segredos (ADR-001)
if service_exists "app-docmost"; then
    SECRET=$(read_data "app-docmost" | grep "App Secret: " | sed 's/.*App Secret: //')
fi
[ -z "$SECRET" ] && SECRET=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando Docmost...${reset}"
docker volume create docmost_storage > /dev/null 2>&1
docker volume create docmost_redis > /dev/null 2>&1
cat > docmost.yaml <<'YAML'
version: "3.7"
services:
  docmost_app:
    image: docmost/docmost:latest
    volumes:
      - docmost_storage:/app/data/storage
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - APP_URL=https://$DOMAIN_DOCMOST
      - PORT=3000
      - APP_SECRET=$SECRET
      - JWT_TOKEN_EXPIRES_IN=30d
      - DISABLE_TELEMETRY=true
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/docmost?schema=public
      - REDIS_URL=redis://docmost_redis:6379
      - STORAGE_DRIVER=local
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.docmost.rule=Host(`$DOMAIN_DOCMOST`)
        - traefik.http.routers.docmost.entrypoints=websecure
        - traefik.http.routers.docmost.tls.certresolver=letsencrypt
        - traefik.http.services.docmost.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M
  docmost_redis:
    image: redis:latest
    command: ["redis-server","--appendonly","yes"]
    volumes:
      - docmost_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
volumes:
  docmost_storage:
    external: true
  docmost_redis:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "docmost.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-docmost" "# Docmost\n\n- Status: Instalado\n- URL: https://$DOMAIN_DOCMOST\n- App Secret: $SECRET"
rm -f docmost.yaml; exit 0