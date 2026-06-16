# Skill: app-typebot

Deploy automatizado do **Typebot** via Docker Swarm com proxy reverso Traefik e SSL automático (Let's Encrypt).

---

## Arquitetura: 2 Domínios Obrigatórios

O Typebot exige **dois subdomínios distintos** — esta é uma restrição do produto, não uma escolha de configuração:

| Serviço | Variável | Função |
|---------|----------|--------|
| **Builder** | `URL_TYPEBOT` | Editor visual de fluxos (acesso restrito à equipe) |
| **Viewer** | `URL_VIEWER_TYPEBOT` | Runtime público onde os bots são executados pelos usuários finais |

> Ambos os domínios precisam ter entradas DNS apontando para o IP da VPS **antes** do deploy.

---

## Inputs Obrigatórios

| Variável | Sensível | Descrição | Exemplo |
|----------|----------|-----------|---------|
| `URL_TYPEBOT` | Não | Domínio do Builder | `typebot.seudominio.com.br` |
| `URL_VIEWER_TYPEBOT` | Não | Domínio do Viewer | `viewer.seudominio.com.br` |
| `SENHA_POSTGRES` | **Sim** | Senha do PostgreSQL externo | `MinhaS3nh@Forte` |
| `EMAIL_SMTP_TYPEBOT` | Não | Email remetente (autenticação) | `noreply@seudominio.com.br` |
| `USER_SMTP_TYPEBOT` | Não | Usuário SMTP | `noreply@seudominio.com.br` |
| `SENHA_SMTP_TYPEBOT` | **Sim** | Senha SMTP | `S3nhaSmtp!` |
| `HOST_SMTP_TYPEBOT` | Não | Host do servidor SMTP | `smtp.gmail.com` |
| `PORTA_SMTP_TYPEBOT` | Não | Porta SMTP | `587` |
| `NOME_REDE_INTERNA` | Não | Rede overlay Docker | `OrionNet` |

### Gerado automaticamente (Claude não pergunta ao usuário)

| Variável | Como é gerado |
|----------|--------------|
| `NEXTAUTH_SECRET` | `openssl rand -hex 16` — gerado no momento do deploy, não persistido em texto |

---

## Dependências

- `infra-bootstrap` — Docker + Docker Swarm configurados
- `app-traefik` — Traefik ativo na rede overlay, com SSL

O PostgreSQL é **externo** à stack: deve estar acessível na rede overlay via hostname `postgres` (user: `postgres`, database: `typebot`).

---

## Fluxo do Claude

```
1. Claude coleta os inputs acima via conversa
2. NEXTAUTH_SECRET é gerado automaticamente por run.sh (openssl)
3. run.sh gera /root/typebot.yaml com builder + viewer
4. docker stack deploy executa a stack "typebot"
5. Metadados (sem senhas) salvos em /root/dados_vps/typebot.md
6. Claude informa as URLs de acesso ao usuário
```

---

## Arquivos Gerados

| Arquivo | Conteúdo |
|---------|----------|
| `/root/typebot.yaml` | Stack YAML completo (builder + viewer) |
| `/root/dados_vps/typebot.md` | Metadados do deploy (sem credenciais sensíveis) |

---

## Pós-Deploy

1. Acesse `https://{URL_TYPEBOT}` e crie o primeiro usuário — ele será o administrador
2. Publique um typebot e acesse via `https://{URL_VIEWER_TYPEBOT}/{typebot-slug}`
3. Verifique os serviços: `docker service ls | grep typebot`
4. Logs do builder: `docker service logs typebot_typebot_builder`
5. Logs do viewer: `docker service logs typebot_typebot_viewer`

---

## Notas de Segurança

- `SENHA_POSTGRES` e `SENHA_SMTP_TYPEBOT` não são persistidas em `/root/dados_vps/typebot.md`
- `NEXTAUTH_SECRET` gerado por `openssl rand -hex 16` — nunca armazenado em texto plano
- Redeployar a stack gera um novo `NEXTAUTH_SECRET` — sessões ativas serão invalidadas (comportamento esperado)
