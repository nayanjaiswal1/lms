---
kind: lesson
id_key: docker/container-commands/lesson
course: docker
section: container-commands
section_title: Container Commands
section_position: 2
title: Container Lifecycle & Commands
position: 0
estimated_minutes: 30
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
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

```bash
# Run a container in interactive mode, get a shell
docker run -it rhel7/rhel bash

# Run a container in detached (background) mode, name it, publish a port
docker run --name mywildfly -d -p 8080:8080 jboss/wildfly

# Run a container in the background with a short flag
docker run -d <image_name>

# Publish container port(s) to the host: -p <host_port>:<container_port>
docker run -p 8080:8080 <image_name>

# Follow the logs of a running container
docker logs -f mywildfly

# List only active containers, then all containers (including stopped)
docker ps
docker ps -a
docker ps --all

# Stop a container, with a 1-second shutdown timeout
docker stop mywildfly
docker stop -t 1 mywildfly

# Remove a stopped container; force stop + remove; remove all containers
docker rm mywildfly
docker rm -f mywildfly
docker rm -f $(docker ps -aq)

# Remove all stopped containers
docker rm $(docker ps -q -f "status=exited")

# Open a shell inside a running container
docker exec -it mywildfly bash

# Inspect a running container
docker inspect mywildfly

# Live resource usage
docker container stats
```
