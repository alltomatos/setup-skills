#!/bin/bash
# skills/app-excalidraw/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="excalidraw"; NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
echo -e "${amarelo}Instalando Excalidraw...${reset}"
docker volume create excalidraw_data > /dev/null 2>&1
cat > excalidraw.yaml <<'YAML'
version: "3.7"
services:
  excalidraw:
    image: excalidraw/excalidraw:latest
    volumes:
      - excalidraw_data:/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NODE_ENV=production
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.excalidraw.rule=Host(`$DOMAIN_EXCALIDRAW`)
        - traefik.http.routers.excalidraw.entrypoints=websecure
        - traefik.http.routers.excalidraw.tls.certresolver=letsencrypt
        - traefik.http.services.excalidraw.loadbalancer.server.port=80
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  excalidraw_data:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "excalidraw.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-excalidraw" "[ EXCALIDRAW ]

Dominio: https://$DOMAIN_EXCALIDRAW

Host: excalidraw

Port: 80

Rede: $NOME_REDE_INTERNA"
rm -f excalidraw.yaml; exit 0