# Skill: app-strapi

Instalação do Strapi (O Headless CMS open-source mais popular) em cluster Docker Swarm.

## Funcionalidades

- Interface administrativa intuitiva para gestão de conteúdo.
- API REST e GraphQL (via plugin) geradas automaticamente.
- Customização total via código.

## Dependências

- **PostgreSQL**: Utiliza a instância global `infra-postgres`.

## Inputs

- `DOMAIN_STRAPI`: Domínio de acesso.

## Observações

- A skill gera automaticamente chaves de segurança para a aplicação e para o painel administrativo.
- Utiliza o volume externo `strapi_data` para persistir o código e os uploads.
- Configurado para o modo de produção por padrão.
