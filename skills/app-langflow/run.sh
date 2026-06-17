#!/bin/bash
# =============================================================================
# skills/app-langflow/run.sh
# Skill: Instalação do Langflow via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="langflow"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Langflow no domínio $DOMAIN_LANGFLOW...${reset}"

docker volume create langflow_data > /dev/null 2>&1

cat > langflow.yaml <<EOL
version: "3.7"
services:
  langflow:
    image: langflowai/langflow:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - langflow_data:/root/.langflow
    environment:
      - LANGFLOW_HOST=0.0.0.0
      - LANGFLOW_PORT=7860
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.langflow.rule=Host(\`$DOMAIN_LANGFLOW\`)"
        - "traefik.http.routers.langflow.entrypoints=websecure"
        - "traefik.http.routers.langflow.tls.certresolver=letsencrypt"
        - "traefik.http.services.langflow.loadbalancer.server.port=7860"
      resources:
        limits:
          cpus: "1"
          memory: 2048M

volumes:
  langflow_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "langflow.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-langflow" "# Langflow (AI/Flow)\n\n- Status: Instalado\n- URL: https://$DOMAIN_LANGFLOW"
else
    exit 1
fi

rm langflow.yaml
exit 0
