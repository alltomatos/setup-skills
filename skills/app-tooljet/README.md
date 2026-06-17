# Skill: app-tooljet

Instalação do ToolJet (plataforma low-code para construir aplicações internas) em cluster Docker Swarm.

## Funcionalidades

- Builder drag-and-drop para aplicações web e móveis.
- Conecta com bases de dados, APIs REST, GraphQL e mais.
- Marketplace de templates e componentes.

## Dependências

- **infra-postgres**: Banco principal e interno.
- **infra-redis**: Cache e filas de background.

## Inputs

- `DOMAIN_TOOLJET`: Domínio de acesso.
- `SMTP_FROM_EMAIL`: Email remetente.
- `SMTP_HOST`: Host SMTP.
- `SMTP_PORT`: Porta SMTP.
- `SMTP_USER`: Usuário SMTP.
- `SMTP_PASS`: Senha SMTP.

## Observações

- Gera `LOCKBOX_MASTER_KEY`, `SECRET_KEY_BASE` automaticamente.
- Inclui ChromaDB para recursos de IA vetorial.
- Porta: 80 (exposta via Traefik).
- Aguardar ~5 min após deploy para migrations concluírem.
