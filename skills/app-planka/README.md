# Skill: Planka

Instala o **Planka**, um quadro Kanban elegante e open-source para grupos de trabalho e organizações.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada.

## Inputs solicitados

- `DOMAIN_PLANKA`: Domínio para acesso à interface.
- `PLANKA_ADMIN_*`: Dados para criação do usuário administrador inicial.
- `SMTP_*`: Configurações do servidor de email para notificações.

## Pós-instalação

1. Acesse `https://<DOMAIN_PLANKA>`.
2. Faça login com as credenciais de administrador configuradas.

## Persistência

Avatares, planos de fundo e anexos são persistidos em volumes Docker dedicados (prefixo `planka_`).
A persistência da skill é salva em `/root/dados_vps/app-planka.md`.
