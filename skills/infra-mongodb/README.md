# Skill: infra-mongodb

Instalação do MongoDB 6.0 para o ecossistema Setup Orion.

## Detalhes

- **Usuário**: `root` (configurado via variáveis de ambiente iniciais).
- **Rede**: Acessível internamente via `mongodb:27017`.
- **Persistência**: Utiliza volume externo `mongodb_data`.

## Inputs

- `MONGO_INITDB_ROOT_PASSWORD`: Senha do usuário root administrativo.
