---
description: |
  Relata o estado atual do ecossistema Orion: stacks ativas, skills instaladas,
  uso de recursos e alertas. Use quando o usuário pedir "status", "como está
  o servidor", "quais serviços estão rodando" ou "ver stacks".
disable-model-invocation: true
allowed-tools: Bash(docker *) Read
---

## Serviços Ativos

```
!`docker service ls 2>/dev/null | grep -v "^ID" | sort || echo "Swarm indisponivel"`
```

## Skills Instaladas

```
!`ls /root/dados_vps/*.md 2>/dev/null | wc -l | xargs echo "Total:" || echo "Nenhuma"`
```

## Recursos

```
!`df -h / 2>/dev/null | tail -1`
```

## Redes Overlay

```
!`docker network ls --filter driver=overlay --format "{{.Name}}" 2>/dev/null`
```