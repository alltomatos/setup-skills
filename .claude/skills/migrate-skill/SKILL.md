---
description: |
  Migra uma deploy skill do formato antigo (setup-orion.sh) para o padrão
  Orion Skills (metadata.json + run.sh + README.md). Extrai configuração do
  bloco de função no SetupOrion.md, gera os 3 arquivos padronizados e valida
  conformidade ADR. Use quando o usuário pedir "migrar skill X" ou
  "converter para skill".
argument-hint: nome-da-ferramenta (ex: nocobase, baserow, calcom)
disable-model-invocation: true
allowed-tools: Bash(read *) Read Write
---

## Fluxo de Migração

### 1. Localizar a função no SetupOrion.md

```
!`grep -n "ferramenta_$ARGUMENTS\b" /root/setup-skills/docs/SetupOrion.md 2>/dev/null | head -5`
```

### 2. Extrair o bloco YAML da função

Ler as linhas correspondentes no SetupOrion.md. Identificar:
- **Imagem Docker** (`image:`)
- **Variáveis de ambiente** (`environment:`)
- **Labels Traefik** (`traefik.http.*`)
- **Volumes** (`volumes:`)
- **Recursos** (`cpus`, `memory`)
- **Secrets inputs** (variações de `read -s` para senha)

### 3. Identificar inputs e dependências

Do bloco de perguntas (`read -r`):
- Tipo `password` → `required_inputs` com `type: "password"`
- Tipo texto → `type: "text"`
- Dependências implícitas: Postgres = `infra-postgres`, Redis = `infra-redis`, Traefik = `app-traefik`

### 4. Gerar os 3 arquivos

**metadata.json**:
```json
{
  "name": "app-$ARGUMENTS",
  "description": "Instala o $ARGUMENTS via Docker Swarm.",
  "depends_on": ["infra-bootstrap", "app-traefik"],
  "required_inputs": [...],
  "persistence_path": "/root/dados_vps/app-$ARGUMENTS.md"
}
```

**run.sh**: Template padrão com `lib-persistence.sh`, `save_data`, YAML com traefik.

**README.md**: 4 seções — Funcionalidades, Dependências, Inputs, Observações.

### 5. Validar

Após criar os 3 arquivos, verificar:
1. `bash -n run.sh` → sem erros de sintaxe
2. `grep -c "lib-persistence" run.sh` → 1+
3. `grep -c "save_data" run.sh` → 1+
4. `grep "hardcoded_password" run.sh` → deve estar vazio

### 6. Registrar no roadmap

Atualizar `ORCHESTRATOR-ROADMAP.md` marcando a task como concluída.