---
kind: lesson
id_key: docker/networking-volumes/lesson
course: docker
section: networking-volumes
section_title: Networking & Volumes
section_position: 5
title: Networks & Volumes
position: 0
estimated_minutes: 35
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 35
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: create-and-inspect-network
      title: Create and inspect a custom network
      points: 10
      description: Create a bridge network named "mynetwork" and confirm it exists with the right driver.
      verification_script: |
        docker network inspect mynetwork --format '{{.Driver}}' 2>/dev/null | grep -q bridge
      hint_context: docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.
      explanation_context: docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.
      solution_script: docker network create mynetwork
    - id_key: named-volume-persists
      title: Prove a named volume survives its container
      points: 10
      description: Create a named volume "mydata", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.
      verification_script: |
        docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2>/dev/null | grep -q "still here"
      hint_context: docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo 'still here' > /data/proof.txt" writes the file (--network host is needed for any container to start at all in this sandbox — see the Container Commands lesson); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what's persisting the data.
      explanation_context: A named volume's data lives independently of any one container — that's the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.
      solution_script: |
        docker volume create mydata
        docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo 'still here' > /data/proof.txt"
---

## Networking

By default every container gets a network interface on Docker's default bridge
network. Custom networks give containers a private, name-resolvable network to
communicate over.

```
docker network [CMD] [OPTS]
```

| Command | Description |
|---|---|
| `docker network create` | Create a new network with the given name |
| `docker network ls` | List all networks |
| `docker network inspect` | Show detailed configuration for a network |
| `docker network connect` | Attach a running container to a network |
| `docker network disconnect` | Detach a container from a network |
| `docker network rm` | Delete one or more networks |

```bash
# Create a network, then run a container attached to it
docker network create mynetwork
docker run --name myserver-net -d --net mynetwork nginx:1.27-alpine
```

> This lab sandbox's Docker daemon runs inside its own nested network — creating a
> container that attaches to a *new* bridge network (like `mynetwork` above) doesn't
> work reliably in this environment, so the hands-on task below checks that you can
> create and inspect a network correctly, rather than two containers actually
> resolving each other by name. Everywhere else in this course that needs a
> container reachable at all, `--network host` is the pattern that works here — see
> the [Container Commands](../container-commands/01-lesson.md) lesson.

[[lab-task:1]]

## Volumes

Volumes persist container data outside the container's writable layer, and let
multiple containers share the same data.

```
docker volume [CMD] [OPTS]
```

| Command | Description |
|---|---|
| `docker volume create` | Create a named volume |
| `docker volume inspect` | Show low-level info about a volume |
| `docker volume ls` | List volumes |
| `docker volume rm` | Remove a volume |

```bash
# Bind-mount a local folder into a container at a specific path
docker run --name myserver-bind -d \
  -v myfolder/:/usr/share/nginx/html/ \
  --network host nginx:1.27-alpine

# Create and use a named (Docker-managed) volume instead
docker volume create mydata
docker run --name myserver-vol -d \
  -v mydata:/usr/share/nginx/html \
  --network host nginx:1.27-alpine
```

`-v host_path:container_path` bind-mounts a path from the host. Omit the host path
(`-v /container/path`) or use a name (`-v myvolume:/container/path`) to use a
Docker-managed named volume instead — the difference matters for portability: a
bind mount depends on the host's filesystem layout, a named volume doesn't.

[[lab-task:2]]
