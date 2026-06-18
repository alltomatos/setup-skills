---
description: |
  Diagnostica problemas em uma stack Docker Swarm do ecossistema Setup Orion.
  Analisa logs, status do serviço, uso de recursos e conectividade de rede.
  Use quando o usuário relatar que um serviço está "offline", "não funciona",
  "dando erro" ou "não sobe". Arg: nome da stack.
argument-hint: nome-da-stack (ex: chatwoot, postgres, n8n)
disable-model-invocation: true
allowed-tools: Bash(docker *) Read
---

## Diagnóstico: $ARGUMENTS

### 1. Status do Serviço

```
!`docker service ls 2>/dev/null | grep "$ARGUMENTS" || echo "Servico nao encontrado"`
```

### 2. Tarefas em Execução

```
!`docker service ps "$ARGUMENTS" 2>/dev/null | head -10 || echo "Nao foi possivel"`
```

### 3. Logs Recentes

```
!`docker service logs --tail 50 "$ARGUMENTS" 2>/dev/null || echo "Logs indisponiveis"`
```

### 4. Volume

```
!`docker volume ls --filter name="$ARGUMENTS" 2>/dev/null || echo "Volume nao encontrado"`
```

### 5. Rede Overlay

```
!`docker network ls --filter driver=overlay --format "{{.Name}}" 2>/dev/null | head -10`
```

## Análise e Ações

Com base nos resultados acima, diagnosticar:

| Sintoma | Causa provável | Ação |
|---------|---------------|------|
| 0/1 replicas | Imagem não baixou | `docker pull <imagem>` manual |
| restarting | Falta volume ou env | Ver logs + verificar volume existe |
| running mas sem resposta | Traefik sem rota | Verificar labels traefik |
| Dependência offline | Postgres/Redis down | `docker service ls \| grep -E "postgres\|redis"` |
| CrashLoopBackOff | Config errada | `docker service logs --tail 200` |

## Remedio

Propor e executar a ação correta:
- **Force restart**: `docker service update --force --detach "$ARGUMENTS"`
- **Verificar dependências**: `docker service ls | grep -E "postgres|redis"`
- **Rede**: `docker network inspect orion_network 2>/dev/null | grep -A5 "$ARGUMENTS"`
- **Logs completos**: `docker service logs --tail 200 "$ARGUMENTS"`