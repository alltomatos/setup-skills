#!/bin/bash
# =============================================================================
# skills/infra-postgres/run.sh
# Skill: Instalação do PostgreSQL 14 via Docker Swarm
#
# Padrão Orion:
#   - Idempotente
#   - Rede interna Orion
#   - Persistência em /root/dados_vps/infra-postgres.md
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
reset="\e[0m"

# Variáveis
SERVICE_NAME="postgres"
STACK_NAME="postgres"
DATA_FILE="/root/dados_vps/infra-postgres.md"

# 1. Obter Nome da Rede Interna
# No ecossistema Orion, a rede é definida no bootstrap/traefik. 
# Tentamos descobrir o nome da rede criada pelo traefik.
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# 2. Gerar senha se não fornecida
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(openssl rand -hex 16)
    GEN_PWD=true
else
    GEN_PWD=false
fi

echo -e "${amarelo}Instalando PostgreSQL 14 via Docker Swarm...${reset}"

# 3. Criar volume se não existir
docker volume create postgres_data > /dev/null 2>&1

# 4. Criar Stack YAML
cat > postgres.yaml <<EOL
version: "3.7"
services:
  postgres:
    image: postgres:14
    command: >
      postgres
      -c max_connections=500
      -c shared_buffers=512MB
      -c timezone=America/Sao_Paulo
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
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
          memory: 1024M

volumes:
  postgres_data:
    external: true
    name: postgres_data

networks:
  $NOME_REDE_INTERNA:
    external: true
    name: $NOME_REDE_INTERNA
EOL

# 5. Deploy da Stack
deploy_via_portainer "$STACK_NAME" "postgres.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    
    # 6. Persistir metadados (Markdown)
    CONTENT="# PostgreSQL (Infra)

- **Status**: Instalado
- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **Versão**: 14
- **Host**: postgres
- **Porta**: 5432
- **Usuário**: postgres
- **Rede**: $NOME_REDE_INTERNA
- **Senha Gerada**: $([ "$GEN_PWD" = true ] && echo "Sim" || echo "Não (fornecida pelo usuário)")

> Nota: A senha real não é persistida aqui conforme ADR-002.
"
    save_data "infra-postgres" "$CONTENT"
    
    echo -e "${branco}Dados da skill salvos em: $DATA_FILE${reset}"
else
    echo -e "${vermelho}Erro ao fazer o deploy da stack PostgreSQL.${reset}"
    exit 1
fi

# Limpeza
rm postgres.yaml
exit 0
