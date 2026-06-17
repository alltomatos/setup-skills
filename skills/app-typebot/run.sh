#!/bin/bash
# =============================================================================
# skills/app-typebot/run.sh
# Skill: Deploy do Typebot (Builder + Viewer) via Docker Swarm (Padrão Orion)
#
# Typebot possui 2 serviços expostos em domínios distintos:
#   - Builder  → editor de fluxos (URL_TYPEBOT)
#   - Viewer   → runtime público dos bots (URL_VIEWER_TYPEBOT)
#
# Entradas obrigatórias (injetadas pelo Claude como variáveis de ambiente):
#   URL_TYPEBOT          — domínio do Builder (ex: typebot.seudominio.com.br)
#   URL_VIEWER_TYPEBOT   — domínio do Viewer  (ex: viewer.seudominio.com.br)
#   SENHA_POSTGRES       — senha do PostgreSQL externo (SENSÍVEL)
#   EMAIL_SMTP_TYPEBOT   — email remetente SMTP
#   USER_SMTP_TYPEBOT    — usuário de autenticação SMTP
#   SENHA_SMTP_TYPEBOT   — senha SMTP (SENSÍVEL)
#   HOST_SMTP_TYPEBOT    — host do servidor SMTP
#   PORTA_SMTP_TYPEBOT   — porta SMTP
#   NOME_REDE_INTERNA    — rede overlay Docker (ex: OrionNet)
#
# Gerado automaticamente (não perguntar ao usuário):
#   NEXTAUTH_SECRET      — via openssl rand -hex 16
#
# Persistência:
#   /root/typebot.yaml           — stack YAML (padrão Orion)
#   /root/dados_vps/typebot.md   — metadados (SEM senhas)
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
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

    [ -z "${URL_TYPEBOT:-}" ]         && echo -e "${vermelho}[ERRO] URL_TYPEBOT não informado.${reset}"         && missing=1
    [ -z "${URL_VIEWER_TYPEBOT:-}" ]  && echo -e "${vermelho}[ERRO] URL_VIEWER_TYPEBOT não informado.${reset}"  && missing=1
    [ -z "${SENHA_POSTGRES:-}" ]      && echo -e "${vermelho}[ERRO] SENHA_POSTGRES não informado.${reset}"      && missing=1
    [ -z "${EMAIL_SMTP_TYPEBOT:-}" ]  && echo -e "${vermelho}[ERRO] EMAIL_SMTP_TYPEBOT não informado.${reset}"  && missing=1
    [ -z "${USER_SMTP_TYPEBOT:-}" ]   && echo -e "${vermelho}[ERRO] USER_SMTP_TYPEBOT não informado.${reset}"   && missing=1
    [ -z "${SENHA_SMTP_TYPEBOT:-}" ]  && echo -e "${vermelho}[ERRO] SENHA_SMTP_TYPEBOT não informado.${reset}"  && missing=1
    [ -z "${HOST_SMTP_TYPEBOT:-}" ]   && echo -e "${vermelho}[ERRO] HOST_SMTP_TYPEBOT não informado.${reset}"   && missing=1
    [ -z "${PORTA_SMTP_TYPEBOT:-}" ]  && echo -e "${vermelho}[ERRO] PORTA_SMTP_TYPEBOT não informado.${reset}"  && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ]   && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}"   && missing=1

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo -e "${amarelo}Uso: URL_TYPEBOT=x URL_VIEWER_TYPEBOT=y SENHA_POSTGRES=z ... ./run.sh${reset}"
        exit 1
    fi
}

# =============================================================================
# GERAÇÃO DO SEGREDO NEXTAUTH (não perguntar ao usuário)
# =============================================================================
generate_secret() {
    echo -e "${amarelo}[1/5] Gerando NEXTAUTH_SECRET...${reset}"
    NEXTAUTH_SECRET="$(openssl rand -hex 16)"
    echo -e "${verde}      Segredo gerado (32 chars hex).${reset}"
}

# =============================================================================
# VOLUMES PERSISTENTES
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in typebot_builder_data typebot_viewer_data; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

