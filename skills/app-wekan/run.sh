#!/bin/bash
# =============================================================================
# skills/app-wekan/run.sh
# Skill: Instalação do Wekan via Docker Swarm
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
vermelho="\e[91m"
reset="\e[0m"

STACK_NAME="wekan"

# =============================================================================
# RESOLUÇÃO DE VARIÁVEIS
# =============================================================================

# 1. Domínio
if [ -z "${DOMAIN_WEKAN:-}" ]; then
    echo -e "${vermelho}[ERRO] DOMAIN_WEKAN não informado.${reset}"
    exit 1
fi

# 2. Rede
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" | head -n 1 || echo "orion_network")

# 3. Segredos (Persistência e Reuso conforme solicitado)
# Tentamos ler do arquivo de persistência primeiro para garantir idempotência
WEKAN_SECRET_KEY=$(read_data "app-wekan" 2>/dev/null | grep -oP '(?<=- WEKAN_SECRET_KEY: ).*' || echo "")
MONGO_PASSWORD=$(read_data "app-wekan" 2>/dev/null | grep -oP '(?<=- MONGO_PASSWORD: ).*' || echo "${MONGO_ROOT_PASSWORD:-}")

if [ -z "$WEKAN_SECRET_KEY" ]; then
    WEKAN_SECRET_KEY=$(openssl rand -hex 32)
    echo -e "${verde}Gerando nova WEKAN_SECRET_KEY...${reset}"
fi

if [ -z "$MONGO_PASSWORD" ]; then
    echo -e "${amarelo}Aviso: MONGO_PASSWORD não encontrada na persistência nem no ambiente.${reset}"
    echo -e "${amarelo}Usando fallback de geração ou falhando se necessário.${reset}"
    # Se não temos, e é uma nova instalação, precisamos dela.
    # Em um ambiente real, ela deveria vir do infra-mongodb.
    # Como não podemos ler de infra-mongodb.md (seguindo ADR-002 lá), 
    # assumimos que o usuário proverá via env na primeira execução.
    if [ -z "${MONGO_ROOT_PASSWORD:-}" ]; then
        echo -e "${vermelho}[ERRO] MONGO_ROOT_PASSWORD/MONGO_PASSWORD não definida.${reset}"
        exit 1
    fi
    MONGO_PASSWORD="$MONGO_ROOT_PASSWORD"
fi

# =============================================================================
# PREPARAÇÃO
# =============================================================================

echo -e "${amarelo}Preparando deploy do Wekan em https://$DOMAIN_WEKAN...${reset}"

docker volume create wekan_files > /dev/null 2>&1

# =============================================================================
# GERAÇÃO DO YAML
# =============================================================================

cat > wekan.yaml <<EOF
version: '3.7'

services:
  wekan:
    image: ghcr.io/wekan/wekan:latest
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MONGO_URL=mongodb://root:$MONGO_PASSWORD@mongodb:27017/wekan?authSource=admin
      - ROOT_URL=https://$DOMAIN_WEKAN
      - WITH_API=true
      - BROWSER_POLICY_ENABLED=true
    volumes:
      - wekan_files:/data
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.wekan.rule=Host(\`$DOMAIN_WEKAN\`)
        - traefik.http.routers.wekan.entrypoints=websecure
        - traefik.http.routers.wekan.tls.certresolver=letsencryptresolver
        - traefik.http.services.wekan.loadbalancer.server.port=8080
        - traefik.http.routers.wekan.service=wekan
        - traefik.http.routers.wekan.tls=true
      resources:
        limits:
          cpus: '1'
          memory: 1024M
      placement:
        constraints:
          - node.role == manager

networks:
  $NOME_REDE_INTERNA:
    external: true

volumes:
  wekan_files:
    external: true
EOF

# =============================================================================
# DEPLOY
# =============================================================================

deploy_via_portainer "$STACK_NAME" "wekan.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Deploy do Wekan concluído com sucesso!${reset}"
    
    # Persistência (Incluindo segredos conforme solicitado na Epic E18)
    CONTENT="# Wekan

- **Status**: Instalado
- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **URL**: https://$DOMAIN_WEKAN
- **Rede**: $NOME_REDE_INTERNA
- **WEKAN_SECRET_KEY**: $WEKAN_SECRET_KEY
- **MONGO_PASSWORD**: $MONGO_PASSWORD
- **Stack**: wekan.yaml
"
    save_data "app-wekan" "$CONTENT"
else
    echo -e "${vermelho}Erro ao realizar deploy do Wekan.${reset}"
    exit 1
fi

rm -f wekan.yaml
exit 0
