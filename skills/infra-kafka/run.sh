#!/bin/bash
# =============================================================================
# skills/infra-kafka/run.sh
# Skill: Instalação do Kafka (KRaft) via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="kafka"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# KRaft cluster ID — único por deploy (ADR-002: gerado em runtime)
KAFKA_CLUSTER_ID=$(echo -n "$(openssl rand -hex 22)" | base64 | tr '+/' '-_' | tr -d '=')

echo -e "${amarelo}Instalando Kafka (KRaft) via Docker Swarm...${reset}"

docker volume create kafka_data > /dev/null 2>&1

cat > kafka.yaml <<EOL
version: "3.7"
services:
  kafka:
    image: bitnami/kafka:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - KAFKA_CFG_NODE_ID=0
      - KAFKA_CFG_PROCESS_ROLES=controller,broker
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@kafka:9093
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_KRAFT_CLUSTER_ID=$KAFKA_CLUSTER_ID
    volumes:
      - kafka_data:/bitnami/kafka
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  kafka_data:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "kafka.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    CONTENT="[ KAFKA ]

Dominio: PLAINTEXT://kafka:9092

Host: kafka

Port: 9092

Usuario: Não tem

Senha: Não tem

Rede: $NOME_REDE_INTERNA"
    save_data "infra-kafka" "$CONTENT"
else
    exit 1
fi

rm kafka.yaml
exit 0
