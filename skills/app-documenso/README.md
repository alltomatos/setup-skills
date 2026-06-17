# Skill: app-documenso

Instalação do Documenso (assinatura digital open-source) em cluster Docker Swarm.

## Funcionalidades

- Assinatura de documentos PDF com múltiplos signatários.
- Templates de documento e histórico de versões.
- API REST para integração com outros sistemas.

## Dependências

- **infra-postgres**: Banco PostgreSQL para dados.
- **app-minio**: Storage S3 para uploads de documento.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_DOCUMENSO`: Domínio de acesso.
- `SMTP_FROM_EMAIL`, `SMTP_USER`, `SMTP_PASS`, `SMTP_HOST`, `SMTP_PORT`: SMTP.

## Observações

- Gera 3 chaves de encryption via `openssl rand` (ADR-002).
- Storage local por simplicidade (alternativa MinIO possível).
- Porta: 3000 (exposta via Traefik).
