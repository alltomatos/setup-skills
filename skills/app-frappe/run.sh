#!/bin/bash
# =============================================================================
# skills/app-frappe/run.sh
# Skill: Instalação do Frappe ERPNext via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="erpnext"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Recupera ou gera senhas (ADR-001)
DB_PASSWORD=$(read_data "app-frappe" | grep -oP '(?<=- DB Password Interno: ).*' || openssl rand -hex 16)
FRAPPE_ADMIN_PASSWORD=$(read_data "app-frappe" | grep -oP '(?<=- Admin Password: ).*' || echo "$ADMIN_PASSWORD")

if [ -z "$FRAPPE_ADMIN_PASSWORD" ]; then
    FRAPPE_ADMIN_PASSWORD=$(openssl rand -hex 12)
fi

echo -e "${amarelo}Instalando Frappe ERPNext em $DOMAIN_FRAPPE...${reset}"

# Criando volumes necessários
docker volume create erpnext_sites > /dev/null 2>&1
docker volume create erpnext_logs > /dev/null 2>&1
docker volume create erpnext_db > /dev/null 2>&1
docker volume create erpnext_cache > /dev/null 2>&1
docker volume create erpnext_queue > /dev/null 2>&1
docker volume create erpnext_socketio > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > erpnext${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  frontend:
    image: frappe/erpnext:v15.49.3
    command: ["nginx-entrypoint.sh"]
    volumes:
      - erpnext_sites:/home/frappe/frappe-bench/sites
      - erpnext_logs:/home/frappe/frappe-bench/logs
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - BACKEND=backend:8000
      - SOCKETIO=websocket:9000
      - FRAPPE_SITE_NAME_HEADER=$DOMAIN_FRAPPE
      - FRAPPE_SITE=$DOMAIN_FRAPPE
    deploy:
      mode: replicated
      replicas: 1
      placement: {constraints: [node.role == manager]}
      resources: {limits: {cpus: "2", memory: 2048M}}
      labels:
        - traefik.enable=true
        - traefik.http.routers.erpnext.rule=Host(\`$DOMAIN_FRAPPE\`)
        - traefik.http.services.erpnext.loadbalancer.server.port=8080
        - traefik.http.routers.erpnext.entrypoints=websecure
        - traefik.http.routers.erpnext.tls.certresolver=letsencrypt
        - traefik.http.routers.erpnext.tls=true

  backend:
    image: frappe/erpnext:v15.49.3
    volumes:
      - erpnext_sites:/home/frappe/frappe-bench/sites
      - erpnext_logs:/home/frappe/frappe-bench/logs
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - DB_HOST=db
      - DB_PORT=3306
      - DB_USER=frappe
      - DB_PASSWORD=$DB_PASSWORD
      - MYSQL_ROOT_PASSWORD=$DB_PASSWORD
    deploy:
      placement: {constraints: [node.role == manager]}

  websocket:
    image: frappe/erpnext:v15.49.3
    command: ["node", "/home/frappe/frappe-bench/apps/frappe/socketio.js"]
    volumes:
      - erpnext_sites:/home/frappe/frappe-bench/sites
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      placement: {constraints: [node.role == manager]}

  db:
    image: mariadb:10.6
    command: ["--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci", "--skip-character-set-client-handshake", "--skip-innodb-read-only-compressed"]
    volumes:
      - erpnext_db:/var/lib/mysql
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASSWORD
    deploy:
      placement: {constraints: [node.role == manager]}

  cache:
    image: redis:latest
    volumes: [erpnext_cache:/data]
    networks: [$NOME_REDE_INTERNA]
    deploy: {placement: {constraints: [node.role == manager]}}

  queue:
    image: redis:latest
    volumes: [erpnext_queue:/data]
    networks: [$NOME_REDE_INTERNA]
    deploy: {placement: {constraints: [node.role == manager]}}

  socketio-redis:
    image: redis:latest
    volumes: [erpnext_socketio:/data]
    networks: [$NOME_REDE_INTERNA]
    deploy: {placement: {constraints: [node.role == manager]}}

volumes:
  erpnext_sites: {external: true}
  erpnext_logs: {external: true}
  erpnext_db: {external: true}
  erpnext_cache: {external: true}
  erpnext_queue: {external: true}
  erpnext_socketio: {external: true}

networks:
  $NOME_REDE_INTERNA: {external: true}
YAML

deploy_via_portainer "$STACK_NAME" "erpnext${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    echo -e "${amarelo}Aguardando inicialização para configurar o site...${reset}"
    sleep 30
    
    # Comandos de inicialização manual do site (como no SetupOrion)
    # docker exec -it \$(docker ps -qf "name=erpnext_backend") bash -c "bench new-site $DOMAIN_FRAPPE --mariadb-root-password=$DB_PASSWORD --admin-password=$FRAPPE_ADMIN_PASSWORD --install-app erpnext"
    
    save_data "app-frappe" "[ FRAPPE ]

Dominio: https://$DOMAIN_FRAPPE

Host: frontend

Port: 8080

Usuario: administrator

Senha: $FRAPPE_ADMIN_PASSWORD

DB Password Interno: $DB_PASSWORD

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f erpnext${SUFFIX}.yaml
exit 0
