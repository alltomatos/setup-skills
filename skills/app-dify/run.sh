#!/bin/bash
# =============================================================================
# skills/app-dify/run.sh
# Skill: Instalação do Dify (Plataforma LLM + RAG) via Docker Swarm
# Porte fiel da config consolidada do Setup Orion (docs/SetupOrion.md).
# Adaptações: storage local (opendal/fs) em vez de S3/MinIO; Redis e Weaviate
# embutidos na stack; sufixo de instância removido (nomes fixos dify_*).
# =============================================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SKILL_DIR/../00-core/lib-persistence.sh"

amarelo="\e[33m"
verde="\e[32m"
vermelho="\e[91m"
reset="\e[0m"

STACK_NAME="dify"
NOME_REDE_INTERNA="${NOME_REDE_INTERNA:-$(docker network ls --filter driver=overlay --format "{{.Name}}" | grep -vw ingress | head -n1)}"

# Credenciais do Postgres (dependência) — env tem prioridade; senão lê do dados_postgres
if [ ! -f "/root/dados_vps/dados_postgres" ]; then
    echo -e "${vermelho}Erro: infra-postgres não encontrado em /root/dados_vps/ (instale a dependência).${reset}"
    exit 1
fi
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(grep "Senha:" /root/dados_vps/dados_postgres | awk -F"Senha:" '{print $2}' | xargs)}"
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${vermelho}Erro: senha do postgres ausente em dados_postgres.${reset}"
    exit 1
fi

# Segredos gerados
secret_key=$(openssl rand -hex 16)
sandbox_api_key=$(openssl rand -hex 16)
token_weaviate=$(openssl rand -hex 16)
token_apikey_plugins=$(openssl rand -hex 16)
token_deamon=$(openssl rand -hex 16)
sandbox_key=$(openssl rand -hex 16)
db_plugin=$(openssl rand -base64 16)

# cookie_domain derivado do domínio da API (remove o primeiro rótulo)
cookie_domain="$(echo "$DOMAIN_DIFY_API" | sed 's/^[^.]\+//')"

echo -e "${amarelo}Instalando Dify no domínio $DOMAIN_DIFY (API: $DOMAIN_DIFY_API)...${reset}"

# Criar volumes
docker volume create dify_storage > /dev/null 2>&1
docker volume create dify_redis_data > /dev/null 2>&1
docker volume create dify_weaviate_data > /dev/null 2>&1
docker volume create dify_sandbox_dependencies > /dev/null 2>&1
docker volume create dify_sandbox_conf > /dev/null 2>&1
docker volume create dify_plugin_daemon > /dev/null 2>&1

