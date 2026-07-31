---
kind: lesson
id_key: docker/container-commands/lesson
course: docker
section: container-commands
section_title: Container Commands
section_position: 2
title: Container Lifecycle & Commands
position: 0
estimated_minutes: 45
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 45
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: run-detached-named
      title: Run a detached, named container
      points: 10
      description: Start an nginx:1.27-alpine container named "myserver", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).
      verification_script: |
        docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx
      hint_context: docker run has a flag for detached mode and one for naming — check the "Starting containers" examples above.
      explanation_context: docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.
      solution_script: docker run --name myserver -d --network host nginx:1.27-alpine
    - id_key: stop-and-remove
      title: Stop and remove a container
      points: 10
      description: Start a second container named "tempbox" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in "docker ps -a".
      verification_script: |
        ! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox
      hint_context: docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.
      explanation_context: docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container's filesystem and metadata. docker rm -f does both in one step.
      solution_script: |
        docker run -d --network host --name tempbox alpine:3.20 sleep 3600
        docker rm -f tempbox
    - id_key: exec-and-logs
      title: Exec into a container and check its logs
      points: 10
      description: Using "docker exec", create a file /tmp/hello.txt inside myserver containing the word "hello". Then view myserver's logs.
      verification_script: |
        docker exec myserver test -f /tmp/hello.txt && docker exec myserver grep -q hello /tmp/hello.txt
      hint_context: docker exec myserver sh -c "echo hello > /tmp/hello.txt" runs a command inside the already-running container.
      explanation_context: docker exec runs a new process inside a container that's already running — unlike docker run, which always starts a fresh container. docker logs shows what the container's main process has printed to stdout/stderr.
      solution_script: docker exec myserver sh -c "echo hello > /tmp/hello.txt"
    - id_key: inspect-and-confirm
      title: Inspect the container and confirm it's serving
      points: 10
      description: Use "docker inspect myserver" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
      hint_context: docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox's terminal can't directly curl a container's port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.
      explanation_context: docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other's ports directly via 127.0.0.1 — the pattern this sandbox uses to check "is it really serving," in place of curl-ing the terminal's own localhost.
      solution_script: docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
---

## Syntax

```
docker [CMD] [OPTS] [CONTAINER]
```

## Lifecycle at a glance

`create` → `start` → (`pause`/`unpause`, `stop`/`restart`) → `rm`. `run` is `create` +
`start` in one step. `kill` force-stops and can be combined with removal.

| Command | Description |
|---|---|
| `docker create` | Create a new container (does not start it) |
| `docker run` | Create **and** start a container from an image |
| `docker start` | Start one or more stopped containers |
| `docker stop` | Stop a container (sends `SIGTERM`, then `SIGKILL` after a grace period) |
| `docker restart` | Restart a container |
| `docker pause` / `docker unpause` | Freeze / unfreeze all processes in a container |
| `docker kill` | Kill a running container immediately with `SIGKILL` (or a specified signal) |
| `docker wait` | Block until one or more containers stop, then print their exit codes |
| `docker rm` | Remove a container — must be stopped first, or use `-f` to force |
| `docker update` | Update the resource configuration of one or more containers |

## Inspecting & interacting

| Command | Description |
|---|---|
| `docker ps` | List running containers (`docker ps -a` for running **and** stopped) |
| `docker attach` | Attach your terminal to a running container's main process |
| `docker exec` | Run a new command inside an already-running container |
| `docker logs` | Fetch a container's logs (`-f` to follow, like `tail -f`) |
| `docker inspect` | Full container/image metadata as JSON |
| `docker top` | Show the running processes inside a container |
| `docker stats` | Live CPU, memory, and network I/O usage |
| `docker port` | Show a container's published ports |
| `docker diff` | Inspect changed files/dirs on a container's filesystem vs. its image |
| `docker rename` | Rename a container |
| `docker cp` | Copy files/folders between a container and the local filesystem |
| `docker commit` | Create a new image from a container's current state |
| `docker export` | Export a container's filesystem as a `.tar` archive |

## Examples

### Starting containers

```bash
# Run a container in interactive mode, get a shell
docker run -it alpine:3.20 sh

# Run a container in detached (background) mode and name it
docker run --name myserver -d --network host nginx:1.27-alpine

# Run a container in the background with a short flag
docker run -d <image_name>

# Normally you'd publish a container port to the host with -p <host_port>:<container_port> —
# this lab's sandbox runs its own Docker daemon inside a nested network, so -p publishing
# doesn't reach the terminal you're typing in. --network host sidesteps that: the container
# shares the sandbox's own network directly, no publishing needed. The "Inspecting" section
# below shows the pattern for actually reaching a --network host container's port.
docker run --network host <image_name>
```

[[lab-task:1]]

### Stopping & removing

```bash
# Stop a container, with a 1-second shutdown timeout
docker stop myserver
docker stop -t 1 myserver

# Remove a stopped container; force stop + remove; remove all containers
docker rm myserver
docker rm -f myserver
docker rm -f $(docker ps -aq)

# Remove all stopped containers
docker rm $(docker ps -q -f "status=exited")
```

[[lab-task:2]]

### Interacting with a running container

```bash
# List only active containers, then all containers (including stopped)
docker ps
docker ps -a
docker ps --all

# Open a shell inside a running container
docker exec -it myserver sh

# Follow the logs of a running container
docker logs -f myserver
```

[[lab-task:3]]

### Inspecting

```bash
# Inspect a running container
docker inspect myserver

# Live resource usage
docker container stats

# Confirm myserver is actually serving, using a second throwaway --network host
# container to reach it via 127.0.0.1 (both share the same network stack)
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

[[lab-task:4]]
