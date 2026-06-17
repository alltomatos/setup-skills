# Skill: app-docmost

Instalação do Docmost (docs colaborativo open-source) em cluster Docker Swarm.

## Funcionalidades

- Editor de documentos colaborativo em tempo real.
- Suporte a comments e versionamento.
- Storage local (S3 opcional).

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_DOCMOST`: Domínio de acesso.

## Observações

- Gera `APP_SECRET` automaticamente via `openssl rand`.
- Redis dedicado para cache.
- Storage local por padrão (alternativa S3 configurável).
