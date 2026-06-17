---
description: |
  Assistente DevOps para deploy de stacks Docker Swarm no ecossistema Orion.
  Use quando o usuário pedir para instalar, configurar ou fazer deploy de qualquer
  aplicação, banco de dados ou serviço de infraestrutura. Também cobre diagnóstico
  de stacks existentes, verificação de pré-requisitos e orientação sobre dependências.
  Argumento opcional: nome da skill para ir direto ao deploy (ex: /devops nocobase).
argument-hint: [nome-da-skill ou vazio para menu interativo]
disable-model-invocation: true
allowed-tools: Bash(bash *) Bash(cat *) Bash(ls *) Bash(find *) Bash(docker *) Bash(python3 *) Read
---

## Instruções para o assistente (não exibir ao usuário)

Você é um assistente DevOps do ecossistema Orion. Ao ser invocado:

1. **Se `$ARGUMENTS` estiver vazio** → exiba o menu categorizado abaixo e aguarde escolha do usuário.
2. **Se `$ARGUMENTS` tiver um nome** → pule o menu e vá direto ao fluxo de deploy para aquela skill.
3. **Após escolha** → leia o `metadata.json` da skill, resolva `depends_on` e siga o fluxo de deploy.

### Regras inegociáveis

- Nunca execute `run.sh` sem ter coletado TODAS as `required_inputs` primeiro.
- Inputs com `"type": "password"` → colete via chat, nunca exiba de volta, nunca logue.
- Sempre resolva `depends_on` antes da skill alvo (verifique `/root/dados_vps/`).
- Redes overlay: leia `/root/dados_vps/traefik.md` para obter o nome da rede.
- Segredos são efêmeros — conforme ADR-002, nunca persistir em arquivos ou logs.

---

## Estado atual do ecossistema

```
!`python3 -c "
import os

DADOS   = '/root/dados_vps'
SKILLS  = '/root/setup-skills/skills'

if os.path.isdir(DADOS):
    installed = set(f.replace('.md','') for f in os.listdir(DADOS) if f.endswith('.md'))
else:
    installed = set()

all_skills = sorted(d for d in os.listdir(SKILLS) if d != '00-core' and os.path.isdir(os.path.join(SKILLS, d)))
ok   = [s for s in all_skills if s in installed]
pend = [s for s in all_skills if s not in installed]

