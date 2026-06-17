# Skill: app-affine

Instalação do AFFiNE (plataforma Notion open-source) em cluster Docker Swarm.

## Funcionalidades

- Edição de documentos com blocos, tabelas e drawings.
- Suporte a workspaces, páginas e databases.
- Sync multi-dispositivo e visualização em grade.

## Dependências

- **infra-pgvector**: Banco PostgreSQL com extensão vetorial.
- **infra-redis**: Cache de sessão.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_AFFINE`: Domínio de acesso.
- `AFFINE_ADMIN_EMAIL`: Email do administrador.
- `AFFINE_ADMIN_PASS`: Senha do admin.

## Observações

- 2 serviços: app + redis dedicado.
- Inclui migration job que roda na inicialização.
- Copilot desabilitado por padrão (requer Ollama/LLM external).
- Porta: 3010 (exposta via Traefik).
