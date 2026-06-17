# Skill: app-gotenberg

Instalação do Gotenberg (API REST para conversão de documentos em PDF) em cluster Docker Swarm.

## Funcionalidades

- Conversão de Office, Markdown, HTML para PDF via API.
- Suporte a LibreOffice headless internamente.
- Basic auth para proteger a API.

## Dependências

- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_GOTENBERG`: Domínio de acesso.
- `GOTENBERG_USER`: Usuário da API (basic auth).
- `GOTENBERG_PASS`: Senha da API.

## Observações

- Single-container, sem banco.
- Timeout de 60s por conversão.
- ADR-002: basic auth em vez de IP whitelist.
- Porta: 3000 (exposta via Traefik).
