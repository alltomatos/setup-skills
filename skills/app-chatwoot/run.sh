#!/bin/bash
# =============================================================================
# skills/app-chatwoot/run.sh
# Skill: Deploy do Chatwoot via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias (injetadas pelo Claude como variáveis de ambiente):
#   URL_CHATWOOT            — domínio do Chatwoot (ex: chatwoot.seudominio.com.br)
#   NOME_EMPRESA_CHATWOOT   — nome da empresa exibido na interface
#   SENHA_PGVECTOR          — senha do PostgreSQL (pgvector)
#   EMAIL_ADMIN_CHATWOOT    — email do remetente SMTP
#   USER_SMTP_CHATWOOT      — usuário de autenticação SMTP
#   SENHA_EMAIL_CHATWOOT    — senha SMTP (sensível — nunca logada)
#   SMTP_HOST_CHATWOOT      — host SMTP (ex: smtp.hostinger.com)
#   PORTA_SMTP_CHATWOOT     — porta SMTP (465 ou 587)
#   NOME_REDE_INTERNA       — rede overlay Docker (lida de /root/dados_vps/dados_traefik)
#
# Padrão de persistência:
#   /root/chatwoot.yaml           — stack YAML do Chatwoot
#   /root/dados_vps/dados_chatwoot   — metadados do deploy (sem senhas)
# =============================================================================

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

    [ -z "${URL_CHATWOOT:-}"          ] && echo -e "${vermelho}[ERRO] URL_CHATWOOT não informado.${reset}"          && missing=1
    [ -z "${NOME_EMPRESA_CHATWOOT:-}" ] && echo -e "${vermelho}[ERRO] NOME_EMPRESA_CHATWOOT não informado.${reset}" && missing=1
    [ -z "${SENHA_PGVECTOR:-}"        ] && echo -e "${vermelho}[ERRO] SENHA_PGVECTOR não informado.${reset}"        && missing=1
    [ -z "${EMAIL_ADMIN_CHATWOOT:-}"  ] && echo -e "${vermelho}[ERRO] EMAIL_ADMIN_CHATWOOT não informado.${reset}"  && missing=1
    [ -z "${USER_SMTP_CHATWOOT:-}"    ] && echo -e "${vermelho}[ERRO] USER_SMTP_CHATWOOT não informado.${reset}"    && missing=1
    [ -z "${SENHA_EMAIL_CHATWOOT:-}"  ] && echo -e "${vermelho}[ERRO] SENHA_EMAIL_CHATWOOT não informado.${reset}"  && missing=1
    [ -z "${SMTP_HOST_CHATWOOT:-}"    ] && echo -e "${vermelho}[ERRO] SMTP_HOST_CHATWOOT não informado.${reset}"    && missing=1
    [ -z "${PORTA_SMTP_CHATWOOT:-}"   ] && echo -e "${vermelho}[ERRO] PORTA_SMTP_CHATWOOT não informado.${reset}"   && missing=1
    [ -z "${NOME_REDE_INTERNA:-}"     ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}"     && missing=1

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo -e "${amarelo}Todas as variáveis acima devem ser injetadas pelo Claude antes de executar.${reset}"
        exit 1
    fi
}

# =============================================================================
# LÓGICA SMTP_SSL AUTOMÁTICA  (465 = true | 587 = false)
# =============================================================================
resolve_smtp_ssl() {
    if [ "$PORTA_SMTP_CHATWOOT" -eq 465 ]; then
        SMTP_SSL="true"
    else
        SMTP_SSL="false"
    fi
    echo -e "${verde}      SMTP_SSL resolvido: $SMTP_SSL (porta $PORTA_SMTP_CHATWOOT)${reset}"
}

# =============================================================================
# GERAÇÃO DA ENCRYPTION KEY (openssl rand -hex 16)
# =============================================================================
generate_encryption_key() {
    CHATWOOT_ENCRYPTION_KEY="$(openssl rand -hex 16)"
    echo -e "${verde}      Encryption key gerada via openssl.${reset}"
}

# =============================================================================
# CRIAÇÃO DE VOLUMES (idempotente)
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in chatwoot_data chatwoot_storage; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

