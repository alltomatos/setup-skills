# Skill: app-wiki

Instalação do Wiki.js (wiki moderna open-source) em cluster Docker Swarm.

## Funcionalidades

- Editor visual com Markdown, AsciiDoc eWYSIWYG.
- Busca full-text, autenticação local e via SAML/OIDC.
- Git-backed storage e Docker authentication.

## Dependências

- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_WIKI`: Domínio de acesso.

## Observações

- Usa SQLite embarcado (sem dependência de banco externo).
- Primeira visita: configurar admin via interface web (porta 3000).
- ADR-002: sem segredos — SQLite é local ao container.
