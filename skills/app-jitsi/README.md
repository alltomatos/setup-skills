# Skill: app-jitsi

Instalação do Jitsi Meet (videoconferência open-source) em cluster Docker Swarm com 4 serviços.

## Funcionalidades

- Videoconferência em sala com vídeo, áudio e screen sharing.
- Autenticação com senha por sala (secure-domain).
- Lobby de espera, enquetes, raise-hand e gravação (via Jibri opcional).

## Dependências

- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_JITSI`: Domínio de acesso.
- `JITSI_PUBLIC_IP`: IP público da VPS (para ICE/NAT).
- `JITSI_USER`: Usuário admin do Prosody.
- `JITSI_PASS`: Senha do admin.

## Observações

- 4 serviços: web + prosody (XMPP) + jicofo (conferencing) + jvb (mídia).
- Portas UDP 10000 e TCP 4443 expostas diretamente (modo host).
- Segredos Jicofo/JVB gerados via `openssl rand` (ADR-002).
- STUN do Google configurado para NAT traversal.
