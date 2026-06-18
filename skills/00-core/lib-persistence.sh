#!/bin/bash
# =============================================================================
# skills/00-core/lib-persistence.sh
# Biblioteca de persistência centralizada do ecossistema Setup Orion
#
# Padrão:
#   - Todo dado persistido em /root/dados_vps/*.md
#   - index.md mantém catálogo de todas as instalações
#   - Escrita atômica via arquivo temporário (evita corrupção)
# =============================================================================

DATA_DIR="/root/dados_vps"

# Garante que o diretório de dados existe
_ensure_data_dir() {
    mkdir -p "$DATA_DIR"
}

# -----------------------------------------------------------------------------
# Salva dados de uma skill em arquivo .md
# Uso: save_data "nome-serviço" "conteúdo markdown completo"
# -----------------------------------------------------------------------------
save_data() {
    local service="$1"
    local content="$2"
    local target="$DATA_DIR/$service.md"
    local tmp
    tmp=$(mktemp)

    _ensure_data_dir

    # Escrita atômica: escreve no temp e move (evita corrupção em falhas)
    echo "$content" > "$tmp" && mv "$tmp" "$target"

    # Atualiza o índice central
    _update_index "$service"
}

# -----------------------------------------------------------------------------
# Lê dados de uma skill persistida
# Uso: read_data "nome-serviço"
# -----------------------------------------------------------------------------
read_data() {
    local service="$1"
    local target="$DATA_DIR/$service.md"

    if [ -f "$target" ]; then
        cat "$target"
    else
        echo "[lib-persistence] Nenhum dado encontrado para: $service"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Verifica se um serviço já foi instalado/registrado
# Uso: service_exists "nome-serviço" → retorna 0 (sim) ou 1 (não)
# -----------------------------------------------------------------------------
service_exists() {
    [ -f "$DATA_DIR/$1.md" ]
}

# -----------------------------------------------------------------------------
# Atualiza o índice central de instalações
# Mantém entradas únicas e ordenadas
# -----------------------------------------------------------------------------
_update_index() {
    local service="$1"
    local index="$DATA_DIR/index.md"

    _ensure_data_dir

    # Cria o cabeçalho se o índice não existe ainda
    if [ ! -f "$index" ]; then
        cat > "$index" <<MD
# Catálogo de Instalações Setup Orion

> Gerado automaticamente pelas skills do ecossistema Setup Orion.

## Serviços Instalados

MD
    fi

    # Adiciona entrada somente se ainda não existir
    local entry="- [$service]($service.md)"
    if ! grep -qF "$entry" "$index"; then
        echo "$entry" >> "$index"
    fi
}

# -----------------------------------------------------------------------------
# Faz o deploy de uma stack através da API do Portainer (modo Total Control)
# Uso: deploy_via_portainer "nome_da_stack" "/caminho/para/arquivo.yaml"
# Requer: /root/dados_vps/portainer.md gerado pelo app-traefik (contendo URL, etc)
# ou env vars fallback. Se falhar, faz fallback silencioso para `docker stack deploy`.
# -----------------------------------------------------------------------------
deploy_via_portainer() {
    local stack_name="$1"
    local compose_file="$2"
    
    # 1. Tentar ler as credenciais do Portainer
    local portainer_file="$DATA_DIR/dados_portainer"
    local portainer_url=""
    local portainer_user=""
    local portainer_pass=""
    local portainer_token=""
    
    if [ -f "$portainer_file" ]; then
        portainer_url=$(grep -oP '(?<=Dominio do portainer: ).*' "$portainer_file" | tr -d '\r')
        portainer_user=$(grep -oP '(?<=Usuario: ).*' "$portainer_file" | tr -d '\r')
        portainer_pass=$(grep -oP '(?<=Senha: ).*' "$portainer_file" | tr -d '\r')
        portainer_token=$(grep -oP '(?<=Token: ).*' "$portainer_file" | tr -d '\r')
    fi
    
    # Se não temos token, tenta gerar um novo
    if [ -z "$portainer_token" ] && [ -n "$portainer_url" ] && [ -n "$portainer_user" ] && [ -n "$portainer_pass" ]; then
        portainer_token=$(curl -k -s -X POST -H "Content-Type: application/json" -d "{\"username\":\"$portainer_user\",\"password\":\"$portainer_pass\"}" "https://$portainer_url/api/auth" | jq -r .jwt)
        # Salva o token de volta se gerou com sucesso
        if [ "$portainer_token" != "null" ] && [ -n "$portainer_token" ]; then
            echo -e "[ PORTAINER ]\nDominio do portainer: $portainer_url\n\nUsuario: $portainer_user\n\nSenha: $portainer_pass\n\nToken: $portainer_token" > "$portainer_file"
        fi
    fi

    # Flag de sucesso
    local deploy_success=0

    if [ -n "$portainer_token" ] && [ "$portainer_token" != "null" ]; then
        # Temos token, vamos tentar a API
        
        # Pega o ID do Endpoint Primary
        local endpoint_id=$(curl -k -s -X GET -H "Authorization: Bearer $portainer_token" "https://$portainer_url/api/endpoints" | jq -r '.[] | select(.Name == "primary") | .Id')
        
        if [ -n "$endpoint_id" ] && [ "$endpoint_id" != "null" ]; then
            # Pega o Swarm ID
            local swarm_id=$(curl -k -s -X GET -H "Authorization: Bearer $portainer_token" "https://$portainer_url/api/endpoints/$endpoint_id/docker/swarm" | jq -r .ID)
            
            if [ -n "$swarm_id" ] && [ "$swarm_id" != "null" ]; then
                # Realiza o deploy via API
                local http_code=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST \
                    -H "Authorization: Bearer $portainer_token" \
                    -F "Name=$stack_name" \
                    -F "file=@$compose_file" \
                    -F "SwarmID=$swarm_id" \
                    -F "endpointId=$endpoint_id" \
                    "https://$portainer_url/api/stacks/create/swarm/file")
                
                if [ "$http_code" -eq 200 ]; then
                    deploy_success=1
                fi
            fi
        fi
    fi

    # Fallback para o modo CLI "Limited Control" caso a API falhe (ou não esteja configurada)
    if [ "$deploy_success" -eq 0 ]; then
        docker stack deploy --prune --resolve-image always -c "$compose_file" "$stack_name"
    fi
}
list_services() {
    local index="$DATA_DIR/index.md"
    if [ -f "$index" ]; then
        grep "^- \[" "$index" | sed 's/- \[//;s/\].*//'
    else
        echo "[lib-persistence] Nenhum serviço registrado ainda."
    fi
}
