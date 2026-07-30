---
kind: lesson
id_key: docker/networking-volumes/lesson
course: docker
section: networking-volumes
section_title: Networking & Volumes
section_position: 5
title: Networks & Volumes
position: 0
estimated_minutes: 25
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
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
docker run --name mywildfly-net -d --net mynetwork \
  -p 8080:8080 jboss/wildfly
```

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
docker run --name mywildfly-volume -d \
  -v myfolder/:/opt/jboss/wildfly/standalone/deployments/ \
  -p 8080:8080 jboss/wildfly
```

`-v host_path:container_path` bind-mounts a path from the host. Omit the host path
(`-v /container/path`) or use a name (`-v myvolume:/container/path`) to use a
Docker-managed named volume instead — the difference matters for portability: a
bind mount depends on the host's filesystem layout, a named volume doesn't.
