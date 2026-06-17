# Skill: Code-Server

Instala o **code-server**, permitindo que você execute o VS Code em qualquer máquina e acesse-o através do navegador.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_CODE_SERVER`: Domínio para acesso ao VS Code.
- `CODE_SERVER_PASSWORD`: Senha de acesso.
- `CODE_SERVER_SUDO_PASSWORD`: Senha para comandos `sudo` no terminal integrado.

## Pós-instalação

1. Acesse `https://<DOMAIN_CODE_SERVER>`.
2. Use a senha configurada para entrar.

## Persistência

As configurações e o workspace do usuário são persistidos no volume `code_server_config`.
A persistência da skill é salva em `/root/dados_vps/app-code-server.md`.
