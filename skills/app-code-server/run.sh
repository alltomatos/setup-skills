#!/bin/bash
# =============================================================================
# skills/app-code-server/run.sh
# Skill: Instalação do Code-Server via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="code-server"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Instalando Code-Server em $DOMAIN_CODE_SERVER...${reset}"

docker volume create code_server_config > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > code_server${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: lscr.io/linuxserver/code-server:latest
    volumes:
      - code_server_config:/config
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
      - PASSWORD=$CODE_SERVER_PASSWORD
      - SUDO_PASSWORD=$CODE_SERVER_SUDO_PASSWORD
      - PROXY_DOMAIN=$DOMAIN_CODE_SERVER
      - DEFAULT_WORKSPACE=/config/workspace
      - PWA_APPNAME=Orion Code
      - DOCKER_MODS=linuxserver/mods:code-server-nodejs|linuxserver/mods:code-server-npmglobal
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
        - traefik.http.routers.code-server.rule=Host(\`$DOMAIN_CODE_SERVER\`)
        - traefik.http.services.code-server.loadbalancer.server.port=8443
        - traefik.http.routers.code-server.service=code-server
        - traefik.http.routers.code-server.entrypoints=websecure
        - traefik.http.routers.code-server.tls.certresolver=letsencryptresolver
        - traefik.http.routers.code-server.tls=true

volumes:
  code_server_config:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "code_server${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-code-server" "[ CODE-SERVER ]

Dominio: https://$DOMAIN_CODE_SERVER

Host: app

Port: 8443

Senha: $CODE_SERVER_PASSWORD

Senha Sudo: $CODE_SERVER_SUDO_PASSWORD

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f code_server${SUFFIX}.yaml
exit 0
