#!/bin/bash
# =============================================================================
# skills/app-minio/run.sh
# Skill: Deploy do MinIO via Docker Swarm (Padrão Orion)
#
# Entradas obrigatórias (injetadas pelo Claude como variáveis de ambiente):
#   URL_MINIO          — domínio do painel admin (ex: minio.seudominio.com.br)
#   URL_S3             — domínio da API S3 (ex: s3.seudominio.com.br)
#   SENHA_MINIO        — senha do usuário root/admin (mínimo 8 caracteres)
#   NOME_REDE_INTERNA  — nome da rede overlay Docker
#
# Padrão de persistência:
#   /root/dados_vps/minio.md  — metadados do deploy (SEM senha)
#   /root/minio.yaml          — stack file Docker Swarm
#
# Padrão pegar_senha_minio:
#   Outras skills (ex: app-chatwoot) NÃO leem a senha deste .md.
#   Credenciais de acesso S3 são geradas manualmente via painel MinIO
#   após o deploy e informadas ao Claude para integração.
# =============================================================================
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

# Cores padrão Orion Design
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
vermelho="\e[91m"
reset="\e[0m"

ERRORS=0

# =============================================================================
# VALIDAÇÃO DE ENTRADAS
# =============================================================================
validate_inputs() {
    local missing=0

    [ -z "${URL_MINIO:-}" ]         && echo -e "${vermelho}[ERRO] URL_MINIO não informado.${reset}"         && missing=1
    [ -z "${URL_S3:-}" ]            && echo -e "${vermelho}[ERRO] URL_S3 não informado.${reset}"            && missing=1
    [ -z "${SENHA_MINIO:-}" ]       && echo -e "${vermelho}[ERRO] SENHA_MINIO não informado.${reset}"       && missing=1
    [ -z "${NOME_REDE_INTERNA:-}" ] && echo -e "${vermelho}[ERRO] NOME_REDE_INTERNA não informado.${reset}" && missing=1

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo -e "${amarelo}Uso: URL_MINIO=x URL_S3=y SENHA_MINIO=z NOME_REDE_INTERNA=w ./run.sh${reset}"
        exit 1
    fi

    # Validação comprimento mínimo da senha
    if [ "${#SENHA_MINIO}" -lt 8 ]; then
        echo -e "${vermelho}[ERRO] SENHA_MINIO deve ter no mínimo 8 caracteres.${reset}"
        exit 1
    fi
}

# =============================================================================
# VOLUME PERSISTENTE
# =============================================================================
setup_volume() {
    echo -e "${amarelo}[1/4] Criando volume persistente minio_data...${reset}"

    if ! docker volume ls --format '{{.Name}}' | grep -q "^minio_data$"; then
        docker volume create minio_data > /dev/null 2>&1
        echo -e "${verde}      Volume criado: minio_data${reset}"
    else
        echo -e "${verde}      Volume existente: minio_data${reset}"
    fi
}

# =============================================================================
# GERAÇÃO DO YAML DO MINIO
# =============================================================================
generate_minio_yaml() {
    echo -e "${amarelo}[2/4] Gerando /root/minio.yaml...${reset}"

    cat > /root/minio.yaml << YAML
version: "3.7"
services:

## --------------------------- ORION --------------------------- ##

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=admin
      - MINIO_ROOT_PASSWORD=${SENHA_MINIO}
      - MINIO_BROWSER_REDIRECT_URL=https://${URL_MINIO}
      - MINIO_SERVER_URL=https://${URL_S3}

    volumes:
      - minio_data:/data

    networks:
      - ${NOME_REDE_INTERNA}

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        # --- Painel Admin (porta 9001) ---
        - "traefik.enable=true"
        - "traefik.http.routers.minio-console.rule=Host(\`${URL_MINIO}\`)"
        - "traefik.http.routers.minio-console.entrypoints=websecure"
        - "traefik.http.routers.minio-console.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.minio-console.service=minio-console"
        - "traefik.http.services.minio-console.loadbalancer.server.port=9001"
        - "traefik.http.routers.minio-console.priority=1"
        # --- API S3 (porta 9000) ---
        - "traefik.http.routers.minio-api.rule=Host(\`${URL_S3}\`)"
        - "traefik.http.routers.minio-api.entrypoints=websecure"
        - "traefik.http.routers.minio-api.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.minio-api.service=minio-api"
        - "traefik.http.services.minio-api.loadbalancer.server.port=9000"
        - "traefik.http.routers.minio-api.priority=1"
        - "traefik.docker.network=${NOME_REDE_INTERNA}"

## --------------------------- ORION --------------------------- ##

volumes:
  minio_data:
    external: true
    name: minio_data

networks:
  ${NOME_REDE_INTERNA}:
    external: true
    attachable: true
    name: ${NOME_REDE_INTERNA}
YAML

    echo -e "${verde}      minio.yaml gerado.${reset}"
}

