#!/bin/bash
# =============================================================================
# skills/app-odoo/run.sh
# Skill: Instalação do Odoo via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="odoo"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Geração de senha para banco interno (ADR-002)
DB_PASSWORD=$(openssl rand -hex 16)

# Validar versão ou assumir padrão
if [ -z "$ODOO_VERSION" ]; then
    ODOO_VERSION="17.0"
fi

echo -e "${amarelo}Instalando Odoo ($ODOO_VERSION) em $DOMAIN_ODOO...${reset}"

docker volume create odoo_app_data > /dev/null 2>&1
docker volume create odoo_app_config > /dev/null 2>&1
docker volume create odoo_app_addons > /dev/null 2>&1
docker volume create odoo_db_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > odoo${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: odoo:$ODOO_VERSION
    volumes:
      - odoo_app_data:/var/lib/odoo
      - odoo_app_config:/etc/odoo
      - odoo_app_addons:/mnt/extra-addons
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - HOST=db
      - USER=odoo
      - PASSWORD=$DB_PASSWORD
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.odoo.rule=Host(\`$DOMAIN_ODOO\`)
        - traefik.http.routers.odoo.entrypoints=websecure
        - traefik.http.routers.odoo.tls.certresolver=letsencrypt
        - traefik.http.routers.odoo.service=odoo
        - traefik.http.services.odoo.loadbalancer.server.port=8069
        - traefik.http.routers.odoo.tls=true

  db:
    image: postgres:15
    volumes:
      - odoo_db_data:/var/lib/postgresql/data/pgdata
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - POSTGRES_USER=odoo
      - PGDATA=/var/lib/postgresql/data/pgdata
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  odoo_app_data:
    external: true
  odoo_app_config:
    external: true
  odoo_app_addons:
    external: true
  odoo_db_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "odoo${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-odoo" "# Odoo\n\n- Status: Instalado\n- URL: https://$DOMAIN_ODOO\n- Versão: $ODOO_VERSION\n- DB Password Interno: $DB_PASSWORD\n\n*Nota: Acesse para configurar a Master Password e o primeiro banco de dados.*"
else
    exit 1
fi

rm -f odoo${SUFFIX}.yaml
exit 0
