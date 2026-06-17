# Skill: app-flowise

Instalação do Flowise (orquestrador LLM low-code) em cluster Docker Swarm.

## Funcionalidades

- Builder visual de fluxos LLM com drag-and-drop.
- Suporte a múltiplas integrações (OpenAI, Langchain, Vector DBs).
- API REST e webhook para automação.

## Dependências

- **PostgreSQL**: Utiliza a instância global `infra-postgres` para persistência de fluxos.

## Inputs

- `DOMAIN_FLOWISE`: Domínio de acesso (ex: `flowise.exemplo.com`).

## Observações

- Porta interna: 3000.
- Fluxos e credenciais persistidos em volume Docker.
- Gera SECRET_KEY_BASE em cada execução via `openssl rand`.
