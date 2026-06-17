# Skill: Shlink

Instala o **Shlink**, um poderoso encurtador de URL self-hosted que suporta domínios personalizados e rastreamento de visitas.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-postgres` instalada.
- `apache2-utils` instalado no host para geração do hash de senha (ou Python).

## Inputs solicitados

- `DOMAIN_SHLINK_UI`: Domínio para acessar o painel de administração (ex: `painel.meudominio.com`).
- `DOMAIN_SHLINK_API`: Domínio principal que será usado para as URLs curtas (ex: `s.meudominio.com`).
- `SHLINK_USER` e `SHLINK_PASSWORD`: Credenciais para acessar o painel UI (protegido por autenticação HTTP básica via Traefik).

## Pós-instalação

1. Acesse `https://<DOMAIN_SHLINK_UI>`.
2. Faça login com o usuário e senha configurados.
3. O servidor que fará o encurtamento estará rodando silenciosamente em `https://<DOMAIN_SHLINK_API>`.

## Persistência

A API Key interna é salva em `/root/dados_vps/app-shlink.md`.
Os dados dos links e visitas são persistidos no PostgreSQL e a configuração no volume `shlink_data`.
