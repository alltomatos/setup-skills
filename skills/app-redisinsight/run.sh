#!/bin/bash
# =============================================================================
# skills/app-redisinsight/run.sh
# Skill: Deploy do RedisInsight via Docker Swarm (Padrão Orion)
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

    [ -z "${URL_REDISINSIGHT:-}" ]    && echo -e "${vermelho}[ERRO] URL_REDISINSIGHT não informado.${reset}"    && missing=1
    [ -z "${USER_REDISINSIGHT:-}" ]   && echo -e "${vermelho}[ERRO] USER_REDISINSIGHT não informado.${reset}"   && missing=1
    [ -z "${PASS_REDISINSIGHT:-}" ]   && echo -e "${vermelho}[ERRO] PASS_REDISINSIGHT não informado.${reset}"   && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ]   && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}"   && missing=1

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}

# =============================================================================
# PREPARAÇÃO
# =============================================================================
prepare() {
    echo -e "${amarelo}[1/5] Gerando chaves e autenticação...${reset}"

    # Gera Encryption Key se não existir
    RI_ENCRYPTION_KEY="$(openssl rand -hex 16)"
    
    # Gera Hash para Basic Auth (Traefik)
    # Nota: htpasswd precisa estar instalado. Em ambientes Swarm Orion ele costuma estar disponível via apache2-utils
    AUTH_REDISINSIGHT=$(htpasswd -nb "$USER_REDISINSIGHT" "$PASS_REDISINSIGHT" | sed -e s/\\$/\\$\\$/g)

    echo -e "${verde}      Hash de autenticação gerado.${reset}"
}

# =============================================================================
# VOLUMES
# =============================================================================
setup_volumes() {
    echo -e "${amarelo}[2/5] Criando volumes persistentes...${reset}"

    for vol in redisinsight_data redisinsight_logs; do
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
    echo -e "${amarelo}[3/5] Gerando /root/redisinsight.yaml...${reset}"

    cat > /root/redisinsight.yaml << YAML
version: "3.7"
services:
  redisinsight:
    image: redislabs/redisinsight:latest
    environment:
      - RI_APP_PORT=5540
      - RI_APP_HOST=0.0.0.0
      - RI_ENCRYPTION_KEY=${RI_ENCRYPTION_KEY}
      - RI_LOG_LEVEL=info
      - RI_FILES_LOGGER=false
      - RI_STDOUT_LOGGER=true
    volumes:
      - redisinsight_data:/db
      - redisinsight_logs:/data/logs
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
        - "traefik.http.routers.redisinsight.rule=Host(\`${URL_REDISINSIGHT}\`)"
        - "traefik.http.routers.redisinsight.entrypoints=websecure"
        - "traefik.http.routers.redisinsight.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.redisinsight.loadbalancer.server.port=5540"
        - "traefik.http.middlewares.redisinsight-auth.basicauth.users=${AUTH_REDISINSIGHT}"
        - "traefik.http.routers.redisinsight.middlewares=redisinsight-auth"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

volumes:
  redisinsight_data:
    external: true
    name: redisinsight_data
  redisinsight_logs:
    external: true
    name: redisinsight_logs

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      redisinsight.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[4/5] Executando deploy da stack redisinsight...${reset}"

    if deploy_via_portainer "redisinsight" "/root/redisinsight.yaml" > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack redisinsight deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy via Portainer. Tentando CLI direto...${reset}"
        docker stack deploy --prune --resolve-image always -c /root/redisinsight.yaml redisinsight || ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA
# =============================================================================
persist_data() {
    echo -e "${amarelo}[5/5] Salvando metadados em /root/dados_vps/redisinsight.md...${reset}"

    save_data "redisinsight" "# RedisInsight

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **URL**: https://${URL_REDISINSIGHT}
- **Usuário**: ${USER_REDISINSIGHT}
- **Rede**: ${NOME_REDE_INTERNA}
- **Stack YAML**: /root/redisinsight.yaml
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

## Nota de Segurança
> A senha de acesso não é armazenada aqui.
> A RI_ENCRYPTION_KEY foi gerada automaticamente."

    echo -e "${verde}      Metadados salvos.${reset}"
}

# =============================================================================
# EXECUÇÃO
# =============================================================================
validate_inputs
prepare
setup_volumes
generate_yaml
deploy_stack
persist_data

exit $ERRORS
