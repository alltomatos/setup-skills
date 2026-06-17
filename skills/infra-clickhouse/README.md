# Skill: infra-clickhouse

Instalação do ClickHouse (banco analítico OLAP) em cluster Docker Swarm.

## Funcionalidades

- Queries analíticas em billions de linhas com latência sub-segundo.
- Formato columnar otimizado para agregações.
- Interface SQL e API HTTP nativa.

## Dependências

- **infra-bootstrap**: Necessário para ambiente Docker Swarm.

## Inputs

- `CLICKHOUSE_PASSWORD`: Senha do usuário default. Se vazia, gera automaticamente via `openssl rand`.

## Observações

- Portas: 8123 (HTTP) e 9000 (Native TCP).
- Volume persistente em `clickhouse_data`.
- Sem TLS nativo — use Traefik como proxy se necessário.
- Recomendado mínimo 2GB RAM.
