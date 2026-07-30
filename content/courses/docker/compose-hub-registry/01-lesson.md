---
kind: lesson
id_key: docker/compose-hub-registry/lesson
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: Docker Compose, Hub & Registries
position: 0
estimated_minutes: 20
source:
  - Docker Command Cheat Sheet.pdf
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Docker Compose

Compose defines and runs multi-container applications from a single YAML file
(`docker-compose.yml`), so you don't have to chain individual `docker run` commands.

| Command | Description |
|---|---|
| `docker-compose build` | Build the images referenced in the compose file |
| `docker-compose up` | Create and start all services defined in the compose file |
| `docker-compose start` | Start services that were already created by a previous `up` |
| `docker-compose run` | Run a one-off command inside one of the compose services |
| `docker-compose ps` | Show status of the compose stack's containers |
| `docker-compose ls` | List running compose projects |
| `docker-compose rm` | Remove the compose stack's containers |

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
