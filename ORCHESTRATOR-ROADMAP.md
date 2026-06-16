# ORCHESTRATOR-ROADMAP

Este documento mapeia o progresso do projeto `setup-skills` sob governança do orquestrador.
Fonte de verdade: `docs/SetupOrion.md` (v2.8.0 — 45.909 linhas, ~110 ferramentas).

---

## Epics

- [x] **E1: Bootstrap do Ecossistema** — Configuração, docs, governança
- [x] **E2: Estrutura de Skills & Persistência** — Decomposição, bibliotecas, padrão MD
- [x] **E3: Skills Base** — infra-bootstrap + app-traefik + app-portainer
- [x] **E4: Skills de Aplicação Prioritárias** — Chatwoot, Evolution, N8n, Typebot, Minio
- [x] **E5: Skills de Infraestrutura de Dados** — Bancos, filas, busca vetorial
- [x] **E6: Skills de Aplicação — AI/LLM** — Agentes, modelos, plataformas de IA
- [x] **E7: Skills de Aplicação — WhatsApp/Messaging** — Gateways e bots
- [x] **E8: Skills de Aplicação — CRM/Atendimento** — CRMs e plataformas de marketing
- [ ] **E9: Skills de Aplicação — Low-code/CMS** — Construtores e gerenciadores de conteúdo
- [ ] **E10: Skills de Aplicação — Produtividade/Collab** — Docs, chat, videoconf
- [ ] **E11: Skills de Aplicação — Docs/PDF/Assinatura** — Geração e assinatura digital
- [ ] **E12: Skills de Aplicação — Segurança/Auth** — SSO, cofres de senhas
- [ ] **E13: Skills de Aplicação — Monitoramento** — Uptime, alertas, inventário
- [ ] **E14: Skills de Aplicação — Analytics/BI** — Dashboards e observabilidade LLM
- [ ] **E15: Skills de Aplicação — Marketing/Web** — Sites, SEO, encurtadores
- [ ] **E16: Skills de Aplicação — Agendamento** — Calendários e reservas
- [ ] **E17: Skills de Aplicação — ERP/Negócio** — ERPs e helpdesk
- [ ] **E18: Skills de Aplicação — Projetos/Kanban** — Gestão de tarefas
- [ ] **E19: Skills de Aplicação — Dev Tools** — Ferramentas para devs e DBAs
- [ ] **E20: Skills de Aplicação — Utilitários** — Remote desktop, radio, backups
- [ ] **E21: Skills de Aplicação — Forms** — Construtores de formulários
- [ ] **E22: Skills de Aplicação — Automação** — Plataformas de automação e chatbots
- [ ] **E23: Auditoria, Testes e Qualidade** — Segurança e validação

---

## Status

- **Fase Atual**: E9 (Skills de Aplicação — Low-code/CMS)
- **Estado**: Em Execução

---

## Convenções

- Cada skill tem: `metadata.json` + `run.sh` + `README.md`
- Segredos nunca persistidos (ADR-002)
- Persistência em `/root/dados_vps/<skill>.md` (ADR-001)
- Dependências declaradas em `metadata.json → depends_on`
- Skills de infra são prefixadas com `infra-`; apps com `app-`

---

## Tarefas (DAG)

### E1–E4: Concluídos

- [x] T1: Criar .gitignore
- [x] T2: Remover lixo de sistema
- [x] T3: Organizar docs/
- [x] T4: Criar ADR-001 (Padrão Persistência em Markdown)
- [x] T5: Criar ADR-002 (Segurança de Segredos e Contexto)
- [x] T6: Estruturar diretório base de skills
- [x] T7: Implementar lib-persistence.sh
- [x] T8: Skill infra-bootstrap
- [x] T9: Skill app-traefik
- [x] T10: Skill app-chatwoot
- [x] T11: Skill app-evolution
- [x] T12: Skill app-n8n
- [x] T13: Skill app-typebot
- [x] T14: Skill app-minio

