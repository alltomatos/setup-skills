#!/bin/bash
# =============================================================================
# skills/app-ntfy/run.sh
# Skill: Instalação do ntfy via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="ntfy"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando ntfy em $DOMAIN_NTFY...${reset}"

# Gerar Hash para Basic Auth no Traefik (ADR-002)
# Requer apache2-utils instalado ou usar python
HASHED_PASS=$(openssl passwd -apr1 "$NTFY_PASSWORD")
TRAEFIK_AUTH="$NTFY_USER:${HASHED_PASS//$/$$}"

docker volume create ntfy_cache > /dev/null 2>&1
docker volume create ntfy_etc > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > ntfy${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: binwiederhier/ntfy:latest
    command: ["serve"]
    volumes:
      - ntfy_cache:/var/cache/ntfy
      - ntfy_etc:/etc/ntfy
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - TZ=America/Sao_Paulo
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
      labels:
        - traefik.enable=true
        - traefik.http.routers.ntfy.rule=Host(\`$DOMAIN_NTFY\`)
        - traefik.http.services.ntfy.loadbalancer.server.port=80
        - traefik.http.routers.ntfy.service=ntfy
        - traefik.http.routers.ntfy.entrypoints=websecure
        - traefik.http.routers.ntfy.tls.certresolver=letsencrypt
        - traefik.http.middlewares.ntfy-auth.basicauth.users=$TRAEFIK_AUTH
        - traefik.http.routers.ntfy.middlewares=ntfy-auth
        - traefik.http.routers.ntfy.tls=true

volumes:
  ntfy_cache:
    external: true
  ntfy_etc:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "ntfy${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-ntfy" "# ntfy\n\n- Status: Instalado\n- URL: https://$DOMAIN_NTFY\n- Usuário: $NTFY_USER"
else
    exit 1
fi

rm -f ntfy${SUFFIX}.yaml
exit 0
