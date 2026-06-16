---
description: |
  Assistente DevOps para deploy de stacks Docker Swarm no ecossistema Orion.
  Use quando o usuário pedir para instalar, configurar ou fazer deploy de qualquer
  aplicação, banco de dados ou serviço de infraestrutura. Também cobre diagnóstico
  de stacks existentes, verificação de pré-requisitos e orientação sobre dependências.
  Argumento opcional: nome da skill para ir direto ao deploy (ex: /devops chatwoot).
argument-hint: [nome-da-skill ou vazio para menu]
allowed-tools: Bash(bash *) Bash(cat *) Bash(ls *) Bash(find *) Bash(docker *) Bash(python3 *) Read
---

## Instruções para o assistente (não exibir ao usuário)

Você é um assistente DevOps do ecossistema Orion. Ao ser invocado:

1. **Se `$ARGUMENTS` estiver vazio** → exiba o menu abaixo e aguarde o usuário escolher.
2. **Se `$ARGUMENTS` tiver um nome** → pule o menu e vá direto ao fluxo de deploy para aquela skill.
3. **Após escolha do usuário** → leia o `metadata.json` da skill escolhida, resolva dependências e siga o fluxo de deploy.

Regras inegociáveis:
- Nunca execute `run.sh` sem ter coletado TODAS as `required_inputs` primeiro.
- Variáveis com `"sensitive": true` → colete via chat, nunca exiba de volta, nunca logue.
- Sempre resolva `depends_on` antes da skill alvo (verifique `/root/dados_vps/`).
- Redes overlay: leia `/root/dados_vps/traefik.md` antes de perguntar ao usuário.

---

## Estado atual do servidor

```
!`python3 -c "
import os, json, glob

dados = set(f.replace('.md','') for f in os.listdir('/root/dados_vps') if f.endswith('.md')) if os.path.isdir('/root/dados_vps') else set()

skills_dir = '/root/setup-skills/skills'
skills = sorted(d for d in os.listdir(skills_dir) if d != '00-core' and os.path.isdir(os.path.join(skills_dir, d)))

installed = [s for s in skills if s in dados or s.replace('app-','').replace('infra-','') in dados]
pending   = [s for s in skills if s not in installed]

