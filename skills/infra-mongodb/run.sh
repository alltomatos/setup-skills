#!/bin/bash
# =============================================================================
# skills/infra-mongodb/run.sh
# Skill: Instalação do MongoDB 6.0 via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
reset="\e[0m"

# Variáveis
STACK_NAME="mongodb"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
    MONGO_INITDB_ROOT_PASSWORD=$(openssl rand -hex 16)
    GEN_PWD=true
else
    GEN_PWD=false
fi

echo -e "${amarelo}Instalando MongoDB 6.0 via Docker Swarm...${reset}"

docker volume create mongodb_data > /dev/null 2>&1

cat > mongodb.yaml <<EOL
version: "3.7"
services:
  mongodb:
    image: mongo:6.0
    volumes:
      - mongodb_data:/data/db
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MONGO_INITDB_ROOT_USERNAME=root
      - MONGO_INITDB_ROOT_PASSWORD=$MONGO_INITDB_ROOT_PASSWORD
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  mongodb_data:
    external: true
    name: mongodb_data

networks:
  $NOME_REDE_INTERNA:
    external: true
    name: $NOME_REDE_INTERNA
EOL

deploy_via_portainer "$STACK_NAME" "mongodb.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    
    # Formato Setup Orion (dados_mongodb) — credenciais persistidas (ADR-002 rev.)
    CONTENT="[ MONGODB ]

Dominio do MongoDB: mongodb://root:${MONGO_INITDB_ROOT_PASSWORD}@mongodb:27017/?authSource=admin

Host: mongodb

Port: 27017

Usuario: root

Senha: ${MONGO_INITDB_ROOT_PASSWORD}

Rede: ${NOME_REDE_INTERNA}
"
    save_data "infra-mongodb" "$CONTENT"
else
    echo -e "${vermelho}Erro ao fazer o deploy da stack MongoDB.${reset}"
    exit 1
fi

rm mongodb.yaml
exit 0
