# Skill: RedisInsight

Esta skill realiza o deploy do **RedisInsight**, uma interface gráfica poderosa para gerenciar e visualizar dados no Redis.

## Características
- **Deploy via Docker Swarm**: Idempotente e resiliente.
- **Autenticação Básica**: Protegido por Traefik Basic Auth.
- **Persistência**: Dados e logs armazenados em volumes Docker externos.
- **Segurança**: RI_ENCRYPTION_KEY gerada automaticamente.

## Requisitos
- `infra-bootstrap`
- `app-traefik` (Rede overlay `OrionNet` e Traefik configurado)

## Como Usar
Defina as variáveis de ambiente necessárias e execute o `run.sh`:

```bash
URL_REDISINSIGHT="redisinsight.exemplo.com" \
USER_REDISINSIGHT="admin" \
PASS_REDISINSIGHT="suasenha" \
NOME_REDE_INTERNA="OrionNet" \
./run.sh
```

## Persistência de Dados
Os metadados da instalação são salvos em `/root/dados_vps/redisinsight.md`.
