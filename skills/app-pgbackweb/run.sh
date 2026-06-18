#!/bin/bash
# =============================================================================
# skills/app-pgbackweb/run.sh
# Skill: Instalação do PgBackWeb via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="pgbackweb"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Carregar credenciais do Postgres (ADR-001)
if [ -f "/root/dados_vps/dados_postgres" ]; then
    POSTGRES_PASS=$(grep "Senha:" /root/dados_vps/dados_postgres | awk '{print $2}')
else
    POSTGRES_PASS=$POSTGRES_PASSWORD
fi

# Recupera ou gera chave de criptografia (ADR-001)
PBW_ENCRYPTION_KEY=$(read_data "app-pgbackweb" | grep -oP '(?<=- Encryption Key: ).*' || openssl rand -hex 32)

echo -e "${amarelo}Instalando PgBackWeb em $DOMAIN_PGBACKWEB...${reset}"

docker volume create pgbackweb_backups > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > pgbackweb${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: eduardolat/pgbackweb:latest
    volumes:
      - pgbackweb_backups:/backups
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - PBW_ENCRYPTION_KEY=$PBW_ENCRYPTION_KEY
      - PBW_POSTGRES_CONN_STRING=postgresql://postgres:$POSTGRES_PASS@postgres:5432/pgbackweb?sslmode=disable
      - TZ=America/Sao_Paulo
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M
      labels:
        - traefik.enable=true
        - traefik.http.routers.pgbackweb.rule=Host(\`$DOMAIN_PGBACKWEB\`)
        - traefik.http.services.pgbackweb.loadbalancer.server.port=8085
        - traefik.http.routers.pgbackweb.service=pgbackweb
        - traefik.http.routers.pgbackweb.entrypoints=websecure
        - traefik.http.routers.pgbackweb.tls.certresolver=letsencryptresolver
        - traefik.http.routers.pgbackweb.tls=true

volumes:
  pgbackweb_backups:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

ensure_db "postgres" "pgbackweb" || { echo "Erro ao preparar o banco no postgres"; exit 1; }
deploy_via_portainer "$STACK_NAME" "pgbackweb${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-pgbackweb" "[ PGBACKWEB ]

Dominio: https://$DOMAIN_PGBACKWEB

Host: app

Port: 8085

Encryption Key: $PBW_ENCRYPTION_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f pgbackweb${SUFFIX}.yaml
exit 0
