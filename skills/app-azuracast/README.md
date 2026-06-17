# Skill: AzuraCast

Instala o **AzuraCast**, uma solução completa de "Rádio em uma Caixa". Inclui tudo o que você precisa para gerenciar uma rádio web funcional.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Portas 2022 e 8005 abertas no firewall (TCP).

## Inputs solicitados

- `DOMAIN_AZURACAST`: Domínio para acesso à interface web.

## Pós-instalação

1. Acesse `https://<DOMAIN_AZURACAST>`.
2. Configure sua primeira estação de rádio e crie o usuário administrador.

## Persistência

Os dados das estações, músicas, backups e banco de dados são persistidos em múltiplos volumes Docker (prefixo `azuracast_`).
A persistência da skill é salva em `/root/dados_vps/app-azuracast.md`.
