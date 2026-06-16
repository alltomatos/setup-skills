#!/bin/bash
# =============================================================================
# skills/infra-mysql/run.sh
# Skill: Instalação do MySQL 8.0 via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
reset="\e[0m"

# Variáveis
STACK_NAME="mysql"
NOME_REDE_INTERNA=$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep "orion" || echo "orion_network")

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD=$(openssl rand -hex 16)
    GEN_PWD=true
else
    GEN_PWD=false
fi

echo -e "${amarelo}Instalando MySQL 8.0 via Docker Swarm...${reset}"

docker volume create mysql_data > /dev/null 2>&1

cat > mysql.yaml <<EOL
version: "3.7"
services:
  mysql:
    image: mysql:8.0
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - $NOME_REDE_INTERNA
    environment:
      - MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
      - TZ=America/Sao_Paulo
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  mysql_data:
    external: true
    name: mysql_data

networks:
  $NOME_REDE_INTERNA:
    external: true
    name: $NOME_REDE_INTERNA
EOL

docker stack deploy --prune --resolve-image always -c mysql.yaml $STACK_NAME

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    
    CONTENT="# MySQL (Infra)

- **Status**: Instalado
- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **Versão**: 8.0
- **Host**: mysql
- **Porta**: 3306
- **Usuário**: root
- **Rede**: $NOME_REDE_INTERNA
- **Senha Gerada**: $([ "$GEN_PWD" = true ] && echo "Sim" || echo "Não")
"
    save_data "infra-mysql" "$CONTENT"
else
    echo -e "${vermelho}Erro ao fazer o deploy da stack MySQL.${reset}"
    exit 1
fi

rm mysql.yaml
exit 0
