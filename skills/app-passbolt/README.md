# Skill: app-passbolt

Instalação do Passbolt (cofre de senhas open-source para equipes) em cluster Docker Swarm.

## Funcionalidades

- Gerenciador de senhas com arquitetura PGP (criptografia de ponta-a-ponta).
- Compartilhamento seguro de credenciais por grupos.
- API REST para automação.
- Extensões de navegador e apps desktop.

## Dependências

- **infra-mysql**: Banco MySQL para dados principais.
- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_PASSBOLT`: Domínio de acesso.
- `PASSBOLT_EMAIL`: Email do primeiro usuário.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`: SMTP.

## Observações

- Sem segredos gerados (ambiente determina chaves PGP).
- Registro público desabilitado por padrão.
- Porta: 80 (exposta via Traefik).
