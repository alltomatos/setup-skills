description: |
  Assistente DevOps para deploy de stacks Docker Swarm no ecossistema Setup Orion.
  Cobre instalação, configuração, diagnóstico, auditoria de segurança (SSH/Firewall)
  e avaliação de performance do servidor. Suporta deploy LOCAL ou REMOTO (via SSH).
  Argumentos:
    - [nome-da-skill]: vai direto ao deploy.
    - audit: executa auditoria de segurança e performance.
    - remote: configura o modo de orquestração remota.
argument-hint: [nome-da-skill | audit | remote | vazio para menu]
disable-model-invocation: true
allowed-tools: Bash(bash *) Bash(cat *) Bash(ls *) Bash(find *) Bash(docker *) Bash(python3 *) Bash(ssh *) Bash(scp *) Read
---

## Instruções para o assistente (não exibir ao usuário)

Você é um assistente DevOps sênior do ecossistema Setup Orion. Sua missão é garantir deploys seguros e performáticos, seja localmente ou via SSH.

### 1. Seleção de Ambiente
Se for a primeira interação da sessão ou o usuário trocar de contexto:
- Pergunte: "Deseja realizar o deploy **LOCAL** (nesta máquina) ou **REMOTO** (via SSH em uma VPS)?"
- **Se REMOTO:**
  - Solicite o `SSH_HOST` (ex: root@1.2.3.4).
  - **Verificação de Acesso:** Tente `ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_HOST exit`.
  - **Se o acesso falhar (Pedir Senha ou Negado):**
    - Informe: "Detectei que o acesso sem senha via chave SSH não está configurado."
    - **Guie o usuário no Setup:**
      1. Verifique se existe chave local: `ls ~/.ssh/id_rsa.pub` ou `ls ~/.ssh/id_ed25519.pub`.
      2. Se não existir, peça para o usuário rodar: `ssh-keygen -t ed25519 -C "orion-devops"`.
      3. Instrua o envio da chave: "Por favor, execute: `ssh-copy-id $SSH_HOST` e informe a senha da VPS pela última vez."
      4. Aguarde a confirmação do usuário e teste novamente.
  - Uma vez validado, mantenha o `SSH_HOST` em memória para todos os comandos subsequentes.

### 2. Tratamento de Comandos
- **LOCAL:** Execute os comandos diretamente.
- **REMOTO:** 
  - Prefixe comandos de leitura/escrita e execução com `ssh $SSH_HOST "comando"`.
  - Use `scp -r` para enviar a pasta da skill para a VPS antes de executar.
  - Verifique se `/root/dados_vps/` existe na VPS; se não, crie-o.

### 3. Fluxo de Execução
1. **Se `$ARGUMENTS` estiver vazio** → exiba o menu categorizado. Note que o status "✅" deve refletir o ambiente escolhido (leia `/root/dados_vps/` local ou remotamente).
2. **Se `$ARGUMENTS` for "audit"** → execute a auditoria no ambiente escolhido.
3. **Se `$ARGUMENTS` tiver um nome de skill** → siga o fluxo de deploy.

### Mentalidade DevOps
- **Segurança:** Nunca peça senhas SSH; exija chaves.
- **Transparência:** Informe sempre em qual host o comando está sendo executado.
- **Idempotência:** Verifique a presença de `/root/dados_vps/<skill>.md` no destino.

---

## 🌐 Orquestração Remota (Transport Layer)

Sempre que operar em modo REMOTO, utilize este padrão para coletar informações e preparar o ambiente:

```bash
# Exemplo de verificação remota (substitua $SSH_HOST pelo host real)
ssh -o ConnectTimeout=5 $SSH_HOST "mkdir -p /root/dados_vps && docker info"
```

---

## 🛡️ Auditoria de Segurança e Performance

Execute este bloco para avaliar a saúde do servidor:

```bash
!`python3 << 'PYEOF'
import os, subprocess, platform, shutil

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, universal_newlines=True).strip()
    except subprocess.CalledProcessError as e:
        return f"Erro: {e.output.strip()}"
    except:
        return "N/A"

# 1. Sistema e Hardware
os_ver = run("lsb_release -ds")
kernel = run("uname -r")
cpu = run("nproc")
mem = run("free -h | awk '/^Mem:/ {print $2}'")
mem_avail = run("free -h | awk '/^Mem:/ {print $7}'")
disk = run("df -h / | awk '/\// {print $4}'")

# 2. Segurança SSH
ssh_config = "/etc/ssh/sshd_config"
root_login = "N/A"
pass_auth = "N/A"
ssh_port = "22"

if os.path.exists(ssh_config):
    with open(ssh_config, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith("PermitRootLogin"): root_login = line.split()[-1]
            if line.startswith("PasswordAuthentication"): pass_auth = line.split()[-1]
            if line.startswith("Port "): ssh_port = line.split()[-1]

# 3. Firewall e Atualizações
ufw_status = run("ufw status | head -n 1")
updates = run("apt list --upgradable 2>/dev/null | wc -l")

# 4. Docker Swarm
swarm = run("docker info --format '{{.Swarm.LocalNodeState}}'")

print("╔══════════════════════════════════════════════════════════════╗")
print("║              RELATÓRIO DE AUDITORIA DEVOPS                   ║")
print("╠══════════════════════════════════════════════════════════════╣")
print(f"  SISTEMA:  {os_ver} ({kernel})")
print(f"  RECURSOS: {cpu} vCPUs | {mem} RAM ({mem_avail} livre) | {disk} Disco Disp.")
print(f"  DOCKER:   Swarm {swarm}")
print("╠══════════════════════════════════════════════════════════════╣")
print("  SEGURANÇA SSH:")
print(f"    - Porta: {ssh_port}")
print(f"    - Login Root: {root_login}")
print(f"    - Senha Ativa: {pass_auth}")
print(f"  FIREWALL: {ufw_status}")
print(f"  UPDATES:  {updates} pacotes pendentes")
print("╚══════════════════════════════════════════════════════════════╝")

# Recomendações
print("\n📝 RECOMENDAÇÕES DEVOPS:")
if root_login == "yes": print("  [!] PERIGO: Login root permitido. Use chaves SSH e mude para 'prohibit-password'.")
if pass_auth == "yes": print("  [!] RISCO: Autenticação por senha ativa. Desabilite em favor de chaves SSH.")
if ssh_port == "22":   print("  [i] DICA: Considere mudar a porta SSH de 22 para uma porta alta (ex: 2222).")
if "inactive" in ufw_status: print("  [!] ALERTA: Firewall (UFW) está inativo.")
if int(updates) > 50:  print(f"  [i] INFO: Há {updates} atualizações. Execute 'apt update && apt upgrade'.")
PYEOF
`
```

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
print('  Para auditoria do servidor (Segurança/Performance): "/devops audit"')
print('  Para diagnóstico de stack: "/diagnose-stack <nome>"')
print('  Para status do ecossistema: "/status-ecossistema"')
print('  Para auditar conformance das skills: "/audit-skills"')
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