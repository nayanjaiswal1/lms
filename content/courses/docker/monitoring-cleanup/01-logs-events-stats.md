---
kind: lesson
id_key: docker/monitoring-cleanup/lesson
course: docker
section: monitoring-cleanup
section_title: Troubleshooting & Cleanup
section_position: 8
title: "Observing Containers: Logs, Events, Stats and Log Drivers"
position: 0
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
---

## Why this matters

When something breaks at 3 a.m., you need to know **what happened** (logs),
**when** (events) and **how hard the machine is working** (stats). You met
`docker logs` in Section 2. This lesson adds the rest of the toolbox, plus the
one setting that stops logs from filling your disk.

## Mental model: a car dashboard

| Gauge | Docker command | Answers |
|---|---|---|
| Trip recorder | `docker logs` | What did the app say? |
| Black box / event log | `docker events` | What happened to containers (start, die, OOM, health)? |
| Speedometer and fuel | `docker stats` | CPU, memory, network, disk I/O right now |
| Passenger list | `docker top`, `docker ps` | Which processes / containers exist? |

## See it work

### Logs, with time filters

```bash
docker logs --since 10m --tail 100 -t api   # last 100 lines from the last 10 min, with timestamps
docker logs -f api 2>&1 | grep -i error    # follow and filter (stderr included)
```

### Events: the daemon's timeline

```bash
docker events --since 30m --filter container=api
```

Expected lines (shortened):

```
2026-10-16T10:01:12 container start 5c1f... (image=api:1.8.0, name=api)
2026-10-16T10:14:55 container oom 5c1f... (name=api)
2026-10-16T10:14:55 container die 5c1f... (exitCode=137, name=api)
2026-10-16T10:14:56 container restart 5c1f... (name=api)
```

This tells a story `docker logs` cannot: the container was **OOM-killed** and
restarted. Other useful filters: `--filter event=die`, `--filter event=health_status`,
`--filter type=image`. Without `--since`, `docker events` streams live until Ctrl+C.

### Stats: live resource use

```bash
docker stats                    # live table for all running containers (Ctrl+C to stop)
docker stats --no-stream        # one snapshot (good for scripts)
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

```bash
docker top api                  # processes inside the container
docker port api                 # published ports
docker ps -a                    # running AND stopped containers
```

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
      "explanation": "docker top answers \"what processes are running in this container\" (like ps inside it). docker stats answers \"how much CPU/memory/network is this container using right now\": a live resource dashboard, not a process list."
    }
  ]
}
```

### Log drivers and rotation

Where do `docker logs` lines live? The default **log driver** `json-file`
writes them to a file under `/var/lib/docker/containers/<id>/`, and by default
that file **grows forever**.

Set rotation per container:

```bash
docker run -d --log-opt max-size=10m --log-opt max-file=3 nginx:1.27-alpine
```

Or for every container, in `/etc/docker/daemon.json` (then restart Docker):

```json
{
  "log-driver": "local",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
```

The `local` driver is compact and rotates by default. Other drivers ship logs
elsewhere: `journald`, `syslog`, `fluentd`, `gelf`, `awslogs`, `gcplogs`. With
most remote drivers, `docker logs` still works through Docker's dual logging cache.

In Compose:

```yaml
services:
  api:
    logging:
      driver: local
      options: { max-size: "10m", max-file: "3" }
```

## Try it

A container restarted at 02:14 and its logs show nothing unusual before the
restart. Which command reveals why, and what would you look for?

<details>
<summary>Show answer</summary>

```bash
docker events --since "2026-10-16T02:00:00" --until "2026-10-16T02:30:00" --filter container=NAME
```

Look for an `oom` event, or `die` with `exitCode=137` (killed) vs another code,
or `health_status: unhealthy` followed by a restart from an orchestrator.
`docker inspect -f '{{.State.OOMKilled}}' NAME` confirms an OOM for the last exit.

</details>

## Common mistakes

- **No log rotation.** The json-file log grows until the disk is full and the host stops.
- **Apps logging to files inside the container.** `docker logs` is empty, and the
  writable layer grows. Log to stdout/stderr.
- **Using `docker stats` for history.** It shows only *now*. For trends, export
  metrics (cAdvisor, Prometheus, your cloud's monitoring).

## Remember

- `logs` = what the app said; `events` = what happened to the container; `stats` = resource use now.
- `docker events --filter container=X --since 1h` explains restarts and OOM kills.
- Default `json-file` logs grow forever: set `max-size`/`max-file`, or use the `local` driver.
- Log to stdout/stderr; ship logs with a log driver or collector.

**Self-check:**

1. Which command shows that a container was OOM-killed, besides `inspect`?
2. Where does the default log driver store logs, and what is its danger?
3. Name two log drivers other than `json-file`.
