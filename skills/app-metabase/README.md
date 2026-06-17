# Skill: Metabase

Instala o **Metabase**, a maneira mais fácil e rápida de compartilhar dados e gerar insights na sua empresa.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada para o banco de dados da aplicação.

## Inputs solicitados

- `DOMAIN_METABASE`: Domínio para acesso ao Metabase.

## Pós-instalação

1. Acesse `https://<DOMAIN_METABASE>`.
2. Siga o assistente de configuração inicial para criar sua conta e conectar seus bancos de dados.

## Persistência

Os dados internos do Metabase são armazenados no PostgreSQL.
A persistência da skill é salva em `/root/dados_vps/app-metabase.md`.
