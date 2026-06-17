# Skill: app-keycloak

Instalação do Keycloak (SSO/Identity Provider open-source) em cluster Docker Swarm.

## Funcionalidades

- Identity Provider com OpenID Connect e SAML 2.0.
- Login social (Google, GitHub, etc.) via providers.
- Gerenciamento de realms e roles.
- Account console para usuários finais.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_KEYCLOAK`: Domínio de acesso.
- `KEYCLOAK_USER`: Usuário admin.
- `KEYCLOAK_PASS`: Senha admin.

## Observações

- Sem segredos gerados (credenciais via inputs — ADR-002 compliance).
- Headers X-Forwarded configurados no Traefik para proxy HTTPS.
- 2 CPUs / 2GB RAM mínimo recomendado.
- Porta: 8080 (exposta via Traefik).
