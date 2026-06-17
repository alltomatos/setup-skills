# Skill: PgBackWeb

Instala o **PgBackWeb**, uma interface web moderna e simples para gerenciar backups do PostgreSQL (suporta S3 e local).

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada.

## Inputs solicitados

- `DOMAIN_PGBACKWEB`: Domínio para acesso à interface.

## Pós-instalação

1. Acesse `https://<DOMAIN_PGBACKWEB>`.
2. Crie seu usuário e senha no primeiro acesso.
3. Configure seus destinos de backup (ex: MinIO S3) e os bancos de dados que deseja fazer backup.

## Persistência

Os backups locais (se configurados) são salvos no volume `pgbackweb_backups`. Os dados da aplicação ficam no banco PostgreSQL interno.
A persistência da skill é salva em `/root/dados_vps/app-pgbackweb.md`.
