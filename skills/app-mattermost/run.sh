#!/bin/bash
# =============================================================================
# skills/app-mattermost/run.sh
# Skill: Instalação do Mattermost via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="mattermost"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/dados_postgres" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/dados_postgres | awk '{print $2}')
else
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

echo -e "${amarelo}Instalando Mattermost em $DOMAIN_MATTERMOST...${reset}"

docker volume create mattermost_data > /dev/null 2>&1
docker volume create mattermost_config > /dev/null 2>&1
docker volume create mattermost_logs > /dev/null 2>&1
docker volume create mattermost_plugins > /dev/null 2>&1
docker volume create mattermost_client_plugins > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > mattermost${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: mattermost/mattermost-team-edition:latest
    volumes:
      - mattermost_data:/mattermost/data
      - mattermost_config:/mattermost/config
      - mattermost_logs:/mattermost/logs
      - mattermost_plugins:/mattermost/plugins
      - mattermost_client_plugins:/mattermost/client/plugins
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MM_SERVICESETTINGS_SITEURL=https://$DOMAIN_MATTERMOST
      - MM_SQLSETTINGS_DRIVERNAME=postgres
      - MM_SQLSETTINGS_DATASOURCE=postgres://postgres:$POSTGRES_PASS@postgres:5432/mattermost?sslmode=disable&connect_timeout=10
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
        - traefik.http.routers.mattermost.rule=Host(\`$DOMAIN_MATTERMOST\`)
        - traefik.http.routers.mattermost.entrypoints=websecure
        - traefik.http.routers.mattermost.tls.certresolver=letsencrypt
        - traefik.http.routers.mattermost.service=mattermost
        - traefik.http.services.mattermost.loadbalancer.server.port=8065
        - traefik.http.services.mattermost.loadbalancer.passHostHeader=true
        - traefik.http.middlewares.sslheader.headers.customrequestheaders.X-Forwarded-Proto=https
        - traefik.http.routers.mattermost.middlewares=sslheader
        - traefik.http.routers.mattermost.tls=true

volumes:
  mattermost_data:
    external: true
  mattermost_config:
    external: true
  mattermost_logs:
    external: true
  mattermost_plugins:
    external: true
  mattermost_client_plugins:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "mattermost${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-mattermost" "[ MATTERMOST ]

Dominio: https://$DOMAIN_MATTERMOST

Host: app

Port: 8065

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f mattermost${SUFFIX}.yaml
exit 0
