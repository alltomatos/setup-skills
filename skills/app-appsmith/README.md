# Skill: app-appsmith

Instalação do Appsmith (plataforma low-code para construir aplicações de negócio) em cluster Docker Swarm.

## Funcionalidades

- Editor visual para criar páginas, widgets e queries.
- Suporte a JavaScript em queries e callbacks.
- Integrações nativas com PostgreSQL, MongoDB, Redis, S3 e mais.

## Dependências

- **app-traefik**: Rede overlay + SSL.

## Inputs

- `DOMAIN_APPSMITH`: Domínio de acesso.

## Observações

- Gera `APPSMITH_ENCRYPTION_KEY` automaticamente via `openssl rand`.
- Sem dependência de banco externo — usa container volume.
- Telemetria desativada por padrão.
- Porta: 80 (exposta via Traefik).
