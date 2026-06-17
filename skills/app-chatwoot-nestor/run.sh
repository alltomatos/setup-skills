#!/bin/bash
# =============================================================================
# skills/app-chatwoot-nestor/run.sh
# Skill: Deploy do Chatwoot Nestor via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias:
#   URL_CHATWOOT       — domínio do serviço (ex: chatwoot.seudominio.com.br)
#   EMAIL_SMTP         — email remetente SMTP
#   USER_SMTP          — usuário SMTP
#   SENHA_SMTP         — senha SMTP (SENSÍVEL)
#   HOST_SMTP          — host SMTP (ex: smtp.hostinger.com)
#   PORTA_SMTP         — porta SMTP (ex: 465)
#   SENHA_POSTGRES     — senha do PostgreSQL (SENSÍVEL)
#   NOME_REDE_INTERNA  — nome da rede overlay Docker
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

validate_inputs() {
    local missing=0
    [ -z "${URL_CHATWOOT:-}" ]      && echo -e "${vermelho}[ERRO] URL_CHATWOOT não informado.${reset}"      && missing=1
    [ -z "${EMAIL_SMTP:-}" ]        && echo -e "${vermelho}[ERRO] EMAIL_SMTP não informado.${reset}"        && missing=1
    [ -z "${USER_SMTP:-}" ]         && echo -e "${vermelho}[ERRO] USER_SMTP não informado.${reset}"         && missing=1
    [ -z "${SENHA_SMTP:-}" ]        && echo -e "${vermelho}[ERRO] SENHA_SMTP não informado.${reset}"        && missing=1
    [ -z "${HOST_SMTP:-}" ]         && echo -e "${vermelho}[ERRO] HOST_SMTP não informado.${reset}"         && missing=1
    [ -z "${PORTA_SMTP:-}" ]        && echo -e "${vermelho}[ERRO] PORTA_SMTP não informado.${reset}"        && missing=1
    [ -z "${SENHA_POSTGRES:-}" ]    && echo -e "${vermelho}[ERRO] SENHA_POSTGRES não informado.${reset}"    && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}

generate_secrets() {
    echo -e "${amarelo}[1/7] Gerando SECRET_KEY_BASE...${reset}"
    SECRET_KEY_BASE="$(openssl rand -hex 16)"
    
    if [ "$PORTA_SMTP" -eq 465 ]; then
        SMTP_SSL=true
    else
        SMTP_SSL=false
    fi
}

setup_db() {
    echo -e "${amarelo}[2/7] Criando banco de dados chatwoot_nestor...${reset}"
    # Assume que o infra-pgvector está rodando na rede interna e aceita conexões
    local pg_container=$(docker ps -q --filter "name=pgvector_pgvector")
    if [ -n "$pg_container" ]; then
        docker exec "$pg_container" psql -U postgres -c "CREATE DATABASE chatwoot_nestor;" || true
    else
        echo -e "${amarelo}      Aviso: Container pgvector_pgvector não encontrado. O banco deve ser criado manualmente ou via infra skill.${reset}"
    fi
}

setup_volumes() {
    echo -e "${amarelo}[3/7] Criando volumes persistentes...${reset}"
    for vol in chatwoot_nestor_storage chatwoot_nestor_public chatwoot_nestor_mailer chatwoot_nestor_mailers; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
        fi
    done
}

