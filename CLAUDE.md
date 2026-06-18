# CLAUDE.md

## O que é este repositório

Conjunto de **deploy skills** que transformam Claude CLI (e agentes compatíveis) em assistentes DevOps para instalação de stacks Docker Swarm no ecossistema Setup Orion.

Cada skill em `skills/<nome>/` é um script bash autocontido que instala uma solução via `docker stack deploy`. O assistente lê o `metadata.json`, coleta as entradas necessárias e executa o `run.sh`.

## Estrutura

```
skills/<nome>/
├── metadata.json   — contrato: depends_on, required_inputs, persistence_path
├── run.sh          — script de deploy (executável, idempotente)
└── README.md       — documentação humana
skills/00-core/
└── lib-persistence.sh  — salva dados em /root/dados_vps/<skill>.md
```

## Para usar como assistente DevOps

Invoque `/devops` — a skill em `.claude/skills/devops/` contém o guia completo com catálogo, fluxo de deploy e diagnóstico.

## ADRs

- `docs/adr/ADR-001.md` — Persistência em Markdown (`/root/dados_vps/`)
- `docs/adr/ADR-002.md` — Segurança de segredos (contexto efêmero)
- `docs/adr/ADR-003.md` — Padrão de Claude Code Skills neste projeto

## Roadmap

`ORCHESTRATOR-ROADMAP.md`
