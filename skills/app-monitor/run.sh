#!/bin/bash
# =============================================================================
# skills/app-monitor/run.sh
# Skill: Instalação da Stack de Monitoramento (Grafana + Prometheus)
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="monitor"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Configurando recursos do Monitor Orion...${reset}"

# Baixando recursos (Configurações do Grafana/Prometheus)
mkdir -p /tmp/orion_resources
cd /tmp/orion_resources
git clone https://github.com/oriondesign2015/SetupOrion.git > /dev/null 2>&1

if [ -d "/opt/monitor-orion" ]; then
  sudo rm -r /opt/monitor-orion
fi
sudo mkdir -p /opt
sudo mv /tmp/orion_resources/SetupOrion/Extras/Grafana/monitor-orion /opt
rm -rf /tmp/orion_resources

# Criando datasource do Grafana
cat > /root/datasource.yml <<EOL
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  url: https://$DOMAIN_PROMETHEUS
  isDefault: true
  access: proxy
  editable: true
EOL

sudo cp /root/datasource.yml /opt/monitor-orion/grafana/
sudo cp /root/datasource.yml /opt/monitor-orion/grafana/provisioning/datasources/
rm /root/datasource.yml

# Criando configuração do Prometheus
cat > /root/prometheus.yml <<EOL
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 15s
alerting:
  alertmanagers:
  - static_configs:
    - targets: []
    scheme: http
    timeout: 10s
    api_version: v2
scrape_configs:
- job_name: prometheus
  honor_timestamps: true
  scrape_interval: 15s
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
  static_configs:
  - targets: ['$DOMAIN_PROMETHEUS','$DOMAIN_CADVISOR','$DOMAIN_NODEEXPORTER']
EOL

sudo mv /root/prometheus.yml /opt/monitor-orion/prometheus/

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > monitor${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - /opt/monitor-orion/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager    
      labels:
        - traefik.enable=true
        - traefik.http.routers.prometheus.rule=Host(\`$DOMAIN_PROMETHEUS\`)
        - traefik.http.routers.prometheus.entrypoints=websecure
        - traefik.http.routers.prometheus.tls.certresolver=letsencrypt
        - traefik.http.routers.prometheus.service=prometheus
        - traefik.http.services.prometheus.loadbalancer.server.port=9090

  grafana:
    image: grafana/grafana:latest
    volumes:
      - /opt/monitor-orion/grafana/grafana.ini:/etc/grafana/grafana.ini
      - /opt/monitor-orion/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources
      - /opt/monitor-orion/grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards
      - /opt/monitor-orion/grafana/dashboards:/etc/grafana/dashboards
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.grafana.rule=Host(\`$DOMAIN_GRAFANA\`)
        - traefik.http.routers.grafana.entrypoints=websecure
        - traefik.http.routers.grafana.tls.certresolver=letsencrypt
        - traefik.http.routers.grafana.service=grafana
        - traefik.http.services.grafana.loadbalancer.server.port=3000

  node-exporter:
    image: prom/node-exporter:latest
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.node-exporter.rule=Host(\`$DOMAIN_NODEEXPORTER\`)
        - traefik.http.routers.node-exporter.entrypoints=websecure
        - traefik.http.routers.node-exporter.tls.certresolver=letsencrypt
        - traefik.http.routers.node-exporter.service=node-exporter
        - traefik.http.services.node-exporter.loadbalancer.server.port=9100

  cadvisor:
    image: gcr.io/cadvisor/cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /sys/fs/cgroup:/sys/fs/cgroup
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager     
      labels:
        - traefik.enable=true
        - traefik.http.routers.cadvisor.rule=Host(\`$DOMAIN_CADVISOR\`)
        - traefik.http.routers.cadvisor.entrypoints=websecure
        - traefik.http.routers.cadvisor.tls.certresolver=letsencrypt
        - traefik.http.routers.cadvisor.service=cadvisor
        - traefik.http.services.cadvisor.loadbalancer.server.port=8080

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "monitor${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-monitor" "# Monitor Orion\n\n- Status: Instalado\n- Grafana: https://$DOMAIN_GRAFANA\n- Prometheus: https://$DOMAIN_PROMETHEUS"
else
    exit 1
fi

rm -f monitor${SUFFIX}.yaml
exit 0
