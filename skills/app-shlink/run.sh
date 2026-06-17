#!/bin/bash
# =============================================================================
# skills/app-shlink/run.sh
# Skill: Instalação do Shlink via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="shlink"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/infra-postgres.md" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/infra-postgres.md | awk '{print $2}')
else
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

echo -e "${amarelo}Instalando Shlink em $DOMAIN_SHLINK_API...${reset}"

# Geração de chave de API (ADR-002)
SHLINK_API_KEY=$(openssl rand -hex 16)

# Gerar Hash para Basic Auth no Traefik (ADR-002)
# Requer apache2-utils instalado ou usar python
HASHED_PASS=$(openssl passwd -apr1 "$SHLINK_PASSWORD")
TRAEFIK_AUTH="$SHLINK_USER:${HASHED_PASS//$/$$}"

docker volume create shlink_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > shlink${SUFFIX}.yaml <<YAML
version: "3.8"
services:
  ui:
    image: shlinkio/shlink-web-client:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DEFAULT_DOMAIN=$DOMAIN_SHLINK_API
      - IS_HTTPS_ENABLED=true
      - INITIAL_API_KEY=$SHLINK_API_KEY
      - DB_DRIVER=postgres
      - DB_HOST=postgres
      - DB_NAME=shlink
      - DB_USER=postgres
      - DB_PASSWORD=$POSTGRES_PASS
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379
      - TIMEZONE=America/Sao_Paulo
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.shlink-ui.rule=Host(\`$DOMAIN_SHLINK_UI\`)
        - traefik.http.routers.shlink-ui.entrypoints=websecure
        - traefik.http.routers.shlink-ui.tls.certresolver=letsencrypt
        - traefik.http.services.shlink-ui.loadbalancer.server.port=8080
        - traefik.http.routers.shlink-ui.middlewares=shlink-auth
        - traefik.http.middlewares.shlink-auth.basicauth.users=$TRAEFIK_AUTH
        - traefik.http.routers.shlink-ui.tls=true

  api:
    image: shlinkio/shlink:latest
    volumes:
      - shlink_data:/etc/shlink
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DEFAULT_DOMAIN=$DOMAIN_SHLINK_API
      - IS_HTTPS_ENABLED=true
      - INITIAL_API_KEY=$SHLINK_API_KEY
      - DB_DRIVER=postgres
      - DB_HOST=postgres
      - DB_NAME=shlink
      - DB_USER=postgres
      - DB_PASSWORD=$POSTGRES_PASS
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379
      - TIMEZONE=America/Sao_Paulo
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.shlink-api.rule=Host(\`$DOMAIN_SHLINK_API\`)
        - traefik.http.routers.shlink-api.entrypoints=websecure
        - traefik.http.routers.shlink-api.tls.certresolver=letsencrypt
        - traefik.http.services.shlink-api.loadbalancer.server.port=8080
        - traefik.http.routers.shlink-api.tls=true

volumes:
  shlink_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

docker stack deploy --prune --resolve-image always -c shlink${SUFFIX}.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-shlink" "# Shlink\n\n- Status: Instalado\n- Painel UI: https://$DOMAIN_SHLINK_UI\n- API/URLs: https://$DOMAIN_SHLINK_API\n- API Key Interna: $SHLINK_API_KEY"
else
    exit 1
fi

rm -f shlink${SUFFIX}.yaml
exit 0
