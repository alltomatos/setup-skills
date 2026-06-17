---
description: |
  Audita todas as deploy skills do ecossistema Orion contra os 3 ADRs.
  Verifica: metadata.json completo, run.sh com lib-persistence.sh e save_data,
  README.md presente, sem segredos hardcoded. Use quando o usuário pedir
  "auditar skills", "revisar padrões" ou "verificar compliance".
disable-model-invocation: true
allowed-tools: Bash(find *) Read Grep
context: fork
agent: Explore
---

## Tarefa

Auditar todas as deploy skills em `/root/setup-skills/skills/` verificando conformidade com os ADRs.

### ADR-001 — Persistência em Markdown

- `run.sh` sourceia `../00-core/lib-persistence.sh`
- `run.sh` chama `save_data` ao final

### ADR-002 — Segurança de Segredos

- Sem segredos hardcoded em texto (senhas, tokens, chaves fixas)
- Segredos gerados via `openssl rand` ou lidos de variáveis de ambiente
- `grep -nE 'password\s*=\s*["\'][^$]' run.sh` deve estar vazio ou apenas comentarios

### ADR-003 — Estrutura de Skill

- `metadata.json` com: name, description, depends_on, required_inputs, persistence_path
- `README.md` presente
- `run.sh` presente e executável

### Checklist Executável

```
!`python3 << 'EOF'
import os, json

SKILLS = "/root/setup-skills/skills"
results = []

for name in sorted(os.listdir(SKILLS)):
    path = os.path.join(SKILLS, name)
    if not os.path.isdir(path):
        continue

    r = {"skill": name}
    r["has_readme"]   = os.path.exists(os.path.join(path, "README.md"))
    r["has_metadata"] = os.path.exists(os.path.join(path, "metadata.json"))
    r["has_runs"]     = os.path.exists(os.path.join(path, "run.sh"))

    if r["has_runs"]:
        with open(os.path.join(path, "run.sh")) as f:
            c = f.read()
        r["has_lib"]  = "lib-persistence" in c
        r["has_save"] = "save_data" in c
    else:
        r["has_lib"] = r["has_save"] = False

    results.append(r)

ok   = [r for r in results if r["has_readme"] and r["has_metadata"] and r["has_runs"] and r["has_lib"] and r["has_save"]]
warn = [r for r in results if not (r["has_readme"] and r["has_metadata"] and r["has_runs"] and r["has_lib"] and r["has_save"])]

print(f"Total de skills : {len(results)}")
print(f"Conformidade OK : {len(ok)}")
print(f"Com gaps        : {len(warn)}")
print()

if warn:
    print("=== GAPS ENCONTRADOS ===")
    for r in warn:
        issues = []
        if not r["has_readme"]:  issues.append("sem README")
        if not r["has_metadata"]: issues.append("sem metadata.json")
        if not r["has_runs"]:    issues.append("sem run.sh")
        if not r["has_lib"]:     issues.append("sem lib-persistence")
        if not r["has_save"]:    issues.append("sem save_data")
        print(f"  {r['skill']:30s} -> {', '.join(issues)}")
EOF
`
```

## Resultado Esperado

Retornar relatório estruturado:
1. Total de skills auditadas
2. Skills em conformidade completa
3. Skills com gaps (listar por skill + problema específico)
4. Classificação: P1 (impede conformance) / P2 (consistência) / P3 (melhoria)