# Skill: Odoo

Instala o **Odoo**, um conjunto de aplicativos de negócios open-source que cobre todas as necessidades de sua empresa: CRM, eCommerce, contabilidade, inventário, ponto de venda, gerenciamento de projetos, etc.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_ODOO`: Domínio para acessar o ERP.
- `ODOO_VERSION`: Versão do Odoo a instalar (ex: `17.0`, `18.0`). Se omitido, instalará a versão 17.0.

## Pós-instalação

1. Acesse `https://<DOMAIN_ODOO>`.
2. A tela inicial solicitará a criação de um banco de dados. Configure o Master Password (você define), o nome do banco, email do admin e senha do admin.
3. Se você não gerenciar a Master Password corretamente, não conseguirá criar ou restaurar bancos de dados futuros pelo painel do Odoo.

## Persistência

A skill configura seu próprio banco de dados PostgreSQL interno para garantir isolamento compatível com o Odoo.
Arquivos de configuração, dados, addons extras e o banco de dados são persistidos em volumes Docker (`odoo_app_data`, `odoo_app_config`, `odoo_app_addons`, `odoo_db_data`).
A persistência da skill é salva em `/root/dados_vps/app-odoo.md`.
