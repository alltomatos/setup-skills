#!/bin/bash
# skills/app-documenso/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="documenso"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi
KEY1=$(openssl rand -hex 16); KEY2=$(openssl rand -hex 16); KEY3=$(openssl rand -hex 16)
SMTP_SECURE="false"; [ "$SMTP_PORT" -eq 465 ] && SMTP_SECURE="true"
echo -e "${amarelo}Instalando Documenso...${reset}"
docker volume create documenso_cert > /dev/null 2>&1
cat > documenso.yaml <<'YAML'
version: "3.7"
services:
  documenso:
    image: documenso/documenso:latest
    volumes:
      - documenso_cert:/opt/documenso/cert.p12
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - PORT=3000
      - NEXTAUTH_URL=https://$DOMAIN_DOCUMENSO
      - NEXT_PUBLIC_WEBAPP_URL=https://$DOMAIN_DOCUMENSO
      - NEXTAUTH_SECRET=$KEY1
      - NEXT_PRIVATE_ENCRYPTION_KEY=$KEY2
      - NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY=$KEY3
      - NEXT_PRIVATE_DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/documenso?sslmode=disable
      - NEXT_PRIVATE_DIRECT_DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/documenso?sslmode=disable
      - NEXT_PUBLIC_UPLOAD_TRANSPORT=local
      - NEXT_PRIVATE_SMTP_TRANSPORT=smtp-auth
      - NEXT_PRIVATE_SMTP_FROM_ADDRESS=$SMTP_FROM_EMAIL
      - NEXT_PRIVATE_SMTP_USERNAME=$SMTP_USER
      - NEXT_PRIVATE_SMTP_PASSWORD=$SMTP_PASS
      - NEXT_PRIVATE_SMTP_HOST=$SMTP_HOST
      - NEXT_PRIVATE_SMTP_PORT=$SMTP_PORT
      - NEXT_PRIVATE_SMTP_SECURE=$SMTP_SECURE
      - NEXT_PRIVATE_SMTP_FROM_NAME=Suporte
      - NEXT_PUBLIC_DOCUMENT_SIZE_UPLOAD_LIMIT=10
      - NEXT_PUBLIC_DISABLE_SIGNUP=false
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.documenso.rule=Host(`$DOMAIN_DOCUMENSO`)
        - traefik.http.routers.documenso.entrypoints=websecure
        - traefik.http.routers.documenso.tls.certresolver=letsencrypt
        - traefik.http.services.documenso.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  documenso_cert:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "documenso.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-documenso" "# Documenso\n\n- Status: Instalado\n- URL: https://$DOMAIN_DOCUMENSO"
rm -f documenso.yaml; exit 0