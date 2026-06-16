# Skill: app-n8n

## O que faz
Deploya o **N8N em modo queue** via **Docker Swarm**, com 3 serviços separados mais um broker Redis:

| Serviço        | Função                                          |
|----------------|-------------------------------------------------|
| `n8n_editor`   | Interface web de criação de workflows           |
| `n8n_worker`   | Executor assíncrono dos workflows (fila Bull)   |
| `n8n_webhook`  | Receptor dedicado de webhooks externos          |
| `n8n_redis`    | Broker de filas entre editor, worker e webhook  |

O modo queue separa criação, execução e recepção de webhooks — escala melhor e isola carga. Webhooks pesados não travam a interface.

## ⚠️ Nota especial — DOIS domínios obrigatórios
Diferente das outras skills, o N8N em modo queue exige **dois subdomínios distintos**, cada um com seu próprio registro DNS apontando para o IP da VPS:

| Domínio            | Para quê                                        |
|--------------------|-------------------------------------------------|
| `URL_N8N`          | Editor — onde você cria e gerencia workflows    |
| `URL_WEBHOOK_N8N`  | Webhook — endpoint público que serviços externos chamam |

Separar o webhook protege o editor: tráfego externo de webhooks bate no serviço dedicado, não na UI. **Ambos os registros DNS precisam existir antes do deploy**, senão o SSL (Let's Encrypt) falha em um dos dois.

## Dependências
- ✅ `infra-bootstrap` (Docker instalado).
- ✅ `app-traefik` (proxy reverso, SSL e rede overlay).
- ✅ **PostgreSQL externo** acessível via host `postgres`, com database `n8n_queue` e usuário `postgres`.

## Dados que o Claude irá solicitar

| Variável            | O que é                                  | Sensível? |
|---------------------|------------------------------------------|-----------|
| `URL_N8N`           | Domínio do editor                        | Não       |
| `URL_WEBHOOK_N8N`   | Domínio do webhook (separado)            | Não       |
| `SENHA_POSTGRES`    | Senha do usuário postgres                | **Sim**   |
| `EMAIL_SMTP_N8N`    | Email remetente SMTP                     | Não       |
| `USER_SMTP_N8N`     | Usuário SMTP                             | Não       |
| `SENHA_SMTP_N8N`    | Senha SMTP                               | **Sim**   |
| `HOST_SMTP_N8N`     | Host SMTP (ex: smtp.hostinger.com)       | Não       |
| `PORTA_SMTP_N8N`    | Porta SMTP (465/587)                     | Não       |
| `NOME_REDE_INTERNA` | Rede overlay Docker                      | Não       |

> **Segurança**: `SENHA_POSTGRES`, `SENHA_SMTP_N8N` e a `N8N_ENCRYPTION_KEY` (gerada via `openssl rand -hex 16`) **nunca** são gravadas em `/root/dados_vps/n8n.md`. Guarde a encryption key em cofre — sem ela, credenciais criptografadas dos workflows são irrecuperáveis.

## Pré-checagens (Claude deve confirmar com o usuário)
1. **DNS editor**: `URL_N8N` aponta para o IP da VPS?
2. **DNS webhook**: `URL_WEBHOOK_N8N` aponta para o IP da VPS? (registro separado)
3. **PostgreSQL**: database `n8n_queue` existe e o host `postgres` responde na rede interna?
4. **Traefik**: a skill `app-traefik` já rodou (rede + SSL prontos)?

## Como o Claude conduz esta skill

1. **Verifica dependências**: confere `/root/dados_vps/traefik.md` e a existência da rede overlay.
2. **Entrevista**: pergunta as 9 variáveis uma a uma. Senhas (`SENHA_POSTGRES`, `SENHA_SMTP_N8N`) são tratadas como sensíveis — não ecoadas em texto claro.
3. **Reforça os dois domínios**: confirma explicitamente que editor e webhook são subdomínios diferentes, ambos com DNS pronto.
4. **Confirmação**: mostra resumo (mascarando senhas) e pede aprovação antes de executar.
5. **Execução**: gera a `N8N_ENCRYPTION_KEY`, injeta as variáveis e roda:
   ```bash
   URL_N8N="..." URL_WEBHOOK_N8N="..." SENHA_POSTGRES="..." \
   EMAIL_SMTP_N8N="..." USER_SMTP_N8N="..." SENHA_SMTP_N8N="..." \
   HOST_SMTP_N8N="..." PORTA_SMTP_N8N="..." NOME_REDE_INTERNA="..." ./run.sh
   ```
6. **Pós-deploy**: lê `n8n.md`, orienta o usuário a criar o admin em `https://{URL_N8N}` e testar um webhook em `https://{URL_WEBHOOK_N8N}`.

## Artefatos gerados

| Arquivo                       | Conteúdo                              |
|-------------------------------|---------------------------------------|
| `/root/n8n.yaml`              | Stack do N8N (editável)               |
| `/root/dados_vps/n8n.md`      | Metadados do deploy (sem senhas)      |

## Recursos provisionados
- **Volume**: `n8n_data`.
- **Serviços**: `n8n_editor`, `n8n_worker`, `n8n_webhook`, `n8n_redis`.
- Rede overlay reutilizada de `NOME_REDE_INTERNA`.

## Escalar workers
```bash
docker service scale n8n_n8n_worker=3
```
Aumenta paralelismo de execução sem reiniciar editor ou webhook.
