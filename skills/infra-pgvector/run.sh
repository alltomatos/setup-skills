#!/bin/bash
# =============================================================================
# skills/infra-pgvector/run.sh
# Skill: Instalação do PostgreSQL + pgvector via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
reset="\e[0m"

# Variáveis
SERVICE_NAME="pgvector"
STACK_NAME="pgvector"
DATA_FILE="/root/dados_vps/dados_pgvector"

NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

if [ -z "$PGVECTOR_PASSWORD" ]; then
    PGVECTOR_PASSWORD=$(openssl rand -hex 16)
    GEN_PWD=true
else
    GEN_PWD=false
fi

echo -e "${amarelo}Instalando PostgreSQL + pgvector via Docker Swarm...${reset}"

docker volume create pgvector_data > /dev/null 2>&1

cat > pgvector.yaml <<EOL
version: "3.7"
services:
  pgvector:
    image: ankane/pgvector:v0.4.1 # Imagem otimizada com pgvector
    command: >
      postgres
      -c max_connections=500
      -c shared_buffers=512MB
      -c timezone=America/Sao_Paulo
    volumes:
      - pgvector_data:/var/lib/postgresql/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - POSTGRES_PASSWORD=$PGVECTOR_PASSWORD
      - TZ=America/Sao_Paulo
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 2048M # Mais memória para buscas vetoriais

volumes:
  pgvector_data:
    external: true
    name: pgvector_data

networks:
  $NOME_REDE_INTERNA:
    external: true
    name: $NOME_REDE_INTERNA
EOL

deploy_via_portainer "$STACK_NAME" "pgvector.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    
    CONTENT="[ PGVECTOR ]

Host: pgvector

Port: 5432

Usuario: postgres

Senha: $PGVECTOR_PASSWORD

Rede: $NOME_REDE_INTERNA"
    save_data "infra-pgvector" "$CONTENT"
else
    echo -e "${vermelho}Erro ao fazer o deploy da stack pgvector.${reset}"
    exit 1
fi

rm pgvector.yaml
exit 0
