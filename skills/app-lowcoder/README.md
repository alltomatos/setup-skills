# Skill: app-lowcoder

Instalação do Lowcoder (plataforma low-code para construir aplicações web) em cluster Docker Swarm.

## Funcionalidades

- Builder visual para aplicações com React.
- Suporte a queries SQL, APIs REST e webhooks.
- Editor de código para customização avançada.

## Dependências

- **infra-mongodb**: Banco MongoDB para dados da aplicação.
- **infra-redis**: Cache e filas.

## Inputs

- `DOMAIN_LOWCODER`: Domínio de acesso.
- `ADMIN_EMAIL`: Email do superadmin.
- `ADMIN_PASSWORD`: Senha do superadmin.
- `SMTP_FROM_EMAIL`: Email remetente SMTP.
- `SMTP_HOST`: Host SMTP.
- `SMTP_PORT`: Porta SMTP.
- `SMTP_USER`: Usuário SMTP.
- `SMTP_PASS`: Senha SMTP.

## Observações

- Stack com 3 serviços: API, Node e Frontend.
- Gera 4 chaves de encryption automaticamente via `openssl rand`.
- Porta API: 8080, Frontend: 3000 (expostos via Traefik).
