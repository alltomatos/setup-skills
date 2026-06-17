# Skill: app-firecrawl

Instalação do Firecrawl (web scraping otimizado para LLMs) em cluster Docker Swarm.

## Funcionalidades

- Captura páginas web inteiras e transforma em markdown.
- Extrai metadados estruturados para pipelines RAG.
- Suporta crawling recursivo e rate limiting configurável.

## Dependências

- **Redis**: Utiliza a instância global `infra-redis` como broker de filas.

## Inputs

- `DOMAIN_FIRECRAWL`: Domínio de acesso à API (ex: `firecrawl.exemplo.com`).

## Observações

- API REST na porta 3002.
- Sem persistência local — dados processados sob demanda.
- Recomendado para pipelines de scraping destined a Retrieval-Augmented Generation.
