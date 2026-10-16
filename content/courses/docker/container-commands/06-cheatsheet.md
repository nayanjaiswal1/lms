---
kind: lesson
id_key: docker/container-commands/cheatsheet
course: docker
section: container-commands
section_title: Running Containers
section_position: 2
title: "Reference: Container Commands Cheat Sheet"
position: 5
estimated_minutes: 5
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

Use this page to **look things up**, not to learn from. Every command here was
explained in this section's lessons. Syntax: `docker [COMMAND] [OPTIONS] [CONTAINER]`.
Most commands also exist in the long form `docker container COMMAND`
(for example `docker container ls` = `docker ps`).

## Lifecycle

| Command | What it does |
|---|---|
| `docker create IMAGE` | Create a container but do not start it |
| `docker run IMAGE` | Create **and** start a container |
| `docker start NAME` | Start a stopped container |
| `docker stop NAME` | SIGTERM, wait 10 s (`-t N` to change), then SIGKILL |
| `docker restart NAME` | Stop then start |
| `docker pause` / `unpause NAME` | Freeze / thaw all processes |
| `docker kill NAME` | SIGKILL now (or `-s SIGNAL`) |
| `docker wait NAME` | Block until it stops, print exit code |
| `docker rm NAME` | Delete a stopped container (`-f` to force-stop first) |
| `docker update NAME` | Change resource limits or restart policy of a live container |
| `docker rename OLD NEW` | Rename a container |

## Inspect and interact

| Command | What it does |
|---|---|
| `docker ps` | List running containers (`-a` all, `-q` IDs only, `--filter`, `--format`) |
| `docker logs NAME` | stdout/stderr (`-f` follow, `--tail N`, `--since 10m`, `-t` timestamps) |
| `docker exec -it NAME sh` | Run a new process (shell) inside a running container |
| `docker attach NAME` | Connect your terminal to the main process (Ctrl+P Ctrl+Q detaches) |
| `docker inspect NAME` | Full JSON config/state (`-f '{{.State.Status}}'` for one field) |
| `docker top NAME` | Processes inside |
| `docker stats` | Live CPU/memory/network/IO (`--no-stream` for one sample) |
| `docker port NAME` | Published port mappings |
| `docker diff NAME` | Files added (A), changed (C), deleted (D) vs the image |
| `docker cp SRC DEST` | Copy files between container and host (`NAME:/path`) |
| `docker commit NAME IMAGE` | Snapshot a container into a new image (prefer Dockerfiles) |
| `docker export NAME > fs.tar` | Export a container's filesystem as a tar |

## Most-used `docker run` flags

| Flag | Meaning |
|---|---|
| `-d` | Detached (background) |
| `-it` | Interactive + terminal |
| `--name NAME` | Container name |
| `--rm` | Delete container when it exits |
| `-p HOST:CONTAINER` | Publish port (outside:inside); `-P` publishes all EXPOSEd ports |
| `-e KEY=VAL`, `--env-file F` | Environment variables |
| `-v SRC:DEST`, `--mount` | Volumes and bind mounts (Section 5) |
| `--network NAME` | Attach to a network (Section 5) |
| `-w /path` | Working directory |
| `--entrypoint CMD` | Override the image's ENTRYPOINT |
| `-u UID:GID` | Run as this user |
| `--restart POLICY` | `no`, `on-failure[:N]`, `always`, `unless-stopped` |
| `--memory`, `--cpus`, `--pids-limit` | Resource limits (Section 7) |
| `--read-only`, `--cap-drop`, `--security-opt` | Hardening (Section 7) |

## Handy one-liners

```bash
docker rm $(docker ps -q -f "status=exited")      # remove all stopped containers
docker rm -f $(docker ps -aq)                     # remove ALL containers (careful)
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"   # custom columns
docker inspect -f '{{.State.ExitCode}} {{.State.OOMKilled}}' NAME # why did it die?
docker run -it --rm --entrypoint sh IMAGE         # poke around an image's filesystem
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1-124 | Application error |
| 125 | `docker run` itself failed |
| 126 / 127 | Command not executable / not found |
| 137 | SIGKILL (kill or out of memory) |
| 143 | SIGTERM (normal `docker stop`) |
