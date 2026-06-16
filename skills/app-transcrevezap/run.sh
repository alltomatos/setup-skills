#!/bin/bash
# =============================================================================
# skills/app-transcrevezap/run.sh
# Skill: Instalação do TranscreveZap via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="transcrevezap"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando TranscreveZap (API: $DOMAIN_TRANSCREVE_API, Manager: $DOMAIN_TRANSCREVE_MANAGER)...${reset}"

docker volume create redis_transcreve_data > /dev/null 2>&1

cat > transcrevezap.yaml <<EOL
version: "3.7"
services:
  transcrevezap:
    image: impacteai/transcrevezap:latest
    command: ./start.sh
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MANAGER_USER=$MANAGER_USER
      - MANAGER_PASSWORD=$MANAGER_PASS
      - API_DOMAIN=$DOMAIN_TRANSCREVE_API
      - UVICORN_PORT=8005
      - UVICORN_HOST=0.0.0.0
      - REDIS_HOST=redis_transcreve
      - REDIS_PORT=6380
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.transcreve_api.rule=Host(\`$DOMAIN_TRANSCREVE_API\`)"
        - "traefik.http.routers.transcreve_api.entrypoints=websecure"
        - "traefik.http.routers.transcreve_api.tls.certresolver=letsencrypt"
        - "traefik.http.services.transcreve_api.loadbalancer.server.port=8005"
        - "traefik.http.routers.transcreve_mgr.rule=Host(\`$DOMAIN_TRANSCREVE_MANAGER\`)"
        - "traefik.http.routers.transcreve_mgr.entrypoints=websecure"
        - "traefik.http.routers.transcreve_mgr.tls.certresolver=letsencrypt"
        - "traefik.http.services.transcreve_mgr.loadbalancer.server.port=8501"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  redis_transcreve:
    image: redis:6
    command: ["redis-server", "--appendonly", "yes", "--port", "6380"]
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - redis_transcreve_data:/data
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  redis_transcreve_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

docker stack deploy --prune --resolve-image always -c transcrevezap.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-transcrevezap" "# TranscreveZap\n\n- Status: Instalado\n- API: https://$DOMAIN_TRANSCREVE_API\n- Manager: https://$DOMAIN_TRANSCREVE_MANAGER"
else
    exit 1
fi

rm transcrevezap.yaml
exit 0
