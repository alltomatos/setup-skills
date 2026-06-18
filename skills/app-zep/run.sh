#!/bin/bash
# =============================================================================
# skills/app-zep/run.sh
# Skill: Instalação do Zep via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="$PGVECTOR_PASSWORDe[33m"
verde="$PGVECTOR_PASSWORDe[32m"
reset="$PGVECTOR_PASSWORDe[0m"

STACK_NAME="zep"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Recuperar ou gerar Zep API Key (idempotência)
if [ -z "$ZEP_AUTH_SECRET" ]; then
    ZEP_AUTH_SECRET=$(read_data "app-zep" | grep -oP '(?<=API Key: ).*' || openssl rand -hex 16)
fi

# Basic Auth para Traefik (painel admin)
HASHED_PASS=$(htpasswd -nb "$ZEP_USER" "$ZEP_PASS" | sed -e 's/$PGVECTOR_PASSWORD$/$PGVECTOR_PASSWORD$$PGVECTOR_PASSWORD$/g')

echo -e "${amarelo}Instalando Zep no domínio $DOMAIN_ZEP...${reset}"

PGVECTOR_PASSWORD=$(grep "Senha:" /root/dados_vps/dados_pgvector | awk -F"Senha:" '{print $2}' | xargs)

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
      - ZEP_STORE_POSTGRES_DSN=postgres://postgres:$PGVECTOR_PASSWORD@pgvector:5432/zep?sslmode=disable
      - ZEP_AUTH_SECRET=$ZEP_AUTH_SECRET
      - ZEP_OPENAI_API_KEY=$OPENAI_API_KEY
      - ZEP_NLP_SERVER_URL=http://zep-nlp:5557
      - ZEP_LOG_LEVEL=info
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.zep.rule=Host($PGVECTOR_PASSWORD`$DOMAIN_ZEP$PGVECTOR_PASSWORD`)"
        - "traefik.http.routers.zep.entrypoints=websecure"
        - "traefik.http.routers.zep.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.zep.loadbalancer.server.port=8000"
        
        # Admin Panel Auth
        - "traefik.http.routers.zep-admin.rule=Host($PGVECTOR_PASSWORD`$DOMAIN_ZEP$PGVECTOR_PASSWORD`) && PathPrefix($PGVECTOR_PASSWORD`/admin$PGVECTOR_PASSWORD`)"
        - "traefik.http.routers.zep-admin.entrypoints=websecure"
        - "traefik.http.routers.zep-admin.tls.certresolver=letsencryptresolver"
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

ensure_db "pgvector" "zep" || { echo "Erro ao preparar o banco"; exit 1; }
deploy_via_portainer "$STACK_NAME" "zep.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    CONTENT="[ ZEP ]

Dominio: https://$DOMAIN_ZEP

Painel Admin: https://$DOMAIN_ZEP/admin

Usuario: $ZEP_USER

Senha: $ZEP_PASS

API Key: $ZEP_AUTH_SECRET

Rede: $NOME_REDE_INTERNA"
    save_data "app-zep" "$CONTENT"
else
    exit 1
fi

rm zep.yaml
exit 0
