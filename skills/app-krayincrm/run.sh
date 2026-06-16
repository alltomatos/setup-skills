#!/bin/bash
# =============================================================================
# skills/app-krayincrm/run.sh
# Skill: Instalação do Krayin CRM via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="krayin"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Gerar chaves aleatórias
APP_KEY="base64:$(openssl rand -base64 32)"
MYSQL_ROOT_PASSWORD=$(openssl rand -hex 16)

# Configuração SMTP
SMTP_ENCRYPTION="tls"
if [ "$SMTP_PORT" -eq 465 ]; then
    SMTP_ENCRYPTION="ssl"
fi

echo -e "${amarelo}Instalando Krayin CRM no domínio $DOMAIN_KRAYIN...${reset}"

# Criar volumes
docker volume create krayin_app > /dev/null 2>&1
docker volume create krayin_db > /dev/null 2>&1
docker volume create krayin_redis > /dev/null 2>&1

cat > krayin.yaml <<EOL
version: "3.7"
services:
  krayin_app:
    image: webkul/krayin:v2.1.2-https
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - krayin_app:/var/www/html/
    environment:
      - APP_URL=https://$DOMAIN_KRAYIN
      - APP_NAME=Krayin CRM
      - APP_ENV=local
      - APP_KEY=$APP_KEY
      - APP_TIMEZONE=America/Sao_Paulo
      - DB_CONNECTION=mysql
      - DB_HOST=krayin_db
      - DB_PORT=3306
      - DB_DATABASE=krayincrm
      - DB_USERNAME=root
      - DB_PASSWORD=$MYSQL_ROOT_PASSWORD
      - REDIS_HOST=krayin_redis
      - REDIS_PORT=6379
      - MAIL_MAILER=smtp
      - MAIL_HOST=$SMTP_HOST
      - MAIL_PORT=$SMTP_PORT
      - MAIL_USERNAME=$SMTP_USER
      - MAIL_PASSWORD=$SMTP_PASS
      - MAIL_ENCRYPTION=$SMTP_ENCRYPTION
      - MAIL_FROM_ADDRESS=$SMTP_FROM_EMAIL
      - MAIL_FROM_NAME=Krayin CRM
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.krayin.rule=Host(\`$DOMAIN_KRAYIN\`)"
        - "traefik.http.routers.krayin.entrypoints=websecure"
        - "traefik.http.routers.krayin.tls.certresolver=letsencrypt"
        - "traefik.http.services.krayin.loadbalancer.server.port=80"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  krayin_db:
    image: percona/percona-server:latest
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_general_ci
      - --default-authentication-plugin=mysql_native_password
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - krayin_db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
      - MYSQL_DATABASE=krayincrm
      - TZ=America/Sao_Paulo

  krayin_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes"]
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - krayin_redis:/data

volumes:
  krayin_app:
    external: true
  krayin_db:
    external: true
  krayin_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

docker stack deploy --prune --resolve-image always -c krayin.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-krayincrm" "# Krayin CRM\n\n- Status: Instalado\n- URL: https://$DOMAIN_KRAYIN\n- DB: MySQL (interno)\n- App Key: $APP_KEY"
else
    exit 1
fi

rm krayin.yaml
exit 0
