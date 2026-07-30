---
kind: lesson
id_key: docker/monitoring-cleanup/lesson
course: docker
section: monitoring-cleanup
section_title: Monitoring & Cleanup
section_position: 7
title: Logs, Monitoring & Cleanup
position: 0
estimated_minutes: 15
source:
  - Docker Command Cheat Sheet.pdf
---

## Logs & monitoring

| Command | Description |
|---|---|
| `docker ps -a` | Show running **and** stopped containers |
| `docker logs` | Show a container's logs (`-f` to follow) |
| `docker events` | Stream real-time events from the daemon (container start/stop/die, image pull, ...) |
| `docker top` | Show running processes inside a container |
| `docker stats` | Live CPU, memory, and network I/O usage per container |
| `docker port` | Show a container's published ports |

## Cleanup / prune commands

Docker accumulates disk usage fast — stopped containers, dangling images, unused
volumes and networks. Prune commands reclaim that space in one shot:

| Command | Description |
|---|---|
| `docker system prune` | Remove all resources (stopped containers, dangling images, unused networks, build cache) not associated with a running container |
| `docker image prune` | Remove dangling (untagged) images |
| `docker container prune` | Remove all stopped containers |
| `docker volume prune` | Remove all volumes not used by at least one container |
| `docker network prune` | Remove all networks not used by at least one container |

```bash
# Reclaim everything unused in one command
docker system prune

# Narrower cleanups
docker container prune
docker image prune
docker volume prune
docker network prune
```

`docker system prune` skips anything a running container still references — it's
safe to run routinely without checking `docker ps` first. Add `-a` to also remove
images not referenced by *any* container (running or not), and `--volumes` to include
unused volumes in the same pass.