cat > dify.yaml <<EOL
version: '3.7'
services:

  dify_api:
    image: langgenius/dify-api:latest

    volumes:
      - dify_storage:/app/api/storage

    networks:
      - $NOME_REDE_INTERNA
      - dify_ssrf_proxy_network

    environment:
      ## URLs e Endpoints
      - CONSOLE_API_URL=https://$DOMAIN_DIFY_API/console/api
      - CONSOLE_WEB_URL=https://$DOMAIN_DIFY
      - SERVICE_API_URL=https://$DOMAIN_DIFY_API/service/api
      - TRIGGER_URL=https://$DOMAIN_DIFY_API/triggers
      - APP_API_URL=https://$DOMAIN_DIFY_API/api
      - APP_WEB_URL=https://$DOMAIN_DIFY
      - FILES_URL=https://$DOMAIN_DIFY_API/files
      - INTERNAL_FILES_URL=http://dify_api:5001/files
      - CHECK_UPDATE_URL=https://updates.dify.ai
      - OPENAI_API_BASE=https://api.openai.com/v1

      ## Localização e Idioma
      - LANG=en_US.UTF-8
      - LC_ALL=en_US.UTF-8
      - PYTHONIOENCODING=utf-8

      ## Logging
      - LOG_LEVEL=INFO
      - LOG_FILE=/app/logs/server.log
      - LOG_FILE_MAX_SIZE=20
      - LOG_FILE_BACKUP_COUNT=5
      - LOG_DATEFORMAT=%Y-%m-%d %H:%M:%S
      - LOG_TZ=UTC
      - DEBUG=false
      - FLASK_DEBUG=false
      - ENABLE_REQUEST_LOGGING=False

      ## Segurança e Autenticação
      - SECRET_KEY=$secret_key
      - ACCESS_TOKEN_EXPIRE_MINUTES=60
      - REFRESH_TOKEN_EXPIRE_DAYS=30

      ## Configuração do Servidor
      - DEPLOY_ENV=PRODUCTION
      - DIFY_BIND_ADDRESS=0.0.0.0
      - DIFY_PORT=5001
      - SERVER_WORKER_AMOUNT=1
      - SERVER_WORKER_CLASS=gevent
      - SERVER_WORKER_CONNECTIONS=10
      - GUNICORN_TIMEOUT=360
      - MIGRATION_ENABLED=true
      - FILES_ACCESS_TIMEOUT=300
      - APP_DEFAULT_ACTIVE_REQUESTS=0
      - APP_MAX_ACTIVE_REQUESTS=0
      - APP_MAX_EXECUTION_TIME=1200
      - RESPECT_XFORWARD_HEADERS_ENABLED=true

      ## Celery e Workers
      - CELERY_WORKER_CLASS=
      - CELERY_WORKER_AMOUNT=
      - CELERY_AUTO_SCALE=false
      - CELERY_MAX_WORKERS=
      - CELERY_MIN_WORKERS=

      ## API Tools
      - API_TOOL_DEFAULT_CONNECT_TIMEOUT=10
      - API_TOOL_DEFAULT_READ_TIMEOUT=60

      ## Website Crawlers
      - ENABLE_WEBSITE_JINAREADER=true
      - ENABLE_WEBSITE_FIRECRAWL=true
      - ENABLE_WEBSITE_WATERCRAWL=true

      ## Frontend
      - NEXT_PUBLIC_ENABLE_SINGLE_DOLLAR_LATEX=false

      ## Banco de Dados (PostgreSQL)
      - DB_TYPE=postgresql
      - DB_USERNAME=postgres
      - DB_PASSWORD=$POSTGRES_PASSWORD
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=dify
      - SQLALCHEMY_POOL_SIZE=30
      - SQLALCHEMY_MAX_OVERFLOW=10
      - SQLALCHEMY_POOL_RECYCLE=3600
      - SQLALCHEMY_ECHO=false
      - SQLALCHEMY_POOL_PRE_PING=false
      - SQLALCHEMY_POOL_USE_LIFO=false
      - SQLALCHEMY_POOL_TIMEOUT=30

      ## Redis
      - REDIS_HOST=dify_redis
      - REDIS_PORT=6379
      - REDIS_USERNAME=
      - REDIS_PASSWORD=
      - REDIS_USE_SSL=false
      - REDIS_DB=0
      - CELERY_BROKER_URL=redis://dify_redis:6379/1
      - CELERY_BACKEND=redis

      ## Cookies e CORS
      - WEB_API_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - CONSOLE_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - COOKIE_DOMAIN=$cookie_domain
      - NEXT_PUBLIC_COOKIE_DOMAIN=$cookie_domain

      ## Storage (local / OpenDAL filesystem)
      - STORAGE_TYPE=opendal
      - OPENDAL_SCHEME=fs
      - OPENDAL_FS_ROOT=/app/api/storage

      ## Vector Store (Weaviate)
      - VECTOR_STORE=weaviate
      - VECTOR_INDEX_NAME_PREFIX=Vector_index
      - WEAVIATE_ENDPOINT=http://dify_weaviate:8080
      - WEAVIATE_API_KEY=$token_weaviate
      - WEAVIATE_GRPC_ENDPOINT=grpc://dify_weaviate:50051
      - WEAVIATE_TOKENIZATION=word

      ## Traefik
      - TRAEFIK_DOMAIN=$DOMAIN_DIFY_API

      ## Modo e Sentry
      - MODE=api
      - SENTRY_DSN=
      - SENTRY_TRACES_SAMPLE_RATE=1.0
      - SENTRY_PROFILES_SAMPLE_RATE=1.0

      ## Plugins
      - PLUGIN_DAEMON_URL=http://dify_plugin_daemon:5002
      - PLUGIN_DAEMON_KEY=$token_deamon
      - PLUGIN_REMOTE_INSTALL_HOST=localhost
      - PLUGIN_REMOTE_INSTALL_PORT=5003
      - PLUGIN_MAX_PACKAGE_SIZE=52428800
      - INNER_API_KEY_FOR_PLUGIN=$token_apikey_plugins

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M
      labels:
        - traefik.enable=true
        - traefik.docker.network=$NOME_REDE_INTERNA
        - traefik.http.routers.dify_api.rule=Host(\`$DOMAIN_DIFY_API\`) && !PathPrefix(\`/service/api\`)
        - traefik.http.routers.dify_api.entrypoints=websecure
        - traefik.http.routers.dify_api.tls.certresolver=letsencryptresolver
        - traefik.http.routers.dify_api.tls=true
        - traefik.http.routers.dify_api.service=dify_api
        - traefik.http.services.dify_api.loadbalancer.server.port=5001
        - traefik.http.services.dify_api.loadbalancer.passHostHeader=true
        - traefik.http.routers.dify_api_service.rule=Host(\`$DOMAIN_DIFY_API\`) && PathPrefix(\`/service/api\`)
        - traefik.http.routers.dify_api_service.entrypoints=websecure
        - traefik.http.routers.dify_api_service.tls.certresolver=letsencryptresolver
        - traefik.http.routers.dify_api_service.tls=true
        - traefik.http.routers.dify_api_service.service=dify_api
        - traefik.http.routers.dify_api_service.priority=20
        - traefik.http.middlewares.dify_api_stripprefix.stripprefix.prefixes=/service/api
        - traefik.http.middlewares.dify_api_stripprefix.stripprefix.forceSlash=false
        - traefik.http.routers.dify_api_service.middlewares=dify_api_stripprefix

  dify_worker:
    image: langgenius/dify-api:latest

    volumes:
      - dify_storage:/app/api/storage

    networks:
      - $NOME_REDE_INTERNA
      - dify_ssrf_proxy_network

    environment:
      ## URLs e Endpoints
      - CONSOLE_API_URL=https://$DOMAIN_DIFY_API/console/api
      - CONSOLE_WEB_URL=https://$DOMAIN_DIFY
      - SERVICE_API_URL=https://$DOMAIN_DIFY_API/service/api
      - TRIGGER_URL=https://$DOMAIN_DIFY_API/triggers
      - APP_API_URL=https://$DOMAIN_DIFY_API/api
      - APP_WEB_URL=https://$DOMAIN_DIFY
      - FILES_URL=https://$DOMAIN_DIFY_API/files
      - INTERNAL_FILES_URL=http://dify_api:5001/files
      - CHECK_UPDATE_URL=https://updates.dify.ai
      - OPENAI_API_BASE=https://api.openai.com/v1

      ## Localização e Idioma
      - LANG=en_US.UTF-8
      - LC_ALL=en_US.UTF-8
      - PYTHONIOENCODING=utf-8

      ## Logging
      - LOG_LEVEL=INFO
      - LOG_FILE=/app/logs/server.log
      - LOG_FILE_MAX_SIZE=20
      - LOG_FILE_BACKUP_COUNT=5
      - LOG_DATEFORMAT=%Y-%m-%d %H:%M:%S
      - LOG_TZ=UTC
      - DEBUG=false
      - FLASK_DEBUG=false
      - ENABLE_REQUEST_LOGGING=False

      ## Segurança e Autenticação
      - SECRET_KEY=$secret_key
      - ACCESS_TOKEN_EXPIRE_MINUTES=60
      - REFRESH_TOKEN_EXPIRE_DAYS=30

      ## Configuração do Servidor
      - DEPLOY_ENV=PRODUCTION
      - DIFY_BIND_ADDRESS=0.0.0.0
      - DIFY_PORT=5001
      - SERVER_WORKER_AMOUNT=1
      - SERVER_WORKER_CLASS=gevent
      - SERVER_WORKER_CONNECTIONS=10
      - GUNICORN_TIMEOUT=360
      - MIGRATION_ENABLED=true
      - FILES_ACCESS_TIMEOUT=300
      - APP_DEFAULT_ACTIVE_REQUESTS=0
      - APP_MAX_ACTIVE_REQUESTS=0
      - APP_MAX_EXECUTION_TIME=1200

      ## Celery e Workers
      - CELERY_WORKER_CLASS=
      - CELERY_WORKER_AMOUNT=
      - CELERY_AUTO_SCALE=false
      - CELERY_MAX_WORKERS=
      - CELERY_MIN_WORKERS=

      ## API Tools
      - API_TOOL_DEFAULT_CONNECT_TIMEOUT=10
      - API_TOOL_DEFAULT_READ_TIMEOUT=60

      ## Website Crawlers
      - ENABLE_WEBSITE_JINAREADER=true
      - ENABLE_WEBSITE_FIRECRAWL=true
      - ENABLE_WEBSITE_WATERCRAWL=true

      ## Frontend
      - NEXT_PUBLIC_ENABLE_SINGLE_DOLLAR_LATEX=false

      ## Banco de Dados (PostgreSQL)
      - DB_TYPE=postgresql
      - DB_USERNAME=postgres
      - DB_PASSWORD=$POSTGRES_PASSWORD
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=dify
      - SQLALCHEMY_POOL_SIZE=30
      - SQLALCHEMY_MAX_OVERFLOW=10
      - SQLALCHEMY_POOL_RECYCLE=3600
      - SQLALCHEMY_ECHO=false
      - SQLALCHEMY_POOL_PRE_PING=false
      - SQLALCHEMY_POOL_USE_LIFO=false
      - SQLALCHEMY_POOL_TIMEOUT=30

      ## Redis
      - REDIS_HOST=dify_redis
      - REDIS_PORT=6379
      - REDIS_USERNAME=
      - REDIS_PASSWORD=
      - REDIS_USE_SSL=false
      - REDIS_DB=0
      - CELERY_BROKER_URL=redis://dify_redis:6379/1
      - CELERY_BACKEND=redis

      ## Cookies e CORS
      - WEB_API_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - CONSOLE_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - COOKIE_DOMAIN=$cookie_domain
      - NEXT_PUBLIC_COOKIE_DOMAIN=$cookie_domain

      ## Storage (local / OpenDAL filesystem)
      - STORAGE_TYPE=opendal
      - OPENDAL_SCHEME=fs
      - OPENDAL_FS_ROOT=/app/api/storage

      ## Vector Store (Weaviate)
      - VECTOR_STORE=weaviate
      - VECTOR_INDEX_NAME_PREFIX=Vector_index
      - WEAVIATE_ENDPOINT=http://dify_weaviate:8080
      - WEAVIATE_API_KEY=$token_weaviate
      - WEAVIATE_GRPC_ENDPOINT=grpc://dify_weaviate:50051
      - WEAVIATE_TOKENIZATION=word

      ## Modo e Sentry
      - MODE=worker
      - SENTRY_DSN=
      - SENTRY_TRACES_SAMPLE_RATE=1.0
      - SENTRY_PROFILES_SAMPLE_RATE=1.0

      ## Plugins
      - PLUGIN_DAEMON_KEY=$token_deamon
      - PLUGIN_MAX_PACKAGE_SIZE=52428800
      - INNER_API_KEY_FOR_PLUGIN=$token_apikey_plugins

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M

  dify_worker_beat:
    image: langgenius/dify-api:latest

    networks:
      - $NOME_REDE_INTERNA
      - dify_ssrf_proxy_network

    environment:
      ## URLs e Endpoints
      - CONSOLE_API_URL=https://$DOMAIN_DIFY_API/console/api
      - CONSOLE_WEB_URL=https://$DOMAIN_DIFY
      - SERVICE_API_URL=https://$DOMAIN_DIFY_API/service/api
      - TRIGGER_URL=https://$DOMAIN_DIFY_API/triggers
      - APP_API_URL=https://$DOMAIN_DIFY_API/api
      - APP_WEB_URL=https://$DOMAIN_DIFY
      - FILES_URL=https://$DOMAIN_DIFY_API/files
      - INTERNAL_FILES_URL=http://dify_api:5001/files
      - CHECK_UPDATE_URL=https://updates.dify.ai
      - OPENAI_API_BASE=https://api.openai.com/v1

      ## Localização e Idioma
      - LANG=en_US.UTF-8
      - LC_ALL=en_US.UTF-8
      - PYTHONIOENCODING=utf-8

      ## Logging
      - LOG_LEVEL=INFO
      - LOG_FILE=/app/logs/server.log
      - LOG_FILE_MAX_SIZE=20
      - LOG_FILE_BACKUP_COUNT=5
      - LOG_DATEFORMAT=%Y-%m-%d %H:%M:%S
      - LOG_TZ=UTC
      - DEBUG=false
      - FLASK_DEBUG=false
      - ENABLE_REQUEST_LOGGING=False

      ## Segurança e Autenticação
      - SECRET_KEY=$secret_key
      - ACCESS_TOKEN_EXPIRE_MINUTES=60
      - REFRESH_TOKEN_EXPIRE_DAYS=30

      ## Configuração do Servidor
      - DEPLOY_ENV=PRODUCTION
      - DIFY_BIND_ADDRESS=0.0.0.0
      - DIFY_PORT=5001
      - SERVER_WORKER_AMOUNT=1
      - SERVER_WORKER_CLASS=gevent
      - SERVER_WORKER_CONNECTIONS=10
      - GUNICORN_TIMEOUT=360
      - MIGRATION_ENABLED=true
      - FILES_ACCESS_TIMEOUT=300
      - APP_DEFAULT_ACTIVE_REQUESTS=0
      - APP_MAX_ACTIVE_REQUESTS=0
      - APP_MAX_EXECUTION_TIME=1200

      ## Celery e Workers
      - CELERY_WORKER_CLASS=
      - CELERY_WORKER_AMOUNT=
      - CELERY_AUTO_SCALE=false
      - CELERY_MAX_WORKERS=
      - CELERY_MIN_WORKERS=

      ## API Tools
      - API_TOOL_DEFAULT_CONNECT_TIMEOUT=10
      - API_TOOL_DEFAULT_READ_TIMEOUT=60

      ## Website Crawlers
      - ENABLE_WEBSITE_JINAREADER=true
      - ENABLE_WEBSITE_FIRECRAWL=true
      - ENABLE_WEBSITE_WATERCRAWL=true

      ## Frontend
      - NEXT_PUBLIC_ENABLE_SINGLE_DOLLAR_LATEX=false

      ## Banco de Dados (PostgreSQL)
      - DB_TYPE=postgresql
      - DB_USERNAME=postgres
      - DB_PASSWORD=$POSTGRES_PASSWORD
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=dify
      - SQLALCHEMY_POOL_SIZE=30
      - SQLALCHEMY_MAX_OVERFLOW=10
      - SQLALCHEMY_POOL_RECYCLE=3600
      - SQLALCHEMY_ECHO=false
      - SQLALCHEMY_POOL_PRE_PING=false
      - SQLALCHEMY_POOL_USE_LIFO=false
      - SQLALCHEMY_POOL_TIMEOUT=30

      ## Redis
      - REDIS_HOST=dify_redis
      - REDIS_PORT=6379
      - REDIS_USERNAME=
      - REDIS_PASSWORD=
      - REDIS_USE_SSL=false
      - REDIS_DB=0
      - CELERY_BROKER_URL=redis://dify_redis:6379/1
      - CELERY_BACKEND=redis

      ## Cookies e CORS
      - WEB_API_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - CONSOLE_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - COOKIE_DOMAIN=$cookie_domain
      - NEXT_PUBLIC_COOKIE_DOMAIN=$cookie_domain

      ## Storage (local / OpenDAL filesystem)
      - STORAGE_TYPE=opendal
      - OPENDAL_SCHEME=fs
      - OPENDAL_FS_ROOT=/app/api/storage

      ## Vector Store (Weaviate)
      - VECTOR_STORE=weaviate
      - VECTOR_INDEX_NAME_PREFIX=Vector_index
      - WEAVIATE_ENDPOINT=http://dify_weaviate:8080
      - WEAVIATE_API_KEY=$token_weaviate
      - WEAVIATE_GRPC_ENDPOINT=grpc://dify_weaviate:50051
      - WEAVIATE_TOKENIZATION=word

      ## Modo
      - MODE=beat

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M

  dify_web:
    image: langgenius/dify-web:latest

    networks:
      - $NOME_REDE_INTERNA

    environment:
      ## URLs e Endpoints
      - TRAEFIK_DOMAIN=$DOMAIN_DIFY
      - CONSOLE_API_URL=https://$DOMAIN_DIFY_API
      - APP_API_URL=https://$DOMAIN_DIFY_API
      - NEXT_PUBLIC_API_PREFIX=https://$DOMAIN_DIFY_API/console/api
      - NEXT_PUBLIC_PUBLIC_API_PREFIX=https://$DOMAIN_DIFY_API/api
      - MARKETPLACE_API_URL=https://marketplace.dify.ai
      - MARKETPLACE_URL=https://marketplace.dify.ai

      ## Cookies
      - NEXT_PUBLIC_COOKIE_DOMAIN=$cookie_domain

      ## Monitoramento e Observabilidade
      - SENTRY_DSN=
      - NEXT_TELEMETRY_DISABLED=0

      ## Configurações de Performance
      - TEXT_GENERATION_TIMEOUT_MS=60000
      - PM2_INSTANCES=2

      ## Segurança e CSP
      - CSP_WHITELIST=
      - ALLOW_EMBED=false
      - ALLOW_UNSAFE_DATA_SCHEME=false

      ## Configurações de Workflow
      - TOP_K_MAX_VALUE=
      - INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH=
      - LOOP_NODE_MAX_COUNT=100
      - MAX_TOOLS_NUM=10
      - MAX_PARALLEL_LIMIT=10
      - MAX_ITERATIONS_NUM=99
      - MAX_TREE_DEPTH=50

      ## Website Crawlers
      - ENABLE_WEBSITE_JINAREADER=true
      - ENABLE_WEBSITE_FIRECRAWL=true
      - ENABLE_WEBSITE_WATERCRAWL=true

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M
      labels:
        - traefik.enable=true
        - traefik.docker.network=$NOME_REDE_INTERNA
        - traefik.http.routers.dify_web.rule=Host(\`$DOMAIN_DIFY\`)
        - traefik.http.routers.dify_web.entrypoints=websecure
        - traefik.http.routers.dify_web.tls.certresolver=letsencryptresolver
        - traefik.http.routers.dify_web.priority=10
        - traefik.http.services.dify_web.loadbalancer.server.port=3000

  dify_redis:
    image: redis:latest
    command: [
        "redis-server",
        "--appendonly",
        "yes",
        "--port",
        "6379"
      ]

    volumes:
      - dify_redis_data:/data

    networks:
      - $NOME_REDE_INTERNA

    environment:
      ## Configuração do Redis
      - REDISCLI_AUTH=

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 2048M

  dify_weaviate:
    image: semitechnologies/weaviate:latest

    volumes:
      - dify_weaviate_data:/var/lib/weaviate

    networks:
      - $NOME_REDE_INTERNA

    environment:
      ## Configuração do Weaviate
      - PERSISTENCE_DATA_PATH=/var/lib/weaviate
      - QUERY_DEFAULTS_LIMIT=25
      - DEFAULT_VECTORIZER_MODULE=none
      - CLUSTER_HOSTNAME=node1
      - DISABLE_TELEMETRY=false

      ## Autenticação e Autorização
      - AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=false
      - AUTHENTICATION_APIKEY_ENABLED=true
      - AUTHENTICATION_APIKEY_ALLOWED_KEYS=$token_weaviate
      - AUTHENTICATION_APIKEY_USERS=hello@dify.ai
      - AUTHORIZATION_ADMINLIST_ENABLED=true
      - AUTHORIZATION_ADMINLIST_USERS=hello@dify.ai

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M

  dify_sandbox:
    image: langgenius/dify-sandbox:latest

    volumes:
      - dify_sandbox_dependencies:/dependencies
      - dify_sandbox_conf:/conf

    networks:
      - dify_ssrf_proxy_network

    environment:
      ## Configuração do Sandbox
      - API_KEY=$sandbox_key
      - GIN_MODE=release
      - WORKER_TIMEOUT=15
      - SANDBOX_PORT=8194

      ## Rede e Proxy
      - ENABLE_NETWORK=true
      - HTTP_PROXY=http://dify_ssrf_proxy:3128
      - HTTPS_PROXY=http://dify_ssrf_proxy:3128

      ## Dependências Python
      - PIP_MIRROR_URL=

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M

  dify_plugin_daemon:
    image: langgenius/dify-plugin-daemon:latest-local

    volumes:
      - dify_plugin_daemon:/app/storage

    networks:
      - $NOME_REDE_INTERNA

    environment:
      ## URLs e Endpoints
      - CONSOLE_API_URL=https://$DOMAIN_DIFY_API/console/api
      - CONSOLE_WEB_URL=https://$DOMAIN_DIFY
      - SERVICE_API_URL=https://$DOMAIN_DIFY_API/service/api
      - TRIGGER_URL=https://$DOMAIN_DIFY_API/triggers
      - APP_API_URL=https://$DOMAIN_DIFY_API/api
      - APP_WEB_URL=https://$DOMAIN_DIFY
      - FILES_URL=https://$DOMAIN_DIFY_API/files
      - INTERNAL_FILES_URL=http://dify_api:5001/files
      - CHECK_UPDATE_URL=https://updates.dify.ai
      - OPENAI_API_BASE=https://api.openai.com/v1

      ## Localização e Idioma
      - LANG=en_US.UTF-8
      - LC_ALL=en_US.UTF-8
      - PYTHONIOENCODING=utf-8

      ## Logging
      - LOG_LEVEL=INFO
      - LOG_FILE=/app/logs/server.log
      - LOG_FILE_MAX_SIZE=20
      - LOG_FILE_BACKUP_COUNT=5
      - LOG_DATEFORMAT=%Y-%m-%d %H:%M:%S
      - LOG_TZ=UTC
      - DEBUG=false
      - FLASK_DEBUG=false
      - ENABLE_REQUEST_LOGGING=False

      ## Segurança e Autenticação
      - SECRET_KEY=$secret_key
      - INIT_PASSWORD=
      - ACCESS_TOKEN_EXPIRE_MINUTES=60
      - REFRESH_TOKEN_EXPIRE_DAYS=30

      ## Configuração do Servidor
      - DEPLOY_ENV=PRODUCTION
      - DIFY_BIND_ADDRESS=0.0.0.0
      - DIFY_PORT=5001
      - SERVER_WORKER_AMOUNT=1
      - SERVER_WORKER_CLASS=gevent
      - SERVER_WORKER_CONNECTIONS=10
      - GUNICORN_TIMEOUT=360
      - MIGRATION_ENABLED=true
      - FILES_ACCESS_TIMEOUT=300
      - APP_DEFAULT_ACTIVE_REQUESTS=0
      - APP_MAX_ACTIVE_REQUESTS=0
      - APP_MAX_EXECUTION_TIME=1200

      ## Celery e Workers
      - CELERY_WORKER_CLASS=
      - CELERY_WORKER_AMOUNT=
      - CELERY_AUTO_SCALE=false
      - CELERY_MAX_WORKERS=
      - CELERY_MIN_WORKERS=

      ## API Tools
      - API_TOOL_DEFAULT_CONNECT_TIMEOUT=10
      - API_TOOL_DEFAULT_READ_TIMEOUT=60

      ## Website Crawlers
      - ENABLE_WEBSITE_JINAREADER=true
      - ENABLE_WEBSITE_FIRECRAWL=true
      - ENABLE_WEBSITE_WATERCRAWL=true

      ## Frontend
      - NEXT_PUBLIC_ENABLE_SINGLE_DOLLAR_LATEX=false

      ## Banco de Dados (PostgreSQL)
      - DB_TYPE=postgresql
      - DB_USERNAME=postgres
      - DB_PASSWORD=$POSTGRES_PASSWORD
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=dify_plugin
      - SQLALCHEMY_POOL_SIZE=30
      - SQLALCHEMY_MAX_OVERFLOW=10
      - SQLALCHEMY_POOL_RECYCLE=3600
      - SQLALCHEMY_ECHO=false
      - SQLALCHEMY_POOL_PRE_PING=false
      - SQLALCHEMY_POOL_USE_LIFO=false
      - SQLALCHEMY_POOL_TIMEOUT=30

      ## Redis
      - REDIS_HOST=dify_redis
      - REDIS_PORT=6379
      - REDIS_USERNAME=
      - REDIS_PASSWORD=
      - REDIS_USE_SSL=false
      - REDIS_DB=0
      - CELERY_BROKER_URL=redis://dify_redis:6379/1
      - CELERY_BACKEND=redis

      ## Cookies e CORS
      - WEB_API_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - CONSOLE_CORS_ALLOW_ORIGINS=https://$DOMAIN_DIFY
      - COOKIE_DOMAIN=$cookie_domain
      - NEXT_PUBLIC_COOKIE_DOMAIN=$cookie_domain

      ## Storage (local / OpenDAL filesystem)
      - STORAGE_TYPE=opendal
      - OPENDAL_SCHEME=fs
      - OPENDAL_FS_ROOT=/app/api/storage

      ## Vector Store (Weaviate)
      - VECTOR_STORE=weaviate
      - VECTOR_INDEX_NAME_PREFIX=Vector_index
      - WEAVIATE_ENDPOINT=http://dify_weaviate:8080
      - WEAVIATE_API_KEY=$token_weaviate
      - WEAVIATE_GRPC_ENDPOINT=grpc://dify_weaviate:50051
      - WEAVIATE_TOKENIZATION=word

      ## Configuração do Plugin Daemon
      - SERVER_PORT=5002
      - SERVER_KEY=$token_deamon
      - MAX_PLUGIN_PACKAGE_SIZE=52428800
      - PPROF_ENABLED=false
      - DIFY_INNER_API_URL=http://dify_api:5001
      - DIFY_INNER_API_KEY=$token_apikey_plugins
      - PLUGIN_REMOTE_INSTALLING_HOST=0.0.0.0
      - PLUGIN_REMOTE_INSTALLING_PORT=5003
      - PLUGIN_WORKING_PATH=/app/storage/cwd
      - FORCE_VERIFYING_SIGNATURE=true
      - PYTHON_ENV_INIT_TIMEOUT=120
      - PLUGIN_MAX_EXECUTION_TIMEOUT=600
      - PLUGIN_STDIO_BUFFER_SIZE=1024
      - PLUGIN_STDIO_MAX_BUFFER_SIZE=5242880
      - PIP_MIRROR_URL=
      - PLUGIN_STORAGE_TYPE=local
      - PLUGIN_STORAGE_LOCAL_ROOT=/app/storage
      - PLUGIN_INSTALLED_PATH=plugin
      - PLUGIN_PACKAGE_CACHE_PATH=plugin_packages
      - PLUGIN_MEDIA_CACHE_PATH=assets

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M
      labels:
        - traefik.enable=true
        - traefik.docker.network=$NOME_REDE_INTERNA
        - traefik.http.routers.dify_plugin.rule=Host(\`$DOMAIN_DIFY\`) && PathPrefix(\`/e/\`)
        - traefik.http.routers.dify_plugin.entrypoints=websecure
        - traefik.http.routers.dify_plugin.tls.certresolver=letsencryptresolver
        - traefik.http.services.dify_plugin.loadbalancer.server.port=5002

  dify_ssrf_proxy:
    image: ubuntu/squid:latest

    networks:
      - $NOME_REDE_INTERNA
      - dify_ssrf_proxy_network

    environment:
      ## Configuração do SSRF Proxy
      - HTTP_PORT=3128
      - COREDUMP_DIR=/var/spool/squid
      - REVERSE_PROXY_PORT=8194

      ## Sandbox
      - SANDBOX_HOST=dify_sandbox
      - SANDBOX_PORT=8194

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "2"
          memory: 4096M

volumes:
  dify_storage:
    external: true
    name: dify_storage
  dify_redis_data:
    external: true
    name: dify_redis_data
  dify_weaviate_data:
    external: true
    name: dify_weaviate_data
  dify_sandbox_dependencies:
    external: true
    name: dify_sandbox_dependencies
  dify_sandbox_conf:
    external: true
    name: dify_sandbox_conf
  dify_plugin_daemon:
    external: true
    name: dify_plugin_daemon

networks:
  $NOME_REDE_INTERNA:
    external: true
    name: $NOME_REDE_INTERNA
  dify_ssrf_proxy_network:
    driver: overlay
    internal: true
EOL

# Cria os bancos no postgres (apps só rodam migrations, não criam o banco)
ensure_db "postgres" "dify" || { echo -e "${vermelho}Erro ao preparar o banco no postgres${reset}"; exit 1; }
ensure_db "postgres" "dify_plugin" || { echo -e "${vermelho}Erro ao preparar o banco no postgres${reset}"; exit 1; }

deploy_via_portainer "$STACK_NAME" "dify.yaml"

if [ $? -eq 0 ]; then
    echo -e "${verde}Stack $STACK_NAME enviada com sucesso!${reset}"
    save_data "app-dify" "[ DIFY ]

Dominio: https://$DOMAIN_DIFY

API: https://$DOMAIN_DIFY_API

Secret Key: $secret_key

Plugin Daemon Key: $token_deamon

Inner API Key (Plugins): $token_apikey_plugins

Weaviate API Key: $token_weaviate

Sandbox API Key: $sandbox_key

Rede: $NOME_REDE_INTERNA"
else
    exit 1
fi

rm dify.yaml
exit 0
