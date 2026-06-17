# Skill: infra-qdrant

Instalação do Qdrant (vector database para busca semântica) em cluster Docker Swarm.

## Funcionalidades

- Busca vetorial em alta dimensionalidade.
- Filtros payload para consultas híbridas.
- API gRPC para performance máxima.

## Dependências

- **infra-bootstrap**: Necessário para ambiente Docker Swarm.

## Inputs

Esta skill não requer inputs — deploy direto.

## Observações

- Portas: 6333 (API REST) e 6334 (gRPC).
- Volume persistente em `qdrant_data`.
- Recomendado para pipelines RAG e similarity search.
- Sem autenticação nativa — exponha apenas na rede overlay ou atrás de proxy.
