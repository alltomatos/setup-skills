# Skill: app-openwebui

Instalação do Open WebUI (interface web moderna para Ollama) em cluster Docker Swarm.

## Funcionalidades

- Interface conversacional completa com Ollama.
- Suporte a upload de documentos e imagens.
- Histórico de conversas e gestão de sessões.

## Dependências

- **app-ollama**: Requer Ollama rodando localmente na rede overlay.
- **Traefik**: Utiliza a rede overlay via `app-traefik`.

## Inputs

- `DOMAIN_OPENWEBUI`: Domínio de acesso (ex: `chat.exemplo.com`).

## Observações

- Porta interna: 8080.
- Aponta automaticamente para `http://ollama:11434` na rede overlay.
- Deploy ollama separadamente via `app-ollama` antes desta skill.
