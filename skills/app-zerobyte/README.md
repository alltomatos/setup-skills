# Skill: app-zerobyte

Instalação do ZeroByte (utilitário para compartilhamento de arquivos) em cluster Docker Swarm.

## Funcionalidades

- Upload e compartilhamento rápido de arquivos.
- Interface minimalista e eficiente.
- Focado em privacidade e velocidade.

## Dependências

- **infra-bootstrap**: Configuração base do cluster.
- **app-traefik**: Gateway de borda.

## Inputs

- `DOMAIN_ZEROBYTE`: Domínio de acesso.

## Observações

- Gera `APP_SECRET` automaticamente para segurança da aplicação.
- Volume persistente: `zerobyte_data` para armazenamento dos arquivos.
- Porta: 4096 (exposta via Traefik).
