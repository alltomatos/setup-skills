# Skill: app-langfuse

Instalação do Langfuse (plataforma de observabilidade para LLMs) em cluster Docker Swarm.

## Funcionalidades

- Tracing de requisições LLM com latência e custo.
- Gerenciamento de prompts e versões.
- Avaliação de qualidade de respostas.

## Dependências

- **PostgreSQL**: Utiliza a instância global `infra-postgres` para dados de tracing.

## Inputs

- `DOMAIN_LANGFUSE`: Domínio de acesso (ex: `langfuse.exemplo.com`).

## Observações

- Porta interna: 3000.
- Gera NEXTAUTH_SECRET e SALT automaticamente via `openssl rand`.
- Integra-se com LangChain, LlamaIndex e qualquer aplicação com SDK Langfuse.
