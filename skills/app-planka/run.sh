#!/bin/bash
# =============================================================================
# skills/app-planka/run.sh
# Skill: Instalação do Planka via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="planka"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/dados_postgres" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/dados_postgres | awk '{print $2}')
else
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

# Recupera ou gera segredo (ADR-001)
SECRET_KEY=$(read_data "app-planka" | grep -oP '(?<=- Secret Key: ).*' || openssl rand -hex 32)

# Configuração SMTP SSL
if [ "$SMTP_PORT" -eq 465 ]; then
    SMTP_SECURE="true"
    TLS_REJECT="false"
else
    SMTP_SECURE="false"
    TLS_REJECT="true"
fi

echo -e "${amarelo}Instalando Planka em $DOMAIN_PLANKA...${reset}"

docker volume create planka_avatars > /dev/null 2>&1
docker volume create planka_backgrounds > /dev/null 2>&1
docker volume create planka_attachments > /dev/null 2>&1
docker volume create planka_redis_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > planka${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: ghcr.io/plankanban/planka:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - planka_avatars:/app/public/user-avatars
      - planka_backgrounds:/app/public/project-background-images
      - planka_attachments:/app/private/attachments
    environment:
      - BASE_URL=https://$DOMAIN_PLANKA
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASS@postgres:5432/planka
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=$SECRET_KEY
      - DEFAULT_ADMIN_NAME=$PLANKA_ADMIN_NAME
      - DEFAULT_ADMIN_EMAIL=$PLANKA_ADMIN_EMAIL
      - DEFAULT_ADMIN_USERNAME=$PLANKA_ADMIN_USER
      - DEFAULT_ADMIN_PASSWORD=$PLANKA_ADMIN_PASSWORD
      - SMTP_HOST=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_SECURE=$SMTP_SECURE
      - SMTP_USER=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASSWORD
      - SMTP_FROM=Planka <$SMTP_EMAIL>
      - SMTP_TLS_REJECT_UNAUTHORIZED=$TLS_REJECT
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
        - traefik.http.routers.planka.rule=Host(\`$DOMAIN_PLANKA\`)
        - traefik.http.services.planka.loadbalancer.server.port=1337
        - traefik.http.routers.planka.service=planka
        - traefik.http.routers.planka.entrypoints=websecure
        - traefik.http.routers.planka.tls.certresolver=letsencryptresolver
        - traefik.http.routers.planka.tls=true

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - planka_redis_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  planka_avatars:
    external: true
  planka_backgrounds:
    external: true
  planka_attachments:
    external: true
  planka_redis_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "planka${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-planka" "[ PLANKA ]

Dominio: https://$DOMAIN_PLANKA

Host: app

Port: 1337

Usuario: $PLANKA_ADMIN_USER

Senha: $PLANKA_ADMIN_PASSWORD

Secret Key: $SECRET_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f planka${SUFFIX}.yaml
exit 0
