#!/bin/bash
# =============================================================================
# skills/app-metabase/run.sh
# Skill: Instalação do Metabase via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="metabase"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/infra-postgres.md" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/infra-postgres.md | awk '{print $2}')
else
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

echo -e "${amarelo}Instalando Metabase em $DOMAIN_METABASE...${reset}"

docker volume create metabase_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > metabase${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: metabase/metabase:latest
    volumes:
      - metabase_data:/metabase-data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MB_SITE_URL=https://$DOMAIN_METABASE
      - MB_REDIRECT_ALL_REQUESTS_TO_HTTPS=true
      - MB_DB_TYPE=postgres
      - MB_DB_HOST=postgres
      - MB_DB_PORT=5432
      - MB_DB_DBNAME=metabase
      - MB_DB_USER=postgres
      - MB_DB_PASS=$POSTGRES_PASS
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.metabase.rule=Host(\`$DOMAIN_METABASE\`)
        - traefik.http.services.metabase.loadbalancer.server.port=3000
        - traefik.http.routers.metabase.service=metabase
        - traefik.http.routers.metabase.entrypoints=websecure
        - traefik.http.routers.metabase.tls.certresolver=letsencrypt
        - traefik.http.routers.metabase.tls=true

volumes:
  metabase_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "metabase${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-metabase" "# Metabase\n\n- Status: Instalado\n- URL: https://$DOMAIN_METABASE"
else
    exit 1
fi

rm -f metabase${SUFFIX}.yaml
exit 0
