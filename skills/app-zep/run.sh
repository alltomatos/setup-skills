#!/bin/bash
# =============================================================================
# skills/app-zep/run.sh
# Skill: Instalação do Zep via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="zep"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Recuperar ou gerar Zep API Key (idempotência)
if [ -z "$ZEP_AUTH_SECRET" ]; then
    ZEP_AUTH_SECRET=$(read_data "app-zep" | grep -oP '(?<=- API Key: ).*' || openssl rand -hex 16)
fi

# Basic Auth para Traefik (painel admin)
HASHED_PASS=$(htpasswd -nb "$ZEP_USER" "$ZEP_PASS" | sed -e 's/\$/\$\$/g')

echo -e "${amarelo}Instalando Zep no domínio $DOMAIN_ZEP...${reset}"

cat > zep.yaml <<EOL
version: "3.7"
services:
  zep-nlp:
    image: ghcr.io/getzep/zep-nlp-server:latest
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 2048M

  zep:
    image: ghcr.io/getzep/zep:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - ZEP_STORE_TYPE=postgres
      - ZEP_STORE_POSTGRES_DSN=postgres://postgres:\$PGVECTOR_PASSWORD@pgvector:5432/zep?sslmode=disable
      - ZEP_AUTH_SECRET=$ZEP_AUTH_SECRET
      - ZEP_OPENAI_API_KEY=$OPENAI_API_KEY
      - ZEP_NLP_SERVER_URL=http://zep-nlp:5557
      - ZEP_LOG_LEVEL=info
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.zep.rule=Host(\`$DOMAIN_ZEP\`)"
        - "traefik.http.routers.zep.entrypoints=websecure"
        - "traefik.http.routers.zep.tls.certresolver=letsencrypt"
        - "traefik.http.services.zep.loadbalancer.server.port=8000"
        
        # Admin Panel Auth
        - "traefik.http.routers.zep-admin.rule=Host(\`$DOMAIN_ZEP\`) && PathPrefix(\`/admin\`)"
        - "traefik.http.routers.zep-admin.entrypoints=websecure"
        - "traefik.http.routers.zep-admin.tls.certresolver=letsencrypt"
        - "traefik.http.routers.zep-admin.middlewares=zep-auth"
        - "traefik.http.middlewares.zep-auth.basicauth.users=$HASHED_PASS"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "zep.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-zep" "# Zep (AI/Memory)\n\n- Status: Instalado\n- URL: https://$DOMAIN_ZEP/admin\n- API Endpoint: https://$DOMAIN_ZEP\n- API Key: $ZEP_AUTH_SECRET\n- DB: pgvector"
else
    exit 1
fi

rm zep.yaml
exit 0
