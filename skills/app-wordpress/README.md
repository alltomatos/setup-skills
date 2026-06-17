# Skill: WordPress

Instala o **WordPress**, o CMS mais popular do mundo, com suporte a Redis para cache.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-mysql` instalada.

## Inputs solicitados

- `DOMAIN_WORDPRESS`: Domínio para acesso ao site.
- `WORDPRESS_SITE_NAME`: Um nome único para identificar este site (usado no banco de dados e volumes).

## Pós-instalação

1. Acesse `https://<DOMAIN_WORDPRESS>`.
2. Siga o assistente de instalação do WordPress para configurar o título do site e usuário administrador.

## Persistência

Os arquivos do WordPress e configurações do PHP são persistidos em volumes Docker dedicados (prefixo `wordpress_`).
A persistência da skill é salva em `/root/dados_vps/app-wordpress.md`.
