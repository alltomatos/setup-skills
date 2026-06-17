# Skill: OpenProject

Instala o **OpenProject**, a plataforma open-source líder para gerenciamento de projetos ágil e clássico.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_OPENPROJECT`: Domínio para acesso ao OpenProject.

## Pós-instalação

1. Acesse `https://<DOMAIN_OPENPROJECT>`.
2. O usuário padrão é `admin` e a senha é `admin`. **Altere imediatamente após o primeiro login.**

## Persistência

Os dados do banco de dados e ativos são persistidos nos volumes `openproject_pgdata`, `openproject_assets`, `openproject_db_data` e `openproject_redis_data`.
A persistência da skill é salva em `/root/dados_vps/app-openproject.md`.
