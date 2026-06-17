#!/bin/bash
# =============================================================================
# skills/app-uptimekuma/run.sh
# Skill: Instalação do Uptime Kuma via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="uptimekuma"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Uptime Kuma no domínio $DOMAIN_UPTIMEKUMA...${reset}"

docker volume create uptimekuma_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > uptimekuma${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  uptimekuma:
    image: louislam/uptime-kuma:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - uptimekuma_data:/app/data
    environment:
      - TZ=America/Sao_Paulo
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M
      labels:
        - traefik.enable=true
        - traefik.http.routers.uptimekuma.rule=Host(\`$DOMAIN_UPTIMEKUMA\`)
        - traefik.http.routers.uptimekuma.entrypoints=websecure
        - traefik.http.routers.uptimekuma.tls.certresolver=letsencrypt
        - traefik.http.services.uptimekuma.loadbalancer.server.port=3001
        - traefik.http.routers.uptimekuma.service=uptimekuma
        - traefik.http.routers.uptimekuma.tls=true

volumes:
  uptimekuma_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "uptimekuma${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-uptimekuma" "# Uptime Kuma\n\n- Status: Instalado\n- URL: https://$DOMAIN_UPTIMEKUMA"
else
    exit 1
fi

rm -f uptimekuma${SUFFIX}.yaml
exit 0
