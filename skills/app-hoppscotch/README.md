# Skill: app-hoppscotch

Instalação do Hoppscotch (cliente API REST/GraphQL open-source) em cluster Docker Swarm.

## Funcionalidades

- Cliente API visual com suporte a REST, GraphQL, WebSocket e SSE.
- Collections, environments e scripts de teste.
- Equipe collaboration e histórico de requisições.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_HOPPSCOTCH`: Domínio frontend.
- `DOMAIN_HOPPSCOTCH_ADMIN`: Domínio admin.
- `DOMAIN_HOPPSCOTCH_BACKEND`: Domínio backend API.
- `SMTP_*`: Configuração SMTP.

## Observações

- 2 serviços: frontend (nginx) + backend (Node.js).
- Todos os segredos gerados via `openssl rand` (ADR-002).
- Autenticação via email por padrão.
