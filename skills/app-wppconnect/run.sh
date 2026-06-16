#!/bin/bash
# =============================================================================
# skills/app-wppconnect/run.sh
# Skill: Instalação do WPPConnect via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="wppconnect"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando WPPConnect no domínio $DOMAIN_WPPCONNECT...${reset}"

docker volume create wppconnect_config > /dev/null 2>&1

cat > wppconnect.yaml <<EOL
version: "3.7"
services:
  wppconnect_api:
    image: wppconnect/server-cli:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - wppconnect_config:/usr/src/wpp-server
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.wppconnect.rule=Host(\`$DOMAIN_WPPCONNECT\`)"
        - "traefik.http.routers.wppconnect.entrypoints=websecure"
        - "traefik.http.routers.wppconnect.tls.certresolver=letsencrypt"
        - "traefik.http.services.wppconnect.loadbalancer.server.port=21465"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  wppconnect_config:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

docker stack deploy --prune --resolve-image always -c wppconnect.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-wppconnect" "# WPPConnect\n\n- Status: Instalado\n- URL: https://$DOMAIN_WPPCONNECT\n- Docs: https://$DOMAIN_WPPCONNECT/api-docs"
else
    exit 1
fi

rm wppconnect.yaml
exit 0
