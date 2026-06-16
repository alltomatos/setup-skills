# Skill: app-chatwoot

Deploy do **Chatwoot** via Docker Swarm — plataforma de atendimento omnichannel open source.

A stack sobe 3 serviços na mesma composição: `app` (Rails), `sidekiq` (worker de filas) e `redis` (broker/cache). O banco de dados usa o container `pgvector` já existente na VPS.

---

## Dependências

| Skill            | Motivo                                      |
|------------------|---------------------------------------------|
| `infra-bootstrap`| Docker + Swarm instalados                   |
| `app-traefik`    | Proxy reverso + SSL + rede overlay Docker   |
| pgvector (externo)| Banco PostgreSQL com suporte a vetores     |

---

## Inputs Obrigatórios

| Variável                | Sensível | Exemplo                        | Descrição                                                      |
|-------------------------|----------|-------------------------------|----------------------------------------------------------------|
| `URL_CHATWOOT`          | Não      | `chatwoot.seudominio.com.br`  | Domínio com DNS apontando para o IP da VPS                     |
| `NOME_EMPRESA_CHATWOOT` | Não      | `Orion Design`                | Nome exibido na interface do Chatwoot                          |
| `SENHA_PGVECTOR`        | **Sim**  | `s3nh@F0rte!`                 | Senha do postgres no pgvector (host fixo: `pgvector`)          |
| `EMAIL_ADMIN_CHATWOOT`  | Não      | `noreply@seudominio.com.br`   | Email remetente (MAILER_SENDER_EMAIL)                          |
| `USER_SMTP_CHATWOOT`    | Não      | `noreply@seudominio.com.br`   | Usuário de autenticação SMTP                                   |
| `SENHA_EMAIL_CHATWOOT`  | **Sim**  | `s3nh@Smtp!`                  | Senha SMTP — nunca registrada em logs ou `.md`                 |
| `SMTP_HOST_CHATWOOT`    | Não      | `smtp.hostinger.com`          | Host do servidor SMTP                                          |
| `PORTA_SMTP_CHATWOOT`   | Não      | `465` ou `587`                | Porta SMTP — determina `SMTP_SSL` automaticamente              |
| `NOME_REDE_INTERNA`     | Não      | `OrionNet`                    | Rede overlay criada pelo Traefik (lida de `traefik.md`)        |

---

## Variáveis Geradas Automaticamente

| Variável           | Origem                                              |
|--------------------|-----------------------------------------------------|
| `SMTP_SSL`         | `true` se porta 465 · `false` se porta 587          |
| `SECRET_KEY_BASE`  | `openssl rand -hex 16` — gerado a cada execução     |

---

## Fluxo de Execução (Claude + run.sh)

```
Claude coleta inputs → injeta como env vars → executa run.sh
                                                    │
                              ┌─────────────────────▼──────────────────────┐
                              │  [0/5] Valida todas as variáveis            │
                              │  [1/5] Resolve SMTP_SSL + gera enc. key     │
                              │  [2/5] Cria volumes (idempotente)           │
                              │  [3/5] Gera /root/chatwoot.yaml             │
                              │         └── app + sidekiq + redis           │
                              │  [4/5] docker stack deploy chatwoot         │
                              │  [5/5] save_data → /root/dados_vps/         │
                              │         └── senha mascarada como ***        │
                              └────────────────────────────────────────────┘
```

---

## Artefatos Gerados em /root/

| Arquivo                          | Conteúdo                                               |
|----------------------------------|--------------------------------------------------------|
| `/root/chatwoot.yaml`            | Stack YAML completa (app + sidekiq + redis)            |
| `/root/dados_vps/chatwoot.md`    | Metadados do deploy — **sem senhas** (SMTP mascarado)  |
| `/root/dados_vps/index.md`       | Catálogo central atualizado pelo lib-persistence.sh    |

---

## Serviços da Stack

| Serviço   | Imagem                      | Função                              |
|-----------|-----------------------------|-------------------------------------|
| `app`     | `chatwoot/chatwoot:latest`  | Rails app — interface web + API     |
| `sidekiq` | `chatwoot/chatwoot:latest`  | Worker Sidekiq — filas de background|
| `redis`   | `redis:7-alpine`            | Broker de mensagens + cache         |

---

## Segurança

- `SENHA_EMAIL_CHATWOOT` e `SENHA_PGVECTOR` marcadas como `sensitive: true` no metadata.json
- Senha SMTP nunca aparece em logs, stdout ou no arquivo `.md` (substituída por `***`)
- `SECRET_KEY_BASE` gerado via `openssl rand -hex 16` — único por execução
- `set -euo pipefail` garante abort em qualquer falha inesperada

---

## Verificação Pós-Deploy

```bash
# Status dos serviços
docker service ls | grep chatwoot

# Logs da aplicação
docker service logs chatwoot_app

# Logs do worker
docker service logs chatwoot_sidekiq

# Metadados salvos
cat /root/dados_vps/chatwoot.md
```

---

## Pre-flight Checks

1. DNS do `URL_CHATWOOT` aponta para o IP da VPS
2. Skill `app-traefik` instalada e rede overlay ativa
3. Container `pgvector` em execução e acessível na rede overlay
4. Banco `chatwoot` existe no pgvector (ou postgres tem permissão de criação)
5. Portas 80 e 443 abertas no firewall
6. `openssl` disponível no host

---

## Primeiro Acesso

Aguarde 60–90 segundos após o deploy (migrations Rails). Acesse `https://{URL_CHATWOOT}` e crie a conta de superadmin no primeiro boot.
