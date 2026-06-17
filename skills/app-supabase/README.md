# Skill: Supabase

Instala o **Supabase**, a alternativa open-source ao Firebase. Inclui Banco de Dados (PostgreSQL), Autenticação, APIs REST e Realtime.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_SUPABASE`: Domínio para acesso ao console do Supabase.
- `SUPABASE_USER`: Usuário para login no Dashboard.
- `SUPABASE_PASSWORD`: Senha para login no Dashboard.

## Pós-instalação

1. Acesse `https://<DOMAIN_SUPABASE>`.
2. Use as credenciais fornecidas durante a instalação.
3. As chaves ANON e SERVICE_ROLE são geradas automaticamente e salvas em `/root/dados_vps/app-supabase.md`.

## Persistência

Os dados do banco de dados são persistidos em `/root/supabase/docker/volumes/db/data`.
A persistência da skill é salva em `/root/dados_vps/app-supabase.md`.
