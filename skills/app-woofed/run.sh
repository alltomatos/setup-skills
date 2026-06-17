#!/bin/bash
# =============================================================================
# skills/app-woofed/run.sh
# Skill: Instalação do WoofedCRM via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="woofed"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

# Chave secreta aleatória
SECRET_KEY_BASE=$(openssl rand -hex 32)

echo -e "${amarelo}Instalando WoofedCRM no domínio $DOMAIN_WOOFED...${reset}"

docker volume create woofed_data > /dev/null 2>&1

cat > woofed.yaml <<EOL
version: "3.7"
services:
  woofed_web:
    image: douglara/woofedcrm:latest
    command: bash -c "bundle exec rails db:prepare && bundle exec puma -C config/puma.rb"
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - woofed_data:/app/storage
    environment:
      - FRONTEND_URL=https://$DOMAIN_WOOFED
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - LANGUAGE=pt-BR
      - ENABLE_USER_SIGNUP=true
      - MOTOR_AUTH_USERNAME=$MOTOR_USER
      - MOTOR_AUTH_PASSWORD=$MOTOR_PASS
      - DEFAULT_TIMEZONE=Brasilia
      - DATABASE_URL=postgres://postgres:\$PGVECTOR_PASSWORD@pgvector:5432/woofed
      - REDIS_URL=redis://redis:6379/0
      - ACTIVE_STORAGE_SERVICE=local
      - RAILS_ENV=production
      - RACK_ENV=production
      - NODE_ENV=production
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.woofed.rule=Host(\`$DOMAIN_WOOFED\`)"
        - "traefik.http.routers.woofed.entrypoints=websecure"
        - "traefik.http.routers.woofed.tls.certresolver=letsencrypt"
        - "traefik.http.services.woofed.loadbalancer.server.port=3000"
        - "traefik.http.middlewares.woofed-ssl.headers.customrequestheaders.X-Forwarded-Proto=https"
        - "traefik.http.routers.woofed.middlewares=woofed-ssl"
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  woofed_sidekiq:
    image: douglara/woofedcrm:latest
    command: bundle exec sidekiq -C config/sidekiq.yml
    networks:
      - $NOME_REDE_INTERNA
    volumes:
      - woofed_data:/app/storage
    environment:
      - FRONTEND_URL=https://$DOMAIN_WOOFED
      - SECRET_KEY_BASE=$SECRET_KEY_BASE
      - LANGUAGE=pt-BR
      - MOTOR_AUTH_USERNAME=$MOTOR_USER
      - MOTOR_AUTH_PASSWORD=$MOTOR_PASS
      - DATABASE_URL=postgres://postgres:\$PGVECTOR_PASSWORD@pgvector:5432/woofed
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=production
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

volumes:
  woofed_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
EOL

deploy_via_portainer "$STACK_NAME" "woofed.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-woofed" "# WoofedCRM\n\n- Status: Instalado\n- URL: https://$DOMAIN_WOOFED\n- Motor User: $MOTOR_USER"
else
    exit 1
fi

rm woofed.yaml
exit 0
