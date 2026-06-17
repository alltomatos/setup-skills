# Skill: Mattermost

Instala o **Mattermost Team Edition**, uma plataforma open-source de mensagens e colaboração em equipe, excelente alternativa ao Slack.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada.

## Inputs solicitados

- `DOMAIN_MATTERMOST`: Domínio para acessar a plataforma.

## Pós-instalação

1. Acesse `https://<DOMAIN_MATTERMOST>`.
2. A primeira conta criada no sistema se tornará automaticamente a conta do System Administrator.

## Persistência

Os arquivos, configurações e plugins são persistidos em volumes Docker dedicados (prefixo `mattermost_`).
Os dados de mensagens são armazenados no PostgreSQL.
A persistência da skill é salva em `/root/dados_vps/app-mattermost.md`.
