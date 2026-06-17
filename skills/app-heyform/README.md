# Skill: HeyForm

Instala o **HeyForm**, um criador de formulários online interativo, open-source e com foco em privacidade. Uma excelente alternativa ao Typeform.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Skill `infra-mongodb` instalada.

## Inputs solicitados

- `DOMAIN_HEYFORM`: Domínio para acessar a interface da aplicação.

## Pós-instalação

1. Acesse `https://<DOMAIN_HEYFORM>`.
2. A primeira conta registrada no sistema se tornará o administrador.

## Persistência

Os uploads de arquivos são armazenados no volume local `heyform_uploads`. Os dados dos formulários e respostas vão para o MongoDB. O Redis é usado para fila e cache.
A persistência da skill é salva em `/root/dados_vps/app-heyform.md`.
