# Skill: Checkmate

Instala o **Checkmate**, uma ferramenta de monitoramento de uptime e performance moderna.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-mongodb` instalada.

## Inputs solicitados

- `DOMAIN_CHECKMATE`: Domínio para o frontend do Checkmate.
- `DOMAIN_CHECKMATE_API`: Domínio para a API do Checkmate.

## Pós-instalação

1. Acesse `https://<DOMAIN_CHECKMATE>`.
2. Configure seus monitores via interface web.

## Persistência

Os dados do Redis são persistidos no volume `checkmate_redis_data`.
A persistência da skill é salva em `/root/dados_vps/app-checkmate.md`.
