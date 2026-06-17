# Skill: pgAdmin 4

Instala o **pgAdmin 4**, a plataforma de administração e desenvolvimento open-source mais popular e rica em recursos para PostgreSQL.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Banco de dados PostgreSQL acessível.

## Inputs solicitados

- `DOMAIN_PGADMIN`: Domínio para acesso à interface.
- `PGADMIN_USER`: Email para o login administrador.
- `PGADMIN_PASSWORD`: Senha para o login administrador.

## Pós-instalação

1. Acesse `https://<DOMAIN_PGADMIN>`.
2. Faça login com o email e senha fornecidos.
3. Adicione um "Novo Servidor" (New Server) apontando para o seu banco PostgreSQL (ex: hostname `postgres` se estiver na mesma rede overlay).

## Persistência

As configurações e servidores salvos no pgAdmin são persistidos no volume `pgadmin_data`.
A persistência da skill é salva em `/root/dados_vps/app-pgadmin.md`.
