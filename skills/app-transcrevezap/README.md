# Skill: app-transcrevezap

Instalação do TranscreveZap (Ferramenta de transcrição de áudios do WhatsApp usando modelos Whisper ou similares) em cluster Docker Swarm.

## Estrutura

- **API**: Endpoint para recebimento de webhooks e processamento.
- **Manager**: Interface Streamlit para gestão de instâncias e visualização de logs.
- **Redis Dedicado**: Instância exclusiva rodando na porta 6380.

## Inputs

- Domínios para API e Manager.
- Credenciais de acesso ao Manager.

## Observações

- A ferramenta é otimizada para integração com Evolution API e outras plataformas de WhatsApp.
- Requer recursos consideráveis de CPU se a transcrição for feita localmente (depende da imagem e configuração interna).