generate_yaml() {
    echo -e "${amarelo}[4/7] Gerando /root/chatwoot_nestor.yaml...${reset}"
    cat > /root/chatwoot_nestor.yaml << YAML
version: "3.7"
services:
  app:
    image: sendingtk/chatwoot:latest
    command: bundle exec rails s -p 3000 -b 0.0.0.0
    entrypoint: docker/entrypoints/rails.sh
    volumes:
      - chatwoot_nestor_storage:/app/storage
      - chatwoot_nestor_public:/app/public
      - chatwoot_nestor_mailer:/app/app/views/devise/mailer
      - chatwoot_nestor_mailers:/app/app/views/mailers
    networks:
      - ${NOME_REDE_INTERNA}
    environment:
      - INSTALLATION_NAME=Chatwoot Nestor
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - FRONTEND_URL=https://${URL_CHATWOOT}
      - FORCE_SSL=true
      - DEFAULT_LOCALE=pt_BR
      - TZ=America/Sao_Paulo
      - REDIS_URL=redis://redis:6379
      - REDIS_PREFIX=chatwoot_nestor_
      - POSTGRES_HOST=pgvector
      - POSTGRES_USERNAME=postgres
      - POSTGRES_PASSWORD=${SENHA_POSTGRES}
      - POSTGRES_DATABASE=chatwoot_nestor
      - ACTIVE_STORAGE_SERVICE=local
      - MAILER_SENDER_EMAIL=${EMAIL_SMTP}
      - SMTP_DOMAIN=$(echo "$EMAIL_SMTP" | cut -d "@" -f 2)
      - SMTP_ADDRESS=${HOST_SMTP}
      - SMTP_PORT=${PORTA_SMTP}
      - SMTP_SSL=${SMTP_SSL}
      - SMTP_USERNAME=${USER_SMTP}
      - SMTP_PASSWORD=${SENHA_SMTP}
      - SMTP_AUTHENTICATION=login
      - SMTP_ENABLE_STARTTLS_AUTO=true
      - NODE_ENV=production
      - RAILS_ENV=production
      - INSTALLATION_ENV=docker
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.chatwoot-nestor.rule=Host(\`${URL_CHATWOOT}\`)
        - traefik.http.routers.chatwoot-nestor.entrypoints=websecure
        - traefik.http.routers.chatwoot-nestor.tls.certresolver=letsencryptresolver
        - traefik.http.services.chatwoot-nestor.loadbalancer.server.port=3000
        - traefik.docker.network=${NOME_REDE_INTERNA}

  sidekiq:
    image: sendingtk/chatwoot:latest
    command: bundle exec sidekiq -C config/sidekiq.yml
    volumes:
      - chatwoot_nestor_storage:/app/storage
      - chatwoot_nestor_public:/app/public
    networks:
      - ${NOME_REDE_INTERNA}
    environment:
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - FRONTEND_URL=https://${URL_CHATWOOT}
      - REDIS_URL=redis://redis:6379
      - POSTGRES_HOST=pgvector
      - POSTGRES_PASSWORD=${SENHA_POSTGRES}
      - POSTGRES_DATABASE=chatwoot_nestor
      - RAILS_ENV=production
    deploy:
      mode: replicated
      replicas: 1

volumes:
  chatwoot_nestor_storage:
    external: true
  chatwoot_nestor_public:
    external: true
  chatwoot_nestor_mailer:
    external: true
  chatwoot_nestor_mailers:
    external: true

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML
}

deploy_stack() {
    echo -e "${amarelo}[5/7] Executando deploy da stack chatwoot_nestor...${reset}"
    deploy_via_portainer "chatwoot_nestor" "/root/chatwoot_nestor.yaml"
}

run_migrations() {
    echo -e "${amarelo}[6/7] Rodando migrações do rails...${reset}"
    sleep 30
    local container=$(docker ps -q --filter "name=chatwoot_nestor_app")
    if [ -n "$container" ]; then
        docker exec "$container" bundle exec rails db:chatwoot_prepare || true
    fi
}

unlock_config() {
    echo -e "${amarelo}[7/7] Desbloqueando installation_configs no postgres...${reset}"
    local pg_container=$(docker ps -q --filter "name=pgvector_pgvector")
    if [ -n "$pg_container" ]; then
        docker exec -i "$pg_container" psql -U postgres -d chatwoot_nestor -c "update installation_configs set locked = false;" || true
    fi
}

persist_data() {
    save_data "chatwoot_nestor" "# Chatwoot Nestor

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **URL**: https://${URL_CHATWOOT}
- **DB**: PostgreSQL (chatwoot_nestor)
- **Cache**: Redis"
}

validate_inputs
generate_secrets
setup_db
setup_volumes
generate_yaml
deploy_stack
run_migrations
unlock_config
persist_data
