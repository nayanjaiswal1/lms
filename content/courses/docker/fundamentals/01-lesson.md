---
kind: lesson
id_key: docker/fundamentals/lesson
course: docker
section: fundamentals
section_title: Fundamentals
section_position: 1
title: What Docker Is
position: 0
estimated_minutes: 20
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Containers, images, registries

Docker packages an application, and everything it needs to run, into a **container
image**: a base operating system, libraries, files and folders, environment variables,
volume mount-points, and the application binaries itself.

- **Image** — a lightweight, standalone, executable template. Multiple containers can
  run from the same image, all sharing identical behavior. This is what makes an
  application scalable and distributable.
- **Container** — a runtime instance of an image. A container always runs the same way
  regardless of the underlying infrastructure, isolating the app from host differences
  (e.g. dev vs. staging).
- **Registry** — a remote store for images (Docker Hub is the default, at
  `https://hub.docker.com`). Images are pushed to and pulled from a registry to move
  them between machines.

## Container architecture

Three components make up the architecture, and you interact with all of them through
the single `docker` client binary:

```
Client                Runtime (Daemon)              Registry
------                -----------------              --------
docker build   --->   builds/runs containers  --->   image registry
docker pull    <---   and images                <---  (pull images down)
docker run     --->   from local images
```

The daemon manages containers and images locally; the client sends it commands
(`build`, `pull`, `run`, ...) either over a local socket or a remote API. The registry
is where named, tagged images live so they can be shared across machines.

## Basic commands

| Command | Description |
|---|---|
| `docker` | List all available Docker commands |
| `docker --help` | Help for Docker, or any subcommand with `--help` |
| `docker version` | Show the Docker client/server version |
| `docker info` | Display system-wide information (daemon, storage driver, containers, images) |
| `docker -d` | Start the Docker daemon directly (normally managed by your OS's service manager) |

The rest of this course walks through the command surface by area: containers,
images, Dockerfiles, networking/volumes, Compose/Hub, and monitoring/cleanup — then
ties it together with two runnable end-to-end examples.
