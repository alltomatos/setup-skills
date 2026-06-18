#!/bin/bash
# skills/app-wisemapping/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="$POSTGRES_PASSWORDe[33m"; verde="$POSTGRES_PASSWORDe[32m"; reset="$POSTGRES_PASSWORDe[0m"
STACK_NAME="wisemapping"; NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
if ! docker service ls --format "{{.Name}}" | grep -qE "(^|_)postgres"; then echo -e "$POSTGRES_PASSWORDe[31mErro: infra-postgres nao instalado.$POSTGRES_PASSWORDe[0m"; exit 1; fi
JWT_SECRET=$(openssl rand -hex 32)
echo -e "${amarelo}Instalando WiseMapping...${reset}"
docker volume create wisemapping_data > /dev/null 2>&1
POSTGRES_PASSWORD=$(grep "Senha:" /root/dados_vps/dados_postgres | awk -F"Senha:" '{print $2}' | xargs)

cat > wisemapping.yaml <<YAML
version: "3.7"
services:
  wisemapping:
    image: wisemapping/wisemapping:latest
    volumes:
      - wisemapping_data:/usr/local/tomcat/webapps/wisemapping/WEB-INF/data
    networks:
      - $POSTGRES_PASSWORD$NOME_REDE_INTERNA
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/wisemapping?stringtype=unspecified
      - SPRING_DATASOURCE_USERNAME=postgres
      - SPRING_DATASOURCE_PASSWORD=$POSTGRES_PASSWORD
      - APP_SITE_UI_BASE_URL=https://$POSTGRES_PASSWORD$DOMAIN_WISEMAPPING
      - APP_SITE_API_BASE_URL=https://$POSTGRES_PASSWORD$DOMAIN_WISEMAPPING
      - APP_JWT_SECRET=$JWT_SECRET
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.wisemapping.rule=Host($POSTGRES_PASSWORD`$POSTGRES_PASSWORD$DOMAIN_WISEMAPPING$POSTGRES_PASSWORD`)
        - traefik.http.routers.wisemapping.entrypoints=websecure
        - traefik.http.routers.wisemapping.tls.certresolver=letsencryptresolver
        - traefik.http.services.wisemapping.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  wisemapping_data:
    external: true
networks:
  $POSTGRES_PASSWORD$NOME_REDE_INTERNA:
    external: true
YAML
ensure_db "postgres" "wisemapping" || { echo "Erro ao preparar o banco"; exit 1; }
deploy_via_portainer "$POSTGRES_PASSWORD$STACK_NAME" "wisemapping.yaml"
[ $POSTGRES_PASSWORD$? -eq 0 ] && echo -e "$POSTGRES_PASSWORD${verde}OK$POSTGRES_PASSWORD${reset}" && save_data "app-wisemapping" "[ WISEMAPPING ]

Dominio: https://$POSTGRES_PASSWORD$DOMAIN_WISEMAPPING

Host: wisemapping

Port: 3000

Usuario: postgres

JWT Secret: $JWT_SECRET

Rede: $POSTGRES_PASSWORD$NOME_REDE_INTERNA"
rm -f wisemapping.yaml; exit 0