# =============================================================================
# GERAÇÃO DO YAML (arquivo salvo em /root/ — padrão Orion)
# =============================================================================
generate_typebot_yaml() {
    echo -e "${amarelo}[3/5] Gerando /root/typebot.yaml...${reset}"

    cat > /root/typebot.yaml << YAML
version: "3.7"
services:

## --------------------------- ORION --------------------------- ##

  typebot_builder:
    image: baptistearno/typebot-builder:latest
    environment:
      - DATABASE_URL=postgresql://postgres:${SENHA_POSTGRES}@postgres:5432/typebot
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - ENCRYPTION_SECRET=${NEXTAUTH_SECRET}
      - NEXTAUTH_URL=https://${URL_TYPEBOT}
      - NEXT_PUBLIC_VIEWER_URL=https://${URL_VIEWER_TYPEBOT}
      - SMTP_HOST=${HOST_SMTP_TYPEBOT}
      - SMTP_PORT=${PORTA_SMTP_TYPEBOT}
      - SMTP_USERNAME=${USER_SMTP_TYPEBOT}
      - SMTP_PASSWORD=${SENHA_SMTP_TYPEBOT}
      - SMTP_AUTH_DISABLED=false
      - NEXT_PUBLIC_SMTP_FROM=Typebot <${EMAIL_SMTP_TYPEBOT}>

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
        - "traefik.http.routers.typebot_builder.rule=Host(\`${URL_TYPEBOT}\`)"
        - "traefik.http.routers.typebot_builder.entrypoints=websecure"
        - "traefik.http.routers.typebot_builder.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.typebot_builder.service=typebot_builder"
        - "traefik.http.services.typebot_builder.loadbalancer.server.port=3000"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

## --------------------------- ORION --------------------------- ##

  typebot_viewer:
    image: baptistearno/typebot-viewer:latest
    environment:
      - DATABASE_URL=postgresql://postgres:${SENHA_POSTGRES}@postgres:5432/typebot
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - ENCRYPTION_SECRET=${NEXTAUTH_SECRET}
      - NEXTAUTH_URL=https://${URL_TYPEBOT}
      - NEXT_PUBLIC_VIEWER_URL=https://${URL_VIEWER_TYPEBOT}
      - SMTP_HOST=${HOST_SMTP_TYPEBOT}
      - SMTP_PORT=${PORTA_SMTP_TYPEBOT}
      - SMTP_USERNAME=${USER_SMTP_TYPEBOT}
      - SMTP_PASSWORD=${SENHA_SMTP_TYPEBOT}
      - SMTP_AUTH_DISABLED=false
      - NEXT_PUBLIC_SMTP_FROM=Typebot <${EMAIL_SMTP_TYPEBOT}>

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
        - "traefik.http.routers.typebot_viewer.rule=Host(\`${URL_VIEWER_TYPEBOT}\`)"
        - "traefik.http.routers.typebot_viewer.entrypoints=websecure"
        - "traefik.http.routers.typebot_viewer.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.typebot_viewer.service=typebot_viewer"
        - "traefik.http.services.typebot_viewer.loadbalancer.server.port=3000"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

## --------------------------- ORION --------------------------- ##

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    attachable: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      typebot.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY DA STACK
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack typebot...${reset}"

    if deploy_via_portainer "typebot" "/root/typebot.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack typebot deployada (builder + viewer).${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy do typebot.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA EM MARKDOWN (SEM senhas) — /root/dados_vps/typebot.md
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Persistindo metadados (sem senhas)...${reset}"

    save_data "typebot" "# Typebot

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **Builder (editor)**: https://$URL_TYPEBOT
- **Viewer (runtime)**: https://$URL_VIEWER_TYPEBOT
- **Banco de Dados**: PostgreSQL externo (host=postgres, db=typebot, user=postgres)
- **Rede**: $NOME_REDE_INTERNA
- **Stack YAML**: /root/typebot.yaml
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

## SMTP
- **Host**: $HOST_SMTP_TYPEBOT
- **Porta**: $PORTA_SMTP_TYPEBOT
- **Remetente**: $EMAIL_SMTP_TYPEBOT
- **Usuário**: $USER_SMTP_TYPEBOT
> Senha SMTP e NEXTAUTH_SECRET não são persistidos por segurança.

## Autenticação
- NEXTAUTH_SECRET gerado automaticamente (openssl rand -hex 16) — não armazenado em texto.
- O primeiro usuário criado no Builder torna-se administrador.

## Observações
- O Builder e o Viewer compartilham o mesmo banco e o mesmo segredo de criptografia.
- O Viewer deve estar acessível publicamente para execução dos fluxos publicados."

    echo -e "${verde}      Metadados salvos em /root/dados_vps/typebot.md${reset}"
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
clear
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}         ORION DESIGN — Deploy Typebot (Builder+Viewer)     ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
generate_secret
setup_volumes
generate_typebot_yaml
deploy_stack
persist_data

echo ""
echo -e "${amarelo}============================================================${reset}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${verde}  Deploy concluído com sucesso.${reset}"
    echo -e "${branco}  Builder: https://$URL_TYPEBOT${reset}"
    echo -e "${branco}  Viewer:  https://$URL_VIEWER_TYPEBOT${reset}"
else
    echo -e "${vermelho}  Deploy concluído com $ERRORS erro(s).${reset}"
    echo -e "${branco}  Consulte os logs: docker service ls${reset}"
fi
echo -e "${branco}  Dados salvos em: /root/dados_vps/typebot.md${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

exit $ERRORS
