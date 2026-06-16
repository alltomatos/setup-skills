# app-minio — Object Storage S3-Compatible

Skill Orion para deploy do **MinIO** via Docker Swarm com SSL automático via Traefik.

MinIO expõe dois endpoints distintos:
- **Painel Admin (Console)** — interface web para gerenciar buckets e usuários (porta 9001)
- **API S3** — endpoint compatível com AWS S3, consumido por outras skills como storage (porta 9000)

---

## Dependências

```
infra-bootstrap → app-traefik → app-minio
```

---

## Inputs

| Variável           | Sensível | Mínimo  | Descrição                                                         | Exemplo                    |
|--------------------|----------|---------|-------------------------------------------------------------------|----------------------------|
| `URL_MINIO`        | Não      | —       | Domínio do painel admin (DNS deve apontar para esta VPS)          | `minio.seudominio.com.br`  |
| `URL_S3`           | Não      | —       | Domínio da API S3 — **lido por outras skills** (DNS obrigatório)  | `s3.seudominio.com.br`     |
| `SENHA_MINIO`      | **SIM**  | 8 chars | Senha do usuário `admin`. Nunca gravada em disco.                 | `MinhaS3nh@Forte!`         |
| `NOME_REDE_INTERNA`| Não      | —       | Rede overlay Docker do ecossistema Orion                          | `OrionNet`                 |

---

## Como o Claude usa esta skill

```
Claude coleta URL_MINIO, URL_S3, SENHA_MINIO, NOME_REDE_INTERNA
        ↓
Claude injeta as variáveis e executa run.sh via SSH
        ↓
run.sh cria volume minio_data
        ↓
run.sh gera /root/minio.yaml (stack Swarm com labels Traefik)
        ↓
docker stack deploy → MinIO sobe com Traefik roteando os 2 domínios
        ↓
run.sh salva /root/dados_vps/minio.md com URL_MINIO e URL_S3
(SENHA_MINIO nunca é escrita em disco)
        ↓
Claude orienta criação de bucket e geração de Access Keys no painel
```

---

## URL_S3 é consumida por outras skills

> Esta é a integração mais importante desta skill no ecossistema Orion.

Quando o Claude instala skills que precisam de storage de arquivos (uploads, attachments, mídia), ele lê `/root/dados_vps/minio.md` para obter o `URL_S3` e usa como endpoint S3 na configuração de cada serviço.

Skills que dependem de `URL_S3`:

| Skill            | Uso do MinIO                              |
|------------------|-------------------------------------------|
| `app-chatwoot`   | Storage de attachments de conversas       |
| `app-n8n`        | Storage de arquivos de workflows          |
| `app-evolution`  | Storage de mídia WhatsApp (audio, imagem) |

**As Access Keys (não a senha root) são as credenciais usadas nessas integrações.**

---

## Arquitetura de Segurança

| Item                  | Comportamento                                                       |
|-----------------------|---------------------------------------------------------------------|
| `SENHA_MINIO`         | Injetada apenas em tempo de execução — nunca gravada em nenhum .md |
| `/root/dados_vps/minio.md` | Contém apenas URLs e metadados operacionais                   |
| Access Keys de integração | Geradas manualmente no painel após o deploy                   |
| SSL                   | Automático via Traefik + Let's Encrypt para os 2 domínios          |

---

## Pós-instalação (passo obrigatório)

Após o deploy, acesse o painel e execute:

1. **Login**: `https://{URL_MINIO}` → usuário `admin`, senha `{SENHA_MINIO}`
2. **Criar bucket**: `Buckets → Create Bucket` (ex: `chatwoot`, `n8n-files`)
3. **Gerar Access Keys**: `Identity → Service Accounts → Create Service Account`
4. **Copiar** Access Key ID + Secret Access Key gerados
5. **Informar ao Claude** as keys para integração com `app-chatwoot` ou outra skill

> Sem as Access Keys, as skills dependentes não conseguem gravar arquivos no MinIO.

---

## Arquivos gerados

| Caminho                        | Conteúdo                                     |
|--------------------------------|----------------------------------------------|
| `/root/minio.yaml`             | Stack Docker Swarm (Traefik labels incluídos)|
| `/root/dados_vps/minio.md`     | Metadados do deploy: URLs, volume, status    |

---

## Troubleshooting

```bash
# Status dos containers
docker service ls | grep minio

# Logs do serviço
docker service logs minio_minio --tail 50

# Verificar se volume existe
docker volume inspect minio_data

# Forçar redeploy
docker stack deploy --prune --resolve-image always -c /root/minio.yaml minio
```