---

### E5: Skills de Infraestrutura de Dados

> Pré-requisito de quase todas as apps. Deps: infra-bootstrap + app-traefik.

- [x] T15: Skill `infra-postgres`      — PostgreSQL standalone via Docker Swarm
- [x] T16: Skill `infra-pgvector`      — PostgreSQL + pgvector (extensão vetorial)
- [x] T17: Skill `infra-redis`         — Redis cache/pub-sub
- [x] T18: Skill `infra-mysql`         — MySQL 8
- [x] T19: Skill `infra-mongodb`       — MongoDB
- [x] T20: Skill `infra-rabbitmq`      — RabbitMQ (fila de mensagens)
- [x] T21: Skill `infra-clickhouse`    — ClickHouse (analytics OLAP)
- [x] T22: Skill `infra-kafka`         — Apache Kafka
- [x] T23: Skill `infra-qdrant`        — Qdrant (busca vetorial)

---

### E6: Skills de Aplicação — AI/LLM

> Deps: E5 (varia por app).

- [x] T24: Skill `app-flowise`         — Flowise (orquestração LLM low-code)
- [x] T25: Skill `app-dify`            — Dify (plataforma LLM + RAG)
- [x] T26: Skill `app-ollama`          — Ollama (modelos locais)
- [x] T27: Skill `app-openwebui`       — Open WebUI (frontend Ollama)
- [x] T28: Skill `app-langfuse`        — Langfuse (observabilidade LLM)
- [x] T29: Skill `app-langflow`        — Langflow (builder visual de fluxos LLM)
- [x] T30: Skill `app-anythingllm`     — AnythingLLM (RAG privado)
- [x] T31: Skill `app-firecrawl`       — Firecrawl (web scraping para LLM)
- [x] T32: Skill `app-zep`             — Zep (memória long-term para agentes)
- [x] T33: Skill `app-evoai`           — EvoAI (plataforma de agentes)
- [x] T34: Skill `app-omnitools`       — OmniTools (hub de ferramentas AI)

---

### E7: Skills de Aplicação — WhatsApp/Messaging

> Deps: infra-bootstrap + app-traefik.

- [x] T35: Skill `app-unoapi`          — UnoAPI (gateway WhatsApp via Baileys)
- [x] T36: Skill `app-quepasa`         — QuePasa (gateway WhatsApp)
- [x] T37: Skill `app-wuzapi`          — WuzAPI (gateway WhatsApp)
- [x] T38: Skill `app-wppconnect`      — WPPConnect (gateway WhatsApp)
- [x] T39: Skill `app-transcrevezap`   — TranscreveZap (transcrição de áudio WhatsApp)

---

### E8: Skills de Aplicação — CRM/Atendimento

> Deps: E5 (postgres/redis).

- [x] T40: Skill `app-woofed`          — WoofedCRM (CRM para WhatsApp)
- [x] T41: Skill `app-krayincrm`       — Krayin CRM (CRM open-source)
- [x] T42: Skill `app-twentycrm`       — Twenty CRM (CRM moderno)
- [x] T43: Skill `app-evocrm`          — EvoCRM (CRM integrado Evolution)
- [x] T44: Skill `app-mautic`          — Mautic (automação de marketing)

---

### E9: Skills de Aplicação — Low-code/CMS

> Deps: E5 (postgres ou mysql).

- [x] T45: Skill `app-strapi`          — Strapi (headless CMS)
- [x] T46: Skill `app-directus`        — Directus (headless CMS + BaaS)
- [ ] T47: Skill `app-nocobase`        — NocoBase (no-code BaaS)
- [ ] T48: Skill `app-nocodb`          — NocoDB (Airtable open-source)
- [ ] T49: Skill `app-baserow`         — Baserow (Airtable open-source)
- [ ] T50: Skill `app-tooljet`         — ToolJet (low-code internal tools)
- [ ] T51: Skill `app-lowcoder`        — Lowcoder (low-code internal tools)
- [ ] T52: Skill `app-appsmith`        — Appsmith (low-code internal tools)

