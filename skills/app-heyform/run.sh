#!/bin/bash
# =============================================================================
# skills/app-heyform/run.sh
# Skill: Instalação do HeyForm via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="heyform"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Carregar credenciais do MongoDB (ADR-001)
if [ -f "/root/dados_vps/infra-mongodb.md" ]; then
    MONGO_USER=$(grep "Usuário:" /root/dados_vps/infra-mongodb.md | awk '{print $2}')
    MONGO_PASS=$(grep "Senha:" /root/dados_vps/infra-mongodb.md | awk '{print $2}')
else
    echo -e "\e[31mErro: infra-mongodb não encontrado em /root/dados_vps/\e[0m"
    exit 1
fi

echo -e "${amarelo}Instalando HeyForm em $DOMAIN_HEYFORM...${reset}"

# Geração de chaves (ADR-002)
SESSION_KEY=$(openssl rand -hex 16)
FORM_ENCRYPTION_KEY=$(openssl rand -hex 16)

docker volume create heyform_uploads > /dev/null 2>&1
docker volume create heyform_redis > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > heyform${SUFFIX}.yaml <<YAML
version: '3.8'
services:
  app:
    image: heyform/community-edition:v0.1.0
    volumes:
      - heyform_uploads:/app/static/upload
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NODE_ENV=production
      - APP_LISTEN_PORT=9157
      - APP_LISTEN_HOSTNAME=0.0.0.0
      - APP_HOMEPAGE_URL=https://$DOMAIN_HEYFORM
      - APP_DISABLE_REGISTRATION=false
      - COOKIE_MAX_AGE=1y
      - SESSION_KEY=$SESSION_KEY
      - SESSION_MAX_AGE=15d
      - FORM_ENCRYPTION_KEY=$FORM_ENCRYPTION_KEY
      - MONGO_URI=mongodb://$MONGO_USER:$MONGO_PASS@mongodb:27017/heyform?authSource=admin
      - MONGO_USER=$MONGO_USER
      - MONGO_PASSWORD=$MONGO_PASS
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_DB=0
      - UPLOAD_FILE_SIZE=10485760
      - BCRYPT_SALT=10
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
        - traefik.http.routers.heyform.rule=Host(\`$DOMAIN_HEYFORM\`)
        - traefik.http.services.heyform.loadbalancer.server.port=9157
        - traefik.http.routers.heyform.service=heyform
        - traefik.http.routers.heyform.tls.certresolver=letsencrypt
        - traefik.http.routers.heyform.entrypoints=websecure
        - traefik.http.routers.heyform.tls=true

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - heyform_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  heyform_uploads:
    external: true
  heyform_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

docker stack deploy --prune --resolve-image always -c heyform${SUFFIX}.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-heyform" "# HeyForm\n\n- Status: Instalado\n- URL: https://$DOMAIN_HEYFORM\n- Nota: Crie sua conta de administrador no primeiro acesso."
else
    exit 1
fi

rm -f heyform${SUFFIX}.yaml
exit 0