print(f'Skills instaladas : {len(installed)}')
print(f'Skills disponíveis: {len(pending)}')
print(f'Total no catálogo : {len(skills)}')
" 2>/dev/null || echo "Ambiente local — servidor não conectado"`
```

---

## ╔══════════════════════════════════════════════╗
## ║        ORION DEVOPS — Menu de Deploy        ║
## ╚══════════════════════════════════════════════╝

```
!`python3 << 'PYEOF'
import os, json, glob

SKILLS_DIR = '/root/setup-skills/skills'
DADOS_DIR  = '/root/dados_vps'

def is_installed(name):
    if not os.path.isdir(DADOS_DIR):
        return False
    slug = name.replace('app-', '').replace('infra-', '')
    return (
        os.path.exists(f'{DADOS_DIR}/{name}.md') or
        os.path.exists(f'{DADOS_DIR}/{slug}.md')
    )

def icon(name):
    return '✅' if is_installed(name) else '⬜'

def row(num, name, label, deps=''):
    i = icon(name)
    dep_str = f'  ← requer: {deps}' if deps else ''
    return f'  [{num:>2}] {i} {label:<38}{dep_str}'

print('┌─────────────────────────────────────────────────────────────────────┐')
print('│  🏗️  INFRAESTRUTURA BASE                                             │')
print('├─────────────────────────────────────────────────────────────────────┤')
print(row(' 0', 'infra-bootstrap', 'Bootstrap do Servidor'))
print(row(' 1', 'app-traefik',     'Traefik + Portainer (proxy + SSL)', 'bootstrap'))
print('├─────────────────────────────────────────────────────────────────────┤')
print('│  🗄️  BANCOS DE DADOS                                                 │')
print('├─────────────────────────────────────────────────────────────────────┤')
print(row(' 2', 'infra-postgres',  'PostgreSQL 14'))
print(row(' 3', 'infra-pgvector',  'PostgreSQL 14 + pgvector (AI/RAG)'))
print(row(' 4', 'infra-redis',     'Redis 7 (cache / pub-sub)'))
print(row(' 5', 'infra-mysql',     'MySQL 8.0'))
print(row(' 6', 'infra-mongodb',   'MongoDB 6.0'))
print(row(' 7', 'infra-rabbitmq',  'RabbitMQ + Management UI'))
print(row(' 8', 'infra-kafka',     'Apache Kafka (KRaft mode)'))
print(row(' 9', 'infra-clickhouse','ClickHouse (analytics OLAP)'))
print(row('10', 'infra-qdrant',    'Qdrant (busca vetorial)'))
print('├─────────────────────────────────────────────────────────────────────┤')
print('│  💬 WHATSAPP / MENSAGERIA                                            │')
print('├─────────────────────────────────────────────────────────────────────┤')
print(row('11', 'app-evolution',   'Evolution API (WhatsApp Business)'))
print(row('12', 'app-unoapi',      'UnoAPI (gateway Baileys)',      'minio, rabbitmq'))
print(row('13', 'app-quepasa',     'QuePasa (gateway WhatsApp)',    'postgres'))
print(row('14', 'app-wuzapi',      'WuzAPI (gateway leve)',         'postgres'))
print(row('15', 'app-wppconnect',  'WPPConnect (gateway robusto)'))
print(row('16', 'app-transcrevezap','TranscreveZap (transcrição áudio)'))
print('├─────────────────────────────────────────────────────────────────────┤')
print('│  🤖 INTELIGÊNCIA ARTIFICIAL / LLM                                    │')
print('├─────────────────────────────────────────────────────────────────────┤')
print(row('17', 'app-ollama',      'Ollama (modelos locais LLM)'))
print(row('18', 'app-openwebui',   'Open WebUI (frontend Ollama)',  'ollama'))
print(row('19', 'app-flowise',     'Flowise (orquestração LLM)',    'postgres'))
print(row('20', 'app-langflow',    'Langflow (builder visual LLM)'))
print(row('21', 'app-langfuse',    'Langfuse (observabilidade LLM)','postgres'))
print(row('22', 'app-dify',        'Dify (plataforma LLM + RAG)',   'postgres, redis'))
print(row('23', 'app-anythingllm', 'AnythingLLM (RAG privado)'))
print(row('24', 'app-firecrawl',   'Firecrawl (web scraping → LLM)','redis'))
print(row('25', 'app-zep',         'Zep (memória long-term agentes)','pgvector'))
print(row('26', 'app-evoai',       'EvoAI (plataforma de agentes)', 'postgres'))
print(row('27', 'app-omnitools',   'OmniTools (hub ferramentas AI)'))
print('├─────────────────────────────────────────────────────────────────────┤')
print('│  🎯 ATENDIMENTO / CRM                                                │')
print('├─────────────────────────────────────────────────────────────────────┤')
print(row('28', 'app-chatwoot',    'Chatwoot (omnichannel)',         'pgvector'))
print(row('29', 'app-woofed',      'WoofedCRM (CRM WhatsApp)',       'pgvector, redis'))
print(row('30', 'app-krayincrm',   'Krayin CRM (Laravel open-source)'))
print(row('31', 'app-twentycrm',   'Twenty CRM (CRM moderno)'))
print(row('32', 'app-evocrm',      'EvoCRM (CRM + AI microservices)','pgvector'))
print('├─────────────────────────────────────────────────────────────────────┤')
print('│  ⚙️  AUTOMAÇÃO / LOW-CODE                                            │')
print('├─────────────────────────────────────────────────────────────────────┤')
print(row('33', 'app-n8n',         'N8N (automação queue mode)',     'postgres, redis'))
print(row('34', 'app-typebot',     'Typebot (chatbot builder)'))
print('├─────────────────────────────────────────────────────────────────────┤')
print('│  💾 STORAGE                                                          │')
print('├─────────────────────────────────────────────────────────────────────┤')
print(row('35', 'app-minio',       'MinIO (object storage S3)'))
print('└─────────────────────────────────────────────────────────────────────┘')
print()
print('  ✅ = já instalado   ⬜ = disponível para instalar')
print()
print('  Digite o número ou o nome da skill para instalar.')
print('  Ex: "2"  ou  "postgres"  ou  "instalar chatwoot"')
print('  Para diagnóstico do servidor: "status" ou "ver stacks"')
PYEOF
`
```

---

## Fluxo de deploy (executar após escolha do usuário)

```
1. Ler metadata.json da skill escolhida
2. Verificar depends_on → instalar pendentes primeiro
3. Coletar required_inputs NÃO sensitive do usuário (todos de uma vez)
4. Solicitar required_inputs sensitive UM A UM
5. Exportar variáveis e executar: bash /root/setup-skills/skills/<nome>/run.sh
6. Verificar resultado: docker service ls | grep <nome>
7. Mostrar dados persistidos: cat /root/dados_vps/<nome>.md
```

## Diagnóstico (quando usuário pedir "status" ou "ver stacks")

```bash
docker service ls 2>/dev/null || echo "Swarm não disponível"
```
```bash
cat /root/dados_vps/*.md 2>/dev/null || echo "Nenhuma skill instalada"
```
