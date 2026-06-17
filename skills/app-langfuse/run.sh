#!/bin/bash
# =============================================================================
# skills/app-langfuse/run.sh
# Skill: Instalação do Langfuse via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="langfuse"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Langfuse no domínio $DOMAIN_LANGFUSE...${reset}"

cat > langfuse.yaml <<EOL
version: "3.7"
services:
  langfuse:
    image: langfuse/langfuse:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DATABASE_URL=postgresql://postgres:\$POSTGRES_PASSWORD@postgres:5432/langfuse
      - NEXTAUTH_URL=https://$DOMAIN_LANGFUSE
      - NEXTAUTH_SECRET=$(openssl rand -base64 32)
      - SALT=$(openssl rand -base64 32)
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.langfuse.rule=Host(\`$DOMAIN_LANGFUSE\`)"
        - "traefik.http.routers.langfuse.entrypoints=websecure"
        - "traefik.http.routers.langfuse.tls.certresolver=letsencrypt"
        - "traefik.http.services.langfuse.loadbalancer.server.port=3000"
      resources:
        limits:
          cpus: "1"
          memory: 2048M

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "langfuse.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-langfuse" "# Langfuse (AI/Observability)\n\n- Status: Instalado\n- URL: https://$DOMAIN_LANGFUSE"
else
    exit 1
fi

rm langfuse.yaml
exit 0
