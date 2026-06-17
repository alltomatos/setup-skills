#!/bin/bash
# =============================================================================
# skills/app-wordpress/run.sh
# Skill: Instalação do WordPress via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="wordpress_$WORDPRESS_SITE_NAME"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Carregar credenciais do MySQL (ADR-001)
if [ -f "/root/dados_vps/infra-mysql.md" ]; then
    MYSQL_PASS=$(grep "Senha root:" /root/dados_vps/infra-mysql.md | awk '{print $3}')
else
    MYSQL_PASS=$MYSQL_PASSWORD
fi

echo -e "${amarelo}Instalando WordPress ($WORDPRESS_SITE_NAME) em $DOMAIN_WORDPRESS...${reset}"

docker volume create wordpress_$WORDPRESS_SITE_NAME > /dev/null 2>&1
docker volume create wordpress_${WORDPRESS_SITE_NAME}_php > /dev/null 2>&1
docker volume create wordpress_${WORDPRESS_SITE_NAME}_redis > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > wordpress_${WORDPRESS_SITE_NAME}${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: wordpress:latest
    volumes:
      - wordpress_$WORDPRESS_SITE_NAME:/var/www/html
      - wordpress_${WORDPRESS_SITE_NAME}_php:/usr/local/etc/php
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - WORDPRESS_DB_NAME=$WORDPRESS_SITE_NAME
      - WORDPRESS_DB_HOST=mysql
      - WORDPRESS_DB_PORT=3306
      - WORDPRESS_DB_USER=root
      - WORDPRESS_DB_PASSWORD=$MYSQL_PASS
      - WP_REDIS_HOST=redis
      - WP_REDIS_PORT=6379
      - WP_REDIS_DATABASE=1
      - VIRTUAL_HOST=$DOMAIN_WORDPRESS
      - WP_LOCALE=pt_BR
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.wordpress_$WORDPRESS_SITE_NAME.rule=Host(\`$DOMAIN_WORDPRESS\`)
        - traefik.http.routers.wordpress_$WORDPRESS_SITE_NAME.entrypoints=websecure
        - traefik.http.routers.wordpress_$WORDPRESS_SITE_NAME.tls.certresolver=letsencrypt
        - traefik.http.routers.wordpress_$WORDPRESS_SITE_NAME.service=wordpress_$WORDPRESS_SITE_NAME
        - traefik.http.services.wordpress_$WORDPRESS_SITE_NAME.loadbalancer.server.port=80

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - wordpress_${WORDPRESS_SITE_NAME}_redis:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  wordpress_$WORDPRESS_SITE_NAME:
    external: true
  wordpress_${WORDPRESS_SITE_NAME}_php:
    external: true
  wordpress_${WORDPRESS_SITE_NAME}_redis:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "wordpress_${WORDPRESS_SITE_NAME}${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-wordpress" "# WordPress: $WORDPRESS_SITE_NAME\n\n- Status: Instalado\n- URL: https://$DOMAIN_WORDPRESS"
else
    exit 1
fi

rm -f wordpress_${WORDPRESS_SITE_NAME}${SUFFIX}.yaml
exit 0
