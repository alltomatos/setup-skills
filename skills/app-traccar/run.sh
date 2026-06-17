#!/bin/bash
# =============================================================================
# skills/app-traccar/run.sh
# Skill: Instalação do Traccar via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="traccar"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Traccar em $DOMAIN_TRACCAR...${reset}"

# Geração ou recuperação de senha interna para o banco (ADR-001/002)
MYSQL_PASS=""
if service_exists "app-traccar"; then
    MYSQL_PASS=$(read_data "app-traccar" | grep "\- MySQL Pass:" | cut -d ':' -f 2 | xargs)
fi

if [ -z "$MYSQL_PASS" ]; then
    MYSQL_PASS=$(openssl rand -hex 16)
fi

# Preparando o arquivo de configuração
mkdir -p /opt/traccar/logs
mkdir -p /opt/traccar/conf

cat > /opt/traccar/conf/traccar.xml <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
    <entry key="database.driver">com.mysql.cj.jdbc.Driver</entry>
    <entry key="database.url">jdbc:mysql://db:3306/traccar?allowPublicKeyRetrieval=true&amp;useSSL=false</entry>
    <entry key="database.user">traccar</entry>
    <entry key="database.password">$MYSQL_PASS</entry>
    <entry key="web.port">8082</entry>
</properties>
EOF

docker volume create traccar_data > /dev/null 2>&1
docker volume create traccar_db > /dev/null 2>&1

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > traccar${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  app:
    image: traccar/traccar:latest
    volumes:
      - /opt/traccar/logs:/opt/traccar/logs:rw
      - /opt/traccar/conf/traccar.xml:/opt/traccar/conf/traccar.xml:ro
      - traccar_data:/opt/traccar/data
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - JAVA_OPTS=-Xms1g -Xmx1g -Djava.net.preferIPv4Stack=true
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
        - traefik.http.routers.traccar.rule=Host(\`$DOMAIN_TRACCAR\`)
        - traefik.http.services.traccar.loadbalancer.server.port=8082
        - traefik.http.routers.traccar.service=traccar
        - traefik.http.routers.traccar.entrypoints=websecure
        - traefik.http.routers.traccar.tls.certresolver=letsencrypt
        - traefik.http.routers.traccar.tls=true

  db:
    image: mysql:8.0
    volumes:
      - traccar_db:/var/lib/mysql
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MYSQL_ROOT_PASSWORD=$MYSQL_PASS
      - MYSQL_DATABASE=traccar
      - MYSQL_USER=traccar
      - MYSQL_PASSWORD=$MYSQL_PASS
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  traccar_data:
    external: true
  traccar_db:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "traccar${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-traccar" "# Traccar\n\n- Status: Instalado\n- URL: https://$DOMAIN_TRACCAR\n- MySQL Pass: $MYSQL_PASS\n- Nota: Crie sua conta de administrador no primeiro acesso."
else
    exit 1
fi

rm -f traccar${SUFFIX}.yaml
exit 0
