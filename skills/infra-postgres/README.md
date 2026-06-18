# Skill: infra-postgres

Instalação otimizada do PostgreSQL 14 em cluster Docker Swarm para o ecossistema Setup Orion.

## Pré-requisitos

- `infra-bootstrap` concluído.
- `app-traefik` instalado (para rede e gestão).

## Inputs

- `POSTGRES_PASSWORD`: Senha do usuário `postgres`. Se não fornecida, uma senha segura de 32 caracteres hexadecimais será gerada.

## Detalhes Técnicos

- **Imagem**: `postgres:14`
- **Rede**: Conectado à rede interna overlay do Swarm.
- **Limites**: 1 CPU, 1024MB RAM.
- **Configuração**: 
    - `max_connections`: 500
    - `shared_buffers`: 512MB
    - `timezone`: America/Sao_Paulo

## Persistência

Os metadados da instalação são salvos em `/root/dados_vps/infra-postgres.md`.
O banco de dados utiliza o volume externo `postgres_data`.
