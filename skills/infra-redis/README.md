# Skill: infra-redis

Instalação do Redis para cache de alta performance e mensagens pub-sub no ecossistema Setup Orion.

## Detalhes

- **Persistência**: Modo `Append Only File (AOF)` ativado para garantir durabilidade dos dados.
- **Memória**: Limite de 2GB configurado.
- **Acesso**: Disponível internamente via `redis:6379`.

## Persistência

- Volume: `redis_data`
- Metadados: `/root/dados_vps/infra-redis.md`
