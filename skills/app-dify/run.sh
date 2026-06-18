#!/bin/bash
# =============================================================================
# skills/app-dify/run.sh
# Skill: Instalação do Dify via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="dify"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Instalando Dify no domínio $DOMAIN_DIFY...${reset}"

# Dify requer múltiplos volumes
docker volume create dify_db_data > /dev/null 2>&1
docker volume create dify_redis_data > /dev/null 2>&1
docker volume create dify_storage_data > /dev/null 2>&1

# O Dify é uma stack complexa. Aqui simplificamos para o padrão Orion Swarm.
# Em produção real, o Dify usa múltiplos containers (api, worker, web, db, redis).
# Para esta skill, focamos na orquestração via Traefik.

cat > dify.yaml <<EOL
version: "3.7"
services:
  # Simplificado: Apenas o frontend/api orquestrado
  dify-web:
    image: langgenius/dify-web:latest
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.dify-web.rule=Host(\`$DOMAIN_DIFY\`)"
        - "traefik.http.routers.dify-web.entrypoints=websecure"
        - "traefik.http.routers.dify-web.tls.certresolver=letsencrypt"
        - "traefik.http.services.dify-web.loadbalancer.server.port=3000"

  dify-api:
    image: langgenius/dify-api:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DB_USERNAME=postgres
      - DB_PASSWORD=\$POSTGRES_PASSWORD
      - DB_HOST=postgres
      - REDIS_HOST=redis
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 2048M

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "dify.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-dify" "[ DIFY ]

Dominio: https://$DOMAIN_DIFY

Host: dify-web

Port: 3000

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm dify.yaml
exit 0
