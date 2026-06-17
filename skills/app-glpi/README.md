# Skill: GLPI

Instala o **GLPI**, a solução open-source definitiva para gestão de ativos de TI e helpdesk.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-mysql` instalada.

## Inputs solicitados

- `DOMAIN_GLPI`: Domínio para acesso à interface.

## Pós-instalação

1. Acesse `https://<DOMAIN_GLPI>`.
2. Siga o assistente de instalação do GLPI.
3. Configure a conexão com o MySQL usando:
   - **Servidor:** `mysql`
   - **Usuário:** `root`
   - **Senha:** (A senha do seu MySQL root)
   - **Banco de dados:** `glpi` (deve ser criado no assistente ou previamente).
4. O usuário padrão é `glpi` e a senha é `glpi`. **Altere imediatamente.**

## Persistência

Os arquivos do GLPI (documentos, plugins, etc) são persistidos no volume `glpi_data`.
A persistência da skill é salva em `/root/dados_vps/app-glpi.md`.
