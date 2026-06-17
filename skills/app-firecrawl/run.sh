#!/bin/bash
# =============================================================================
# skills/app-firecrawl/run.sh
# Skill: Instalação do Firecrawl via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="firecrawl"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Firecrawl no domínio $DOMAIN_FIRECRAWL...${reset}"

cat > firecrawl.yaml <<EOL
version: "3.7"
services:
  firecrawl:
    image: mendable/firecrawl:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - REDIS_URL=redis://redis:6379
      - PORT=3002
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.firecrawl.rule=Host(\`$DOMAIN_FIRECRAWL\`)"
        - "traefik.http.routers.firecrawl.entrypoints=websecure"
        - "traefik.http.routers.firecrawl.tls.certresolver=letsencrypt"
        - "traefik.http.services.firecrawl.loadbalancer.server.port=3002"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "firecrawl.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-firecrawl" "# Firecrawl (AI/Scraping)\n\n- Status: Instalado\n- URL: https://$DOMAIN_FIRECRAWL"
else
    exit 1
fi

rm firecrawl.yaml
exit 0
