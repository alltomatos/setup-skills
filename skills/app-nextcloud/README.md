# Skill: app-nextcloud

Instalação do Nextcloud (armazenamento em nuvem open-source) em cluster Docker Swarm.

## Funcionalidades

- Armazenamento de arquivos com acesso web, sync desktop e mobile.
- Suporte a calendário, contatos, tarefas e editor de documentos online.
- Apps marketplace e colaboração em tempo real.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **infra-redis**: Cache de sessão.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_NEXTCLOUD`: Domínio de acesso.
- `NEXTCLOUD_USER`: Nome de usuário admin.
- `NEXTCLOUD_PASS`: Senha do admin.

## Observações

- 3 serviços: app + cron + redis dedicado.
- Middleware Traefik para redirecionar CalDAV/CardDAV.
- ADR-002: sem segredos hardcoded.
