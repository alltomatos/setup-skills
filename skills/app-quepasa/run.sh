#!/bin/bash
# =============================================================================
# skills/app-quepasa/run.sh
# Skill: Instalação do Quepasa via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="quepasa"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Gerar chaves aleatórias
MASTERKEY=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando Quepasa no domínio $DOMAIN_QUEPASA...${reset}"

docker volume create quepasa_volume > /dev/null 2>&1

cat > quepasa.yaml <<EOL
version: "3.7"
services:
  quepasa:
    image: codeleaks/quepasa:latest
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - quepasa_volume:/opt/quepasa
    environment:
      - DOMAIN=$DOMAIN_QUEPASA
      - MASTERKEY=$MASTERKEY
      - WEBSERVER_PORT=31000
      - ACCOUNTSETUP=true
      - APP_TITLE=OrionDesign
      - TZ=America/Sao_Paulo
      - DBDRIVER=postgres
      - DBHOST=postgres
      - DBDATABASE=quepasa
      - DBPORT=5432
      - DBUSER=postgres
      - DBPASSWORD=\$POSTGRES_PASSWORD
      - DBSSLMODE=disable
      - SIGNING_SECRET=$MASTERKEY
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.quepasa.rule=Host(\`$DOMAIN_QUEPASA\`)"
        - "traefik.http.routers.quepasa.entrypoints=websecure"
        - "traefik.http.routers.quepasa.tls.certresolver=letsencrypt"
        - "traefik.http.services.quepasa.loadbalancer.server.port=31000"
      resources:
        limits:
          cpus: "2"
          memory: 2048M

volumes:
  quepasa_volume:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

docker stack deploy --prune --resolve-image always -c quepasa.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-quepasa" "# Quepasa\n\n- Status: Instalado\n- URL: https://$DOMAIN_QUEPASA\n- MasterKey: $MASTERKEY"
else
    exit 1
fi

rm quepasa.yaml
exit 0
