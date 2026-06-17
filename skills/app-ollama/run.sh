#!/bin/bash
# =============================================================================
# skills/app-ollama/run.sh
# Skill: Instalação do Ollama via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="ollama"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

echo -e "${amarelo}Instalando Ollama via Docker Swarm...${reset}"

docker volume create ollama_data > /dev/null 2>&1

cat > ollama.yaml <<EOL
version: "3.7"
services:
  ollama:
    image: ollama/ollama:latest
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - $NOME_REDE_INTERNA
    deploy:
      resources:
        limits:
          cpus: "4" # LLMs locais exigem mais CPU/GPU
          memory: 4096M
EOL

deploy_via_portainer "$STACK_NAME" "ollama.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-ollama" "# Ollama (AI/Local LLM)\n\n- Status: Instalado\n- Host: ollama\n- Porta: 11434"
else
    exit 1
fi

rm ollama.yaml
exit 0
