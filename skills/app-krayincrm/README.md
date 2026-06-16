# Skill: app-krayincrm

Instalação do Krayin CRM (CRM open-source baseado em PHP/Laravel) em cluster Docker Swarm.

## Estrutura

- **App**: Aplicação Laravel rodando em Apache com suporte a HTTPS.
- **Banco de Dados**: Percona Server (MySQL compatível).
- **Redis**: Instância dedicada para cache.

## Inputs

- `DOMAIN_KRAYIN`: Domínio de acesso.
- `SMTP_HOST` / `SMTP_PORT`: Configuração de envio de e-mails.
- `SMTP_USER` / `SMTP_PASS`: Credenciais SMTP.
- `SMTP_FROM_EMAIL`: E-mail que aparecerá como remetente.

## Observações

- A skill gera automaticamente uma `APP_KEY` segura para a instalação.
- Utiliza volumes externos para garantir a persistência de dados e uploads.
