#!/bin/bash
# =============================================================================
# skills/app-traefik/run.sh
# Skill: Deploy do Traefik + Portainer via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias (injetadas pelo Claude como variáveis de ambiente):
#   NOME_SERVIDOR      — nome do servidor (ex: OrionDesign)
#   NOME_REDE_INTERNA  — nome da rede overlay (ex: OrionNet)
#   EMAIL_SSL          — email para Let's Encrypt
#   URL_PORTAINER      — domínio do Portainer (ex: portainer.seudominio.com.br)
#
# Padrão de persistência:
#   /root/dados_vps/traefik.md    — metadados do deploy
#   /root/dados_vps/portainer.md  — credenciais do Portainer
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

    [ -z "$NOME_SERVIDOR" ]     && echo -e "${vermelho}[ERRO] NOME_SERVIDOR não informado.${reset}"     && missing=1
    [ -z "$NOME_REDE_INTERNA" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1
    [ -z "$EMAIL_SSL" ]         && echo -e "${vermelho}[ERRO] EMAIL_SSL não informado.${reset}"         && missing=1
    [ -z "$URL_PORTAINER" ]     && echo -e "${vermelho}[ERRO] URL_PORTAINER não informado.${reset}"     && missing=1

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo -e "${amarelo}Uso: NOME_SERVIDOR=x NOME_REDE_INTERNA=y EMAIL_SSL=z URL_PORTAINER=w ./run.sh${reset}"
        exit 1
    fi
}

# =============================================================================
# PRÉ-REQUISITOS: Docker Swarm + Volumes + Rede
# =============================================================================
setup_swarm() {
    echo -e "${amarelo}[1/6] Inicializando Docker Swarm...${reset}"

    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        docker swarm init > /dev/null 2>&1
        echo -e "${verde}      Swarm inicializado.${reset}"
    else
        echo -e "${verde}      Swarm já está ativo.${reset}"
    fi
}

setup_volumes() {
    echo -e "${amarelo}[2/6] Criando volumes persistentes...${reset}"

    for vol in volume_swarm_shared volume_swarm_certificates portainer_data; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            docker volume create "$vol" > /dev/null 2>&1
            echo -e "${verde}      Volume criado: $vol${reset}"
        else
            echo -e "${verde}      Volume existente: $vol${reset}"
        fi
    done
}

setup_network() {
    echo -e "${amarelo}[3/6] Criando rede interna overlay: $NOME_REDE_INTERNA...${reset}"

    if ! docker network ls --format '{{.Name}}' | grep -q "^${NOME_REDE_INTERNA}$"; then
        docker network create --driver=overlay --attachable "$NOME_REDE_INTERNA" > /dev/null 2>&1
        echo -e "${verde}      Rede criada: $NOME_REDE_INTERNA${reset}"
    else
        echo -e "${verde}      Rede já existe: $NOME_REDE_INTERNA${reset}"
    fi
}

# =============================================================================
# GERAÇÃO DO YAML DO TRAEFIK (arquivo salvo em /root/ — padrão Orion)
# =============================================================================
generate_traefik_yaml() {
    echo -e "${amarelo}[4/6] Gerando /root/traefik.yaml...${reset}"

    cat > /root/traefik.yaml << YAML
version: "3.7"
services:

## --------------------------- ORION --------------------------- ##

  traefik:
    image: traefik:v3.5.3
    command:
      - "--api.dashboard=true"
      - "--providers.swarm=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=${NOME_REDE_INTERNA}"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.transport.respondingTimeouts.idleTimeout=3600"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_SSL}"
      - "--log.level=DEBUG"
      - "--log.format=common"
      - "--log.filePath=/var/log/traefik/traefik.log"
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/traefik/access-log"

    volumes:
      - "vol_certificates:/etc/traefik/letsencrypt"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"

    networks:
      - ${NOME_REDE_INTERNA}

    ports:
      - target: 80
        published: 80
        mode: host
      - target: 443
        published: 443
        mode: host

    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.middlewares.redirect-https.redirectscheme.scheme=https"
        - "traefik.http.middlewares.redirect-https.redirectscheme.permanent=true"
        - "traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)"
        - "traefik.http.routers.http-catchall.entrypoints=web"
        - "traefik.http.routers.http-catchall.middlewares=redirect-https@docker"
        - "traefik.http.routers.http-catchall.priority=1"

## --------------------------- ORION --------------------------- ##

volumes:
  vol_shared:
    external: true
    name: volume_swarm_shared
  vol_certificates:
    external: true
    name: volume_swarm_certificates

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    attachable: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      traefik.yaml gerado.${reset}"
}

