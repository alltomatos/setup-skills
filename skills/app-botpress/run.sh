#!/bin/bash
# =============================================================================
# skills/app-botpress/run.sh
# Skill: Instalação do Botpress via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="botpress"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/dados_postgres" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/dados_postgres | awk '{print $2}')
else
    # Fallback ou erro se não encontrar
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

echo -e "${amarelo}Instalando Botpress em $DOMAIN_BOTPRESS...${reset}"

docker volume create botpress_data > /dev/null 2>&1
docker volume create botpress_redis_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > botpress${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: botpress/server:latest
    volumes:
      - botpress_data:/botpress/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - EXTERNAL_URL=https://$DOMAIN_BOTPRESS
      - BP_PRODUCTION=true
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASS@postgres:5432/botpress
      - REDIS_URL=redis://redis:6379
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
        - traefik.http.routers.botpress.rule=Host(\`$DOMAIN_BOTPRESS\`)
        - traefik.http.services.botpress.loadbalancer.server.port=3000
        - traefik.http.routers.botpress.service=botpress
        - traefik.http.routers.botpress.tls.certresolver=letsencryptresolver
        - traefik.http.routers.botpress.entrypoints=websecure
        - traefik.http.routers.botpress.tls=true

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - botpress_redis_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  botpress_data:
    external: true
  botpress_redis_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

ensure_db "postgres" "botpress" || { echo "Erro ao preparar o banco no postgres"; exit 1; }
deploy_via_portainer "$STACK_NAME" "botpress${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-botpress" "[ BOTPRESS ]

Dominio: https://$DOMAIN_BOTPRESS

Host: app

Port: 3000

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f botpress${SUFFIX}.yaml
exit 0
