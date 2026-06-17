# Skill: app-wisemapping

Instalação do WiseMapping (mind mapping open-source) em cluster Docker Swarm.

## Funcionalidades

- Criação de mapas mentais com layout automático.
- Exportação para PNG, PDF, FreeMind e SVG.
- Editor colaborativo e histórico de versões.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_WISEMAPPING`: Domínio de acesso.

## Observações

- Gera `APP_JWT_SECRET` automaticamente via `openssl rand`.
- Usa JDBC PostgreSQL (não precisa de banco próprio — conecta na global).
