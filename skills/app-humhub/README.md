# Skill: app-humhub

Instalação do HumHub (rede social/coworking open-source) em cluster Docker Swarm.

## Funcionalidades

- Rede social corporativa com perfis, espaços e atividades.
- Módulos de CRM, wiki, calendário e polls.
- Integração com email e SSO.

## Dependências

- **infra-mysql**: Banco MySQL.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_HUMHUB`: Domínio de acesso.
- `HUMHUB_ADMIN_USER`, `HUMHUB_ADMIN_EMAIL`, `HUMHUB_ADMIN_PASS`: Admin.
- `SMTP_*`: Configuração SMTP.

## Observações

- Auto-config ativada por padrão (cria usuário admin automaticamente).
- Imagem custom: `humhub/custom:latest`.
