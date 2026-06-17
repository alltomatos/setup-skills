# Skill: ntfy

Instala o **ntfy**, um serviço de notificações push via HTTP, simples e self-hosted.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_NTFY`: Domínio para acesso ao ntfy.
- `NTFY_USER`: Usuário para autenticação básica.
- `NTFY_PASSWORD`: Senha para o usuário.

## Pós-instalação

1. Acesse `https://<DOMAIN_NTFY>`.
2. O acesso é protegido por Basic Auth via Traefik.
3. Use o aplicativo ntfy no Android/iOS ou envie notificações via `curl`.

## Persistência

Os arquivos de cache e configuração são persistidos nos volumes `ntfy_cache` e `ntfy_etc`.
A persistência da skill é salva em `/root/dados_vps/app-ntfy.md`.
