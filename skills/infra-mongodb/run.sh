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
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

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

docker stack deploy --prune --resolve-image always -c mongodb.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    
    CONTENT="# MongoDB (Infra)

- **Status**: Instalado
- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **Versão**: 6.0
- **Host**: mongodb
- **Porta**: 27017
- **Usuário**: root
- **Rede**: $NOME_REDE_INTERNA
- **Senha Gerada**: $([ "$GEN_PWD" = true ] && echo "Sim" || echo "Não")
"
    save_data "infra-mongodb" "$CONTENT"
else
    echo -e "${vermelho}Erro ao fazer o deploy da stack MongoDB.${reset}"
    exit 1
fi

rm mongodb.yaml
exit 0
