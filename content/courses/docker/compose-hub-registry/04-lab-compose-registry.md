---
kind: lesson
id_key: docker/compose-hub-registry/lesson
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: Docker Compose, Hub & Registries
position: 0
estimated_minutes: 35
source:
  - Docker Command Cheat Sheet.pdf
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 35
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: compose-up
      title: Bring up a service with Docker Compose
      points: 10
      description: Write the compose.yaml from the example above to ~/work/compose.yaml and bring it up with "docker compose up -d".
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
      hint_context: docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.
      explanation_context: Compose's whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.
      solution_script: |
        mkdir -p /home/labuser/work-compose && cd /home/labuser/work-compose
        cat > compose.yaml <<'EOF'
        services:
          web:
            image: nginx:1.27-alpine
            network_mode: host
            volumes:
              - webdata:/usr/share/nginx/html
        volumes:
          webdata:
        EOF
        docker compose up -d
    - id_key: registry-round-trip
      title: Push and pull through the offline registry
      points: 10
      description: Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.
      verification_script: |
        docker image inspect localhost:5000/myimage:latest >/dev/null 2>&1
      hint_context: docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.
      explanation_context: The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.
      solution_script: |
        docker tag alpine:3.20 localhost:5000/myimage:latest
        docker push localhost:5000/myimage:latest
        docker rmi localhost:5000/myimage:latest
        docker pull localhost:5000/myimage:latest
---

## Docker Compose

Compose defines and runs multi-container applications from a single YAML file
(`compose.yaml`), so you don't have to chain individual `docker run` commands.
`docker-compose` (a separate binary) was Compose v1 — `docker compose` (a subcommand
of the `docker` CLI itself, no hyphen) is v2 and what every modern install ships.

| Command | Description |
|---|---|
| `docker compose build` | Build the images referenced in the compose file |
| `docker compose up` | Create and start all services defined in the compose file |
| `docker compose start` | Start services that were already created by a previous `up` |
| `docker compose run` | Run a one-off command inside one of the compose services |
| `docker compose ps` | Show status of the compose stack's containers |
| `docker compose ls` | List running compose projects |
| `docker compose down` | Stop and remove the compose stack's containers |

```yaml
# compose.yaml
services:
  web:
    image: nginx:1.27-alpine
    # This lab sandbox's Docker runs inside its own nested network (see the
    # Container Commands lesson) — network_mode: host is Compose's equivalent
    # of --network host, needed here for the same reason.
    network_mode: host
    volumes:
      - webdata:/usr/share/nginx/html

volumes:
  webdata:
```

```bash
docker compose up -d
docker compose ps
docker compose down
```

[[lab-task:1]]

## Docker Hub

Docker Hub (`https://hub.docker.com`) is Docker's hosted registry for finding and
sharing images with a team.

| Command | Description |
|---|---|
| `docker login -u <username>` | Log in to a registry (defaults to Docker Hub) |
| `docker logout` | Log out of a registry |
| `docker search <image_name>` | Search Hub for an image |
| `docker pull <image_name>` | Pull an image from Hub |
| `docker push <username>/<image_name>` | Publish an image to Hub |
| `docker tag <image>[:tag][username/] <new-name>[:new-tag]` | Retag an image for a specific registry/namespace before pushing |

```bash
# Log in, then publish an image under your namespace
docker login -u myuser
docker tag myimage:latest myuser/myimage:latest
docker push myuser/myimage:latest
```

Registries other than Docker Hub (a private registry, GHCR, ECR, etc.) work the same
way — `docker login <registry-host>` first, then tag images with that host as the
prefix (`<registry-host>/<username>/<image>:<tag>`) before pushing.

## Practicing against a real registry, offline

This sandbox has no internet access, so `docker login`/`push`/`pull` against Docker
Hub itself isn't something you can practice hands-on here — but the sandbox runs its
own private registry (the same `registry:2` image Docker Hub itself is built on) on
`localhost:5000`, with no login required. The push/pull mechanics are identical to
Hub; only the hostname differs.

```bash
# Tag an existing image for the local registry, then push it
docker tag alpine:3.20 localhost:5000/myimage:latest
docker push localhost:5000/myimage:latest

# Remove your local copy, then pull it back from the registry to prove the round trip
docker rmi localhost:5000/myimage:latest
docker pull localhost:5000/myimage:latest
```

Unlike a container's published port, `docker push`/`pull`/`build` all reach
`localhost:5000` fine directly from this terminal — those commands are carried out by
the Docker daemon itself (which shares a network with the registry), not by the
terminal's own network stack, so they aren't affected by the nested-network
constraint that `-p` publishing and raw `curl` hit elsewhere in this course.

[[lab-task:2]]
