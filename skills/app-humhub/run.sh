#!/bin/bash
# skills/app-humhub/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="humhub"; NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
if ! docker service ls --format "{{.Name}}" | grep -q "^mysql$"; then echo -e "\e[31mErro: infra-mysql nao instalado.\e[0m"; exit 1; fi
SMTP_SECURE="false"; [ "$SMTP_PORT" -eq 465 ] && SMTP_SECURE="true"
echo -e "${amarelo}Instalando HumHub...${reset}"
docker volume create humhub_data > /dev/null 2>&1
cat > humhub.yaml <<'YAML'
version: "3.7"
services:
  humhub:
    image: humhub/custom:latest
    volumes:
      - humhub_data:/var/www/localhost/htdocs
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - HUMHUB_AUTO_INSTALL=1
      - HUMHUB_ADMIN_USER=$HUMHUB_ADMIN_USER
      - HUMHUB_ADMIN_EMAIL=$HUMHUB_ADMIN_EMAIL
      - HUMHUB_ADMIN_PASS=$HUMHUB_ADMIN_PASS
      - HUMHUB_DB_HOST=mysql
      - HUMHUB_DB_NAME=humhub
      - HUMHUB_DB_USER=root
      - HUMHUB_DB_PASS=$MYSQL_PASSWORD
      - SMTP_HOST=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_USERNAME=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_FROM=$SMTP_FROM_EMAIL
      - SMTP_FROM_NAME=HumHub
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.humhub.rule=Host(`$DOMAIN_HUMHUB`)
        - traefik.http.routers.humhub.entrypoints=websecure
        - traefik.http.routers.humhub.tls.certresolver=letsencryptresolver
        - traefik.http.services.humhub.loadbalancer.server.port=80
volumes:
  humhub_data:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "humhub.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-humhub" "[ HUMHUB ]

Dominio: https://$DOMAIN_HUMHUB

Host: humhub

Port: 80

Usuario: $HUMHUB_ADMIN_USER

Senha: $HUMHUB_ADMIN_PASS

Email Admin: $HUMHUB_ADMIN_EMAIL

Rede: $NOME_REDE_INTERNA"
rm -f humhub.yaml; exit 0