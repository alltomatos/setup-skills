#!/bin/bash
# =============================================================================
# skills/app-zerobyte/run.sh
# Skill: Instalacao do ZeroByte via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="zerobyte"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Ler ou gerar segredo (idempotência)
APP_SECRET=$(read_data "app-zerobyte" | grep -oP '(?<=APP_SECRET: ).*' || openssl rand -hex 32)

echo -e "${amarelo}Instalando ZeroByte no dominio $DOMAIN_ZEROBYTE...${reset}"

docker volume create zerobyte_data > /dev/null 2>&1

cat > zerobyte.yaml <<YAML
version: "3.7"
services:
  zerobyte:
    image: ghcr.io/nicotsx/zerobyte:latest
    volumes:
      - zerobyte_data:/var/lib/zerobyte
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - BASE_URL=https://$DOMAIN_ZEROBYTE
      - APP_SECRET=$APP_SECRET
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.zerobyte.rule=Host(\`$DOMAIN_ZEROBYTE\`)
        - traefik.http.routers.zerobyte.entrypoints=websecure
        - traefik.http.routers.zerobyte.tls.certresolver=letsencrypt
        - traefik.http.services.zerobyte.loadbalancer.server.port=4096
        - traefik.http.routers.zerobyte.service=zerobyte
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  zerobyte_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "zerobyte.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    CONTENT="[ ZEROBYTE ]

Dominio: https://$DOMAIN_ZEROBYTE

APP_SECRET: $APP_SECRET

Rede: $NOME_REDE_INTERNA"
    save_data "app-zerobyte" "$CONTENT"
else
    exit 1
fi

rm -f zerobyte.yaml
exit 0
