#!/bin/bash
# =============================================================================
# skills/app-openwebui/run.sh
# Skill: Instalação do Open WebUI via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="openwebui"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Instalando Open WebUI no domínio $DOMAIN_OPENWEBUI...${reset}"

docker volume create openwebui_data > /dev/null 2>&1

cat > openwebui.yaml <<EOL
version: "3.7"
services:
  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - openwebui_data:/app/backend/data
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.openwebui.rule=Host(\`$DOMAIN_OPENWEBUI\`)"
        - "traefik.http.routers.openwebui.entrypoints=websecure"
        - "traefik.http.routers.openwebui.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.openwebui.loadbalancer.server.port=8080"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  openwebui_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "openwebui.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-openwebui" "[ OPENWEBUI ]

Dominio: https://$DOMAIN_OPENWEBUI

Host: openwebui

Port: 8080

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm openwebui.yaml
exit 0
