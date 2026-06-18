#!/bin/bash
# skills/app-wiki/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="wiki"; NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
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
deploy_via_portainer "$STACK_NAME" "wiki.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-wiki" "[ WIKI ]

Dominio: https://$DOMAIN_WIKI

Host: wiki

Port: 3000

Rede: $NOME_REDE_INTERNA"
rm -f wiki.yaml; exit 0