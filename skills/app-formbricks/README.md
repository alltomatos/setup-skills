# Skill: Formbricks

Instala o **Formbricks**, a solução open-source de "Experience Management" para coletar feedback de usuários via formulários e surveys.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-pgvector` instalada.
- Skill `app-minio` (S3) instalada para armazenamento de uploads.
- Servidor SMTP para envio de notificações e verificação de email.

## Inputs solicitados

- `DOMAIN_FORMBRICKS`: Domínio para acesso ao console do Formbricks.
- `SMTP_*`: Configurações do seu servidor de email.

## Pós-instalação

1. Acesse `https://<DOMAIN_FORMBRICKS>`.
2. O primeiro usuário a se registrar torna-se o administrador.
3. Crie um "Bucket" chamado `formbricks` no seu MinIO se ele não for criado automaticamente.

## Persistência

Os uploads locais são persistidos no volume `formbricks_data`, mas o Formbricks é configurado para priorizar o S3 (MinIO).
A persistência da skill é salva em `/root/dados_vps/app-formbricks.md`.
