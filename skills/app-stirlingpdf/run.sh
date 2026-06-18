#!/bin/bash
# skills/app-stirlingpdf/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="stirlingpdf"; NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"
echo -e "${amarelo}Instalando Stirling PDF...${reset}"
for vol in backend_data backend_config backend_logs frontend_data; do
    docker volume create stirlingpdf_${vol} > /dev/null 2>&1
done
cat > stirlingpdf.yaml <<'YAML'
version: "3.7"
services:
  stirlingpdf_backend:
    image: stirlingtools/stirling-pdf:latest
    volumes:
      - stirlingpdf_backend_data:/usr/share/tessdata
      - stirlingpdf_backend_config:/configs
      - stirlingpdf_backend_logs:/logs
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - SECURITY_ENABLELOGIN=true
      - DOCKER_ENABLE_SECURITY=false
      - DISABLE_ADDITIONAL_FEATURES=false
      - UI_APPNAME=$STIRLING_APP_NAME
      - UI_APPNAMENAVBAR=$STIRLING_APP_NAME
      - SYSTEM_DEFAULTLOCALE=pt_BR
      - SYSTEM_MAXFILESIZE=100
      - SYSTEM_GOOGLEVISIBILITY=false
      - METRICS_ENABLED=true
      - LANGS=en_GB,en_US,pt_BR,es_ES,fr_FR,de_DE,it_IT,zh_CN,ja_JP
      - PUID=1000
      - PGID=1000
      - MODE=BACKEND
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  stirlingpdf_frontend:
    image: stirlingtools/stirling-pdf:latest
    volumes:
      - stirlingpdf_frontend_data:/usr/share/nginx/html
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - BACKEND_URL=http://stirlingpdf_backend:8080
      - MODE=FRONTEND
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.stirlingpdf.rule=Host(`$DOMAIN_STIRLINGPDF`)
        - traefik.http.routers.stirlingpdf.entrypoints=websecure
        - traefik.http.routers.stirlingpdf.tls.certresolver=letsencrypt
        - traefik.http.services.stirlingpdf.loadbalancer.server.port=8080
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  stirlingpdf_backend_data:
    external: true
  stirlingpdf_backend_config:
    external: true
  stirlingpdf_backend_logs:
    external: true
  stirlingpdf_frontend_data:
    external: true
networks:
  $NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "$STACK_NAME" "stirlingpdf.yaml"
[ $? -eq 0 ] && echo -e "${verde}OK${reset}" && save_data "app-stirlingpdf" "[ STIRLINGPDF ]

Dominio: https://$DOMAIN_STIRLINGPDF

Host: stirlingpdf_frontend

Port: 8080

Rede: $NOME_REDE_INTERNA"
rm -f stirlingpdf.yaml; exit 0