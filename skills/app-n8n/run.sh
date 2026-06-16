#!/bin/bash
# =============================================================================
# skills/app-n8n/run.sh
# Skill: Deploy do N8N (modo queue) via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias (injetadas pelo Claude como variáveis de ambiente):
#   URL_N8N            — domínio do editor (ex: n8n.seudominio.com.br)
#   URL_WEBHOOK_N8N    — domínio do webhook (ex: webhook.seudominio.com.br)
#   SENHA_POSTGRES     — senha do PostgreSQL externo (SENSÍVEL)
#   EMAIL_SMTP_N8N     — email remetente SMTP
#   USER_SMTP_N8N      — usuário SMTP
#   SENHA_SMTP_N8N     — senha SMTP (SENSÍVEL)
#   HOST_SMTP_N8N      — host SMTP (ex: smtp.hostinger.com)
#   PORTA_SMTP_N8N     — porta SMTP (ex: 465)
#   NOME_REDE_INTERNA  — nome da rede overlay Docker
#
# Padrão de persistência:
#   /root/dados_vps/n8n.md   — metadados do deploy (sem senhas)
#   /root/n8n.yaml           — stack Docker Swarm
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores padrão Orion Design
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
vermelho="\e[91m"
reset="\e[0m"

ERRORS=0

# =============================================================================
# VALIDAÇÃO DE ENTRADAS
# =============================================================================
validate_inputs() {
    local missing=0

    [ -z "${URL_N8N:-}" ]            && echo -e "${vermelho}[ERRO] URL_N8N não informado.${reset}"            && missing=1
    [ -z "${URL_WEBHOOK_N8N:-}" ]    && echo -e "${vermelho}[ERRO] URL_WEBHOOK_N8N não informado.${reset}"    && missing=1
    [ -z "${SENHA_POSTGRES:-}" ]     && echo -e "${vermelho}[ERRO] SENHA_POSTGRES não informado.${reset}"     && missing=1
    [ -z "${EMAIL_SMTP_N8N:-}" ]     && echo -e "${vermelho}[ERRO] EMAIL_SMTP_N8N não informado.${reset}"     && missing=1
    [ -z "${USER_SMTP_N8N:-}" ]      && echo -e "${vermelho}[ERRO] USER_SMTP_N8N não informado.${reset}"      && missing=1
    [ -z "${SENHA_SMTP_N8N:-}" ]     && echo -e "${vermelho}[ERRO] SENHA_SMTP_N8N não informado.${reset}"     && missing=1
    [ -z "${HOST_SMTP_N8N:-}" ]      && echo -e "${vermelho}[ERRO] HOST_SMTP_N8N não informado.${reset}"      && missing=1
    [ -z "${PORTA_SMTP_N8N:-}" ]     && echo -e "${vermelho}[ERRO] PORTA_SMTP_N8N não informado.${reset}"     && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ]  && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}"  && missing=1

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo -e "${amarelo}Uso: URL_N8N=x URL_WEBHOOK_N8N=y SENHA_POSTGRES=z ... ./run.sh${reset}"
        exit 1
    fi
}

# =============================================================================
# GERAR ENCRYPTION KEY
# =============================================================================
generate_encryption_key() {
    echo -e "${amarelo}[1/5] Gerando N8N_ENCRYPTION_KEY...${reset}"

    N8N_ENCRYPTION_KEY="$(openssl rand -hex 16)"

    echo -e "${verde}      Encryption key gerada.${reset}"
}

# =============================================================================
# VOLUMES
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in n8n_data; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

