# Skill: app-directus

Instalação do Directus (Headless CMS + Data Platform open-source) em cluster Docker Swarm.

## Funcionalidades

- Transforma qualquer banco de dados SQL em uma API instantânea.
- Interface administrativa poderosa para gestão de coleções e relacionamentos.
- Extensível via hooks e endpoints personalizados.

## Dependências

- **PostgreSQL**: Utiliza a instância global `infra-postgres`.
- **Redis**: Instância dedicada para cache.
- **Minio (S3)**: Para armazenamento de assets.

## Inputs

- Domínio de acesso.
- Credenciais de administrador inicial.
- Configurações SMTP.
- Credenciais S3 (Minio).

## Observações

- A skill gera automaticamente chaves `KEY` e `SECRET` para a aplicação.
- Utiliza volumes externos para garantir a integridade dos uploads e metadados.