# =============================================================================
# GERAÇÃO DO YAML DO CHATWOOT (app + sidekiq + redis na mesma stack)
# Salvo em /root/chatwoot.yaml — padrão Orion
# =============================================================================
generate_chatwoot_yaml() {
    echo -e "${amarelo}[3/5] Gerando /root/chatwoot.yaml...${reset}"

    cat > /root/chatwoot.yaml << YAML
version: "3.7"

## --------------------------- ORION --------------------------- ##

services:

  app:
    image: chatwoot/chatwoot:latest
    command: bundle exec rails s -p 3000 -b 0.0.0.0
    entrypoint: docker/entrypoints/rails.sh

    environment:
      - SECRET_KEY_BASE=${CHATWOOT_ENCRYPTION_KEY}
      - FRONTEND_URL=https://${URL_CHATWOOT}
      - DEFAULT_LOCALE=pt_BR
      - FORCE_SSL=true
      - ENABLE_ACCOUNT_SIGNUP=false
      - INSTALLATION_NAME=${NOME_EMPRESA_CHATWOOT}

      - POSTGRES_HOST=pgvector
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=chatwoot
      - POSTGRES_USERNAME=postgres
      - POSTGRES_PASSWORD=${SENHA_PGVECTOR}

      - REDIS_URL=redis://redis:6379

      - MAILER_SENDER_EMAIL=${EMAIL_ADMIN_CHATWOOT}
      - SMTP_ADDRESS=${SMTP_HOST_CHATWOOT}
      - SMTP_PORT=${PORTA_SMTP_CHATWOOT}
      - SMTP_USERNAME=${USER_SMTP_CHATWOOT}
      - SMTP_PASSWORD=${SENHA_EMAIL_CHATWOOT}
      - SMTP_SSL=${SMTP_SSL}
      - SMTP_AUTHENTICATION=login
      - SMTP_ENABLE_STARTTLS_AUTO=false

      - RAILS_LOG_TO_STDOUT=true
      - LOG_LEVEL=info

    volumes:
      - chatwoot_storage:/app/storage

    networks:
      - ${NOME_REDE_INTERNA}

    depends_on:
      - redis

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.chatwoot.rule=Host(\`${URL_CHATWOOT}\`)"
        - "traefik.http.routers.chatwoot.entrypoints=websecure"
        - "traefik.http.routers.chatwoot.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.chatwoot.loadbalancer.server.port=3000"
        - "traefik.http.routers.chatwoot.service=chatwoot"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"
        - "traefik.http.routers.chatwoot.priority=1"

## --------------------------- ORION --------------------------- ##

  sidekiq:
    image: chatwoot/chatwoot:latest
    command: bundle exec sidekiq -C config/sidekiq.yml
    entrypoint: docker/entrypoints/rails.sh

    environment:
      - SECRET_KEY_BASE=${CHATWOOT_ENCRYPTION_KEY}
      - FRONTEND_URL=https://${URL_CHATWOOT}
      - DEFAULT_LOCALE=pt_BR
      - FORCE_SSL=true

      - POSTGRES_HOST=pgvector
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=chatwoot
      - POSTGRES_USERNAME=postgres
      - POSTGRES_PASSWORD=${SENHA_PGVECTOR}

      - REDIS_URL=redis://redis:6379

      - MAILER_SENDER_EMAIL=${EMAIL_ADMIN_CHATWOOT}
      - SMTP_ADDRESS=${SMTP_HOST_CHATWOOT}
      - SMTP_PORT=${PORTA_SMTP_CHATWOOT}
      - SMTP_USERNAME=${USER_SMTP_CHATWOOT}
      - SMTP_PASSWORD=${SENHA_EMAIL_CHATWOOT}
      - SMTP_SSL=${SMTP_SSL}
      - SMTP_AUTHENTICATION=login
      - SMTP_ENABLE_STARTTLS_AUTO=false

      - RAILS_LOG_TO_STDOUT=true
      - LOG_LEVEL=info

    volumes:
      - chatwoot_storage:/app/storage

    networks:
      - ${NOME_REDE_INTERNA}

    depends_on:
      - redis

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager

## --------------------------- ORION --------------------------- ##

  redis:
    image: redis:7-alpine
    command: redis-server --save 60 1 --loglevel warning

    volumes:
      - chatwoot_data:/data

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
  chatwoot_data:
    external: true
    name: chatwoot_data
  chatwoot_storage:
    external: true
    name: chatwoot_storage

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    attachable: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      chatwoot.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY DA STACK
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack chatwoot...${reset}"

    ensure_db "pgvector" "chatwoot" || { echo "Erro ao preparar o banco"; exit 1; }
    if deploy_via_portainer "chatwoot" "/root/chatwoot.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack chatwoot deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy do chatwoot.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA EM MARKDOWN (padrão /root/dados_vps/*.md)
# ATENÇÃO: SENHA_EMAIL_CHATWOOT NUNCA é escrita no .md (mascarada como ***)
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Persistindo metadados em /root/dados_vps/dados_chatwoot...${reset}"

    save_data "chatwoot" "[ CHATWOOT ]

Dominio: https://${URL_CHATWOOT}

Host: app

Port: 3000

Secret Key Base: ${CHATWOOT_ENCRYPTION_KEY}

Rede: ${NOME_REDE_INTERNA}"

    echo -e "${verde}      Dados salvos (senha SMTP mascarada como ***).${reset}"
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
clear 2>/dev/null || true
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}       ORION DESIGN — Deploy Chatwoot                       ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

echo -e "${amarelo}[0/5] Validando entradas...${reset}"
validate_inputs

echo -e "${amarelo}[1/5] Resolvendo SMTP_SSL e encryption key...${reset}"
resolve_smtp_ssl
generate_encryption_key

setup_volumes
generate_chatwoot_yaml
deploy_stack
persist_data

echo ""
echo -e "${amarelo}============================================================${reset}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${verde}  Deploy concluído com sucesso.${reset}"
    echo -e "${branco}  Chatwoot disponível em: https://${URL_CHATWOOT}${reset}"
else
    echo -e "${vermelho}  Deploy concluído com $ERRORS erro(s).${reset}"
    echo -e "${branco}  Consulte: docker service ls | grep chatwoot${reset}"
fi
echo -e "${branco}  Dados salvos em: /root/dados_vps/dados_chatwoot${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

exit $ERRORS
