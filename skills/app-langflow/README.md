# Skill: app-langflow

Instalação do Langflow (builder visual de fluxos LLM baseado em LangChain) em cluster Docker Swarm.

## Funcionalidades

- Interface gráfica para construir pipelines LLM com LangChain.
- Suporte a agentes, chains, retrieval e ferramentas customizadas.
- Exporta fluxos como código Python.

## Dependências

- **Traefik**: Utiliza a rede overlay via `app-traefik`.

## Inputs

- `DOMAIN_LANGFLOW`: Domínio de acesso (ex: `langflow.exemplo.com`).

## Observações

- Porta interna: 7860.
- Persistência em volume Docker (`langflow_data`).
- Funciona bem em conjunto com `app-ollama` para LLM local.
