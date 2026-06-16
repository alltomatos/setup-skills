#!/bin/bash
# =============================================================================
# skills/app-mautic/run.sh
# Skill: Instalação do Mautic 5 via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="mautic"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Mautic 5 no domínio $DOMAIN_MAUTIC...${reset}"

# Criar volumes
docker volume create mautic_config > /dev/null 2>&1
docker volume create mautic_docroot > /dev/null 2>&1
docker volume create mautic_media > /dev/null 2>&1
docker volume create mautic_logs > /dev/null 2>&1
docker volume create mautic_cron > /dev/null 2>&1

cat > mautic.yaml <<EOL
version: "3.7"
services:
  mautic_web:
    image: mautic/mautic:5.2.8-apache
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - mautic_config:/var/www/html/config
      - mautic_docroot:/var/www/html/docroot
      - mautic_media:/var/www/html/docroot/media
      - mautic_logs:/var/www/html/var/logs
      - mautic_cron:/opt/mautic/cron
    environment:
      - MAUTIC_URL=https://$DOMAIN_MAUTIC
      - MAUTIC_DB_NAME=mautic
      - MAUTIC_DB_HOST=mysql
      - MAUTIC_DB_PORT=3306
      - MAUTIC_DB_USER=root
      - MAUTIC_DB_PASSWORD=\$MYSQL_ROOT_PASSWORD
      - MAUTIC_TRUSTED_PROXIES=["0.0.0.0/0"]
      - DOCKER_MAUTIC_ROLE=mautic_web
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.mautic.rule=Host(\`$DOMAIN_MAUTIC\`)"
        - "traefik.http.routers.mautic.entrypoints=websecure"
        - "traefik.http.routers.mautic.tls.certresolver=letsencrypt"
        - "traefik.http.services.mautic.loadbalancer.server.port=80"
      resources:
        limits:
          cpus: "2"
          memory: 2048M

  mautic_worker:
    image: mautic/mautic:5.2.8-apache
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - mautic_config:/var/www/html/config
      - mautic_docroot:/var/www/html/docroot
      - mautic_media:/var/www/html/docroot/media
      - mautic_logs:/var/www/html/var/logs
      - mautic_cron:/opt/mautic/cron
    environment:
      - MAUTIC_URL=https://$DOMAIN_MAUTIC
      - MAUTIC_DB_NAME=mautic
      - MAUTIC_DB_HOST=mysql
      - MAUTIC_DB_PASSWORD=\$MYSQL_ROOT_PASSWORD
      - DOCKER_MAUTIC_ROLE=mautic_worker
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  mautic_cron:
    image: mautic/mautic:5.2.8-apache
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - mautic_config:/var/www/html/config
      - mautic_docroot:/var/www/html/docroot
      - mautic_media:/var/www/html/docroot/media
      - mautic_logs:/var/www/html/var/logs
      - mautic_cron:/opt/mautic/cron
    environment:
      - MAUTIC_URL=https://$DOMAIN_MAUTIC
      - MAUTIC_DB_NAME=mautic
      - MAUTIC_DB_HOST=mysql
      - MAUTIC_DB_PASSWORD=\$MYSQL_ROOT_PASSWORD
      - DOCKER_MAUTIC_ROLE=mautic_cron
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  mautic_config:
    external: true
  mautic_docroot:
    external: true
  mautic_media:
    external: true
  mautic_logs:
    external: true
  mautic_cron:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

docker stack deploy --prune --resolve-image always -c mautic.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-mautic" "# Mautic 5\n\n- Status: Instalado\n- URL: https://$DOMAIN_MAUTIC\n- DB: MySQL (global)"
else
    exit 1
fi

rm mautic.yaml
exit 0