# =============================================================================
# DEPLOY DA STACK
# =============================================================================
deploy_stack() {
    echo -e "${amarelo}[3/4] Executando deploy da stack minio...${reset}"

    if docker stack deploy --prune --resolve-image always -c /root/minio.yaml minio > /dev/null 2>&1; then
        echo -e "${verde}      [OK] Stack minio deployada.${reset}"
    else
        echo -e "${vermelho}      [FAIL] Falha no deploy do minio.${reset}"
        ERRORS=$((ERRORS + 1))
    fi
}

# =============================================================================
# PERSISTÊNCIA EM MARKDOWN (padrão /root/dados_vps/*.md)
# ATENÇÃO: SENHA_MINIO NUNCA é gravada neste arquivo.
# Outras skills leem este .md via grep para obter URL_MINIO e URL_S3.
# =============================================================================
persist_data() {
    echo -e "${amarelo}[4/4] Salvando metadados em /root/dados_vps/minio.md...${reset}"

    save_data "minio" "# MinIO

- **Data do Deploy**: $(date '+%d/%m/%Y %H:%M:%S')
- **Versão**: minio/minio:latest
- **Rede**: ${NOME_REDE_INTERNA}
- **Stack YAML**: /root/minio.yaml
- **Volume de Dados**: minio_data
- **Status**: $([ "$ERRORS" -eq 0 ] && echo 'OK' || echo 'ERRO')

## URLs de Acesso
- **Painel Admin (Console)**: https://${URL_MINIO}
- **API S3 (Endpoint)**: https://${URL_S3}

## Credenciais
- **Usuário Root**: admin
- **Senha Root**: (não armazenada — use o painel para gerar Access Keys)

## Portas Internas
- Painel Admin: 9001
- API S3: 9000

## Pós-instalação
1. Acesse https://${URL_MINIO} com usuário \`admin\` e a senha definida
2. Crie um bucket (ex: \`chatwoot\`, \`attachments\`)
3. Gere Access Key + Secret Key via Identity → Service Accounts
4. Informe as keys ao Claude para integração com outras skills (ex: app-chatwoot)

## Integração com outras skills
- Skills que precisam de storage S3 (ex: Chatwoot) leem este arquivo para obter URL_S3
- As Access Keys são geradas manualmente e informadas separadamente"

    echo -e "${verde}      Metadados salvos (sem senha).${reset}"
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
clear
echo -e "${amarelo}============================================================${reset}"
echo -e "${branco}          ORION DESIGN — Deploy MinIO Object Storage         ${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

validate_inputs
setup_volume
generate_minio_yaml
deploy_stack
persist_data

echo ""
echo -e "${amarelo}============================================================${reset}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${verde}  Deploy concluído com sucesso.${reset}"
    echo -e "${branco}  Painel Admin : https://${URL_MINIO}${reset}"
    echo -e "${branco}  API S3       : https://${URL_S3}${reset}"
    echo -e "${branco}  Usuário      : admin${reset}"
    echo -e "${amarelo}  PRÓXIMO PASSO: Criar bucket e gerar Access Keys no painel.${reset}"
else
    echo -e "${vermelho}  Deploy concluído com $ERRORS erro(s).${reset}"
    echo -e "${branco}  Consulte os logs: docker service ls && docker service logs minio_minio${reset}"
fi
echo -e "${branco}  Dados salvos em: /root/dados_vps/minio.md${reset}"
echo -e "${amarelo}============================================================${reset}"
echo ""

exit $ERRORS
