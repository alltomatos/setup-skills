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
# Normaliza o nome de um serviço para o caminho de persistência no padrão
# Setup Orion: /root/dados_vps/dados_<nome>  (SEM extensão, prefixo app-/infra-
# removido). Ex.: "infra-mongodb" -> dados_mongodb ; "app-checkmate" -> dados_checkmate.
# -----------------------------------------------------------------------------
_dados_path() {
    local s="${1#app-}"; s="${s#infra-}"
    echo "$DATA_DIR/dados_$s"
}

# -----------------------------------------------------------------------------
# Salva dados de uma skill (padrão Setup Orion: arquivo dados_<nome> sem extensão)
# Uso: save_data "nome-serviço" "conteúdo completo"
# -----------------------------------------------------------------------------
save_data() {
    local service="$1"
    local content="$2"
    local target; target="$(_dados_path "$service")"
    local tmp
    tmp=$(mktemp)

    _ensure_data_dir

    # Escrita atômica: escreve no temp e move (evita corrupção em falhas)
    echo "$content" > "$tmp" && mv "$tmp" "$target"
    # Arquivos podem conter credenciais (padrão Setup Orion) — restringe acesso.
    chmod 600 "$target" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Lê dados de uma skill persistida
# Uso: read_data "nome-serviço"
# -----------------------------------------------------------------------------
read_data() {
    local service="$1"
    local target; target="$(_dados_path "$service")"

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
    [ -f "$(_dados_path "$1")" ]
}

# -----------------------------------------------------------------------------
# Cria um banco de dados numa instância Postgres/pgvector (idempotente).
# Necessário porque apps rodam apenas `db:migrate` (não criam o banco).
# Uso: ensure_db "pgvector" "evocrm"   |   ensure_db "postgres" "n8n"
# (o 1º arg é o filtro de nome do serviço/container da infra de banco)
# -----------------------------------------------------------------------------
ensure_db() {
    local infra="$1" db="$2" cid
    cid=$(docker ps -q --filter "name=${infra}" | head -n1)
    if [ -z "$cid" ]; then
        echo "[db] ERRO: container da infra '${infra}' não encontrado (instale a dependência)." >&2
        return 1
    fi
    case "$infra" in
      *mysql*|*mariadb*)
        # MySQL/MariaDB: senha root vem de dados_mysql (Senha:)
        local mpass
        mpass=$(grep "Senha:" "$DATA_DIR/dados_mysql" 2>/dev/null | awk -F"Senha:" '{print $2}' | xargs)
        if docker exec -e MYSQL_PWD="$mpass" "$cid" mysql -u root -e "SHOW DATABASES LIKE '$db';" 2>/dev/null | grep -qw "$db"; then
            echo "[db] banco '$db' já existe em ${infra}."
            return 0
        fi
        if docker exec -e MYSQL_PWD="$mpass" "$cid" mysql -u root -e "CREATE DATABASE IF NOT EXISTS $db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1; then
            echo "[db] banco '$db' criado em ${infra}."
            return 0
        fi
        ;;
      *)
        # PostgreSQL / pgvector
        if docker exec "$cid" psql -U postgres -lqt 2>/dev/null | cut -d'|' -f1 | grep -qw "$db"; then
            echo "[db] banco '$db' já existe em ${infra}."
            return 0
        fi
        if docker exec "$cid" psql -U postgres -c "CREATE DATABASE \"$db\";" >/dev/null 2>&1; then
            echo "[db] banco '$db' criado em ${infra}."
            return 0
        fi
        ;;
    esac
    echo "[db] ERRO ao criar o banco '$db' em ${infra}." >&2
    return 1
}

# =============================================================================
# PORTAINER — Modo "Total Control" (replica a técnica do Setup Orion)
# Credenciais persistidas em /root/dados_vps/dados_portainer (compatível com o
# ecossistema), formato:
#   [ PORTAINER ]
#   Dominio do portainer: <dominio>
#   Usuario: <user>
#   Senha: <pass>
#   Token: <jwt>
# Apps são criados via API do Portainer (NÃO via `docker stack deploy`, que
# geraria stacks "limited/external" não gerenciáveis pela UI).
# =============================================================================
PORTAINER_CRED_FILE="$DATA_DIR/dados_portainer"

