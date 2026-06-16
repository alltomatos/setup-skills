# Skill: app-traefik

## O que faz
Deploya o **Traefik v3.5.3** (proxy reverso com SSL automático) e o **Portainer CE** (gerenciador visual de containers) via **Docker Swarm**. Esta é a **segunda skill obrigatória** do ecossistema — sem ela, nenhuma aplicação (Chatwoot, Evolution, N8n, etc.) consegue ser exposta com domínio e HTTPS.

## Dependências
- ✅ `infra-bootstrap` deve ter sido executada antes (Docker instalado).

## Dados que o Claude irá solicitar

| Variável            | O que é                          | Sensível? |
|---------------------|----------------------------------|-----------|
| `NOME_SERVIDOR`     | Nome identificador do servidor   | Não       |
| `NOME_REDE_INTERNA` | Nome da rede overlay Docker      | Não       |
| `EMAIL_SSL`         | Email para Let's Encrypt         | Não       |
| `URL_PORTAINER`     | Domínio do Portainer             | Não       |

> **Nota de segurança (ADR-002)**: Esta skill não coleta senhas. As credenciais do Portainer são definidas pelo próprio usuário no primeiro acesso à interface web.

## Pré-checagens (Claude deve confirmar com o usuário)
1. **DNS**: O `URL_PORTAINER` já aponta para o IP desta VPS? (Sem isso, o SSL falha).
2. **Firewall**: As portas `80` e `443` estão liberadas?
3. **Bootstrap**: A skill `infra-bootstrap` já rodou?

## Como o Claude conduz esta skill

1. **Verifica dependência**: confere se `/root/dados_vps/bootstrap.md` existe.
2. **Entrevista**: pergunta as 4 variáveis ao usuário, uma de cada vez, validando o formato (ex: email válido, domínio sem `http://`).
3. **Pré-flight**: relembra o usuário das checagens de DNS e firewall.
4. **Confirmação**: mostra um resumo dos dados e pede aprovação explícita antes de executar.
5. **Execução**: injeta as variáveis e roda:
   ```bash
   NOME_SERVIDOR="..." NOME_REDE_INTERNA="..." EMAIL_SSL="..." URL_PORTAINER="..." ./run.sh
   ```
6. **Pós-deploy**: lê `traefik.md` e `portainer.md`, e orienta o usuário a acessar a URL do Portainer para criar o admin **em até 5 minutos**.

## Artefatos gerados

| Arquivo                          | Conteúdo                          |
|----------------------------------|-----------------------------------|
| `/root/traefik.yaml`             | Stack do Traefik (editável)       |
| `/root/portainer.yaml`           | Stack do Portainer (editável)     |
| `/root/dados_vps/traefik.md`     | Metadados do deploy do Traefik    |
| `/root/dados_vps/portainer.md`   | Metadados e URL do Portainer      |

## Recursos provisionados
- **Docker Swarm** inicializado (se ainda não estiver).
- **Volumes**: `volume_swarm_shared`, `volume_swarm_certificates`, `portainer_data`.
- **Rede overlay**: conforme `NOME_REDE_INTERNA`.
