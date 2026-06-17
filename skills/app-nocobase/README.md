# Skill: app-nocobase

Instalação do NocoBase (no-code BaaS open-source) em cluster Docker Swarm.

## Funcionalidades

- Construtor de aplicações sem código com modelos de dados visuais.
- API REST automática gerada a partir dos modelos.
- Plugin system extensível.
- Suporte a múltiplos usuários e permissões.

## Dependências

- **infra-postgres**: Banco PostgreSQL para persistência dos dados.
- **app-traefik**: Proxy reverso com SSL automático.

## Inputs

- `DOMAIN_NOCOBASE`: Domínio de acesso.
- `NOCOBASE_EMAIL`: Email do administrador inicial.
- `NOCOBASE_USERNAME`: Nome de usuário do admin.
- `NOCOBASE_PASSWORD`: Senha do administrador (sensível).

## Observações

- Gera `APP_KEY` e `ENCRYPTION_FIELD_KEY` automaticamente via `openssl rand` (ADR-002).
- Criado o banco de dados `nocobase` automaticamente na instância postgres.
- Aguardar ~60s após deploy para inicialização completa.
- Porta interna: 80 (exposta via Traefik).
