# Skill: Monitor Orion

Instala a stack de monitoramento padrão do ecossistema Orion, composta por Grafana, Prometheus, cAdvisor e NodeExporter.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.

## Inputs solicitados

- `DOMAIN_GRAFANA`: Domínio para acesso ao painel do Grafana.
- `DOMAIN_PROMETHEUS`: Domínio para acesso ao Prometheus.
- `DOMAIN_CADVISOR`: Domínio para métricas de containers.
- `DOMAIN_NODEEXPORTER`: Domínio para métricas do host.

## Pós-instalação

1. Acesse o Grafana em `https://<DOMAIN_GRAFANA>`.
2. O datasource Prometheus já vem pré-configurado.
3. Dashboards padrão podem ser encontrados em `/opt/monitor-orion/grafana/dashboards`.

## Persistência

Os arquivos de configuração são armazenados em `/opt/monitor-orion/`.
A persistência da skill é salva em `/root/dados_vps/app-monitor.md`.
