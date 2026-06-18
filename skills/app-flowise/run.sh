#!/bin/bash
# =============================================================================
# skills/app-flowise/run.sh
# Skill: Instalação do Flowise via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="flowise"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Recuperar ou gerar API Key (idempotência)
if [ -z "$API_KEY" ]; then
    API_KEY=$(read_data "app-flowise" | grep -oP '(?<=- API Key: ).*' || openssl rand -hex 16)
fi

echo -e "${amarelo}Instalando Flowise no domínio $DOMAIN_FLOWISE...${reset}"

docker volume create flowise_data > /dev/null 2>&1

cat > flowise.yaml <<EOL
version: "3.7"
services:
  flowise:
    image: flowiseai/flowise:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DATABASE_TYPE=postgres
      - DATABASE_PORT=5432
      - DATABASE_HOST=postgres
      - DATABASE_NAME=flowise
      - DATABASE_USER=postgres
      - DATABASE_PASSWORD=\$POSTGRES_PASSWORD
      - API_KEY=$API_KEY
      - PORT=3000
    volumes:
      - flowise_data:/root/.flowise
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.flowise.rule=Host(\`$DOMAIN_FLOWISE\`)"
        - "traefik.http.routers.flowise.entrypoints=websecure"
        - "traefik.http.routers.flowise.tls.certresolver=letsencrypt"
        - "traefik.http.services.flowise.loadbalancer.server.port=3000"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  flowise_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

# Nota: POSTGRES_PASSWORD deve vir do contexto ou ser solicitada se necessário.
# Aqui assumimos que o orquestrador gerencia a injeção conforme ADR-002.
deploy_via_portainer "$STACK_NAME" "flowise.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-flowise" "[ FLOWISE ]

Dominio: https://$DOMAIN_FLOWISE

Host: flowise

Port: 3000

API Key: $API_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm flowise.yaml
exit 0
