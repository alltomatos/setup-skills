# Skill: Uptime Kuma

Instala o **Uptime Kuma**, uma ferramenta de monitoramento self-hosted fácil de usar.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_UPTIMEKUMA`: Domínio onde o Uptime Kuma será acessível.

## Pós-instalação

1. Acesse `https://<DOMAIN_UPTIMEKUMA>`.
2. Crie a conta de administrador inicial.
3. Comece a adicionar seus monitores.

## Persistência

Os dados da instalação são salvos em `/root/dados_vps/app-uptimekuma.md`.
Os dados do banco de dados do Uptime Kuma são persistidos no volume Docker `uptimekuma_data`.
