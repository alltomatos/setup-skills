# Skill: Cal.com

Instala o **Cal.com**, a plataforma de agendamento open-source que coloca você no controle do seu calendário.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada.
- Servidor SMTP para envio de convites e notificações.

## Inputs solicitados

- `DOMAIN_CALCOM`: Domínio para acesso ao Cal.com.
- `SMTP_*`: Configurações do seu servidor de email.

## Pós-instalação

1. Acesse `https://<DOMAIN_CALCOM>`.
2. Configure seu perfil e conecte seus calendários (Google, Outlook, etc).

## Persistência

Os dados do Cal.com são persistidos no banco de dados PostgreSQL.
A persistência da skill é salva em `/root/dados_vps/app-calcom.md`.
