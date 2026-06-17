# Skill: app-stirlingpdf

Instalação do Stirling PDF (manipulação de PDF open-source) em cluster Docker Swarm.

## Funcionalidades

- Merge, split, rotate, watermark, OCR e compress de PDFs.
- Conversão entre formatos (PDF <-> Office, imagens).
- Edição de metadados e assinatura digital.

## Dependências

- **app-traefik**: Proxy reverso + SSL.

## Inputs

- `DOMAIN_STIRLINGPDF`: Domínio de acesso.
- `STIRLING_APP_NAME`: Nome exibido na interface.

## Observações

- 2 serviços: backend (Java) + frontend (nginx).
- Sem banco externo — tudo local.
- OCR via Tesseract (dentro do container).
- Login habilitado (admin/stirling padrão — trocar após instalar).
