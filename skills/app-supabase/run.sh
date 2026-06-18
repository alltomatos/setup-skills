#!/bin/bash
# =============================================================================
# skills/app-supabase/run.sh
# Skill: Instalação do Supabase via Docker Swarm
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
reset="\e[0m"

STACK_NAME="supabase"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

echo -e "${amarelo}Gerando tokens e configurando Supabase em $DOMAIN_SUPABASE...${reset}"

# Recupera dados existentes (ADR-001)
EXISTING_DATA=$(read_data "app-supabase" 2>/dev/null)

# Função de geração de tokens extraída do SetupOrion
generate_jwt_tokens() {
    payload_service_key='{"role":"service_role","iss":"supabase","iat":1715050800,"exp":1872817200}'
    payload_anon_key='{"role":"anon","iss":"supabase","iat":1715050800,"exp":1872817200}'
    secret=$(openssl rand -hex 20)
    header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | openssl base64 | tr -d '=' | tr '+/' '-_' | tr -d '\n')
    payload_service_key_base64=$(echo -n "$payload_service_key" | openssl base64 | tr -d '=' | tr '+/' '-_' | tr -d '\n')
    payload_anon_key_base64=$(echo -n "$payload_anon_key" | openssl base64 | tr -d '=' | tr '+/' '-_' | tr -d '\n')
    signature_service_key=$(echo -n "$header.$payload_service_key_base64" | openssl dgst -sha256 -hmac "$secret" -binary | openssl base64 | tr -d '=' | tr '+/' '-_' | tr -d '\n')
    signature_anon_key=$(echo -n "$header.$payload_anon_key_base64" | openssl dgst -sha256 -hmac "$secret" -binary | openssl base64 | tr -d '=' | tr '+/' '-_' | tr -d '\n')
    token_service_key="$header.$payload_service_key_base64.$signature_service_key"
    token_anon_key="$header.$payload_anon_key_base64.$signature_anon_key"
    echo "$secret $token_anon_key $token_service_key"
}

JWT_SECRET=$(echo "$EXISTING_DATA" | grep -oP '(?<=- JWT Secret: ).*')
ANON_KEY=$(echo "$EXISTING_DATA" | grep -oP '(?<=- Anon Key: ).*')
SERVICE_KEY=$(echo "$EXISTING_DATA" | grep -oP '(?<=- Service Key: ).*')

if [ -z "$JWT_SECRET" ] || [ -z "$ANON_KEY" ] || [ -z "$SERVICE_KEY" ]; then
    read JWT_SECRET ANON_KEY SERVICE_KEY <<< $(generate_jwt_tokens)
fi

# Preparar estrutura de arquivos
BASE_DIR="/root/supabase"
mkdir -p $BASE_DIR/docker/volumes/api
mkdir -p $BASE_DIR/docker/volumes/db/data
mkdir -p $BASE_DIR/docker/volumes/storage
mkdir -p $BASE_DIR/docker/volumes/functions
mkdir -p $BASE_DIR/docker/volumes/logs/
mkdir -p $BASE_DIR/docker/volumes/pooler/

# Baixar recursos necessários do repositório oficial (como o SetupOrion faz)
TMP_DIR="/tmp/supabase_git"
mkdir -p $TMP_DIR
cd $TMP_DIR
git clone --depth 1 https://github.com/supabase/supabase.git . > /dev/null 2>&1
cd docker/volumes/db
cp *.sql $BASE_DIR/docker/volumes/db/
cd ../logs
cp vector.yml $BASE_DIR/docker/volumes/logs/
cd ../pooler
cp pooler.exs $BASE_DIR/docker/volumes/pooler/
rm -rf $TMP_DIR

# Hash para o MCP
HASH=$(openssl rand -hex 5)

# Configurar Kong
cat > $BASE_DIR/docker/volumes/api/kong.yml <<EOF
_format_version: '2.1'
_transform: true
consumers:
  - username: DASHBOARD
  - username: anon
    keyauth_credentials: [{key: "$ANON_KEY"}]
  - username: service_role
    keyauth_credentials: [{key: "$SERVICE_KEY"}]
acls:
  - {consumer: anon, group: anon}
  - {consumer: service_role, group: admin}
basicauth_credentials:
  - {consumer: DASHBOARD, username: "$SUPABASE_USER", password: "$SUPABASE_PASSWORD"}
services:
  - name: auth-v1-open
    url: http://auth:9999/verify
    routes: [{name: auth-v1-open, paths: [/auth/v1/verify]}]
    plugins: [{name: cors}]
  - name: auth-v1
    url: http://auth:9999/
    routes: [{name: auth-v1-all, paths: [/auth/v1/]}]
    plugins: [{name: cors}, {name: key-auth}, {name: acl, config: {allow: [admin, anon]}}]
  - name: rest-v1
    url: http://rest:3000/
    routes: [{name: rest-v1-all, paths: [/rest/v1/]}]
    plugins: [{name: cors}, {name: key-auth}, {name: acl, config: {allow: [admin, anon]}}]
  - name: storage-v1
    url: http://storage:5000/
    routes: [{name: storage-v1-all, paths: [/storage/v1/]}]
    plugins: [{name: cors}]
  - name: dashboard
    url: http://studio:3000/
    routes: [{name: dashboard-all, paths: [/]}]
    plugins: [{name: cors}, {name: basic-auth}]
