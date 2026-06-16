# Skill: app-evolution

## O que faz

Deploya a **Evolution API** (gateway WhatsApp Business) via **Docker Swarm** em stack única com Redis embutido, integração ao PostgreSQL externo e geração automática de API Key segura. Exposição via Traefik com SSL automático (Let's Encrypt).

## Dependências

- `app-traefik` deve ter sido executada antes (Traefik ativo e rede overlay criada).
- PostgreSQL externo acessível na rede overlay via `host=postgres, user=postgres`.

---

## Inputs solicitados pelo Claude

| Variável            | O que é                                       | Fonte                              | Sensível? |
|---------------------|-----------------------------------------------|------------------------------------|-----------|
| `URL_EVOLUTION`     | Domínio da Evolution API (sem `https://`)     | Usuário informa                    | Não       |
| `SENHA_POSTGRES`    | Senha do usuário `postgres` no BD externo     | Usuário informa                    | **Sim**   |
| `NOME_REDE_INTERNA` | Nome da rede overlay Docker                   | Lido de `/root/dados_vps/traefik.md` | Não       |

> `AUTHENTICATION_API_KEY` é gerada automaticamente via `openssl rand -hex 16` — o usuário não precisa informá-la.

---

## Pré-checagens (Claude confirma com o usuário)

1. **DNS**: `URL_EVOLUTION` já aponta para o IP desta VPS? (SSL falha sem isso)
2. **Traefik**: skill `app-traefik` já foi executada e o Traefik está ativo?
3. **PostgreSQL**: o banco `evolution` existe? (`CREATE DATABASE evolution;`)

---

## Como o Claude conduz esta skill

1. **Lê dependências**: verifica `/root/dados_vps/traefik.md` para confirmar Traefik ativo e capturar `NOME_REDE_INTERNA`.
2. **Entrevista**: solicita `URL_EVOLUTION` e `SENHA_POSTGRES` ao usuário. `NOME_REDE_INTERNA` é preenchido automaticamente.
3. **Pré-flight**: confirma DNS do domínio e existência do banco `evolution` no PostgreSQL.
4. **Confirmação**: exibe resumo (sem mostrar `SENHA_POSTGRES`) e pede aprovação explícita antes de executar.
5. **Execução**: injeta as variáveis e roda:
   ```bash
   URL_EVOLUTION="..." SENHA_POSTGRES="..." NOME_REDE_INTERNA="..." ./run.sh
   ```
6. **Pós-deploy**: lê `/root/dados_vps/evolution.md`, exibe a `API_KEY` gerada e orienta o usuário a acessar `/manager`.

---

## Artefatos gerados

| Arquivo                            | Conteúdo                                          |
|------------------------------------|---------------------------------------------------|
| `/root/evolution.yaml`             | Stack Docker Swarm da Evolution API (editável)    |
| `/root/dados_vps/evolution.md`     | Metadados do deploy, URL, API Key gerada          |

> A `SENHA_POSTGRES` **nunca** é escrita em nenhum arquivo — política inegociável de segurança Orion.

---

## Recursos provisionados

- **Serviços Swarm**: `evolution_api` (porta 8080) e `evolution_redis` (cache interno).
- **Volumes**: `evolution_instances` (instâncias WhatsApp), `evolution_redis` (persistência Redis).
- **Rede**: usa a rede overlay existente (`NOME_REDE_INTERNA`) provisionada pelo Traefik.
- **SSL**: gerenciado pelo Traefik via Let's Encrypt (sem configuração adicional).
- **Manager**: `https://{URL_EVOLUTION}/manager` — painel web de gerenciamento de instâncias.
