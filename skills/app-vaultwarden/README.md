# Skill: app-vaultwarden

Instalação do Vaultwarden (cofre de senhas compatible com Bitwarden) em cluster Docker Swarm.

## Funcionalidades

- Gerenciador de senhas com clientes web, desktop e mobile.
- Vault Bitwarden-compatible (extensões de navegador).
- Sync entre dispositivos, 2FA, reports.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_VAULTWARDEN`: Domínio de acesso.
- `SMTP_FROM_EMAIL`, `SMTP_USER`, `SMTP_PASS`, `SMTP_HOST`, `SMTP_PORT`: SMTP.

## Observações

- Gera `ADMIN_TOKEN` via `openssl rand` (ADR-002).
- Admin panel em `/admin` após deploy.
- WebSocket habilitado para sync em tempo real.
- Registro aberto por padrão.
