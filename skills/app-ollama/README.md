# Skill: app-ollama

Instalação do Ollama (motor de modelos LLM locais) em cluster Docker Swarm.

## Funcionalidades

- Executa modelos open-source localmente (Llama 3, Mistral, Phi, Gemma, etc).
- API REST compatível com OpenAI na porta 11434.
- Sem necessidade de GPU — funciona em CPU (mais lento).

## Dependências

- **infra-bootstrap**: Necessário para ambiente Docker Swarm.

## Inputs

Esta skill não requer inputs — deploy direto.

## Observações

- Sem interface web nativa — combine com `app-openwebui` para UI completa.
- Modelos baixados sob demanda após o deploy: `docker exec <servico> ollama pull llama3`.
- Porta API: 11434.
- Recomendado mínimo 4GB RAM por modelo.
