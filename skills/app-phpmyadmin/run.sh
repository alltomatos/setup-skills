#!/bin/bash
# =============================================================================
# skills/app-phpmyadmin/run.sh
# Skill: Instalação do phpMyAdmin via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="phpmyadmin"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Tratar HOST:PORTA
if [[ "$MYSQL_HOST" == *:* ]]; then
  PMA_PORT=$(echo "$MYSQL_HOST" | cut -d':' -f2)
  PMA_HOST=$(echo "$MYSQL_HOST" | cut -d':' -f1)
else
  PMA_PORT=3306
  PMA_HOST=$MYSQL_HOST
fi

echo -e "${amarelo}Instalando phpMyAdmin em $DOMAIN_PHPMYADMIN...${reset}"

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > phpmyadmin${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: phpmyadmin/phpmyadmin:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - PMA_HOSTS=$PMA_HOST
      - PMA_PORT=$PMA_PORT
      - PMA_ABSOLUTE_URI=https://$DOMAIN_PHPMYADMIN
      - UPLOAD_LIMIT=64M
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
      labels:
        - traefik.enable=true
        - traefik.http.routers.phpmyadmin.rule=Host(\`$DOMAIN_PHPMYADMIN\`)
        - traefik.http.routers.phpmyadmin.entrypoints=websecure
        - traefik.http.routers.phpmyadmin.tls.certresolver=letsencrypt
        - traefik.http.services.phpmyadmin.loadbalancer.server.port=80
        - traefik.http.routers.phpmyadmin.service=phpmyadmin
        - traefik.http.routers.phpmyadmin.tls=true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "phpmyadmin${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-phpmyadmin" "[ PHPMYADMIN ]

Dominio: https://$DOMAIN_PHPMYADMIN

Host: app

Port: 80

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f phpmyadmin${SUFFIX}.yaml
exit 0
