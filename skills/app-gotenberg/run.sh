#!/bin/bash
# skills/app-gotenberg/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="gotenberg"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
echo -e "${amarelo}Instalando Gotenberg...${reset}"
docker volume create gotenberg_data > /dev/null 2>&1
cat > gotenberg.yaml <<'YAML'
version: "3.7"
services:
  gotenberg:
    image: gotenberg/gotenberg:latest
    volumes:
      - gotenberg_data:/gotenberg
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - API_ENABLE_BASIC_AUTH=true
      - GOTENBERG_API_BASIC_AUTH_USERNAME=$GOTENBERG_USER
      - GOTENBERG_API_BASIC_AUTH_PASSWORD=$GOTENBERG_PASS
      - LOG_LEVEL=info
      - API_PORT=3000
      - API_TIMEOUT=60s
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.gotenberg.rule=Host(`$DOMAIN_GOTENBERG`)
        - traefik.http.routers.gotenberg.entrypoints=websecure
        - traefik.http.routers.gotenberg.tls.certresolver=letsencrypt
        - traefik.http.services.gotenberg.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  gotenberg_data:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "gotenberg.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-gotenberg" "# Gotenberg\n\n- Status: Instalado\n- URL: https://$DOMAIN_GOTENBERG\n- API Key: $GOTENBERG_USER / $GOTENBERG_PASS"
rm -f gotenberg.yaml; exit 0