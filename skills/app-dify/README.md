# Skill: app-dify

Instalação simplificada do Dify (plataforma LLM + RAG open-source) em cluster Docker Swarm.

## Funcionalidades

- Builder visual de agentes e workflows LLM.
- Suporte a RAG com múltiplas fontes de dados.
- API REST para integração com aplicações externas.

## Dependências

- **PostgreSQL**: Utiliza a instância global `infra-postgres`.
- **Redis**: Utiliza a instância global `infra-redis`.

## Inputs

- `DOMAIN_DIFY`: Domínio de acesso (ex: `dify.exemplo.com`).

## Observações

- Stack simplificada: expõe apenas frontend web e API. Em produção completa, o Dify requer múltiplos serviços (api, worker, web, db, redis).
- A skill foca na orquestração via Traefik para acesso rápido.
- Para produção, considere usar o docker-compose oficial completo.
