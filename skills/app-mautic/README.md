# Skill: app-mautic

Instalação do Mautic 5 (Plataforma líder em Automação de Marketing open-source) em cluster Docker Swarm.

## Estrutura

- **Web**: Interface principal e API.
- **Worker**: Processamento de filas de e-mail e hits.
- **Cron**: Execução programada de campanhas e segmentos.

## Dependências

- **MySQL**: Utiliza a instância global `infra-mysql`.

## Inputs

- `DOMAIN_MAUTIC`: Domínio de acesso.

## Observações

- A skill configura automaticamente os workers e o cron do Mautic via containers dedicados.
- Recomenda-se configurar o SMTP dentro do painel do Mautic após o primeiro acesso.
- Utiliza volumes externos para garantir que uploads e configurações não sejam perdidos.
