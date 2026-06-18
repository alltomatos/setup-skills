# Setup Skills — Orion Design

> Ecossistema de skills atômicas para deploy de aplicações self-hosted via Docker Swarm, governado pelo Claude Code CLI.
> Fonte: SetupOrion v2.8.0 · Licença MIT · [oriondesign.art.br](https://oriondesign.art.br/setup)

---

## 🚀 Starter — Pré-requisitos

### 1. Node.js 22 LTS

```bash
# Via nvm (recomendado)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc

nvm install 22
nvm use 22
nvm alias default 22

node -v   # v22.x.x
npm -v    # 10.x.x
```

> Alternativa: pacote oficial Debian/Ubuntu
> ```bash
> curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
> sudo apt-get install -y nodejs
> ```

---

### 2. Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code

# Verificar instalação
claude --version

# Login (abre autenticação no browser)
claude login
```

> Requer conta Anthropic com acesso ao Claude Code (claude.ai/code).

---

### 3. Clonar o projeto

```bash
git clone https://github.com/alltomatos/setup-skills.git
cd setup-skills

# Iniciar o orquestrador
claude
```

---

## 📐 Arquitetura

```
setup-skills/
├── .claude/
│   ├── config.json          # Configuração do orquestrador
│   └── context7.json        # Context7 MCP para docs live
├── catalog/
│   ├── readme.md            # Catálogo de Soluções Setup Orion
│   └── docs/                # Documentação de negócio das aplicações
├── docs/
│   ├── SetupOrion.md        # Script-fonte Orion v2.8.0 (45k linhas)
│   ├── adr/
│   │   ├── ADR-001.md       # Padrão de persistência em Markdown
│   │   ├── ADR-002.md       # Segurança de segredos e contexto
│   │   └── ADR-003.md       # Convenções para Claude Code Skills
│   └── Setup.md             # Guia de setup da VPS
├── skills/
│   ├── 00-core/
│   │   └── lib-persistence.sh   # Biblioteca de persistência atômica
│   ├── infra-bootstrap/         # Bootstrap inicial da VPS
│   ├── app-traefik/             # Traefik + Portainer (Swarm)
│   ├── app-chatwoot/            # Chatwoot (atendimento omnichannel)
│   ├── app-evolution/           # Evolution API (WhatsApp)
│   ├── app-n8n/                 # N8N (automação)
│   ├── app-typebot/             # Typebot (chatbot visual)
│   ├── app-minio/               # MinIO (object storage S3-compat)
│   └── ...                      # ~95 skills pendentes (ver Roadmap)
├── ORCHESTRATOR-ROADMAP.md      # Roadmap completo (E1–E23, ~102 skills)
├── ESTADO_ORQUESTRATOR.md       # Estado atual e GAPs
└── CLAUDE.md                    # Diretivas do orquestrador
```

---

## 🏗️ Como as Skills Funcionam

Cada skill é uma unidade atômica e idempotente composta por 3 arquivos:

| Arquivo | Papel |
|---------|-------|
| `metadata.json` | Declaração de inputs, deps, pré-flight checks e persistência |
| `run.sh` | Lógica de deploy (Docker Swarm stack) |
| `README.md` | Guia humano: pré-requisitos, inputs, pós-instalação |

**Fluxo de execução:**
```
Claude coleta inputs → valida pré-flight → injeta variáveis → executa run.sh → persiste metadados em /root/dados_vps/<skill>.md
```

**Regras inegociáveis (ADR-001 + ADR-002):**
- Segredos nunca em disco, git ou logs — apenas em memória efêmera
- Persistência exclusivamente em `/root/dados_vps/*.md`
- Escrita atômica via arquivo temporário (sem corrupção parcial)
- Idempotência: re-executar a skill não duplica serviços

---

## 🛠️ Orquestração & DevOps

O ecossistema conta com uma skill inteligente de **DevOps** para gerenciar o ciclo de vida das aplicações e a saúde do servidor.

### 🛡️ Auditoria de Segurança e Performance
O comando `/devops audit` realiza uma avaliação proativa do servidor:
- **Segurança:** Checagem de porta SSH, login root, autenticação por senha e status do Firewall (UFW).
- **Recursos:** Monitoramento de vCPUs, RAM disponível e espaço em disco.
- **Updates:** Identificação de pacotes pendentes de atualização no SO.

### 🌐 Orquestração Remota via SSH
Você pode rodar o Claude CLI no seu computador local e realizar o deploy em uma VPS remota sem instalar nada no servidor de destino:
1. Inicie `/devops` e escolha o modo **REMOTO**.
2. O agente guiará a configuração de chaves SSH (acesso sem senha).
3. Todo o catálogo de skills será enviado e executado via SSH/SCP de forma transparente.

---

## 📦 Skills Disponíveis


Para uma visão detalhada de cada aplicação, consulte o [**Catálogo de Soluções Setup Orion**](./catalog/readme.md).

### ✅ Implementadas (7)

| Skill | Descrição | Deps |
|-------|-----------|------|
| `infra-bootstrap` | Bootstrap inicial da VPS (Docker, Swarm, usuário) | — |
| `app-traefik` | Traefik reverse proxy + Portainer + SSL automático | infra-bootstrap |
| `app-chatwoot` | Chatwoot — atendimento omnichannel | app-traefik, pgvector |
| `app-evolution` | Evolution API — gateway WhatsApp | app-traefik |
| `app-n8n` | N8N — automação de workflows | app-traefik, postgres |
| `app-typebot` | Typebot — chatbot visual | app-traefik, postgres |
| `app-minio` | MinIO — object storage S3-compatível | app-traefik |

### ⏳ Roadmap (~95 pendentes)

Ver [ORCHESTRATOR-ROADMAP.md](./ORCHESTRATOR-ROADMAP.md) para o mapa completo organizado por épico:

| Epic | Categoria | Skills |
|------|-----------|--------|
| E5 | Infra/Banco | postgres, pgvector, redis, mysql, mongodb, rabbitmq, clickhouse, kafka, qdrant |
| E6 | AI/LLM | flowise, dify, ollama, openwebui, langfuse, langflow, anythingllm, firecrawl, zep, evoai |
| E7 | WhatsApp/Messaging | unoapi, quepasa, wuzapi, wppconnect, transcrevezap |
| E8 | CRM/Atendimento | woofed, krayincrm, twentycrm, evocrm, mautic |
| E9 | Low-code/CMS | strapi, directus, nocobase, nocodb, baserow, tooljet, lowcoder, appsmith |
| E10 | Produtividade | nextcloud, outline, mattermost, docmost, wiki, affine, jitsi, excalidraw… |
| E11 | Docs/PDF | documenso, docuseal, stirlingpdf, gotenberg, opensign |
| E12 | Segurança/Auth | vaultwarden, keycloak, authentik, passbolt |
| E13 | Monitoramento | uptimekuma, monitor, checkmate, netbox |
| E14–E22 | Demais | metabase, wordpress, calcom, odoo, frappe, supabase, rustdesk… |
| E23 | Auditoria | testes, segurança, idempotência |

---

## 🔐 Segurança

- **Zero hardcode**: nenhum token, senha ou chave no repositório
- **Shift-left**: segredos solicitados via chat, usados e descartados
- **Mascaramento**: valores sensíveis nunca aparecem em logs
- **Pre-commit**: instalar Husky + lint-staged para reforço local

---

## 📋 Governança

| Artefato | Papel |
|----------|-------|
| `CLAUDE.md` | Diretivas do orquestrador (regras inegociáveis) |
| `ORCHESTRATOR-ROADMAP.md` | Roadmap de skills (source of truth) |
| `ESTADO_ORQUESTRATOR.md` | Estado atual, GAPs e pendências |
| `catalog/readme.md` | Catálogo de Soluções Setup Orion |
| `docs/adr/ADR-001.md` | Decisão: persistência em Markdown |
| `docs/adr/ADR-002.md` | Decisão: segurança de segredos |
| `docs/adr/ADR-003.md` | Decisão: convenções de skills |

---

## 🤝 Créditos

Script original: **Orion Design** — [oriondesign.art.br](https://oriondesign.art.br/setup)
Licença: MIT · Atribuição obrigatória ao autor original.
