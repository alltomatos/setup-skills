#!/bin/bash
# =============================================================================
# skills/app-duplicati/run.sh
# Skill: Instalacao do Duplicati via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="duplicati"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Ler ou gerar segredo (idempotência)
ENCRYPTION_KEY=$(read_data "app-duplicati" | grep -oP '(?<=- ENCRYPTION_KEY: ).*' || openssl rand -hex 16)

echo -e "${amarelo}Instalando Duplicati no dominio $DOMAIN_DUPLICATI...${reset}"

docker volume create duplicati_data > /dev/null 2>&1
docker volume create duplicati_backups > /dev/null 2>&1

cat > duplicati.yaml <<YAML
version: "3.7"
services:
  duplicati:
    image: duplicati/duplicati:latest
    volumes:
      - duplicati_data:/data
      - duplicati_backups:/backups
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DUPLICATI__WEBSERVICE_PORT=8200
      - DUPLICATI__WEBSERVICE_INTERFACE=any
      - DUPLICATI__WEBSERVICE_ALLOWED_HOSTNAMES=$DOMAIN_DUPLICATI
      - DUPLICATI__WEBSERVICE_PASSWORD=$PASS_DUPLICATI
      - DUPLICATI__DISABLE_DB_ENCRYPTION=false
      - DUPLICATI__REQUIRE_DB_ENCRYPTION_KEY=true
      - SETTINGS_ENCRYPTION_KEY=$ENCRYPTION_KEY
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.duplicati.rule=Host(\`$DOMAIN_DUPLICATI\`)
        - traefik.http.routers.duplicati.entrypoints=websecure
        - traefik.http.routers.duplicati.tls.certresolver=letsencryptresolver
        - traefik.http.services.duplicati.loadbalancer.server.port=8200
        - traefik.http.routers.duplicati.service=duplicati
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  duplicati_data:
    external: true
  duplicati_backups:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "duplicati.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-duplicati" "[ DUPLICATI ]

Dominio: https://$DOMAIN_DUPLICATI

Host: duplicati

Port: 8200

Senha: $PASS_DUPLICATI

Encryption Key: $ENCRYPTION_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f duplicati.yaml
exit 0
