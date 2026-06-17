#!/bin/bash
# skills/app-wisemapping/run.sh
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"
amarelo="\e[33m"; verde="\e[32m"; reset="\e[0m"
STACK_NAME="wisemapping"; NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")
if ! docker service ls --format "{{.Name}}" | grep -q "^postgres$"; then echo -e "\e[31mErro: infra-postgres nao instalado.\e[0m"; exit 1; fi
JWT_SECRET=$(openssl rand -hex 32)
echo -e "${amarelo}Instalando WiseMapping...${reset}"
mkdir -p /root/wisemapping_data
cat > wisemapping.yaml <<YAML
version: "3.7"
services:
  wisemapping:
    image: wisemapping/wisemapping:latest
    volumes:
      - /root/wisemapping_data:/opt/wisemapping/data
    networks:
      - \$NOME_REDE_INTERNA
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/wisemapping?stringtype=unspecified
      - SPRING_DATASOURCE_USERNAME=postgres
      - SPRING_DATASOURCE_PASSWORD=\$POSTGRES_PASSWORD
      - APP_SITE_UI_BASE_URL=https://\$DOMAIN_WISEMAPPING
      - APP_SITE_API_BASE_URL=https://\$DOMAIN_WISEMAPPING
      - APP_JWT_SECRET=$JWT_SECRET
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.wisemapping.rule=Host(\`\$DOMAIN_WISEMAPPING\`)
        - traefik.http.routers.wisemapping.entrypoints=websecure
        - traefik.http.routers.wisemapping.tls.certresolver=letsencrypt
        - traefik.http.services.wisemapping.loadbalancer.server.port=3000
      resources:
        limits:
          cpus: "1"
          memory: 1024M
volumes:
  wisemapping_data:
    external: true
networks:
  \$NOME_REDE_INTERNA:
    external: true
YAML
deploy_via_portainer "\$STACK_NAME" "wisemapping.yaml"
[ \$? -eq 0 ] && echo -e "\${verde}OK\${reset}" && save_data "app-wisemapping" "# WiseMapping\n\n- Status: Instalado\n- URL: https://\$DOMAIN_WISEMAPPING"
rm -f wisemapping.yaml; exit 0