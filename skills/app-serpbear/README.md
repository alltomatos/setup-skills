# Skill: SerpBear

Esta skill realiza o deploy do **SerpBear**, uma ferramenta Open Source para rastreamento de posição em motores de busca (SERP).

## Características
- **Deploy via Docker Swarm**: Idempotente e resiliente.
- **Persistência**: Dados da aplicação armazenados em volume Docker externo.
- **Segurança**: SECRET e APIKEY gerados automaticamente.

## Requisitos
- `infra-bootstrap`
- `app-traefik` (Rede overlay `OrionNet` e Traefik configurado)

## Como Usar
Defina as variáveis de ambiente necessárias e execute o `run.sh`:

```bash
URL_SERPBEAR="serpbear.exemplo.com" \
USER_SERPBEAR="admin" \
PASS_SERPBEAR="suasenha" \
NOME_REDE_INTERNA="OrionNet" \
./run.sh
```

## Persistência de Dados
Os metadados da instalação são salvos em `/root/dados_vps/serpbear.md`.
