# Skill: YOURLS

Instala o **YOURLS** (Your Own URL Shortener), um conjunto de scripts PHP simples que permite rodar seu próprio encurtador de URLs.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-mysql` instalada.

## Inputs solicitados

- `DOMAIN_YOURLS`: Domínio para acessar o seu encurtador.
- `YOURLS_USER`: Usuário para a área administrativa.
- `YOURLS_PASSWORD`: Senha para a área administrativa.

## Pós-instalação

1. Acesse `https://<DOMAIN_YOURLS>/admin`.
2. Faça login com o usuário e senha configurados.

## Persistência

Todos os dados (links, cliques, configurações) são persistidos no banco de dados MySQL interno na tabela/banco `yourls`. Não há persistência de arquivos configurada nesta stack simplificada, plugins e temas seriam efêmeros.
A persistência da skill é salva em `/root/dados_vps/app-yourls.md`.
