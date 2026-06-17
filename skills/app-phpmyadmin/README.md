# Skill: phpMyAdmin

Instala o **phpMyAdmin**, uma ferramenta de software livre escrita em PHP, com a intenção de lidar com a administração do MySQL sobre a Internet.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Banco de dados MySQL acessível.

## Inputs solicitados

- `DOMAIN_PHPMYADMIN`: Domínio para acesso à interface.
- `MYSQL_HOST`: Host do MySQL ao qual o phpMyAdmin irá se conectar (ex: `mysql` se estiver na mesma rede overlay, ou `IP:3306`).

## Pós-instalação

1. Acesse `https://<DOMAIN_PHPMYADMIN>`.
2. Faça login com as credenciais do seu banco de dados MySQL.

## Persistência

O phpMyAdmin em si não possui estado persistente crucial, operando como um cliente para o MySQL.
A persistência da skill é salva em `/root/dados_vps/app-phpmyadmin.md`.