# =============================================================================
# GERAÇÃO DO YAML (salvo em /root/n8n.yaml — padrão Orion)
# =============================================================================
generate_n8n_yaml() {
    echo -e "${amarelo}[3/5] Gerando /root/n8n.yaml...${reset}"

    cat > /root/n8n.yaml << YAML
version: "3.7"
services:

## --------------------------- ORION --------------------------- ##

  n8n_editor:
    image: n8nio/n8n:latest
    command: n8n start
    environment:
      - N8N_HOST=${URL_N8N}
      - N8N_EDITOR_BASE_URL=https://${URL_N8N}/
      - WEBHOOK_URL=https://${URL_WEBHOOK_N8N}/
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=n8n_redis
      - QUEUE_BULL_REDIS_PORT=6379
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n_queue
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${SENHA_POSTGRES}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_EMAIL_MODE=smtp
      - N8N_SMTP_HOST=${HOST_SMTP_N8N}
      - N8N_SMTP_PORT=${PORTA_SMTP_N8N}
      - N8N_SMTP_USER=${USER_SMTP_N8N}
      - N8N_SMTP_PASS=${SENHA_SMTP_N8N}
      - N8N_SMTP_SENDER=${EMAIL_SMTP_N8N}
      - N8N_SMTP_SSL=true
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.n8n-editor.rule=Host(\`${URL_N8N}\`)"
        - "traefik.http.routers.n8n-editor.entrypoints=websecure"
        - "traefik.http.routers.n8n-editor.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.n8n-editor.loadbalancer.server.port=5678"
        - "traefik.http.routers.n8n-editor.service=n8n-editor"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"
        - "traefik.http.routers.n8n-editor.priority=1"

## --------------------------- ORION --------------------------- ##

  n8n_worker:
    image: n8nio/n8n:latest
    command: n8n worker
    environment:
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=n8n_redis
      - QUEUE_BULL_REDIS_PORT=6379
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n_queue
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${SENHA_POSTGRES}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager

## --------------------------- ORION --------------------------- ##

  n8n_webhook:
    image: n8nio/n8n:latest
    command: n8n webhook
    environment:
      - N8N_HOST=${URL_WEBHOOK_N8N}
      - WEBHOOK_URL=https://${URL_WEBHOOK_N8N}/
      - N8N_PROTOCOL=https
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=n8n_redis
      - QUEUE_BULL_REDIS_PORT=6379
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n_queue
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${SENHA_POSTGRES}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.n8n-webhook.rule=Host(\`${URL_WEBHOOK_N8N}\`)"
        - "traefik.http.routers.n8n-webhook.entrypoints=websecure"
        - "traefik.http.routers.n8n-webhook.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.n8n-webhook.loadbalancer.server.port=5678"
        - "traefik.http.routers.n8n-webhook.service=n8n-webhook"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"
        - "traefik.http.routers.n8n-webhook.priority=1"

## --------------------------- ORION --------------------------- ##

  n8n_redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager

## --------------------------- ORION --------------------------- ##

volumes:
  n8n_data:
    external: true
    name: n8n_data

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    attachable: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      n8n.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY DA STACK
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack n8n...${reset}"

    if docker stack deploy --prune --resolve-image always -c /root/n8n.yaml n8n > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack n8n deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy da stack n8n.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA EM MARKDOWN (sem senhas — padrão Orion)
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Salvando metadados em /root/dados_vps/n8n.md...${reset}"

    save_data "n8n" "# N8N

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **Modo**: Queue (editor + worker + webhook)
- **URL Editor**: https://${URL_N8N}
- **URL Webhook**: https://${URL_WEBHOOK_N8N}
- **Banco de Dados**: PostgreSQL (host=postgres, db=n8n_queue, user=postgres)
- **Cache/Queue**: Redis 7 (serviço interno n8n_redis)
- **SMTP Host**: ${HOST_SMTP_N8N}:${PORTA_SMTP_N8N}
- **SMTP Remetente**: ${EMAIL_SMTP_N8N}
- **Rede**: ${NOME_REDE_INTERNA}
- **Stack YAML**: /root/n8n.yaml
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

## Serviços na Stack
| Serviço        | Função                                    |
|----------------|-------------------------------------------|
| n8n_editor     | Interface web de criação de workflows     |
| n8n_worker     | Executor assíncrono de workflows em queue |
| n8n_webhook    | Receptor dedicado de webhooks externos    |
| n8n_redis      | Broker de filas Bull entre os serviços    |

## Nota de Segurança
> Senhas do PostgreSQL, SMTP e N8N_ENCRYPTION_KEY **não** são armazenadas aqui.
> A ENCRYPTION_KEY foi gerada via \`openssl rand -hex 16\` em tempo de execução.
> Guarde-a em cofre seguro — sem ela os workflows criptografados não podem ser restaurados."

    echo -e "${verde}      Metadados salvos.${reset}"
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
clear
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}       ORION DESIGN — Deploy N8N (Modo Queue)               ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
generate_encryption_key
setup_volumes
generate_n8n_yaml
deploy_stack
persist_data

echo ""
echo -e "${amarelo}============================================================${reset}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${verde}  Deploy concluído com sucesso.${reset}"
    echo -e "${branco}  Editor  : https://${URL_N8N}${reset}"
    echo -e "${branco}  Webhook : https://${URL_WEBHOOK_N8N}${reset}"
else
    echo -e "${vermelho}  Deploy concluído com $ERRORS erro(s).${reset}"
    echo -e "${branco}  Consulte: docker service ls | grep n8n${reset}"
fi
echo -e "${branco}  Dados salvos em: /root/dados_vps/n8n.md${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

exit $ERRORS
