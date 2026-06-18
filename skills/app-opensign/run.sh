#!/bin/bash
# skills/app-opensign/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="opensign"; NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
if ! docker service ls --format "{{.Name}}" | grep -q "^mongodb$"; then echo -e "\e[31mErro: infra-mongodb nao instalado.\e[0m"; exit 1; fi

# Persistencia de Segredos (ADR-001)
if service_exists "app-opensign"; then
    EXISTING_DATA=$(read_data "app-opensign")
    MASTER_KEY=$(echo "$EXISTING_DATA" | grep "Master Key: " | sed 's/.*Master Key: //')
    JWT_SECRET=$(echo "$EXISTING_DATA" | grep "JWT Secret: " | sed 's/.*JWT Secret: //')
fi

[ -z "$MASTER_KEY" ] && MASTER_KEY=$(openssl rand -hex 16)
[ -z "$JWT_SECRET" ] && JWT_SECRET=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando OpenSign...${reset}"
docker volume create opensign_files > /dev/null 2>&1
cat > opensign.yaml <<'YAML'
version: "3.7"
services:
  opensign_server:
    image: opensign/opensignserver:main
    command: ["node", "index.js"]
    volumes:
      - opensign_files:/usr/src/app/files
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NODE_ENV=production
      - SERVER_URL=https://$DOMAIN_OPENSIGN/app
      - PUBLIC_URL=https://$DOMAIN_OPENSIGN
      - PORT=8080
      - MONGODB_URI=mongodb://mongodb:27017/OpenSignDB?authSource=admin
      - DATABASE_URI=mongodb://mongodb:27017/OpenSignDB?authSource=admin
      - MASTER_KEY=$MASTER_KEY
      - JWT_SECRET=$JWT_SECRET
      - USE_LOCAL=true
      - SMTP_ENABLE=false
      - TZ=America/Sao_Paulo
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.opensign_server.rule=Host(`$DOMAIN_OPENSIGN`) && PathPrefix(`/app`)
        - traefik.http.routers.opensign_server.entrypoints=websecure
        - traefik.http.routers.opensign_server.tls.certresolver=letsencrypt
        - traefik.http.services.opensign_server.loadbalancer.server.port=8080
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  opensign_client:
    image: opensign/opensign:main
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - NODE_ENV=production
      - REACT_APP_SERVERURL=https://$DOMAIN_OPENSIGN/app
      - PUBLIC_URL=https://$DOMAIN_OPENSIGN
      - REACT_APP_APPID=opensign
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.opensign_client.rule=Host(`$DOMAIN_OPENSIGN`) && !PathPrefix(`/app`)
        - traefik.http.routers.opensign_client.entrypoints=websecure
        - traefik.http.routers.opensign_client.tls.certresolver=letsencrypt
        - traefik.http.services.opensign_client.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  opensign_files:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "opensign.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-opensign" "[ OPENSIGN ]

Dominio: https://$DOMAIN_OPENSIGN

Host: opensign_server

Port: 8080

Master Key: $MASTER_KEY

JWT Secret: $JWT_SECRET

Rede: $NOME_REDE_INTERNA"
rm -f opensign.yaml; exit 0