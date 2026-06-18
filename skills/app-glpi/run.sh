#!/bin/bash
# =============================================================================
# skills/app-glpi/run.sh
# Skill: Instalação do GLPI via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="glpi"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do MySQL (ADR-001)
if [ -f "/root/dados_vps/dados_mysql" ]; then
    MYSQL_PASS=$(grep "Senha:" /root/dados_vps/dados_mysql | awk '{print $2}')
else
    MYSQL_PASS=$MYSQL_PASSWORD
fi

echo -e "${amarelo}Instalando GLPI em $DOMAIN_GLPI...${reset}"

docker volume create glpi_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > glpi${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: diouxx/glpi:latest
    volumes:
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
      - glpi_data:/var/www/html/glpi
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - TIMEZONE=America/Sao_Paulo
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
        - traefik.http.routers.glpi.rule=Host(\`$DOMAIN_GLPI\`)
        - traefik.http.services.glpi.loadbalancer.server.port=80
        - traefik.http.routers.glpi.service=glpi
        - traefik.http.routers.glpi.entrypoints=websecure
        - traefik.http.routers.glpi.tls.certresolver=letsencryptresolver
        - traefik.http.routers.glpi.tls=true

volumes:
  glpi_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "glpi${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-glpi" "[ GLPI ]

Dominio: https://$DOMAIN_GLPI

Host: app

Port: 80

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f glpi${SUFFIX}.yaml
exit 0
