# Skill: app-quepasa

Instalação do Quepasa (Gateway WhatsApp de alta performance) em cluster Docker Swarm.

## Funcionalidades

- Gerenciamento de múltiplas instâncias de WhatsApp.
- API estável e rápida.
- Painel administrativo integrado (inicialmente com setup aberto).

## Inputs

- `DOMAIN_QUEPASA`: Domínio de acesso.

## Observações

- **Banco de Dados**: Utiliza a instância global `infra-postgres`.
- **Segurança**: O `ACCOUNTSETUP` é ativado por padrão para permitir a criação da primeira conta. Recomenda-se desativá-lo após o setup inicial.
- **Recursos**: Configurado com limite de 2 CPUs e 2GB RAM para garantir estabilidade.
