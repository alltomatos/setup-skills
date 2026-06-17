#!/bin/bash
# =============================================================================
# skills/infra-rabbitmq/run.sh
# Skill: Instalação do RabbitMQ via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
reset="\e[0m"

# Variáveis
STACK_NAME="rabbitmq"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

if [ -z "$RABBITMQ_DEFAULT_PASS" ]; then
    RABBITMQ_DEFAULT_PASS=$(openssl rand -hex 16)
    GEN_PWD=true
else
    GEN_PWD=false
fi

echo -e "${amarelo}Instalando RabbitMQ via Docker Swarm...${reset}"

docker volume create rabbitmq_data > /dev/null 2>&1

cat > rabbitmq.yaml <<EOL
version: "3.7"
services:
  rabbitmq:
    image: rabbitmq:3-management
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=$RABBITMQ_DEFAULT_PASS
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  rabbitmq_data:
    external: true
    name: rabbitmq_data

networks:
  $NOME_REDE_INTERNA:
    external: true
    name: $NOME_REDE_INTERNA
EOL

deploy_via_portainer "$STACK_NAME" "rabbitmq.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    
    CONTENT="# RabbitMQ (Infra/Fila)

- **Status**: Instalado
- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **Host**: rabbitmq
- **Portas**: 5672 (AMQP), 15672 (Management)
- **Usuário**: admin
- **Rede**: $NOME_REDE_INTERNA
- **Senha Gerada**: $([ "$GEN_PWD" = true ] && echo "Sim" || echo "Não")
"
    save_data "infra-rabbitmq" "$CONTENT"
else
    echo -e "${vermelho}Erro ao fazer o deploy da stack RabbitMQ.${reset}"
    exit 1
fi

rm rabbitmq.yaml
exit 0
