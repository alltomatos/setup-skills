# Skill: NetBox

Instala o **NetBox**, a ferramenta padrão para IPAM (IP Address Management) e DCIM (Data Center Infrastructure Management).

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_NETBOX`: Domínio para acesso ao NetBox.

## Pós-instalação

1. Acesse `https://<DOMAIN_NETBOX>`.
2. O usuário padrão é `admin` e a senha é `admin`. **Altere imediatamente após o primeiro login.**

## Persistência

Os dados do banco de dados e arquivos de mídia são persistidos em volumes Docker dedicados (prefixo `netbox_`).
A persistência da skill é salva em `/root/dados_vps/app-netbox.md`.
