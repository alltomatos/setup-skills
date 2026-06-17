#!/bin/bash
# skills/app-docuseal/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="docuseal"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi

# Persistencia de Segredos (ADR-001)
if service_exists "app-docuseal"; then
    SECRET_KEY=$(read_data "app-docuseal" | grep "App Key: " | sed 's/.*App Key: //')
fi
[ -z "$SECRET_KEY" ] && SECRET_KEY=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando DocuSeal...${reset}"
docker volume create docuseal_data > /dev/null 2>&1
cat > docuseal.yaml <<'YAML'
version: "3.7"
services:
  docuseal:
    image: docuseal/docuseal:latest
    volumes:
      - docuseal_data:/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - HOST=$DOMAIN_DOCUSEAL
      - FORCE_SSL=true
      - SECRET_KEY_BASE=$SECRET_KEY
      - DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/docuseal?sslmode=disable
      - SMTP_USERNAME=$SMTP_USER
      - SMTP_PASSWORD=$SMTP_PASS
      - SMTP_ADDRESS=$SMTP_HOST
      - SMTP_PORT=$SMTP_PORT
      - SMTP_FROM=$SMTP_FROM_EMAIL
      - SMTP_AUTHENTICATION=login
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.docuseal.rule=Host(`$DOMAIN_DOCUSEAL`)
        - traefik.http.routers.docuseal.entrypoints=websecure
        - traefik.http.routers.docuseal.tls.certresolver=letsencrypt
        - traefik.http.services.docuseal.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  docuseal_data:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "docuseal.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-docuseal" "# DocuSeal\n\n- Status: Instalado\n- URL: https://$DOMAIN_DOCUSEAL\n- App Key: $SECRET_KEY"
rm -f docuseal.yaml; exit 0