print(f'Instaladas : {len(ok)}')
print(f'Pendentes  : {len(pend)}')
print(f'Total      : {len(all_skills)}')
" 2>/dev/null || echo "Servidor nao conectado"`
```

---

## ╔══════════════════════════════════════════════════════════════╗
## ║              ORION DEVOPS — Catálogo de Deploy               ║
## ╚══════════════════════════════════════════════════════════════╝

```
!`python3 << 'PYEOF'
import os

SKILLS_DIR = '/root/setup-skills/skills'
DADOS_DIR  = '/root/dados_vps'

def is_installed(name):
    if not os.path.isdir(DADOS_DIR):
        return False
    return os.path.exists(f'{DADOS_DIR}/{name}.md') or \
           os.path.exists(f'{DADOS_DIR}/{name.replace("app-","").replace("infra-","")}.md')

def icon(name):
    return '✅' if is_installed(name) else '⬜'

def row(num, name, label, deps=''):
    i = icon(name)
    dep_str = f'  ← {deps}' if deps else ''
    return f'  [{num:>3}] {i} {label:<40}{dep_str}'

# E1-E4: Base
BASE = [
    (' 0', 'infra-bootstrap',  'Bootstrap do Servidor',         ''),
    (' 1', 'app-traefik',      'Traefik + SSL + Portainer',     'bootstrap'),
]
# E5: Dados
DATA = [
    (' 2', 'infra-postgres',   'PostgreSQL 14',                 ''),
    (' 3', 'infra-pgvector',   'PostgreSQL + pgvector (AI/RAG)','postgres'),
    (' 4', 'infra-redis',      'Redis 7 (cache / pub-sub)',     ''),
    (' 5', 'infra-mysql',      'MySQL 8.0',                     ''),
    (' 6', 'infra-mongodb',    'MongoDB 6.0',                   ''),
    (' 7', 'infra-rabbitmq',   'RabbitMQ + Management UI',      ''),
    (' 8', 'infra-kafka',      'Apache Kafka (KRaft)',          ''),
    (' 9', 'infra-clickhouse', 'ClickHouse (analytics OLAP)',   ''),
    ('10', 'infra-qdrant',     'Qdrant (vector search)',        ''),
]
# E6: AI/LLM
AI = [
    ('11', 'app-ollama',       'Ollama (modelos locais LLM)',    ''),
    ('12', 'app-openwebui',    'Open WebUI (frontend Ollama)',  'ollama'),
    ('13', 'app-flowise',      'Flowise (orquestrador LLM)',    'postgres'),
    ('14', 'app-langflow',     'Langflow (builder visual LLM)', ''),
    ('15', 'app-langfuse',     'Langfuse (observabilidade LLM)','postgres'),
    ('16', 'app-dify',         'Dify (plataforma LLM + RAG)',   'postgres, redis'),
    ('17', 'app-anythingllm',  'AnythingLLM (RAG privado)',     ''),
    ('18', 'app-firecrawl',    'Firecrawl (web scraping LLM)',  'redis'),
    ('19', 'app-zep',          'Zep (memória long-term agentes)','pgvector'),
    ('20', 'app-evoai',        'EvoAI (plataforma de agentes)', 'postgres'),
    ('21', 'app-omnitools',    'OmniTools (hub ferramentas AI)',''),
]
# E7: WhatsApp
WA = [
    ('22', 'app-evolution',    'Evolution API (WhatsApp)',      ''),
    ('23', 'app-unoapi',       'UnoAPI (gateway Baileys)',       'minio, rabbitmq'),
    ('24', 'app-quepasa',      'QuePasa (gateway WhatsApp)',     'postgres'),
    ('25', 'app-wuzapi',       'WuzAPI (gateway leve)',          'postgres'),
    ('26', 'app-wppconnect',   'WPPConnect (gateway robusto)',  ''),
    ('27', 'app-transcrevezap','TranscreveZap (transcrição)',    ''),
]
# E8: CRM
CRM = [
    ('28', 'app-chatwoot',     'Chatwoot (omnichannel)',         'pgvector'),
    ('29', 'app-woofed',       'WoofedCRM (CRM WhatsApp)',       'pgvector, redis'),
    ('30', 'app-krayincrm',    'Krayin CRM',                     ''),
    ('31', 'app-twentycrm',    'Twenty CRM',                     ''),
    ('32', 'app-evocrm',       'EvoCRM (CRM + AI)',              'pgvector'),
    ('33', 'app-mautic',       'Mautic (automação marketing)',   'postgres'),
]
# E9: Low-code/CMS
CMS = [
    ('34', 'app-strapi',       'Strapi (headless CMS)',          'postgres'),
    ('35', 'app-directus',     'Directus (headless CMS + BaaS)', 'postgres, redis, minio'),
    ('36', 'app-nocobase',     'NocoBase (no-code BaaS)',        'postgres'),
    ('37', 'app-nocodb',       'NocoDB (Airtable open-source)',  'postgres'),
    ('38', 'app-baserow',      'Baserow (no-code DB)',           'postgres'),
    ('39', 'app-tooljet',      'ToolJet (low-code internal tools)','postgres'),
    ('40', 'app-lowcoder',     'Lowcoder (low-code apps)',       'postgres'),
    ('41', 'app-appsmith',     'Appsmith (low-code internal tools)','postgres'),
]
# E10: Produtividade
COLLAB = [
    ('42', 'app-nextcloud',    'Nextcloud (armazenamento)',      ''),
    ('43', 'app-outline',      'Outline (wiki/knowledge base)',  ''),
    ('44', 'app-mattermost',   'Mattermost (chat team)',         ''),
    ('45', 'app-docmost',      'Docmost (docs colaborativo)',    ''),
    ('46', 'app-wiki',         'Wiki.js (wiki moderna)',         ''),
    ('47', 'app-affine',       'AFFiNE (Notion open-source)',    ''),
    ('48', 'app-jitsi',        'Jitsi Meet (videoconferência)',  ''),
    ('49', 'app-hoppscotch',   'Hoppscotch (API client)',        ''),
    ('50', 'app-excalidraw',   'Excalidraw (diagramas collab)',  ''),
]
# E11: Docs/PDF
DOCS = [
    ('51', 'app-documenso',    'Documenso (assinatura digital)', ''),
    ('52', 'app-docuseal',     'DocuSeal (assinatura digital)',  ''),
    ('53', 'app-stirlingpdf',  'Stirling PDF (manipulação PDF)', ''),
    ('54', 'app-gotenberg',    'Gotenberg (API PDF)',            ''),
    ('55', 'app-opensign',     'OpenSign (assinatura digital)',  ''),
]
# E12: Segurança
SEC = [
    ('56', 'app-vaultwarden',  'Vaultwarden (cofre senhas)',     ''),
    ('57', 'app-keycloak',     'Keycloak (SSO/IAM)',             ''),
    ('58', 'app-authentik',    'Authentik (SSO/IAM)',            ''),
    ('59', 'app-passbolt',     'Passbolt (cofre senhas team)',   ''),
]
# E13: Monitoramento
MON = [
    ('60', 'app-uptimekuma',   'Uptime Kuma (monitoramento)',    ''),
    ('61', 'app-monitor',      'Stack Prometheus + Grafana',     ''),
    ('62', 'app-checkmate',    'Checkmate (monitoramento)',      ''),
    ('63', 'app-netbox',       'NetBox (inventário rede)',       ''),
]
# E14-E22: Diversos
MISC = [
    ('64', 'app-metabase',     'Metabase (BI dashboards)',       'postgres'),
    ('65', 'app-wordpress',    'WordPress (CMS/blog)',           ''),
    ('66', 'app-calcom',       'Cal.com (agendamento)',          'postgres'),
    ('67', 'app-odoo',         'Odoo (ERP completo)',            'postgres'),
    ('68', 'app-frappe',       'Frappe/ERPNext (ERP)',           'postgres'),
    ('69', 'app-glpi',         'GLPI (helpdesk/ITSM)',           'postgres'),
    ('70', 'app-openproject',  'OpenProject (gestão projetos)',  'postgres'),
    ('71', 'app-planka',       'Planka (kanban Trello-like)',    'postgres'),
    ('72', 'app-supabase',     'Supabase (BaaS + auth + storage)',''),
    ('73', 'app-code-server',  'Code Server (VSCode no browser)',''),
    ('74', 'app-rustdesk',     'RustDesk (remote desktop)',      ''),
    ('75', 'app-azuracast',    'AzuraCast (rádio web)',          ''),
    ('76', 'app-ntfy',         'ntfy (notificações push)',       ''),
    ('77', 'app-formbricks',   'Formbricks (surveys)',           'postgres'),
    ('78', 'app-activepieces', 'Activepieces (automação)',       ''),
    ('79', 'app-botpress',     'Botpress (chatbot platform)',    ''),
]

def section(title, items):
    print('+-' + '-'*75 + '-+')
    print(f'|  {title}')
    print('+-' + '-'*75 + '-+')
    for item in items:
        print(row(*item))
    print()

sections = [
    ('E1-E4  BASE / INFRAESTRUTURA',         BASE),
    ('E5     DADOS / BANCO / FILAS',          DATA),
    ('E6     AI / LLM / ORQUESTRAÇÃO',        AI),
    ('E7     WHATSAPP / MENSAGERIA',          WA),
    ('E8     CRM / ATENDIMENTO',              CRM),
    ('E9     LOW-CODE / CMS',                 CMS),
    ('E10    PRODUTIVIDADE / COLABORAÇÃO',    COLLAB),
    ('E11    DOCS / PDF / ASSINATURA',        DOCS),
    ('E12    SEGURANÇA / AUTENTICAÇÃO',       SEC),
    ('E13    MONITORAMENTO',                  MON),
    ('E14-E22 UTILITÁRIOS / DIVERSOS',        MISC),
]

print()
for title, items in sections:
    section(title, items)

print('  ✅ = já instalado   ⬜ = disponível para instalar')
print()
print('  Digite o número, nome da skill ou categoria para instalar.')
print('  Ex: "36"  ou  "nocobase"  ou  "instalar calcom"')
print('  Para diagnóstico: "/diagnose-stack <nome>"')
print('  Para status: "/status-ecossistema"')
print('  Para auditar: "/audit-skills"')
PYEOF
`
```

---

## Fluxo de deploy (após escolha do usuário)

```
1. Ler metadata.json da skill escolhida
   → cat /root/setup-skills/skills/<nome>/metadata.json

2. Verificar e instalar depends_on pendentes
   → ls /root/dados_vps/*.md | grep <dep>

3. Coletar required_inputs NÃO sensitive (todos de uma vez)
   → perguntar domínio, email, host SMTP, etc.

4. Coletar required_inputs sensitive (UM A UM, sem eco)
   → senha: "Senha recebida ✓" (não repetir o valor)

5. Exportar variáveis e executar
   → bash /root/setup-skills/skills/<nome>/run.sh

6. Verificar resultado
   → docker service ls | grep <nome>

7. Confirmar persistência
   → cat /root/dados_vps/<nome>.md
```

## Diagnóstico rápido

- Status das stacks: `/status-ecossistema`
- Debug de stack: `/diagnose-stack <nome>`
- Auditoria de conformance: `/audit-skills`