#!/bin/bash
# =============================================================================
# skills/infra-bootstrap/run.sh
# Skill: Verificação e preparação do ambiente Debian 11 para o ecossistema Setup Orion
#
# Padrão:
#   - Executado como root
#   - Idempotente: verifica existência antes de instalar
#   - Loga cada etapa em /root/dados_vps/dados_bootstrap
#   - Usa lib-persistence.sh para escrita estruturada
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores (padrão Orion Design)
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
vermelho="\e[91m"
reset="\e[0m"

LOG_FILE="/root/dados_vps/dados_bootstrap"
ERRORS=0
INSTALLED=()
PRESENT=()
FAILED=()

# -----------------------------------------------------------------------------
# Inicializa o log Markdown
# -----------------------------------------------------------------------------
init_log() {
    mkdir -p /root/dados_vps
    cat > "$LOG_FILE" <<MD
# Bootstrap do Ambiente Orion

- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **Usuário**: $(whoami)
- **Hostname**: $(hostname)
- **OS**: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

## Verificação de Pacotes
MD
}

# -----------------------------------------------------------------------------
# Verifica pré-requisitos críticos: root e SO
# -----------------------------------------------------------------------------
check_requirements() {
    echo -e "${amarelo}Verificando pré-requisitos...${reset}"

    # Root obrigatório
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${vermelho}[ERRO] Este script precisa ser executado como root.${reset}"
        echo "## Erro Fatal" >> "$LOG_FILE"
        echo "- Execução abortada: usuário não é root." >> "$LOG_FILE"
        exit 1
    fi

    # OS recomendado: Debian 11
    if ! grep -q 'PRETTY_NAME="Debian GNU/Linux 11' /etc/os-release 2>/dev/null; then
        echo -e "${amarelo}[AVISO] Sistema operacional não é Debian 11. Prosseguindo com cautela.${reset}"
        echo "- **Aviso**: SO não é Debian 11. Instalação pode apresentar incompatibilidades." >> "$LOG_FILE"
    fi

    # Diretório /root
    if [ "$PWD" != "/root" ]; then
        echo -e "${amarelo}Mudando para /root...${reset}"
        cd /root || exit 1
    fi
}

# -----------------------------------------------------------------------------
# Instala pacote com verificação de existência (idempotente)
# Uso: check_pkg <nome-binario> <nome-pacote-apt>
# -----------------------------------------------------------------------------
check_pkg() {
    local bin="$1"
    local pkg="${2:-$1}"

    printf "${branco}%-35s${reset}" "Verificando $pkg..."

    if command -v "$bin" &>/dev/null; then
        echo -e "${verde}[  OK  ] Já instalado${reset}"
        echo "- [x] \`$pkg\` — já presente no sistema" >> "$LOG_FILE"
        PRESENT+=("$pkg")
    else
        echo -e "${amarelo}[ INST ] Instalando...${reset}"
        if apt-get install -y "$pkg" > /dev/null 2>&1; then
            echo -e "${verde}[  OK  ] $pkg instalado com sucesso${reset}"
            echo "- [x] \`$pkg\` — instalado nesta execução" >> "$LOG_FILE"
            INSTALLED+=("$pkg")
        else
            echo -e "${vermelho}[ FAIL ] Falha ao instalar $pkg${reset}"
            echo "- [ ] \`$pkg\` — **FALHA NA INSTALAÇÃO**" >> "$LOG_FILE"
            FAILED+=("$pkg")
            ERRORS=$((ERRORS + 1))
        fi
    fi
}

# -----------------------------------------------------------------------------
# Verificação e configuração do Docker
# -----------------------------------------------------------------------------
check_docker() {
    printf "${branco}%-35s${reset}" "Verificando Docker..."

    if ! command -v docker &>/dev/null; then
        echo -e "${amarelo}[ INST ] Instalando Docker...${reset}"
        curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${verde}[  OK  ] Docker instalado${reset}"
            echo "- [x] \`docker\` — instalado via script oficial" >> "$LOG_FILE"
            INSTALLED+=("docker")
        else
            echo -e "${vermelho}[ FAIL ] Falha ao instalar Docker${reset}"
            echo "- [ ] \`docker\` — **FALHA NA INSTALAÇÃO**" >> "$LOG_FILE"
            FAILED+=("docker")
            ERRORS=$((ERRORS + 1))
            return
        fi
    else
        echo -e "${verde}[  OK  ] Já instalado${reset}"
        echo "- [x] \`docker\` — já presente no sistema" >> "$LOG_FILE"
        PRESENT+=("docker")
    fi

    # Garante configuração DOCKER_MIN_API_VERSION=1.24 (padrão Orion)
    local override="/etc/systemd/system/docker.service.d/override.conf"
    if ! grep -q "DOCKER_MIN_API_VERSION=1.24" "$override" 2>/dev/null; then
        mkdir -p /etc/systemd/system/docker.service.d
        cat > "$override" <<CONF
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
CONF
        systemctl daemon-reload > /dev/null 2>&1
        systemctl restart docker > /dev/null 2>&1
        echo "  - Docker API mínima configurada para 1.24" >> "$LOG_FILE"
    fi
}

# -----------------------------------------------------------------------------
# Gera relatório final em Markdown
# -----------------------------------------------------------------------------
finalize_log() {
    cat >> "$LOG_FILE" <<MD

## Resumo Final

| Categoria       | Quantidade |
|-----------------|------------|
| Já presentes    | ${#PRESENT[@]} |
| Instalados agora| ${#INSTALLED[@]} |
| Com falha       | ${#FAILED[@]} |

MD

    if [ ${#FAILED[@]} -gt 0 ]; then
        echo "### ⚠️ Pacotes com falha" >> "$LOG_FILE"
        for pkg in "${FAILED[@]}"; do
            echo "- \`$pkg\`" >> "$LOG_FILE"
        done
    fi

    echo "---" >> "$LOG_FILE"
    echo "_Gerado automaticamente pela skill \`infra-bootstrap\`_" >> "$LOG_FILE"
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
clear 2>/dev/null || true
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}         ORION DESIGN — Bootstrap de Infraestrutura         ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

init_log
check_requirements

echo ""
echo -e "${amarelo}Atualizando repositórios de pacotes...${reset}"
apt-get update -y > /dev/null 2>&1

echo ""
echo -e "${amarelo}Verificando dependências do sistema:${reset}"
echo ""
check_pkg "sudo"        "sudo"
check_pkg "git"         "git"
check_pkg "python3"     "python3"
check_pkg "jq"          "jq"
check_pkg "curl"        "curl"
check_pkg "htpasswd"    "apache2-utils"
check_docker

finalize_log

echo ""
echo -e "${amarelo}============================================================${reset}"

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${verde}  Bootstrap concluído com sucesso.${reset}"
else
    echo -e "${vermelho}  Bootstrap concluído com $ERRORS erro(s). Verifique /root/dados_vps/dados_bootstrap${reset}"
fi

echo -e "${branco}  Relatório salvo em: /root/dados_vps/dados_bootstrap${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

exit $ERRORS
