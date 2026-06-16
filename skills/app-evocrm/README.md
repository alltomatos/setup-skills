# Skill: app-evocrm

Instalação do EvoCRM (Sistema de CRM focado em AI e Automação baseada em microserviços) em cluster Docker Swarm.

## Arquitetura

- **Gateway**: Roteador interno para os serviços.
- **Auth**: Serviço de autenticação centralizado.
- **CRM Core**: Core da aplicação de atendimento.
- **Processor**: Processamento de inteligência artificial e agentes.
- **Bot Runtime**: Execução de fluxos de chatbot.
- **Frontend**: Interface React para o usuário.

## Dependências

- **PgVector**: Base de dados vetorial compartilhada.
- **Redis**: Instância dedicada para filas e cache.

## Inputs

- Domínios para Frontend e API Gateway.
- Configurações SMTP completas.

## Observações

- Devido à complexidade da stack, os serviços de banco de dados e Redis são configurados com limites de recursos claros.
- A skill realiza migrações automáticas nos serviços Rails.
