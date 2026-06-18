#!/bin/bash
# =============================================================================
# skills/app-pgadmin/run.sh
# Skill: Instalação do pgAdmin 4 via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="pgadmin"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Instalando pgAdmin 4 em $DOMAIN_PGADMIN...${reset}"

docker volume create pgadmin_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > pgadmin${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: dpage/pgadmin4:latest
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - PGADMIN_DEFAULT_EMAIL=$PGADMIN_USER
      - PGADMIN_DEFAULT_PASSWORD=$PGADMIN_PASSWORD
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
        - traefik.http.routers.pgadmin.rule=Host(\`$DOMAIN_PGADMIN\`)
        - traefik.http.routers.pgadmin.entrypoints=websecure
        - traefik.http.routers.pgadmin.tls.certresolver=letsencrypt
        - traefik.http.services.pgadmin.loadbalancer.server.port=80
        - traefik.http.routers.pgadmin.service=pgadmin
        - traefik.http.routers.pgadmin.tls=true

volumes:
  pgadmin_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "pgadmin${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-pgadmin" "[ PGADMIN ]

Dominio: https://$DOMAIN_PGADMIN

Host: app

Port: 80

Usuario: $PGADMIN_USER

Senha: $PGADMIN_PASSWORD

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f pgadmin${SUFFIX}.yaml
exit 0
