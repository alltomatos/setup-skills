# Skill: app-docuseal

Instalação do DocuSeal (assinatura digital open-source) em cluster Docker Swarm.

## Funcionalidades

- Criação e envio de documentos para assinatura.
- Workflow de aprovação e múltiplos signatários.
- Portal de assinador para quem não tem conta.

## Dependências

- **infra-postgres**: Banco PostgreSQL.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_DOCUSEAL`: Domínio de acesso.
- `SMTP_FROM_EMAIL`, `SMTP_USER`, `SMTP_PASS`, `SMTP_HOST`, `SMTP_PORT`: SMTP.

## Observações

- Gera `SECRET_KEY_BASE` via `openssl rand` (ADR-002).
- Storage local embarcado (sem S3 necessário).
