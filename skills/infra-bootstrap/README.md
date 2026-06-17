# Skill: infra-bootstrap

## O que faz
Prepara o ambiente Debian 11 para receber as demais skills do ecossistema Orion. Esta é a **skill base** e deve ser executada **antes de qualquer outra**.

## Pré-requisitos
- Sistema operacional: **Debian 11** (recomendado)
- Usuário: **root**
- Conexão com internet ativa

## O que é verificado/instalado

| Pacote         | Finalidade                                    |
|----------------|-----------------------------------------------|
| `sudo`         | Elevação de privilégios                       |
| `git`          | Versionamento de configurações                |
| `python3`      | Scripts auxiliares e automações               |
| `jq`           | Parsing de JSON em scripts bash               |
| `curl`         | Downloads e chamadas HTTP                     |
| `apache2-utils`| Geração de senhas HTTP Basic (`htpasswd`)     |
| `docker`       | Container runtime (instalado via script oficial)|

## Onde os dados ficam

Ao finalizar, a skill grava o relatório em:

```
/root/dados_vps/bootstrap.md
```

E registra a entrada no catálogo central:

```
/root/dados_vps/index.md
```

## Como o Claude conduz esta skill

1. **Claude verifica** se já existe um `bootstrap.md` em `/root/dados_vps/`.
2. Se existir → Claude informa ao usuário o que já está instalado e pergunta se deseja reexecutar.
3. Se não existir → Claude orienta o usuário a confirmar que está logado como `root` e que o sistema é Debian 11.
4. Após confirmação → Claude executa `run.sh`.
5. Claude lê o `bootstrap.md` gerado e apresenta um resumo amigável ao usuário.

## Segurança
- Nenhuma credencial é solicitada nesta skill.
- Todos os pacotes são instalados via repositórios oficiais (`apt` / `get.docker.com`).
- O relatório gerado não contém dados sensíveis.

## 🛠️ Guia de Operações Manuais (DevOps)
Este guia contém rotinas operacionais extraídas do `SetupOrion.md` para serem executadas sob demanda.

### 1. Expurgando (Limpeza Profunda)
Para liberar espaço em disco e remover lixo acumulado de containers e logs:
```bash
# Limpeza completa do Docker (Containers parados, redes não usadas, imagens sem tag e volumes órfãos)
docker system prune -a -f --volumes

# Limpeza de logs do sistema (mantendo apenas as últimas 24h)
journalctl --vacuum-time=1d

# Limpeza de cache de pacotes
apt-get clean && apt-get autoremove -y
```

### 2. Trocar Logos (Rebranding)
As marcas visuais das aplicações podem ser substituídas diretamente nos volumes de dados:
- **Localização:** `/root/dados_vps/app-<nome-da-skill>/`
- **Procedimento:**
  1. Identifique o caminho da imagem no `README.md` da skill ou no container.
  2. Substitua o arquivo físico no host.
  3. Reinicie o serviço: `docker service update --force <nome_da_stack>_<serviço>`

### 3. Gestão de Stacks e Limpeza
Para remover uma solução completamente:
1. **Remover containers:** `docker stack rm <nome_da_stack>`
2. **Remover volumes (opcional):** `docker volume rm $(docker volume ls -q | grep <nome_da_stack>)`
3. **Limpar metadados:** Remova o arquivo correspondente em `/root/dados_vps/app-<nome-da-skill>.md` para que o orquestrador considere a skill desinstalada.
