#!/bin/bash
# =============================================================================
# skills/app-calcom/run.sh
# Skill: Instalação do Cal.com via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="calcom"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/dados_postgres" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/dados_postgres | awk '{print $2}')
else
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

# Persistência de Segredos (ADR-001)
if service_exists "app-calcom"; then
    NEXTAUTH_SECRET=$(read_data "app-calcom" | grep "NEXTAUTH_SECRET:" | awk '{print $2}')
    CALENDSO_ENCRYPTION_KEY=$(read_data "app-calcom" | grep "CALENDSO_ENCRYPTION_KEY:" | awk '{print $2}')
fi

# Geração de segredos se não existirem (ADR-002 fallback)
NEXTAUTH_SECRET=${NEXTAUTH_SECRET:-$(openssl rand -hex 16)}
CALENDSO_ENCRYPTION_KEY=${CALENDSO_ENCRYPTION_KEY:-$(openssl rand -hex 16)}

echo -e "${amarelo}Instalando Cal.com em $DOMAIN_CALCOM...${reset}"

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > calcom${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: calcom/cal.com:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_DISABLE_SIGNUP=false
      - NEXT_PUBLIC_APP_NAME=Cal.com
      - CALCOM_TELEMETRY_DISABLED=1
      - TZ=America/Sao_Paulo
      - NEXT_PUBLIC_WEBAPP_URL=https://$DOMAIN_CALCOM
      - NEXTAUTH_URL=https://$DOMAIN_CALCOM
      - NEXT_PUBLIC_CONSOLE_URL=https://$DOMAIN_CALCOM
      - NEXT_PUBLIC_WEBSITE_URL=https://$DOMAIN_CALCOM
      - DATABASE_HOST=postgres
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASS@postgres:5432/calcom
      - NEXTAUTH_SECRET=$NEXTAUTH_SECRET
      - CALENDSO_ENCRYPTION_KEY=$CALENDSO_ENCRYPTION_KEY
      - NEXT_PUBLIC_SUPPORT_MAIL_ADDRESS=$SMTP_EMAIL
      - EMAIL_FROM=$SMTP_EMAIL
      - EMAIL_SERVER_HOST=$SMTP_HOST
      - EMAIL_SERVER_PORT=$SMTP_PORT
      - EMAIL_SERVER_USER=$SMTP_USER
      - EMAIL_SERVER_PASSWORD=$SMTP_PASSWORD
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.calcom.rule=Host(\`$DOMAIN_CALCOM\`)
        - traefik.http.routers.calcom.entrypoints=websecure
        - traefik.http.routers.calcom.tls.certresolver=letsencryptresolver
        - traefik.http.routers.calcom.service=calcom
        - traefik.http.services.calcom.loadbalancer.server.port=3000

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

ensure_db "postgres" "calcom" || { echo "Erro ao preparar o banco no postgres"; exit 1; }
deploy_via_portainer "$STACK_NAME" "calcom${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-calcom" "[ CALCOM ]

Dominio: https://$DOMAIN_CALCOM

Host: app

Port: 3000

NextAuth Secret: $NEXTAUTH_SECRET

Encryption Key: $CALENDSO_ENCRYPTION_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f calcom${SUFFIX}.yaml
exit 0
