#!/bin/bash
# =============================================================================
# skills/app-easyappointments/run.sh
# Skill: Deploy do Easy!Appointments via Docker Swarm (Padrão Orion)
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

    [ -z "${URL_EASYAPPOINTMENTS:-}" ] && echo -e "${vermelho}[ERRO] URL_EASYAPPOINTMENTS não informado.${reset}" && missing=1
    [ -z "${SENHA_MYSQL:-}" ]           && echo -e "${vermelho}[ERRO] SENHA_MYSQL não informado.${reset}"           && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ]     && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}"     && missing=1

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}

# =============================================================================
# PREPARAÇÃO DE CONFIGURAÇÕES
# =============================================================================
prepare_configs() {
    echo -e "${amarelo}[1/5] Preparando arquivos de configuração...${reset}"

    mkdir -p /root/easyappointments > /dev/null 2>&1
    
    cat > /root/easyappointments/apache-custom.conf << EOL
ServerName ${URL_EASYAPPOINTMENTS}
EOL

    echo -e "${verde}      apache-custom.conf gerado em /root/easyappointments/.${reset}"
}

# =============================================================================
# VOLUMES
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in easyappointments_data; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

# =============================================================================
# GERAÇÃO DO YAML
# =============================================================================
generate_yaml() {
    echo -e "${amarelo}[3/5] Gerando /root/easyappointments.yaml...${reset}"

    cat > /root/easyappointments.yaml << YAML
version: "3.7"
services:
  easyappointments:
    image: alextselegidis/easyappointments:latest
    environment:
      - BASE_URL=https://${URL_EASYAPPOINTMENTS}
      - APACHE_SERVER_NAME=${URL_EASYAPPOINTMENTS}
      - DB_HOST=mysql
      - DB_NAME=easyappointments
      - DB_USERNAME=root
      - DB_PASSWORD=${SENHA_MYSQL}
      - GOOGLE_SYNC_FEATURE=false
      - DEBUG_MODE=TRUE
    volumes:
      - easyappointments_data:/var/www/html
      - /root/easyappointments/apache-custom.conf:/etc/apache2/conf-enabled/custom.conf:ro
    networks:
      - ${NOME_REDE_INTERNA}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.easyappointments.rule=Host(\`${URL_EASYAPPOINTMENTS}\`)"
        - "traefik.http.routers.easyappointments.entrypoints=websecure"
        - "traefik.http.routers.easyappointments.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.easyappointments.loadbalancer.server.port=80"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

volumes:
  easyappointments_data:
    external: true
    name: easyappointments_data

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      easyappointments.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack easyappointments...${reset}"

    ensure_db "mysql" "easyappointments" || { echo "Erro ao preparar o banco no mysql"; exit 1; }
    if deploy_via_portainer "easyappointments" "/root/easyappointments.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack easyappointments deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy via Portainer. Tentando CLI direto...${reset}"
        docker stack deploy --prune --resolve-image always -c /root/easyappointments.yaml easyappointments || ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Salvando metadados em /root/dados_vps/dados_easyappointments...${reset}"

    save_data "easyappointments" "[ EASYAPPOINTMENTS ]

Dominio: https://${URL_EASYAPPOINTMENTS}

Host: easyappointments

Port: 80

Rede: ${NOME_REDE_INTERNA}"

    echo -e "${verde}      Metadados salvos.${reset}"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================
validate_inputs
prepare_configs
setup_volumes
generate_yaml
deploy_stack
persist_data

exit $ERRORS