---

### E10: Skills de Aplicação — Produtividade/Collab

> Deps: infra-bootstrap + app-traefik (alguns requerem postgres).

- [ ] T53: Skill `app-nextcloud`       — Nextcloud (armazenamento e collab)
- [ ] T54: Skill `app-outline`         — Outline (wiki/knowledge base)
- [ ] T55: Skill `app-mattermost`      — Mattermost (chat team)
- [ ] T56: Skill `app-docmost`         — Docmost (docs colaborativo)
- [ ] T57: Skill `app-wiki`            — Wiki.js (wiki moderna)
- [ ] T58: Skill `app-affine`          — AFFiNE (Notion open-source)
- [ ] T59: Skill `app-humhub`          — HumHub (rede social corporativa)
- [ ] T60: Skill `app-hoppscotch`      — Hoppscotch (API client open-source)
- [ ] T61: Skill `app-excalidraw`      — Excalidraw (diagramas colaborativos)
- [ ] T62: Skill `app-wisemapping`     — WiseMapping (mind maps)
- [ ] T63: Skill `app-papra`           — Papra (gestão de documentos)
- [ ] T64: Skill `app-jitsi`           — Jitsi Meet (videoconferência)

---

### E11: Skills de Aplicação — Docs/PDF/Assinatura

> Deps: infra-bootstrap + app-traefik.

- [ ] T65: Skill `app-documenso`       — Documenso (assinatura digital)
- [ ] T66: Skill `app-docuseal`        — DocuSeal (assinatura digital)
- [ ] T67: Skill `app-stirlingpdf`     — Stirling PDF (manipulação PDF)
- [ ] T68: Skill `app-gotenberg`       — Gotenberg (API PDF via Docker)
- [ ] T69: Skill `app-opensign`        — OpenSign (assinatura digital)

---

### E12: Skills de Aplicação — Segurança/Auth

> Deps: infra-bootstrap + app-traefik.

- [ ] T70: Skill `app-vaultwarden`     — Vaultwarden (cofre de senhas Bitwarden-compat)
- [ ] T71: Skill `app-keycloak`        — Keycloak (SSO / IAM)
- [ ] T72: Skill `app-authentik`       — Authentik (SSO / IAM)
- [ ] T73: Skill `app-passbolt`        — Passbolt (cofre de senhas para times)

---

### E13: Skills de Aplicação — Monitoramento

> Deps: infra-bootstrap + app-traefik.

- [ ] T74: Skill `app-uptimekuma`      — Uptime Kuma (monitoramento de uptime)
- [ ] T75: Skill `app-monitor`         — Monitor Orion (stack de métricas Prometheus/Grafana)
- [ ] T76: Skill `app-checkmate`       — Checkmate (monitoramento alternativo)
- [ ] T77: Skill `app-netbox`          — NetBox (inventário de rede/infra)

---

### E14: Skills de Aplicação — Analytics/BI

> Deps: E5 (postgres ou clickhouse).

- [ ] T78: Skill `app-metabase`        — Metabase (BI e dashboards)
- [ ] T79: Skill `app-redisinsight`    — RedisInsight (UI para Redis)

---

### E15: Skills de Aplicação — Marketing/Web

> Deps: infra-bootstrap + app-traefik.

- [ ] T80: Skill `app-wordpress`       — WordPress (CMS/blog)
- [ ] T81: Skill `app-serpbear`        — SerpBear (rastreamento SEO)
- [ ] T82: Skill `app-astracampaign`   — AstraCampaign (campanhas de email)
- [ ] T83: Skill `app-yourls`          — YOURLS (encurtador de URLs próprio)
- [ ] T84: Skill `app-shlink`          — Shlink (encurtador de URLs avançado)

---

### E16: Skills de Aplicação — Agendamento

