# Skill: app-opensign

Instalação do OpenSign (assinatura digital open-source) em cluster Docker Swarm.

## Funcionalidades

- Assinatura de PDFs com certificados digitais.
- Portal web para signatários sem conta.
- API para integração.

## Dependências

- **infra-mongodb**: Banco MongoDB.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_OPENSIGN`: Domínio de acesso.

## Observações

- 2 serviços: server (Node.js) + client (React).
- Gera `MASTER_KEY` e `JWT_SECRET` via `openssl rand` (ADR-002).
- Traefik routing: `/app` → server, tudo mais → client.
- SMTP desabilitado por padrão.
