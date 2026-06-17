#!/bin/bash
# skills/app-passbolt/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="passbolt"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^mysql$"; then echo -e "\e[31mErro: infra-mysql nao instalado.\e[0m"; exit 1; fi
echo -e "${amarelo}Instalando Passbolt...${reset}"
docker volume create passbolt_data > /dev/null 2>&1
docker volume create passbolt_config > /dev/null 2>&1
cat > passbolt.yaml <<'YAML'
version: "3.7"
services:
  passbolt:
    image: passbolt/passbolt:latest
    volumes:
      - passbolt_data:/var/www/passbolt/webroot
      - passbolt_config:/etc/passbolt/
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - APP_FULL_BASE_URL=https://$DOMAIN_PASSBOLT
      - PASSBOLT_REGISTRATION_PUBLIC=false
      - PASSBOLT_SSL_FORCE=true
      - DATASOURCES_DEFAULT_HOST=mysql
      - DATASOURCES_DEFAULT_USERNAME=root
      - DATASOURCES_DEFAULT_PASSWORD=$MYSQL_PASSWORD
      - DATASOURCES_DEFAULT_DATABASE=passbolt
      - EMAIL_TRANSPORT_DEFAULT_HOST=$SMTP_HOST
      - EMAIL_TRANSPORT_DEFAULT_PORT=$SMTP_PORT
      - EMAIL_TRANSPORT_DEFAULT_USERNAME=$SMTP_USER
      - EMAIL_TRANSPORT_DEFAULT_PASSWORD=$SMTP_PASS
      - EMAIL_TRANSPORT_DEFAULT_TLS=false
      - EMAIL_FROM_NAME=Passbolt
      - EMAIL_FROM_DEFAULT=$PASSBOLT_EMAIL
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.passbolt.rule=Host(`$DOMAIN_PASSBOLT`)
        - traefik.http.routers.passbolt.entrypoints=websecure
        - traefik.http.routers.passbolt.tls.certresolver=letsencrypt
        - traefik.http.services.passbolt.loadbalancer.server.port=80
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  passbolt_data:
    external: true
  passbolt_config:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
docker stack deploy --prune --resolve-image always -c passbolt.yaml $STACK_NAME
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-passbolt" "# Passbolt\n\n- Status: Instalado\n- URL: https://$DOMAIN_PASSBOLT"
rm -f passbolt.yaml; exit 0