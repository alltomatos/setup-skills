#!/bin/bash
# =============================================================================
# skills/app-jitsi/run.sh
# Skill: Instalacao do Jitsi Meet via Docker Swarm (4 servicos)
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="jitsi"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Persistencia de Segredos (ADR-001)
if service_exists "app-jitsi"; then
    EXISTING_DATA=$(read_data "app-jitsi")
    JICOFO_SECRET=$(echo "$EXISTING_DATA" | grep "Jicofo Secret: " | sed 's/.*Jicofo Secret: //')
    JICOFO_COMPONENT=$(echo "$EXISTING_DATA" | grep "Jicofo Component: " | sed 's/.*Jicofo Component: //')
    JVB_AUTH=$(echo "$EXISTING_DATA" | grep "JVB Auth: " | sed 's/.*JVB Auth: //')
fi

# Gerar segredos se nao existirem
[ -z "$JICOFO_SECRET" ] && JICOFO_SECRET=$(openssl rand -hex 16)
[ -z "$JICOFO_COMPONENT" ] && JICOFO_COMPONENT=$(openssl rand -hex 16)
[ -z "$JVB_AUTH" ] && JVB_AUTH=$(openssl rand -hex 16)

echo -e "${amarelo}Instalando Jitsi Meet no dominio $DOMAIN_JITSI...${reset}"

# Criar volumes
for vol in web_config web_crontabs transcripts prosody_config prosody_plugins jicofo_config jvb_config; do
    docker volume create jitsi_${vol} > /dev/null 2>&1
done

cat > jitsi.yaml <<'YAML'
version: "3.7"
services:
  jitsi_web:
    image: jitsi/web:stable
    volumes:
      - jitsi_web_config:/config:Z
      - jitsi_web_crontabs:/var/spool/cron/crontabs:Z
      - jitsi_transcripts:/usr/share/jitsi-meet/transcripts:Z
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - TZ=America/Sao_Paulo
      - ENABLE_AUTH=1
      - AUTH_TYPE=internal
      - ENABLE_GUESTS=1
      - ENABLE_LOBBY=1
      - PUBLIC_URL=https://$DOMAIN_JITSI
      - ENABLE_PREJOIN_PAGE=1
      - ENABLE_WELCOME_PAGE=1
      - ENABLE_BREAKOUT_ROOMS=1
      - ENABLE_POLLS=1
      - ENABLE_RAISE_HAND=1
      - ENABLE_P2P=1
      - ENABLE_NOISE_SUPPRESSION=1
      - XMPP_SERVER=jitsi_prosody
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_GUEST_DOMAIN=guest.meet.jitsi
      - XMPP_MUC_DOMAIN=muc.meet.jitsi
      - XMPP_BOSH_URL_BASE=http://jitsi_prosody:5280
      - ENABLE_XMPP_WEBSOCKET=1
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.jitsi_web.rule=Host(`$DOMAIN_JITSI`)
        - traefik.http.routers.jitsi_web.entrypoints=websecure
        - traefik.http.routers.jitsi_web.tls.certresolver=letsencryptresolver
        - traefik.http.services.jitsi_web.loadbalancer.server.port=80
      resources:
        limits:
          cpus: "1"
          memory: 1024M

  jitsi_prosody:
    image: jitsi/prosody:stable
    volumes:
      - jitsi_prosody_config:/config:Z
      - jitsi_prosody_plugins:/prosody-plugins-custom:Z
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - TZ=America/Sao_Paulo
      - ENABLE_AUTH=1
      - AUTH_TYPE=internal
      - ENABLE_GUESTS=1
      - JICOFO_AUTH_USER=focus
      - JICOFO_AUTH_PASSWORD=$JICOFO_SECRET
      - JICOFO_COMPONENT_SECRET=$JICOFO_COMPONENT
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD=$JVB_AUTH
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_GUEST_DOMAIN=guest.meet.jitsi
      - XMPP_MUC_DOMAIN=muc.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - ENABLE_XMPP_WEBSOCKET=1
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

  jitsi_jicofo:
    image: jitsi/jicofo:stable
    volumes:
      - jitsi_jicofo_config:/config:Z
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - TZ=America/Sao_Paulo
      - ENABLE_AUTH=1
      - AUTH_TYPE=internal
      - JICOFO_COMPONENT_SECRET=$JICOFO_COMPONENT
      - JICOFO_AUTH_USER=focus
      - JICOFO_AUTH_PASSWORD=$JICOFO_SECRET
      - XMPP_SERVER=jitsi_prosody
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M

  jitsi_jvb:
    image: jitsi/jvb:stable
    volumes:
      - jitsi_jvb_config:/config:Z
    networks:
      - $NOME_REDE_INTERNA
    ports:
      - target: 10000
        published: 10000
        protocol: udp
        mode: host
      - target: 4443
        published: 4443
        protocol: tcp
        mode: host
    environment:
      - TZ=America/Sao_Paulo
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD=$JVB_AUTH
      - JVB_BREWERY_MUC=jvbbrewery
      - JVB_PORT=10000
      - JVB_TCP_PORT=4443
      - JVB_TCP_HARVESTER_DISABLED=false
      - DOCKER_HOST_ADDRESS=$JITSI_PUBLIC_IP
      - JVB_ADVERTISE_IPS=$JITSI_PUBLIC_IP
      - JVB_STUN_SERVERS=stun.l.google.com:19302
      - XMPP_SERVER=jitsi_prosody
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2048M

volumes:
  jitsi_web_config:
    external: true
  jitsi_web_crontabs:
    external: true
  jitsi_transcripts:
    external: true
  jitsi_prosody_config:
    external: true
  jitsi_prosody_plugins:
    external: true
  jitsi_jicofo_config:
    external: true
  jitsi_jvb_config:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "jitsi.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    echo -e "${amarelo}Aguardando 30s para o Prosody criar o usuario admin...${reset}"
    sleep 30
    docker exec -t "$(docker ps --filter "name=jitsi_prosody" -q)" \
        prosodyctl --config /config/prosody.cfg.lua register $JITSI_USER meet.jitsi $JITSI_PASS 2>/dev/null || true
    save_data "app-jitsi" "[ JITSI ]

Dominio: https://$DOMAIN_JITSI

Host: jitsi_web

Port: 80

Usuario: $JITSI_USER

Senha: $JITSI_PASS

Jicofo Secret: $JICOFO_SECRET

Jicofo Component: $JICOFO_COMPONENT

JVB Auth: $JVB_AUTH

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f jitsi.yaml
exit 0
