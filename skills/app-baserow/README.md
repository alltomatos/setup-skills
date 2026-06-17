# Skill: app-baserow

Instalação do Baserow (banco de dados no-code open-source) em cluster Docker Swarm.

## Funcionalidades

- Construtor de banco de dados sem código com interface web.
- Suporte a fórmulas, views, e relações entre tabelas.
- API REST e webhook para automação.

## Dependências

- **app-traefik**: Rede overlay + SSL.

## Inputs

- `DOMAIN_BASEROW`: Domínio de acesso.
- `SMTP_FROM_EMAIL`: Email remetente.
- `SMTP_HOST`: Host SMTP.
- `SMTP_PORT`: Porta SMTP (465 ou 587).
- `SMTP_USER`: Usuário SMTP.
- `SMTP_PASS`: Senha SMTP.

## Observações

- Gera `SECRET_KEY` e `BASEROW_JWT_SIGNING_KEY` automaticamente.
- Inclui Redis dedicado para cache e filas.
- Porta: 80 (exposta via Traefik).
