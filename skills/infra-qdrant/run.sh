#!/bin/bash
# =============================================================================
# skills/infra-qdrant/run.sh
# Skill: Instalação do Qdrant via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="qdrant"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Instalando Qdrant via Docker Swarm...${reset}"

docker volume create qdrant_data > /dev/null 2>&1

cat > qdrant.yaml <<EOL
version: "3.7"
services:
  qdrant:
    image: qdrant/qdrant:latest
    volumes:
      - qdrant_data:/qdrant/storage
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1024M
EOL

deploy_via_portainer "$STACK_NAME" "qdrant.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    CONTENT="[ QDRANT ]

Host: qdrant

Port: 6333

Usuario: Não tem

Senha: Não tem

Rede: $NOME_REDE_INTERNA"
    save_data "infra-qdrant" "$CONTENT"
else
    exit 1
fi

rm qdrant.yaml
exit 0
