# Skill: app-unoapi

Instalação da UnoAPI (Gateway WhatsApp baseado em Baileys) em cluster Docker Swarm.

## Dependências

- **Minio (S3)**: Para armazenamento de sessões e arquivos.
- **RabbitMQ**: Para gerenciamento de filas de mensagens.
- **Redis**: Instância dedicada para cache de sessões.

## Inputs

- Domínio de acesso.
- Credenciais S3 (Minio).
- Credenciais RabbitMQ.

## Observações

- O token de autenticação da API é gerado automaticamente e salvo nos metadados da instalação.
- A skill assume a existência da rede interna `orion_network` (ou similar).
