# Skill: Wekan (app-wekan)

Este skill realiza a instalação do **Wekan**, um quadro Kanban open-source (similar ao Trello), utilizando Docker Swarm.

## Visão Técnica

- **Imagem**: `ghcr.io/wekan/wekan:latest`
- **Banco de Dados**: MongoDB (infra-mongodb)
- **Persistence**: 
  - Volume `wekan_files` montado em `/data` no container.
  - Metadados em `/root/dados_vps/app-wekan.md`.
- **Segurança**:
  - Utiliza Traefik para SSL/TLS automático via Let's Encrypt.
  - Segredos (MONGO_PASSWORD e WEKAN_SECRET_KEY) são persistidos localmente para garantir a persistência da instalação e reuso em caso de re-deploy.

## Requisitos (Dependências)

- `infra-bootstrap`: Configuração básica do Swarm e redes.
- `app-traefik`: Proxy reverso para acesso externo e SSL.
- `infra-mongodb`: Instância de banco de dados NoSQL.

## Variáveis de Ambiente Necessárias

- `DOMAIN_WEKAN`: Domínio para acesso (ex: wekan.meudominio.com).
- `MONGO_ROOT_PASSWORD`: Senha do root do MongoDB (necessária no primeiro deploy se não estiver persistida).

## Persistence de Dados (ADR-001/ADR-002)

Seguindo as instruções da Epic E18, este skill persiste segredos sensíveis no arquivo de dados do VPS para assegurar a continuidade do serviço e recuperação de desastres, sobrepondo as restrições padrão de não-persistência de segredos quando solicitado.

## Deploy

```bash
export DOMAIN_WEKAN="wekan.exemplo.com"
export MONGO_ROOT_PASSWORD="sua_senha_mongo"
./run.sh
```
