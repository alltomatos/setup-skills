#!/bin/bash
# =============================================================================
# skills/app-rustdesk/run.sh
# Skill: Instalação do RustDesk Server via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="rustdesk"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Geração ou recuperação de chave do RustDesk (ADR-001/002)
RUSTDESK_KEY=""
if service_exists "app-rustdesk"; then
    RUSTDESK_KEY=$(read_data "app-rustdesk" | grep "\- Public Key:" | cut -d ':' -f 2 | xargs)
fi

if [ -z "$RUSTDESK_KEY" ]; then
    RUSTDESK_KEY=$(openssl rand -hex 16)
fi

# Função para gerar a string de configuração base64 (rev)
generate_rustdesk_string() {
    local json="{\"host\":\"$DOMAIN_HBBS\",\"relay\":\"$DOMAIN_HBBR\",\"api\":\"\",\"key\":\"$RUSTDESK_KEY\"}"
    echo -n "$json" | base64 -w 0 | rev
}

RUSTDESK_STRING=$(generate_rustdesk_string)

echo -e "${amarelo}Instalando RustDesk Server em $DOMAIN_HBBS / $DOMAIN_HBBR...${reset}"

docker volume create rustdesk_data > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > rustdesk${SUFFIX}.yaml <<YAML
version: "3.8"
services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    command: hbbs -r $DOMAIN_HBBR -k $RUSTDESK_KEY
    volumes:
      - rustdesk_data:/root
    networks:
      - $NOME_REDE_INTERNA
    ports:
      - 21115:21115
      - 21116:21116
      - 21116:21116/udp
      - 21118:21118
    environment:
      - ALWAYS_USE_RELAY=N
      - RELAY=$DOMAIN_HBBR
      - KEY=$RUSTDESK_KEY
      - RUST_LOG=info
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.rustdesk-hbbs.rule=Host(\`$DOMAIN_HBBS\`)
        - traefik.http.routers.rustdesk-hbbs.entrypoints=websecure
        - traefik.http.routers.rustdesk-hbbs.tls.certresolver=letsencryptresolver
        - traefik.http.services.rustdesk-hbbs.loadbalancer.server.port=21116

  hbbr:
    image: rustdesk/rustdesk-server:latest
    command: hbbr -k $RUSTDESK_KEY
    volumes:
      - rustdesk_data:/root
    networks:
      - $NOME_REDE_INTERNA
    ports:
      - 21117:21117
      - 21119:21119
    environment:
      - KEY=$RUSTDESK_KEY
      - LIMIT_SPEED=200
      - SINGLE_BANDWIDTH=50
      - TOTAL_BANDWIDTH=500
      - RUST_LOG=info
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.rustdesk-hbbr.rule=Host(\`$DOMAIN_HBBR\`)
        - traefik.http.routers.rustdesk-hbbr.entrypoints=websecure
        - traefik.http.routers.rustdesk-hbbr.tls.certresolver=letsencryptresolver
        - traefik.http.services.rustdesk-hbbr.loadbalancer.server.port=21117

volumes:
  rustdesk_data:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "rustdesk${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-rustdesk" "[ RUSTDESK ]

Dominio: https://$DOMAIN_HBBS

ID Server: $DOMAIN_HBBS

Relay Server: $DOMAIN_HBBR

Public Key: $RUSTDESK_KEY

Config String: $RUSTDESK_STRING

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f rustdesk${SUFFIX}.yaml
exit 0
