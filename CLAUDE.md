# CLAUDE.md

## Governança do Projeto
- **Orquestrador**: Ativo
- **Infraestrutura**: `.claude/config.json`, `.claude/context7.json`
- **Roadmap**: `ORCHESTRATOR-ROADMAP.md`
- **ADRs**: `docs/adr/` (ADR-001, ADR-002, ADR-003)

---

## Glossário de "Skills" neste projeto

> ⚠️ Este projeto usa o termo "skill" em dois sentidos distintos. Não confundir.

| Tipo | Localização | O que é |
|------|-------------|---------|
| **Deploy Skill** | `skills/<nome>/` | Script bash (`run.sh`) que instala uma stack Docker Swarm. Unidade de deploy do ecossistema Orion. |
| **Claude Code Skill** | `.claude/skills/<nome>/SKILL.md` | Arquivo markdown com frontmatter YAML que ensina Claude a executar um procedimento. Invocável via `/nome`. |

---

## Deploy Skills (scripts de deploy)

Cada skill de deploy contém obrigatoriamente:
- `metadata.json` — contrato declarativo (nome, depends_on, required_inputs, persistence_path)
- `run.sh` — script bash executável, carrega `00-core/lib-persistence.sh`
- `README.md` — documentação humana

**Convenções**:
- Prefixo `infra-` para infraestrutura (bancos, filas, storage)
- Prefixo `app-` para aplicações
- Persistência em `/root/dados_vps/<skill>.md` via `save_data()` (ADR-001)
- Zero segredos em arquivos ou logs (ADR-002)

---

## Claude Code Skills (skills de procedimento)

Ficam em `.claude/skills/<nome>/SKILL.md`. Seguem o padrão [Agent Skills](https://agentskills.io).
Ver **ADR-003** para convenções completas.

**Quando criar uma Claude Code Skill**:
- Procedimento repetido que hoje é colado no chat
- Fluxo de auditoria, validação ou diagnóstico das deploy skills
- Orquestração de múltiplas deploy skills em sequência

**Frontmatter obrigatório mínimo**:
```yaml
---
description: O que faz e quando usar. Caso de uso principal PRIMEIRO (cap 1536 chars).
disable-model-invocation: true   # para skills com side-effects
---
```

**Injeção dinâmica** (rodar antes de Claude ver o conteúdo):
```markdown
!`cat /root/dados_vps/traefik.md`
```

---

## Regras de Desenvolvimento

1. **Rigor de Código**: Edições atômicas, zero pseudocódigo.
2. **Segurança**: Shift-left — sem tokens, senhas ou chaves no git (ADR-002).
3. **Qualidade**: Testes em tudo (unitário + security). E23 cobre auditoria.
4. **Governança**: Uso estrito das skills e diretrizes do Orquestrador.
5. **Sem duplicatas**: Antes de criar nova deploy skill ou Claude Code Skill, verificar se já existe.
6. **Context7**: Usar `mcp_context7_resolve_library_id` + `mcp_context7_query_docs` antes de propor dependências externas.
