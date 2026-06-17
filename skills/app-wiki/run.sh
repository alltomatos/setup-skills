#!/bin/bash
# skills/app-wiki/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="wiki"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
echo -e "${amarelo}Instalando Wiki.js...${reset}"
docker volume create wiki_data > /dev/null 2>&1
cat > wiki.yaml <<'YAML'
version: "3.7"
services:
  wiki:
    image: ghcr.io/requarks/wiki:2
    volumes:
      - wiki_data:/wiki
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DB_TYPE=sqlite
      - DB_FILEPATH=/wiki/db.sqlite
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.wiki.rule=Host(`$DOMAIN_WIKI`)
        - traefik.http.routers.wiki.entrypoints=websecure
        - traefik.http.routers.wiki.tls.certresolver=letsencrypt
        - traefik.http.services.wiki.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  wiki_data:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
docker stack deploy --prune --resolve-image always -c wiki.yaml $STACK_NAME
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-wiki" "# Wiki.js\n\n- Status: Instalado\n- URL: https://$DOMAIN_WIKI"
rm -f wiki.yaml; exit 0