# =============================================================================
# GERAÇÃO DO YAML DO PORTAINER
# =============================================================================
generate_portainer_yaml() {
    echo -e "${amarelo}[5/6] Gerando /root/portainer.yaml...${reset}"

    cat > /root/portainer.yaml << YAML
version: "3.7"
services:

## --------------------------- ORION --------------------------- ##

  agent:
    image: portainer/agent:latest

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes

    networks:
      - ${NOME_REDE_INTERNA}

    deploy:
      mode: global
      placement:
        constraints: [node.platform.os == linux]

## --------------------------- ORION --------------------------- ##

  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.agent:9001 --tlsskipverify

    volumes:
      - portainer_data:/data

    networks:
      - ${NOME_REDE_INTERNA}

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(\`${URL_PORTAINER}\`)"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"
        - "traefik.http.routers.portainer.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.portainer.service=portainer"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.priority=1"

## --------------------------- ORION --------------------------- ##

volumes:
  portainer_data:
    external: true
    name: portainer_data

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    attachable: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      portainer.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY DAS STACKS
# =============================================================================
deploy_stacks() {
    echo -e "${amarelo}[6/6] Executando deploy das stacks...${reset}"

    # Traefik
    deploy_via_portainer ""/root/traefik.yaml"" ""traefik""
    if [ $? -eq 0 ]; then
        echo -e "${verde}      [OK] Stack traefik deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy do traefik.${reset}"
        ERRORS=$((ERRORS + 1))
    fi

    # Aguarda Traefik estabilizar
    echo -e "${amarelo}      Aguardando Traefik estabilizar (30s)...${reset}"
    sleep 30

    # Portainer
    deploy_via_portainer ""/root/portainer.yaml"" ""portainer""
    if [ $? -eq 0 ]; then
        echo -e "${verde}      [OK] Stack portainer deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy do portainer.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA EM MARKDOWN (padrão /root/dados_vps/*.md)
# =============================================================================
persist_data() {
    # Traefik
    save_data "traefik" "# Traefik

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **Servidor**: $NOME_SERVIDOR
- **Versão**: traefik:v3.5.3
- **Rede**: $NOME_REDE_INTERNA
- **Email SSL**: $EMAIL_SSL
- **Stack YAML**: /root/traefik.yaml
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

## Configuração
- Entrypoints: HTTP (80 → redirect) e HTTPS (443)
- Certificate Resolver: Let's Encrypt (HTTP Challenge)
- Dashboard: habilitado (acessível via rede interna)"

    # Portainer
    save_data "portainer" "# Portainer

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **Servidor**: $NOME_SERVIDOR
- **Versão**: portainer-ce:latest
- **URL de Acesso**: https://$URL_PORTAINER
- **Stack YAML**: /root/portainer.yaml
- **Status**: $([ $ERRORS -eq 0 ] && echo 'OK' || echo 'ERRO')

## Credenciais Iniciais
> Acesse https://$URL_PORTAINER e crie o usuário admin no primeiro acesso.
> Guarde as credenciais em local seguro — esta skill não gerencia senhas do Portainer."
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
clear
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}       ORION DESIGN — Deploy Traefik + Portainer            ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
setup_swarm
setup_volumes
setup_network
generate_traefik_yaml
generate_portainer_yaml
deploy_stacks
persist_data

echo ""
echo -e "${amarelo}============================================================${reset}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${verde}  Deploy concluído com sucesso.${reset}"
    echo -e "${branco}  Portainer disponível em: https://$URL_PORTAINER${reset}"
else
    echo -e "${vermelho}  Deploy concluído com $ERRORS erro(s).${reset}"
    echo -e "${branco}  Consulte os logs: docker service ls${reset}"
fi
echo -e "${branco}  Dados salvos em: /root/dados_vps/${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

exit $ERRORS
