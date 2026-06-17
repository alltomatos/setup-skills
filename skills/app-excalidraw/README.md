# Skill: app-excalidraw

Instalação do Excalidraw (whiteboard colaborativo open-source) em cluster Docker Swarm.

## Funcionalidades

- Quadro branco colaborativo com figuras, setas e texto.
- Excalidraw Library (componentes reutilizáveis).
- Exportação para PNG, SVG e PDF.

## Dependências

- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_EXCALIDRAW`: Domínio de acesso.

## Observações

- Deploy single-container (sem banco externo).
- Dados persistidos via volume Docker.
- ADR-002: sem segredos.
