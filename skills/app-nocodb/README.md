# Skill: app-nocodb

Instalação do NocoDB (banco de dados no-code estilo Airtable) em cluster Docker Swarm.

## Funcionalidades

- Interface tipo planilha para gestão de dados sem código.
- API REST automática para cada tabela criada.
- Suporte a visualizações, formulários e widgets customizados.

## Dependências

- **infra-postgres**: Banco PostgreSQL para persistência.

## Inputs

- `DOMAIN_NOCODB`: Domínio de acesso.

## Observações

- Gera `NC_AUTH_JWT_SECRET` automaticamente via `openssl rand`.
- Inclui serviço Redis dedicado para cache de sessão.
- Porta: 8080 (exposta via Traefik).
