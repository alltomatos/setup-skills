# Orion DevOps — Deploy Skills

> Ecossistema de **deploy skills** que transforma qualquer CLI de IA agêntica (Claude Code, Gemini CLI, Codex CLI…) em um assistente DevOps para instalar stacks Docker Swarm no padrão **Setup Orion**.
>
> Núcleo 100% **bash puro** — agnóstico de agente. Fonte: SetupOrion · [oriondesign.art.br](https://oriondesign.art.br/setup)

---

## ⚡ TL;DR

```bash
# 1. instale uma CLI de IA (Claude, Gemini ou Codex — veja abaixo)
# 2. clone o repositório
git clone https://github.com/alltomatos/devops.git && cd devops
# 3. abra a CLI e invoque o assistente DevOps
claude            # ou: gemini   |   codex
> /devops         # (Claude) renderiza o catálogo e conduz o deploy
```

No Windows? Sem problema: a CLI roda local e faz o deploy **remoto** na sua VPS via SSH (nada é instalado manualmente no servidor).

---

## 🤖 Starter — escolha sua CLI

O repositório funciona com **qualquer agente compatível**, porque as skills são scripts bash + `metadata.json`. As diretivas do projeto ficam em [`CLAUDE.md`](./CLAUDE.md) (o Claude lê automaticamente; para Gemini/Codex, basta apontá-los para esse arquivo).

### 0. Node.js 22 LTS (pré-requisito comum às 3 CLIs)

```bash
# Via nvm (recomendado)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 22 && nvm use 22 && nvm alias default 22
node -v   # v22.x.x
```
> Alternativa Debian/Ubuntu: `curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs`

### 1. Claude Code CLI (Anthropic)

```bash
npm install -g @anthropic-ai/claude-code
claude --version
claude            # primeiro uso pede login (browser)
```
> Requer conta Anthropic com acesso ao Claude Code. Suporte nativo a **skills** (`/devops`, `/status-ecossistema`, etc.).

### 2. Gemini CLI (Google) — **tem uso gratuito** 🆓

```bash
npm install -g @google/gemini-cli
gemini --version
gemini            # faça login com sua conta Google pessoal
```
> **Plano gratuito generoso** logando com conta Google pessoal (sem cartão) — ótimo para começar sem custo. As diretivas ficam em `CLAUDE.md`; para o Gemini lê-las automaticamente, crie um atalho:
> ```bash
> ln -s CLAUDE.md GEMINI.md      # Linux/macOS
> ```

### 3. Codex CLI (OpenAI)

```bash
npm install -g @openai/codex
codex --version
codex             # primeiro uso pede login/API key
```
> Para o Codex carregar as diretivas, aponte-o ao `CLAUDE.md`:
> ```bash
> ln -s CLAUDE.md AGENTS.md      # Linux/macOS
> ```

> 💡 **Por que funciona em qualquer CLI?** Os `run.sh` e o `lib-persistence.sh` são bash puro (sem Python/Node em runtime). O agente apenas lê o `metadata.json`, coleta os inputs e executa o `run.sh` no destino. A inteligência de orquestração está no `CLAUDE.md` + scripts auxiliares — não em um agente específico.

---

## 🚀 Como usar

1. **Clone** o repositório (local, na sua máquina — Windows/Linux/macOS):
   ```bash
   git clone https://github.com/alltomatos/devops.git && cd devops
   ```
2. **Abra a CLI** escolhida (`claude` / `gemini` / `codex`).
3. **Inicie o assistente DevOps**:
   - No Claude: digite `/devops`.
   - No Gemini/Codex: peça "aja como o assistente DevOps do CLAUDE.md e renderize o catálogo".
4. **Selecione o ambiente**:
   - **REMOTO** (padrão no Windows): informe `SSH_HOST` (ex.: `root@1.2.3.4`). O agente valida o acesso por chave SSH, **clona o repo na VPS** (`/root/devops`) e roda tudo via SSH.
   - **LOCAL**: quando a própria CLI roda na VPS Linux.
5. **Escolha a stack** pelo número/nome do catálogo. O agente resolve dependências, coleta inputs e faz o deploy.

Comandos do assistente (Claude):

| Comando | Função |
|---|---|
| `/devops` | Catálogo de deploy (status real ✅/⬜) e fluxo de instalação |
| `/devops audit` | Auditoria de segurança e performance da VPS |
| `/status-ecossistema` | Resumo das stacks instaladas x pendentes |
| `/diagnose-stack <nome>` | Diagnóstico de uma stack específica |
| `/audit-skills` | Conformance das skills |

---

## 🏛️ Arquitetura de deploy (padrão Setup Orion)

A escolha do **modo de deploy não é opcional** — replica o comportamento consolidado do Setup Orion:

| Camada | Como é deployado | Por quê |
|---|---|---|
| **Item 0** `infra-bootstrap` | direto na VPS | prepara Docker + Swarm |
| **Item 1** `app-traefik` (Traefik + Portainer) | `docker stack deploy` | o Portainer ainda não existe para usar sua API |
| **Todas as demais skills** | **API do Portainer** (`/api/stacks`) | stacks ficam com **controle total** na UI (editor, env, redeploy, logs) — `docker stack deploy` as criaria como "limited/external" |

O `app-traefik` cria o admin do Portainer **via API** automaticamente e persiste as credenciais; a partir daí, toda app é criada via `deploy_via_portainer` (em `skills/00-core/lib-persistence.sh`).

---

## 🏗️ Como as skills funcionam

Cada skill em `skills/<nome>/` é atômica e idempotente:

| Arquivo | Papel |
|---------|-------|
| `metadata.json` | Inputs, `depends_on`, pré-flight checks, caminho de persistência |
| `run.sh` | Lógica de deploy (gera o YAML e sobe a stack) — **bash puro** |
| `README.md` | Guia humano: pré-requisitos, inputs, pós-instalação |

**Fluxo:** `agente coleta inputs → valida deps/pré-flight → injeta variáveis → executa run.sh → deploy (API Portainer) → persiste em /root/dados_vps/dados_<servico>`

### Persistência (formato Setup Orion)

Os dados de cada instalação ficam em **`/root/dados_vps/dados_<servico>`** (sem extensão), no formato:

```
[ POSTGRES ]

Host: postgres

Port: 5432

Usuario: postgres

Senha: <senha>
```

- Skills dependentes leem as credenciais via `grep "Senha:" dados_<dep> | awk '{print $2}'`.
- Arquivos com **`chmod 600`**; `/root` é restrito a root.
- Há um arquivo global `dados_vps` (nome do servidor, rede interna, email SSL, link do Portainer) e `dados_portainer` (credenciais do admin para a API).

---

## 🔐 Segurança

- **Zero hardcode no git**: segredos são **gerados em runtime** (`openssl rand`) ou recebidos por env — nunca commitados (ADR-002).
- **Persistência operacional na VPS**: credenciais ficam em `/root/dados_vps/dados_<servico>` com `chmod 600` (necessário para o modelo de dependências entre stacks). Recomenda-se disco criptografado/backup seguro.
- **SSH só por chave**: o assistente nunca pede senha SSH; guia a configuração de chave.
- **Mascaramento**: valores sensíveis não aparecem em resumos/logs do chat.

---

## 📦 Catálogo de skills

São **~103 skills** cobrindo bancos, IA/LLM, WhatsApp, CRM, low-code, produtividade, docs, segurança, monitoramento e utilitários. O catálogo com status real é renderizado pelo `/devops`.

| Epic | Categoria | Exemplos |
|------|-----------|----------|
| E1–E4 | Base/Infra | infra-bootstrap, app-traefik (Traefik + Portainer) |
| E5 | Dados/Banco/Filas | postgres, pgvector, redis, mysql, mongodb, rabbitmq, clickhouse, kafka, qdrant |
| E6 | IA/LLM | ollama, openwebui, flowise, dify, langfuse, langflow, anythingllm, firecrawl, zep, evoai |
| E7 | WhatsApp/Mensageria | evolution, unoapi, quepasa, wuzapi, wppconnect, transcrevezap |
| E8 | CRM/Atendimento | chatwoot, woofed, krayincrm, twentycrm, evocrm, mautic |
| E9 | Low-code/CMS | strapi, directus, nocobase, nocodb, baserow, tooljet, lowcoder, appsmith |
| E10 | Produtividade | nextcloud, outline, mattermost, docmost, wiki, affine, jitsi, excalidraw |
| E11 | Docs/PDF/Assinatura | documenso, docuseal, stirlingpdf, gotenberg, opensign |
| E12 | Segurança/Auth | vaultwarden, keycloak, authentik, passbolt |
| E13 | Monitoramento | uptimekuma, monitor (Prometheus+Grafana), checkmate, netbox |
| E14+ | Diversos | metabase, wordpress, calcom, odoo, frappe, supabase, rustdesk, n8n, typebot, minio… |

Detalhes de negócio: [Catálogo de Soluções](./catalog/readme.md) · Roadmap: [ORCHESTRATOR-ROADMAP.md](./ORCHESTRATOR-ROADMAP.md)

---

## 📋 Governança

| Artefato | Papel |
|----------|-------|
| `CLAUDE.md` | Diretivas do orquestrador (lidas por qualquer CLI) |
| `.claude/skills/` | Skills do assistente (devops, audit-skills, diagnose-stack, status-ecossistema, migrate-skill) |
| `docs/SetupOrion.md` | Script-fonte do Setup Orion (referência da técnica) |
| `docs/adr/ADR-001.md` | Persistência em `dados_<servico>` (formato Setup Orion) |
| `docs/adr/ADR-002.md` | Segurança de segredos (persistência operacional `chmod 600`) |
| `docs/adr/ADR-003.md` | Convenções das skills |
| `ORCHESTRATOR-ROADMAP.md` · `ESTADO_ORQUESTRATOR.md` | Roadmap e estado atual |

---

## 🤝 Créditos

Técnica e catálogo baseados no **Setup Orion** — [oriondesign.art.br](https://oriondesign.art.br/setup). Atribuição ao autor original.