EOF

# Geração de mais segredos
POSTGRES_PASSWORD=$(openssl rand -hex 16)
Logflare_key=$(openssl rand -hex 16)
SECRET_KEY_BASE=$(openssl rand -hex 32)
VAULT_ENC_KEY=$(openssl rand -base64 32 | cut -c1-32)
PG_META_CRYPTO_KEY=$(openssl rand -hex 32)

# Determinar sufixo de ambiente se fornecido via $1
SUFFIX="${1:+_$1}"

cat > supabase${SUFFIX}.yaml <<YAML
version: "3.7"
services:
  studio:
    image: supabase/studio:2025.11.10-sha-5291fe3
    networks: [$NOME_REDE_INTERNA]
    environment:
      - SUPABASE_URL=http://kong:8000
      - SUPABASE_PUBLIC_URL=https://$DOMAIN_SUPABASE
      - SUPABASE_ANON_KEY=$ANON_KEY
      - SUPABASE_SERVICE_KEY=$SERVICE_KEY
      - AUTH_JWT_SECRET=$JWT_SECRET
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
      - PG_META_CRYPTO_KEY=$PG_META_CRYPTO_KEY
    deploy:
      placement: {constraints: [node.role == manager]}

  kong:
    image: kong:2.8.1
    entrypoint: bash -c 'eval "echo \"\$\$(cat /home/kong/temp.yml)\"" > /home/kong/kong.yml && /docker-entrypoint.sh kong docker-start'
    volumes:
      - $BASE_DIR/docker/volumes/api/kong.yml:/home/kong/temp.yml:ro
    networks: [$NOME_REDE_INTERNA]
    environment:
      - DASHBOARD_USERNAME=$SUPABASE_USER
      - DASHBOARD_PASSWORD=$SUPABASE_PASSWORD
      - JWT_SECRET=$JWT_SECRET
      - SUPABASE_ANON_KEY=$ANON_KEY
      - SUPABASE_SERVICE_KEY=$SERVICE_KEY
      - KONG_DATABASE=off
      - KONG_DECLARATIVE_CONFIG=/home/kong/kong.yml
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.supabase.rule=Host(\`$DOMAIN_SUPABASE\`)
        - traefik.http.services.supabase.loadbalancer.server.port=8000
        - traefik.http.routers.supabase.entrypoints=websecure
        - traefik.http.routers.supabase.tls.certresolver=letsencryptresolver

  db:
    image: supabase/postgres:15.8.1.085
    volumes:
      - $BASE_DIR/docker/volumes/db/data:/var/lib/postgresql/data
    networks: [$NOME_REDE_INTERNA]
    environment:
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
      - JWT_SECRET=$JWT_SECRET
    deploy:
      placement: {constraints: [node.role == manager]}

  auth:
    image: supabase/gotrue:v2.182.1
    networks: [$NOME_REDE_INTERNA]
    environment:
      - GOTRUE_DB_DATABASE_URL=postgres://supabase_auth_admin:$POSTGRES_PASSWORD@db:5432/postgres
      - GOTRUE_JWT_SECRET=$JWT_SECRET
      - GOTRUE_SITE_URL=https://$DOMAIN_SUPABASE
    deploy:
      placement: {constraints: [node.role == manager]}

  rest:
    image: postgrest/postgrest:v13.0.7
    networks: [$NOME_REDE_INTERNA]
    environment:
      - PGRST_DB_URI=postgres://authenticator:$POSTGRES_PASSWORD@db:5432/postgres
      - PGRST_JWT_SECRET=$JWT_SECRET
    deploy:
      placement: {constraints: [node.role == manager]}

  storage:
    image: supabase/storage-api:v1.29.0
    volumes:
      - supabase_storage:/var/lib/storage
    networks: [$NOME_REDE_INTERNA]
    environment:
      - ANON_KEY=$ANON_KEY
      - SERVICE_KEY=$SERVICE_KEY
      - PGRST_JWT_SECRET=$JWT_SECRET
      - DATABASE_URL=postgres://supabase_storage_admin:$POSTGRES_PASSWORD@db:5432/postgres
      - STORAGE_BACKEND=file
    deploy:
      placement: {constraints: [node.role == manager]}

volumes:
  supabase_storage:
    external: true

networks:
  $NOME_REDE_INTERNA:
    external: true
YAML

deploy_via_portainer "$STACK_NAME" "supabase${SUFFIX}.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-supabase" "[ SUPABASE ]

Dominio: https://$DOMAIN_SUPABASE

Host: kong

Port: 8000

Usuario: $SUPABASE_USER

Senha: $SUPABASE_PASSWORD

JWT Secret: $JWT_SECRET

Anon Key: $ANON_KEY

Service Key: $SERVICE_KEY

Postgres Password: $POSTGRES_PASSWORD

PG Meta Crypto Key: $PG_META_CRYPTO_KEY

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm -f supabase${SUFFIX}.yaml
exit 0
