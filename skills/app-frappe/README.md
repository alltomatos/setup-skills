# Skill: Frappe ERPNext

Instala o **ERPNext**, o ERP open-source mais avançado do mundo, construído sobre o Frappe Framework.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Recomendado: Pelo menos 4GB de RAM disponíveis no nó.

## Inputs solicitados

- `DOMAIN_FRAPPE`: Domínio para acesso ao ERPNext.
- `FRAPPE_ADMIN_PASSWORD`: Senha para o usuário administrador (`administrator`).

## Pós-instalação

1. Acesse `https://<DOMAIN_FRAPPE>`.
2. Pode levar alguns minutos para o ambiente estar totalmente pronto.
3. Se o site não carregar (erro 404/502), pode ser necessário rodar a criação do site manualmente:
   ```bash
   docker exec -it $(docker ps -qf "name=erpnext_backend") bash -c "bench new-site <DOMAIN_FRAPPE> --install-app erpnext"
   ```

## Persistência

Sites, logs e bancos de dados são persistidos em volumes Docker dedicados (prefixo `erpnext_`).
A persistência da skill é salva em `/root/dados_vps/app-frappe.md`.
