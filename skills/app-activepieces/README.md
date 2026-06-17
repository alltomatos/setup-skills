# Skill: ActivePieces

Instala o **ActivePieces**, uma ferramenta poderosa e open-source para automação de tarefas no-code (alternativa ao Zapier e Make).

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada.

## Inputs solicitados

- `DOMAIN_ACTIVEPIECES`: Domínio para acessar a interface da aplicação.

## Pós-instalação

1. Acesse `https://<DOMAIN_ACTIVEPIECES>`.
2. A primeira conta criada será a do administrador principal.

## Persistência

Os dados dos fluxos, configurações e contas são armazenados no PostgreSQL.
Cache e filas usam o Redis configurado na stack.
A persistência da skill é salva em `/root/dados_vps/app-activepieces.md`.
