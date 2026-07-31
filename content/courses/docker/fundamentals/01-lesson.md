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

```knowledge-check
{
  "questions": [
    {
      "id": "docker-fundamentals-concepts-q1",
      "type": "mcq",
      "prompt": "What is the relationship between an image and a container?",
      "options": [
        { "id": "a", "text": "They are interchangeable names for the same thing" },
        { "id": "b", "text": "An image is a runtime instance of a container" },
        { "id": "c", "text": "A container is a runtime instance created from an image; many containers can run from one image" },
        { "id": "d", "text": "An image can only ever produce one container" }
      ],
      "correct": "c",
      "explanation": "The image is the standalone, executable template. A container is what you get when that template is actually run — and any number of containers can be started from the same image, all sharing identical starting behavior."
    },
    {
      "id": "docker-fundamentals-concepts-q2",
      "type": "mcq",
      "prompt": "What is a registry for?",
      "options": [
        { "id": "a", "text": "Running containers from images" },
        { "id": "b", "text": "Storing images remotely so they can be pushed to and pulled from other machines" },
        { "id": "c", "text": "Compiling application source code into an image" },
        { "id": "d", "text": "Monitoring container CPU and memory usage" }
      ],
      "correct": "b",
      "explanation": "A registry (Docker Hub by default) is a remote store for named, tagged images — the mechanism for moving an image between machines via push/pull."
    }
  ]
}
```

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

```knowledge-check
{
  "questions": [
    {
      "id": "docker-fundamentals-architecture-q1",
      "type": "mcq",
      "prompt": "Which component actually builds and runs containers and images?",
      "options": [
        { "id": "a", "text": "The docker client binary" },
        { "id": "b", "text": "The runtime (daemon)" },
        { "id": "c", "text": "The registry" },
        { "id": "d", "text": "The Dockerfile" }
      ],
      "correct": "b",
      "explanation": "The client is just how you send commands (build/pull/run) to the daemon, over a local socket or remote API. The daemon is the runtime that actually manages containers and images; the registry only stores images."
    }
  ]
}
```

## Basic commands

| Command | Description |
|---|---|
| `docker` | List all available Docker commands |
| `docker --help` | Help for Docker, or any subcommand with `--help` |
| `docker version` | Show the Docker client/server version |
| `docker info` | Display system-wide information (daemon, storage driver, containers, images) |
| `docker -d` | Start the Docker daemon directly (normally managed by your OS's service manager) |

```knowledge-check
{
  "questions": [
    {
      "id": "docker-fundamentals-commands-q1",
      "type": "mcq",
      "prompt": "You want to see the daemon's storage driver, and how many containers and images currently exist. Which command shows that?",
      "options": [
        { "id": "a", "text": "docker version" },
        { "id": "b", "text": "docker info" },
        { "id": "c", "text": "docker --help" },
        { "id": "d", "text": "docker -d" }
      ],
      "correct": "b",
      "explanation": "docker version only reports the client/server version numbers. docker info is the one that shows system-wide daemon state — storage driver, container counts, image counts, and more."
    }
  ]
}
```

The rest of this course walks through the command surface by area: containers,
images, Dockerfiles, networking/volumes, Compose/Hub, and monitoring/cleanup — then
ties it together with two runnable end-to-end examples.
