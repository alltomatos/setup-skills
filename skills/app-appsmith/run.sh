#!/bin/bash
# =============================================================================
# skills/app-appsmith/run.sh
# Skill: Instalacao do Appsmith via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="appsmith"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Gerar segredo (ADR-002)
SECRET_KEY=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando Appsmith no dominio $DOMAIN_APPSMITH...${reset}"

docker volume create appsmith_data > /dev/null 2>&1

cat > appsmith.yaml <<'YAML'
version: "3.7"
services:
  appsmith:
    image: appsmith/appsmith-ee:latest
    volumes:
      - appsmith_data:/appsmith-stacks
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - APPSMITH_CUSTOM_DOMAIN=https://$DOMAIN_APPSMITH
      - APPSMITH_SIGNUP_DISABLED=false
      - APPSMITH_FORM_LOGIN_DISABLED=false
      - APPSMITH_DISABLE_TELEMETRY=true
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.appsmith.rule=Host(`$DOMAIN_APPSMITH`)
        - traefik.http.routers.appsmith.entrypoints=websecure
        - traefik.http.routers.appsmith.tls.certresolver=letsencryptresolver
        - traefik.http.services.appsmith.loadbalancer.server.port=80
        - traefik.http.services.appsmith.loadbalancer.passHostHeader=true
      resources:
        limits:
          cpus: "2"
          memory: 4096M

volumes:
  appsmith_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "appsmith.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-appsmith" "[ APPSMITH ]

Dominio: https://$DOMAIN_APPSMITH

Host: appsmith

Port: 80

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f appsmith.yaml
exit 0
