#!/bin/bash
# =============================================================================
# skills/app-nocobase/run.sh
# Skill: Instalação do NocoBase via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="nocobase"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Ler ou gerar segredos (idempotência)
APP_KEY=$(read_data "app-nocobase" | grep -oP '(?<=- APP_KEY: ).*' || openssl rand -hex 16)
ENCRYPTION_KEY=$(read_data "app-nocobase" | grep -oP '(?<=- ENCRYPTION_KEY: ).*' || openssl rand -hex 16)

# Resolver banco — usa infra-postgres se já existir, caso contrário falha
# O orquestrador (devops) garante que depends_on está satisfeito antes de chamar
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then
    echo -e "\e[31mErro: infra-postgres não está instalado. Execute /devops e instale postgres primeiro.\e[0m"
    exit 1
fi

echo -e "${amarelo}Instalando NocoBase no domínio $DOMAIN_NOCOBASE...${reset}"

docker volume create nocobase_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > nocobase${SUFFIX}.yaml <<'YAML'
version: "3.7"
services:
  nocobase:
    image: nocobase/nocobase:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - nocobase_data:/app/nocobase/storage
    environment:
      - INIT_ROOT_EMAIL=$NOCOBASE_EMAIL
      - INIT_ROOT_PASSWORD=$NOCOBASE_PASSWORD
      - INIT_ROOT_NICKNAME=$NOCOBASE_USERNAME
      - INIT_ROOT_USERNAME=$NOCOBASE_USERNAME
      - INIT_LANG=pt-BR
      - DB_DIALECT=postgres
      - DB_HOST=postgres
      - DB_DATABASE=nocobase
      - DB_USER=postgres
      - DB_PASSWORD=$POSTGRES_PASSWORD
      - LOCAL_STORAGE_BASE_URL=/storage/uploads
      - API_BASE_PATH=/api/
      - APP_KEY=$APP_KEY
      - ENCRYPTION_FIELD_KEY=$ENCRYPTION_KEY
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
        - traefik.http.routers.nocobase.rule=Host(`$DOMAIN_NOCOBASE`)
        - traefik.http.services.nocobase.loadbalancer.server.port=80
        - traefik.http.routers.nocobase.service=nocobase
        - traefik.http.routers.nocobase.tls.certresolver=letsencryptresolver
        - traefik.http.routers.nocobase.entrypoints=websecure
        - traefik.http.routers.nocobase.tls=true

volumes:
  nocobase_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "nocobase${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-nocobase" "[ NOCOBASE ]

Dominio: https://$DOMAIN_NOCOBASE

Host: nocobase

Port: 80

Usuario: $NOCOBASE_EMAIL

Senha: $NOCOBASE_PASSWORD

App Key: $APP_KEY

Encryption Key: $ENCRYPTION_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f nocobase${SUFFIX}.yaml
exit 0
