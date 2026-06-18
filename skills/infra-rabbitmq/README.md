# Skill: infra-rabbitmq

Instalação do RabbitMQ com painel de gerenciamento para o ecossistema Setup Orion.

## Detalhes

- **Imagem**: `rabbitmq:3-management` (inclui interface web).
- **Usuário**: `admin`.
- **Portas Internas**: 
    - `5672`: Protocolo AMQP.
    - `15672`: Interface de Gerenciamento.
- **Rede**: Acessível internamente via `rabbitmq`.

## Inputs

- `RABBITMQ_DEFAULT_PASS`: Senha para o usuário admin.
