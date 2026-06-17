# Skill: AstraCampaign

Esta skill realiza o deploy do **AstraCampaign**, um sistema de gestão de contatos e automação de marketing.

## Características
- **Arquitetura Backend/Frontend**: Deploy separado para melhor escalabilidade.
- **Banco de Dados**: Utiliza PostgreSQL externo.
- **Fila de Tarefas**: Redis dedicado para processamento em segundo plano.
- **Segurança**: JWT_SECRET gerado automaticamente.

## Requisitos
- `infra-bootstrap`
- `app-traefik`
- `infra-postgres` (Banco de dados PostgreSQL ativo no host `postgres`)

## Como Usar
Defina as variáveis de ambiente necessárias e execute o `run.sh`:

```bash
URL_ASTRACAMPAIGN="astracampaign.exemplo.com" \
SENHA_POSTGRES="suasenha" \
NOME_REDE_INTERNA="OrionNet" \
./run.sh
```

## Persistência de Dados
Os metadados da instalação são salvos em `/root/dados_vps/astracampaign.md`.
Os contatos e uploads são armazenados em volumes Docker externos.
