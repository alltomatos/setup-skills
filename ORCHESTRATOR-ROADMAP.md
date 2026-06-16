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
- [ ] **E6: Skills de Aplicação — AI/LLM** [EM PROGRESSO] — Agentes, modelos, plataformas de IA
- [ ] **E7: Skills de Aplicação — WhatsApp/Messaging** — Gateways e bots
- [ ] **E8: Skills de Aplicação — CRM/Atendimento** — CRMs e plataformas de marketing
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

- **Fase Atual**: E6 (Skills de Aplicação — AI/LLM)
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
- [ ] T29: Skill `app-langflow`        — Langflow (builder visual de fluxos LLM)
- [ ] T30: Skill `app-anythingllm`     — AnythingLLM (RAG privado)
- [ ] T31: Skill `app-firecrawl`       — Firecrawl (web scraping para LLM)
- [ ] T32: Skill `app-zep`             — Zep (memória long-term para agentes)
- [ ] T33: Skill `app-evoai`           — EvoAI (plataforma de agentes)
- [ ] T34: Skill `app-omnitools`       — OmniTools (hub de ferramentas AI)
