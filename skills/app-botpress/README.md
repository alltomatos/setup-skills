# Skill: Botpress

Instala o **Botpress**, uma plataforma poderosa para criação de chatbots conversacionais.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada.
- Skill `infra-redis` instalada.

## Inputs solicitados

- `DOMAIN_BOTPRESS`: Domínio para acesso ao console do Botpress.

## Pós-instalação

1. Acesse `https://<DOMAIN_BOTPRESS>`.
2. Crie sua conta de administrador no primeiro acesso.

## Persistência

Os dados do Botpress são persistidos no volume `botpress_data`.
A persistência da skill é salva em `/root/dados_vps/app-botpress.md`.