> Deps: infra-bootstrap + app-traefik + postgres.

- [ ] T85: Skill `app-calcom`          — Cal.com (agendamento open-source)
- [ ] T86: Skill `app-easyappointments` — Easy!Appointments (agendamento simples)

---

### E17: Skills de Aplicação — ERP/Negócio

> Deps: E5 (postgres ou mysql).

- [ ] T87: Skill `app-odoo`            — Odoo (ERP completo)
- [ ] T88: Skill `app-frappe`          — Frappe/ERPNext (ERP open-source)
- [ ] T89: Skill `app-glpi`            — GLPI (helpdesk e ITSM)

---

### E18: Skills de Aplicação — Projetos/Kanban

> Deps: infra-bootstrap + app-traefik.

- [ ] T90: Skill `app-openproject`     — OpenProject (gestão de projetos)
- [ ] T91: Skill `app-planka`          — Planka (kanban estilo Trello)
- [ ] T92: Skill `app-wekan`           — Wekan (kanban open-source)

---

### E19: Skills de Aplicação — Dev Tools

> Deps: E5 (varia por app).

- [ ] T93: Skill `app-supabase`        — Supabase (BaaS open-source + auth + storage)
- [ ] T94: Skill `app-code-server`     — Code Server (VSCode no browser)
- [ ] T95: Skill `app-phpmyadmin`      — phpMyAdmin (UI para MySQL)
- [ ] T96: Skill `app-pgadmin`         — pgAdmin 4 (UI para PostgreSQL)
- [ ] T97: Skill `app-redisinsight`    — RedisInsight (UI para Redis) ← movido para E14
- [ ] T98: Skill `app-pgbackweb`       — PgBackWeb (backup PostgreSQL via UI)

---

### E20: Skills de Aplicação — Utilitários

> Deps: infra-bootstrap + app-traefik.

- [ ] T99:  Skill `app-rustdesk`       — RustDesk (remote desktop open-source)
- [ ] T100: Skill `app-azuracast`      — AzuraCast (rádio web open-source)
- [ ] T101: Skill `app-ntfy`           — ntfy (notificações push self-hosted)
- [ ] T102: Skill `app-traccar`        — Traccar (rastreamento GPS)
- [ ] T103: Skill `app-duplicati`      — Duplicati (backup com criptografia)
- [ ] T104: Skill `app-zerobyte`       — ZeroByte (utilitário Orion)

---

### E21: Skills de Aplicação — Forms

> Deps: infra-bootstrap + app-traefik + postgres.

- [ ] T105: Skill `app-formbricks`     — Formbricks (surveys e formulários)
- [ ] T106: Skill `app-heyform`        — HeyForm (formulários conversacionais)

---

### E22: Skills de Aplicação — Automação

> Deps: infra-bootstrap + app-traefik.

- [ ] T107: Skill `app-activepieces`   — Activepieces (automação no-code)
- [ ] T108: Skill `app-botpress`       — Botpress (plataforma de chatbots)

---

### E23: Auditoria, Testes e Qualidade

> Deps: E5–E22 concluídos.

- [ ] T109: Auditoria de segurança em todas as skills (ADR-002 compliance)
- [ ] T110: Testes de smoke (pré-flight) automatizados
- [ ] T111: Validação de idempotência (re-execução sem efeitos colaterais)
- [ ] T112: Documentação final de cada skill (README padronizado)
- [ ] T113: Atualizar ESTADO_ORQUESTRATOR.md com resultado da auditoria

---

## Resumo de Progresso

| Epic | Skills | Status |
|------|--------|--------|
| E1–E4 | 7 | ✅ Concluído |
| E5 | 9 | ✅ Concluído |
| E6 | 11 | ✅ Concluído |
| E7 | 5 | ⏳ Em Progresso |
| E8–E22 | ~70 | ⏳ Aguardando |
| **Total** | **~102 skills** | **35 feitas / 67 pendentes** |
