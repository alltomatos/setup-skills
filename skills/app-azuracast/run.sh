#!/bin/bash
# =============================================================================
# skills/app-azuracast/run.sh
# Skill: Instalação do AzuraCast via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="azuracast"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Geração ou recuperação de senhas internas (ADR-001/002)
MYSQL_PASS=""
if service_exists "app-azuracast"; then
    MYSQL_PASS=$(read_data "app-azuracast" | grep "\- MySQL Pass:" | cut -d ':' -f 2 | xargs)
fi

if [ -z "$MYSQL_PASS" ]; then
    MYSQL_PASS=$(openssl rand -hex 16)
fi

echo -e "${amarelo}Instalando AzuraCast em $DOMAIN_AZURACAST...${reset}"

# Criando volumes
docker volume create azuracast_station_data > /dev/null 2>&1
docker volume create azuracast_backups > /dev/null 2>&1
docker volume create azuracast_db_data > /dev/null 2>&1
docker volume create azuracast_www_uploads > /dev/null 2>&1
docker volume create azuracast_shoutcast2_install > /dev/null 2>&1
docker volume create azuracast_stereo_tool_install > /dev/null 2>&1
docker volume create azuracast_rsas_install > /dev/null 2>&1
docker volume create azuracast_geolite_install > /dev/null 2>&1
docker volume create azuracast_sftpgo_data > /dev/null 2>&1
docker volume create azuracast_acme > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > azuracast${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  web:
    image: ghcr.io/azuracast/azuracast:latest
    volumes:
      - azuracast_station_data:/var/azuracast/stations
      - azuracast_backups:/var/azuracast/backups
      - azuracast_db_data:/var/lib/mysql
      - azuracast_www_uploads:/var/azuracast/storage/uploads
      - azuracast_shoutcast2_install:/var/azuracast/storage/shoutcast2
      - azuracast_stereo_tool_install:/var/azuracast/storage/stereo_tool
      - azuracast_rsas_install:/var/azuracast/storage/rsas
      - azuracast_geolite_install:/var/azuracast/storage/geoip
      - azuracast_sftpgo_data:/var/azuracast/storage/sftpgo
      - azuracast_acme:/var/azuracast/storage/acme
    networks:
      - $NOME_REDE_INTERNA
    ports:
      - target: 2022
        published: 2022
        protocol: tcp
        mode: host
      - target: 8005
        published: 8005
        protocol: tcp
        mode: host
    environment:
      - AZURACAST_HTTP_PORT=80
      - AZURACAST_HTTPS_PORT=443
      - AZURACAST_SFTP_PORT=2022
      - AZURACAST_PUID=1000
      - AZURACAST_PGID=1000
      - ENABLE_INTERNAL_MYSQL=true
      - MYSQL_ROOT_PASSWORD=$MYSQL_PASS
      - MYSQL_DATABASE=azuracast
      - MYSQL_USER=azuracast
      - MYSQL_PASSWORD=$MYSQL_PASS
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.azuracast.rule=Host(\`$DOMAIN_AZURACAST\`)
        - traefik.http.services.azuracast.loadbalancer.server.port=80
        - traefik.http.routers.azuracast.entrypoints=websecure
        - traefik.http.routers.azuracast.tls.certresolver=letsencryptresolver
        - traefik.http.routers.azuracast.tls=true

  updater:
    image: ghcr.io/azuracast/updater:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager

volumes:
  azuracast_station_data: {external: true}
  azuracast_backups: {external: true}
  azuracast_db_data: {external: true}
  azuracast_www_uploads: {external: true}
  azuracast_shoutcast2_install: {external: true}
  azuracast_stereo_tool_install: {external: true}
  azuracast_rsas_install: {external: true}
  azuracast_geolite_install: {external: true}
  azuracast_sftpgo_data: {external: true}
  azuracast_acme: {external: true}

networks:
  $NOME_REDE_INTERNA: {external: true}
YAML

deploy_via_portainer "$STACK_NAME" "azuracast${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-azuracast" "[ AZURACAST ]

Dominio: https://$DOMAIN_AZURACAST

Host: web

Port: 80

Usuario: azuracast

Senha: $MYSQL_PASS

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f azuracast${SUFFIX}.yaml
exit 0
