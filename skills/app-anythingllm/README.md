# Skill: app-anythingllm

Instalação do AnythingLLM (RAG full-stack open-source) em cluster Docker Swarm.

## Funcionalidades

- Interface web para聊天 com documentos privados.
- Suporte a múltiplos workspaces e fontes de conhecimento.
- Conecta com Ollama, OpenAI, Azure e outros provedores LLM.

## Dependências

- **Traefik**: Utiliza a rede overlay via `app-traefik`.

## Inputs

- `DOMAIN_ANYTHINGLLM`: Domínio de acesso (ex: `rag.exemplo.com`).

## Observações

- Não requer banco de dados dedicado — persiste em volume Docker.
- Porta interna: 3001.
- Memória recomendada: 2GB mínimo (LLMs locais consomem recursos).