# -----------------------------------------------------------------------------
# Resolve credenciais (env tem prioridade; senão o arquivo dados_portainer).
# Popula as globais: _PORT_URL (sem https://) _PORT_USER _PORT_PASS
# -----------------------------------------------------------------------------
_portainer_load_auth() {
    _PORT_URL="${PORTAINER_URL:-}"
    _PORT_USER="${PORTAINER_USER:-}"
    _PORT_PASS="${PORTAINER_PASS:-}"

    if [ -f "$PORTAINER_CRED_FILE" ]; then
        [ -z "$_PORT_URL" ]  && _PORT_URL=$(grep "Dominio do portainer:" "$PORTAINER_CRED_FILE" | awk -F "Dominio do portainer:" '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r')
        [ -z "$_PORT_USER" ] && _PORT_USER=$(grep "Usuario:" "$PORTAINER_CRED_FILE" | awk -F "Usuario:" '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r')
        [ -z "$_PORT_PASS" ] && _PORT_PASS=$(grep "Senha:" "$PORTAINER_CRED_FILE" | awk -F "Senha:" '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r')
    fi
    # Fallback de URL a partir do portainer.md (campo "URL de Acesso")
    if [ -z "$_PORT_URL" ] && [ -f "$DATA_DIR/portainer.md" ]; then
        _PORT_URL=$(grep -oP '(?<=URL de Acesso\*\*: ).*' "$DATA_DIR/portainer.md" | tr -d '\r ')
    fi
    _PORT_URL="${_PORT_URL#https://}"; _PORT_URL="${_PORT_URL#http://}"; _PORT_URL="${_PORT_URL%/}"
}

# -----------------------------------------------------------------------------
# Persiste credenciais no formato Setup Orion (chmod 600).
# Uso: portainer_save_auth <url> <user> <pass> [token]
# -----------------------------------------------------------------------------
portainer_save_auth() {
    _ensure_data_dir
    local url="${1#https://}"; url="${url%/}"
    ( umask 077; cat > "$PORTAINER_CRED_FILE" <<EOF
[ PORTAINER ]

Dominio do portainer: $url

Usuario: $2

Senha: $3

Token: ${4:-}
EOF
    )
    chmod 600 "$PORTAINER_CRED_FILE"
}

# -----------------------------------------------------------------------------
# Autentica e ecoa um JWT fresco (retry até 6x). Vazio + status !=0 em falha.
# Uso: _portainer_jwt <base_url> <user> <pass>
# -----------------------------------------------------------------------------
_portainer_jwt() {
    local base="$1" user="$2" pass="$3" jwt="" i
    for i in $(seq 1 6); do
        jwt=$(curl -k -s -X POST -H "Content-Type: application/json" \
              -d "$(jq -nc --arg u "$user" --arg p "$pass" '{username:$u,password:$p}')" \
              "$base/api/auth" | jq -r '.jwt // empty')
        [ -n "$jwt" ] && { echo "$jwt"; return 0; }
        sleep 5
    done
    return 1
}

# -----------------------------------------------------------------------------
# Inicializa o admin do Portainer via API (modo Total Control) e persiste auth.
# Cria o admin se ainda não existe (retry 4x); valida e persiste o JWT.
# Uso: portainer_init_admin <url> <user> <pass>
# -----------------------------------------------------------------------------
portainer_init_admin() {
    local url="${1#https://}"; url="${url%/}"
    local user="$2" pass="$3"
    local base="https://$url"
    local i

    # Aguarda a API responder
    for i in $(seq 1 30); do
        curl -k -s -o /dev/null "$base/api/status" && break
        sleep 2
    done

    local check
    check=$(curl -k -s -o /dev/null -w "%{http_code}" "$base/api/users/admin/check")
    if [ "$check" = "404" ]; then
        local resp
        for i in $(seq 1 4); do
            resp=$(curl -k -s -X POST "$base/api/users/admin/init" \
                -H "Content-Type: application/json" \
                -d "$(jq -nc --arg u "$user" --arg p "$pass" '{Username:$u,Password:$p}')")
            echo "$resp" | grep -q "\"Username\"" && break
            sleep 15
        done
    fi

    # Gera o primeiro token (JWT) e persiste
    local token
    token=$(_portainer_jwt "$base" "$user" "$pass")
    if [ -n "$token" ]; then
        portainer_save_auth "$url" "$user" "$pass" "$token"
        echo "[portainer] Admin pronto; credenciais persistidas em $PORTAINER_CRED_FILE."
        return 0
    fi
    echo "[portainer] ERRO: não foi possível autenticar como '$user' (admin existe com outra senha?)." >&2
    return 1
}

