#!/bin/bash
# =============================================================================
# skills/app-anythingllm/run.sh
# Skill: Instalação do AnythingLLM via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="anythingllm"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Instalando AnythingLLM no domínio $DOMAIN_ANYTHINGLLM...${reset}"

docker volume create anythingllm_storage > /dev/null 2>&1

cat > anythingllm.yaml <<EOL
version: "3.7"
services:
  anythingllm:
    image: mintplexlabs/anythingllm:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - anythingllm_storage:/app/server/storage
    environment:
      - STORAGE_DIR=/app/server/storage
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.anythingllm.rule=Host(\`$DOMAIN_ANYTHINGLLM\`)"
        - "traefik.http.routers.anythingllm.entrypoints=websecure"
        - "traefik.http.routers.anythingllm.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.anythingllm.loadbalancer.server.port=3001"
      resources:
        limits:
          cpus: "1"
          memory: 2048M

volumes:
  anythingllm_storage:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "anythingllm.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-anythingllm" "[ ANYTHINGLLM ]

Dominio: https://$DOMAIN_ANYTHINGLLM

Host: anythingllm

Port: 3001

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm anythingllm.yaml
exit 0
