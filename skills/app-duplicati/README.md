# Skill: app-duplicati

Instalação do Duplicati (ferramenta de backup com criptografia) em cluster Docker Swarm.

## Funcionalidades

- Backups incrementais e comprimidos.
- Criptografia forte (AES-256) nativa.
- Suporte a múltiplos backends (S3, B2, FTP, SSH, etc).
- Interface web amigável.

## Dependências

- **infra-bootstrap**: Configuração base do cluster.
- **app-traefik**: Gateway de borda.

## Inputs

- `DOMAIN_DUPLICATI`: Domínio de acesso.
- `PASS_DUPLICATI`: Senha da interface web.

## Observações

- Gera `SETTINGS_ENCRYPTION_KEY` automaticamente para criptografia do banco de dados interno.
- Volumes persistentes: `duplicati_data` (configurações) e `duplicati_backups` (armazenamento local opcional).
- Porta: 8200 (exposta via Traefik).
