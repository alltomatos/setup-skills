#!/bin/bash
# =============================================================================
# skills/app-checkmate/run.sh
# Skill: Instalação do Checkmate via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="checkmate"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Persistência de Segredos (ADR-001)
if service_exists "app-checkmate"; then
    JWT_SECRET=$(read_data "app-checkmate" | grep "JWT_SECRET:" | awk '{print $2}')
fi

# Geração de chaves se não existirem (ADR-002: runtime fallback)
JWT_SECRET=${JWT_SECRET:-$(openssl rand -hex 16)}

# Carregar credenciais do MongoDB do dados_mongodb (formato Setup Orion).
# Env (MONGO_USER/MONGO_PASS) tem prioridade; senão lê do arquivo persistido.
if [ ! -f "/root/dados_vps/dados_mongodb" ]; then
    echo -e "\e[31mErro: infra-mongodb não encontrado em /root/dados_vps/ (instale a dependência).\e[0m"
    exit 1
fi
MONGO_USER="${MONGO_USER:-$(grep "Usuario:" /root/dados_vps/dados_mongodb | awk -F"Usuario:" '{print $2}' | xargs)}"
MONGO_USER="${MONGO_USER:-root}"
MONGO_PASS="${MONGO_PASS:-$(grep "Senha:" /root/dados_vps/dados_mongodb | awk -F"Senha:" '{print $2}' | xargs)}"
if [ -z "$MONGO_PASS" ]; then
    echo -e "\e[31mErro: senha do MongoDB ausente em /root/dados_vps/dados_mongodb (e MONGO_PASS não informado).\e[0m"
    exit 1
fi

echo -e "${amarelo}Instalando Checkmate em $DOMAIN_CHECKMATE...${reset}"

docker volume create checkmate_redis_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > checkmate${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  client:
    image: ghcr.io/bluewave-labs/checkmate-client:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - UPTIME_APP_CLIENT_HOST=https://$DOMAIN_CHECKMATE
      - UPTIME_APP_API_BASE_URL=https://$DOMAIN_CHECKMATE_API/api/v1
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
        - traefik.http.routers.checkmate_client.rule=Host(\`$DOMAIN_CHECKMATE\`)
        - traefik.http.services.checkmate_client.loadbalancer.server.port=80
        - traefik.http.routers.checkmate_client.service=checkmate_client
        - traefik.http.routers.checkmate_client.tls.certresolver=letsencryptresolver
        - traefik.http.routers.checkmate_client.entrypoints=websecure
        - traefik.http.routers.checkmate_client.tls=true

  server:
    image: ghcr.io/bluewave-labs/checkmate-backend:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      $NOME_REDE_INTERNA:
        aliases:
          - server 
    environment:
      - VITE_APP_API_BASE_URL=https://$DOMAIN_CHECKMATE_API/api/v1
      - VITE_APP_CLIENT_HOST=https://$DOMAIN_CHECKMATE
      - UPTIME_APP_CLIENT_HOST=https://$DOMAIN_CHECKMATE
      - CLIENT_HOST=https://$DOMAIN_CHECKMATE
      - VITE_APP_LOG_LEVEL=info
      - DB_CONNECTION_STRING=mongodb://$MONGO_USER:$MONGO_PASS@mongodb:27017/checkmate?authSource=admin
      - REDIS_URL=redis://checkmate_redis:6379
      - JWT_SECRET=$JWT_SECRET
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
        - traefik.http.routers.checkmate_server.rule=Host(\`$DOMAIN_CHECKMATE_API\`)
        - traefik.http.services.checkmate_server.loadbalancer.server.port=52345
        - traefik.http.routers.checkmate_server.service=checkmate_server
        - traefik.http.routers.checkmate_server.tls.certresolver=letsencryptresolver
        - traefik.http.routers.checkmate_server.entrypoints=websecure
        - traefik.http.routers.checkmate_server.tls=true

  redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - checkmate_redis_data:/data
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  checkmate_redis_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "checkmate${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-checkmate" "[ CHECKMATE ]

Dominio: https://$DOMAIN_CHECKMATE

API: https://$DOMAIN_CHECKMATE_API

JWT_SECRET: $JWT_SECRET

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f checkmate${SUFFIX}.yaml
exit 0
