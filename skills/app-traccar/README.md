# Skill: Traccar

Instala o **Traccar**, um sistema moderno, open-source e completo para rastreamento GPS de frotas e dispositivos móveis.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- **Portas:** A porta web padrão do Traefik será usada. Se você precisar que os rastreadores (GPS físico) enviem dados, será necessário expor portas adicionais (TCP/UDP) no cluster no arquivo `run.sh` dependendo do protocolo do seu aparelho.

## Inputs solicitados

- `DOMAIN_TRACCAR`: Domínio para acessar a interface da aplicação.

## Pós-instalação

1. Acesse `https://<DOMAIN_TRACCAR>`.
2. A aplicação fará a criação inicial do esquema do banco de dados (isso pode levar 1-2 minutos).
3. O usuário e senha padrão devem ser cadastrados no primeiro login.

## Persistência

A configuração em XML (`traccar.xml`) e os logs ficam em `/opt/traccar/`.
Os dados do banco de dados ficam no volume `traccar_db`.
A persistência da skill é salva em `/root/dados_vps/app-traccar.md`.
