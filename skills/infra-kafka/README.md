# Skill: infra-kafka

Instalação do Apache Kafka (broker de mensagens distribuído) em modo KRaft em cluster Docker Swarm.

## Funcionalidades

- Streaming de eventos em tempo real.
- Pub/sub de mensagens com alta-throughput.
- Sem dependência de Zookeeper (modo KRaft).

## Dependências

- **infra-bootstrap**: Necessário para ambiente Docker Swarm.

## Inputs

Esta skill não requer inputs — deploy direto.

## Observações

- Usa imagem Bitnami com KRaft mode (sem Zookeeper).
- Porta: 9092.
- Cluster ID gerado automaticamente em cada execução.
- Para produção multi-broker, são necessários pelo menos 3 nós manager.
- Volume persistente em `kafka_data`.
