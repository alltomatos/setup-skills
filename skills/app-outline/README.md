# Skill: app-outline

Instalação do Outline Wiki (knowledge base colaborativa) em cluster Docker Swarm.

## Funcionalidades

- Wiki colaborativo com editor rico (Slate.js).
- Autenticação via Google OAuth e email.
- Busca full-text, templates e versionamento.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **infra-redis**: Cache e filas.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_OUTLINE`: Domínio de acesso.
- `OUTLINE_GOOGLE_CLIENT_ID`: OAuth Client ID do Google Cloud Console.
- `OUTLINE_GOOGLE_CLIENT_SECRET`: OAuth Client Secret.
- `SMTP_FROM_EMAIL`, `SMTP_USER`, `SMTP_PASS`, `SMTP_HOST`, `SMTP_PORT`: Configuração SMTP.

## Observações

- Login primário via Google OAuth (precisa configurar no Google Cloud Console).
- Gera `SECRET_KEY` e `UTILS_SECRET` automaticamente via `openssl rand`.
- Porta: 3000 (exposta via Traefik).
