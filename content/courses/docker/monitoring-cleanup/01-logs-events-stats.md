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

```knowledge-check
{
  "questions": [
    {
      "id": "docker-monitoring-logs-q1",
      "type": "mcq",
      "prompt": "docker ps with no flags shows only running containers. Which command also shows stopped ones?",
      "options": [
        { "id": "a", "text": "docker ps -a" },
        { "id": "b", "text": "docker top" },
        { "id": "c", "text": "docker events" },
        { "id": "d", "text": "docker port" }
      ],
      "correct": "a",
      "explanation": "docker ps -a (\"all\") includes containers that have exited, not just currently-running ones. docker top shows processes inside a running container; docker events streams daemon activity; docker port shows a container's published ports."
    },
    {
      "id": "docker-monitoring-logs-q2",
      "type": "mcq",
      "prompt": "What's the difference between docker top and docker stats?",
      "options": [
        { "id": "a", "text": "They are aliases for the same command" },
        { "id": "b", "text": "docker top lists the container's running processes; docker stats shows live CPU/memory/network usage" },
        { "id": "c", "text": "docker top shows CPU usage; docker stats lists processes" },
        { "id": "d", "text": "docker stats only works on stopped containers" }
      ],
      "correct": "b",
      "explanation": "docker top answers \"what processes are running in this container\" (like ps inside it). docker stats answers \"how much CPU/memory/network is this container using right now\" — a live resource dashboard, not a process list."
    }
  ]
}
```

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

```knowledge-check
{
  "questions": [
    {
      "id": "docker-monitoring-prune-q1",
      "type": "mcq",
      "prompt": "Is it safe to run plain docker system prune without first checking docker ps?",
      "options": [
        { "id": "a", "text": "No — it can delete a running container" },
        { "id": "b", "text": "Yes — it only removes resources not associated with a running container" },
        { "id": "c", "text": "Only if --volumes is omitted" },
        { "id": "d", "text": "Only on a freshly restarted daemon" }
      ],
      "correct": "b",
      "explanation": "docker system prune skips anything a running container still references. Whatever it removes was already stopped/dangling/unused, so it's safe to run routinely."
    },
    {
      "id": "docker-monitoring-prune-q2",
      "type": "mcq",
      "prompt": "What does adding -a to docker system prune change?",
      "options": [
        { "id": "a", "text": "It also stops running containers first" },
        { "id": "b", "text": "It also removes images not referenced by any container, running or not" },
        { "id": "c", "text": "It also removes named volumes" },
        { "id": "d", "text": "It runs the prune faster" }
      ],
      "correct": "b",
      "explanation": "Plain prune only touches dangling (untagged) images. -a widens that to every image not currently used by any container. --volumes is the separate flag that additionally reclaims unused volumes."
    }
  ]
}
```
