# Skill: RustDesk Server

Instala o seu próprio servidor de acesso remoto **RustDesk**, garantindo total privacidade e controle sobre suas conexões de suporte técnico.

## Pré-requisitos

- Cluster Docker Swarm ativo.
- Skill `app-traefik` instalada.
- Portas 21115-21119 abertas no firewall (TCP e UDP para 21116).

## Inputs solicitados

- `DOMAIN_HBBS`: Domínio para o servidor de ID (ex: id.meudominio.com).
- `DOMAIN_HBBR`: Domínio para o servidor de relay (ex: relay.meudominio.com).

## Pós-instalação

1. No cliente RustDesk, acesse **Configurações -> Rede**.
2. No campo **Servidor de ID**, coloque o `DOMAIN_HBBS`.
3. No campo **Servidor de Relay**, coloque o `DOMAIN_HBBR`.
4. No campo **Key**, cole a chave pública gerada.
5. Alternativamente, cole a `Config String` no campo correspondente para configuração rápida.

## Persistência

As chaves do servidor e logs são persistidos no volume `rustdesk_data`.
A persistência da skill é salva em `/root/dados_vps/app-rustdesk.md`.
