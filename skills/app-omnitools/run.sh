#!/bin/bash
# =============================================================================
# skills/app-omnitools/run.sh
# Skill: Instalação do OmniTools via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="omnitools"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Instalando OmniTools no domínio $DOMAIN_OMNITOOLS...${reset}"

cat > omnitools.yaml <<EOL
version: "3.7"
services:
  omnitools:
    image: iib0011/omni-tools:latest
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.omnitools.rule=Host(\`$DOMAIN_OMNITOOLS\`)"
        - "traefik.http.routers.omnitools.entrypoints=websecure"
        - "traefik.http.routers.omnitools.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.omnitools.loadbalancer.server.port=3000"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "omnitools.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-omnitools" "[ OMNITOOLS ]

Dominio: https://$DOMAIN_OMNITOOLS

Host: omnitools

Port: 3000

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm omnitools.yaml
exit 0
