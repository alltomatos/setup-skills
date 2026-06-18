#!/bin/bash
# =============================================================================
# skills/app-yourls/run.sh
# Skill: Instalação do YOURLS via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="yourls"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do MySQL (ADR-001)
if [ -f "/root/dados_vps/dados_mysql" ]; then
    MYSQL_PASS=$(grep "Senha:" /root/dados_vps/dados_mysql | awk '{print $2}')
else
    MYSQL_PASS=$MYSQL_PASSWORD
fi

echo -e "${amarelo}Instalando YOURLS em $DOMAIN_YOURLS...${reset}"

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > yourls${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: yourls:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - YOURLS_SITE=https://$DOMAIN_YOURLS
      - YOURLS_USER=$YOURLS_USER
      - YOURLS_PASS=$YOURLS_PASSWORD
      - YOURLS_DB_HOST=mysql
      - YOURLS_DB_NAME=yourls
      - YOURLS_DB_USER=root
      - YOURLS_DB_PASS=$MYSQL_PASS
    deploy:
      mode: replicated
      replicas: 1
      resources:
        limits:
          cpus: "1"
          memory: 1024M
      labels:
        - traefik.enable=true
        - traefik.http.routers.yourls.rule=Host(\`$DOMAIN_YOURLS\`)
        - traefik.http.routers.yourls.entrypoints=websecure
        - traefik.http.routers.yourls.tls.certresolver=letsencrypt
        - traefik.http.routers.yourls.service=yourls
        - traefik.http.services.yourls.loadbalancer.server.port=80
        - traefik.http.routers.yourls.tls=true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "yourls${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-yourls" "[ YOURLS ]

Dominio: https://$DOMAIN_YOURLS

Host: app

Port: 80

Usuario: $YOURLS_USER

Senha: $YOURLS_PASSWORD

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f yourls${SUFFIX}.yaml
exit 0
