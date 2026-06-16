# Skill: app-wppconnect

Instalação do WPPConnect (Gateway WhatsApp robusto e escalável) em cluster Docker Swarm.

## Funcionalidades

- Suporte a múltiplas instâncias de WhatsApp simultâneas.
- API abrangente para envio de mensagens, áudios, botões e listas.
- Documentação interativa via Swagger disponível no endpoint `/api-docs`.

## Inputs

- `DOMAIN_WPPCONNECT`: Domínio de acesso para a API.

## Observações

- A skill utiliza o volume externo `wppconnect_config` para persistir dados de configuração e sessões.
- Configurado com limites de 1 CPU e 1GB RAM por padrão.
