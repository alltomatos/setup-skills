# ORCHESTRATOR-ROADMAP

Este documento mapeia o progresso do projeto `setup-skills` sob governança do orquestrador.

## Epics

- [x] **E1: Bootstrap do Ecossistema** (Configuração, docs, governança)
- [x] **E2: Estrutura de Skills & Persistência** (Decomposição, bibliotecas, padrão MD)
- [x] **E3: Implementação de Skills Base** (infra-bootstrap + app-traefik)
- [ ] **E4: Implementação de Skills de Aplicação** (Chatwoot, Evolution, N8n, Typebot, Minio, etc)
- [ ] **E5: Auditoria, Testes e Qualidade** (Segurança e Validação)

## Status

- **Fase Atual**: 4 (Skills de Aplicação)
- **Estado**: Iniciando

## Tarefas (DAG)

- [x] T1: Criar .gitignore | depends_on: []
- [x] T2: Remover lixo de sistema | depends_on: []
- [x] T3: Organizar docs/ | depends_on: []
- [x] T4: Criar ADR-001 (Padrão Persistência em Markdown) | depends_on: []
- [x] T5: Criar ADR-002 (Segurança de Segredos e Contexto) | depends_on: []
- [x] T6: Estruturar diretório base de skills | depends_on: [T4, T5]
- [x] T7: Implementar lib-persistence.sh (escrita atômica, index.md) | depends_on: [T6]
- [x] T8: Skill infra-bootstrap (idempotente, log MD) | depends_on: [T7]
- [x] T9: Skill app-traefik + app-portainer (Swarm, SSL, pré-flight) | depends_on: [T8]
- [ ] T10: Skill app-chatwoot | depends_on: [T9]
- [ ] T11: Skill app-evolution | depends_on: [T9]
- [ ] T12: Skill app-n8n | depends_on: [T9]
- [ ] T13: Skill app-typebot | depends_on: [T9]
- [ ] T14: Skill app-minio | depends_on: [T9]
- [ ] T15: Auditoria de segurança e testes | depends_on: [T10, T11, T12, T13, T14]
