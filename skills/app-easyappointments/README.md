# Skill: Easy!Appointments

Esta skill realiza o deploy do **Easy!Appointments**, uma aplicação web altamente customizável que permite que seus clientes agendem compromissos com você via web.

## Características
- **Deploy via Docker Swarm**: Idempotente e resiliente.
- **Banco de Dados**: Utiliza MySQL externo.
- **Customização Apache**: Inclui configuração de `ServerName` para evitar conflitos de redirecionamento.
- **Persistência**: Dados da aplicação armazenados em volume Docker externo.

## Requisitos
- `infra-bootstrap`
- `app-traefik`
- `infra-mysql` (Banco de dados MySQL ativo no host `mysql`)

## Como Usar
Defina as variáveis de ambiente necessárias e execute o `run.sh`:

```bash
URL_EASYAPPOINTMENTS="agenda.exemplo.com" \
SENHA_MYSQL="suasenha" \
NOME_REDE_INTERNA="OrionNet" \
./run.sh
```

## Persistência de Dados
Os metadados da instalação são salvos em `/root/dados_vps/easyappointments.md`.
Os dados do site são armazenados em volume Docker externo.
