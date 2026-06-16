# Skill: infra-pgvector

Instalação do PostgreSQL com a extensão `pgvector`, otimizada para aplicações de Inteligência Artificial e RAG (Retrieval-Augmented Generation).

## Diferenciais

- Baseado na imagem `ankane/pgvector`.
- Configuração de memória expandida (2GB) para suportar índices vetoriais.
- Compatível com Flowise, Dify e AnythingLLM.

## Inputs

- `PGVECTOR_PASSWORD`: Senha do banco. Gerada automaticamente se omitida.

## Persistência

- Volume: `pgvector_data`
- Metadados: `/root/dados_vps/infra-pgvector.md`
