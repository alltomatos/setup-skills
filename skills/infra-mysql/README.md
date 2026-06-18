# Skill: infra-mysql

Instalação do MySQL 8.0 otimizado para o ecossistema Setup Orion.

## Detalhes

- **Autenticação**: Configurado com `mysql_native_password` para compatibilidade legada.
- **Rede**: Acessível internamente via `mysql:3306`.
- **Persistência**: Utiliza volume externo `mysql_data`.

## Inputs

- `MYSQL_ROOT_PASSWORD`: Senha do usuário root.