# -----------------------------------------------------------------------------
# Faz o deploy de uma stack através da API do Portainer (modo Total Control).
# As stacks ficam totalmente gerenciáveis pela UI do Portainer.
# Idempotente: cria (multipart, estilo Setup Orion) se nova; atualiza se existir.
# Uso: deploy_via_portainer "nome_da_stack" "/caminho/para/arquivo.yaml"
# Auth: env PORTAINER_URL/USER/PASS ou /root/dados_vps/dados_portainer.
# Retorna 0 em sucesso; !=0 em falha (SEM fallback para docker stack deploy).
# -----------------------------------------------------------------------------
deploy_via_portainer() {
    local stack_name="$1"
    local compose_file="$2"

    if [ ! -f "$compose_file" ]; then
        echo "[portainer] ERRO: arquivo compose não encontrado: $compose_file" >&2
        return 1
    fi

    local _PORT_URL _PORT_USER _PORT_PASS
    _portainer_load_auth
    if [ -z "$_PORT_URL" ] || [ -z "$_PORT_USER" ] || [ -z "$_PORT_PASS" ]; then
        echo "[portainer] ERRO: credenciais ausentes (dados_portainer ou PORTAINER_URL/USER/PASS)." >&2
        return 1
    fi

    local base="https://$_PORT_URL"
    local token
    token=$(_portainer_jwt "$base" "$_PORT_USER" "$_PORT_PASS")
    if [ -z "$token" ]; then
        echo "[portainer] ERRO: autenticação falhou (verifique usuário/senha do Portainer)." >&2
        return 1
    fi

    # Endpoint local (prefere Name=="primary", senão o primeiro) e SwarmID
    local endpoint_id swarm_id
    endpoint_id=$(curl -k -s -H "Authorization: Bearer $token" "$base/api/endpoints" \
                  | jq -r 'map(select(.Name=="primary"))[0].Id // .[0].Id // empty')
    if [ -z "$endpoint_id" ]; then
        echo "[portainer] ERRO: nenhum endpoint Docker encontrado." >&2
        return 1
    fi
    swarm_id=$(curl -k -s -H "Authorization: Bearer $token" "$base/api/endpoints/$endpoint_id/docker/swarm" | jq -r '.ID // empty')
    if [ -z "$swarm_id" ]; then
        echo "[portainer] ERRO: SwarmID não encontrado (endpoint $endpoint_id)." >&2
        return 1
    fi

    # Stack já existe? -> update (redeploy); senão -> create (multipart)
    local existing_id resp_file http_code
    existing_id=$(curl -k -s -H "Authorization: Bearer $token" "$base/api/stacks" \
                  | jq -r --arg n "$stack_name" 'map(select(.Name==$n))[0].Id // empty')
    resp_file=$(mktemp)

    if [ -n "$existing_id" ]; then
        local content_json body
        content_json=$(jq -Rs . < "$compose_file")
        body=$(jq -nc --argjson c "$content_json" '{StackFileContent:$c, Env:[], Prune:true}')
        http_code=$(curl -k -s -o "$resp_file" -w "%{http_code}" -X PUT \
            -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
            -d "$body" "$base/api/stacks/$existing_id?endpointId=$endpoint_id")
    else
        http_code=$(curl -k -s -o "$resp_file" -w "%{http_code}" -X POST \
            -H "Authorization: Bearer $token" \
            -F "Name=$stack_name" \
            -F "file=@$compose_file" \
            -F "SwarmID=$swarm_id" \
            -F "endpointId=$endpoint_id" \
            "$base/api/stacks/create/swarm/file")
    fi

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        rm -f "$resp_file"
        echo "[portainer] Stack '$stack_name' via API (HTTP $http_code, $([ -n "$existing_id" ] && echo update || echo create))."
        return 0
    fi
    echo "[portainer] ERRO: deploy via API de '$stack_name' falhou (HTTP $http_code):" >&2
    cat "$resp_file" >&2 2>/dev/null; echo >&2
    rm -f "$resp_file"
    return 1
}
list_services() {
    if ls "$DATA_DIR"/dados_* >/dev/null 2>&1; then
        ls -1 "$DATA_DIR"/dados_* | sed "s#.*/dados_##"
    else
        echo "[lib-persistence] Nenhum serviço registrado ainda."
    fi
}
