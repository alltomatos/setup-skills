#!/bin/bash
# skills/app-keycloak/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="keycloak"; NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi
echo -e "${amarelo}Instalando Keycloak...${reset}"
cat > keycloak.yaml <<'YAML'
version: "3.7"
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    command: start
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - KEYCLOAK_ADMIN=$KEYCLOAK_USER
      - KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_PASS
      - TZ=America/Sao_Paulo
      - KC_HOSTNAME=$DOMAIN_KEYCLOAK
      - KC_HOSTNAME_STRICT=false
      - KC_HOSTNAME_STRICT_HTTPS=false
      - KC_HOSTNAME_STRICT_BACKCHANNEL=false
      - KC_HTTP_ENABLED=true
      - KC_PROXY_HEADERS=xforwarded
      - KC_HTTP_RELATIVE_PATH=/
      - KC_DB=postgres
      - KC_DB_URL=jdbc:postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/keycloak?sslmode=disable
      - KC_DB_USERNAME=postgres
      - KC_DB_PASSWORD=$POSTGRES_PASSWORD
      - KC_HEALTH_ENABLED=true
      - KC_METRICS_ENABLED=true
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.keycloak.rule=Host(`$DOMAIN_KEYCLOAK`)
        - traefik.http.routers.keycloak.entrypoints=websecure
        - traefik.http.routers.keycloak.tls.certresolver=letsencryptresolver
        - traefik.http.routers.keycloak.tls=true
        - traefik.http.services.keycloak.loadbalancer.server.port=8080
        - traefik.http.routers.keycloak.middlewares=keycloak_headers
        - traefik.http.middlewares.keycloak_headers.headers.customrequestheaders.X-Forwarded-Proto=https
        - traefik.http.middlewares.keycloak_headers.headers.customrequestheaders.X-Forwarded-Host=$DOMAIN_KEYCLOAK
      resources:
        limits:
          cpus: "2"
          memory: 2048M
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "keycloak.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-keycloak" "[ KEYCLOAK ]

Dominio: https://$DOMAIN_KEYCLOAK

Host: keycloak

Port: 8080

Usuario: $KEYCLOAK_USER

Senha: $KEYCLOAK_PASS

Rede: $NOME_REDE_INTERNA"
rm -f keycloak.yaml; exit 0