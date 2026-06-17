# Skill: app-authentik

Instalação do Authentik (Identity Provider moderno open-source) em cluster Docker Swarm.

## Funcionalidades

- SSO com OpenID Connect, OAuth 2.0 e SAML 2.0.
- LDAP Provider para autenticar usuários on-premises.
- Proxy reverso e outbound proxy integrado.
- UI moderna com Blueprints para automação.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **infra-redis**: Cache e task queue.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_AUTHENTIK`: Domínio de acesso.
- `AUTHENTIK_EMAIL`: Email do admin inicial.
- `AUTHENTIK_PASS`: Senha do admin inicial.

## Observações

- 3 serviços: server + worker + redis dedicado.
- Gera `AUTHENTIK_SECRET_KEY` via `openssl rand` (ADR-002).
- Porto do servidor: 9000 (exposto via Traefik).
- Tempo de boot ~2min na primeira vez (migrations).
