---
kind: lesson
id_key: docker/image-commands/lesson
course: docker
section: image-commands
section_title: Image Commands
section_position: 3
title: Building & Managing Images
position: 0
estimated_minutes: 25
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Syntax

```
docker [CMD] [OPTS] [IMAGE]
```

## Command reference

| Command | Description |
|---|---|
| `docker build` | Build an image from a Dockerfile |
| `docker images` | List local images |
| `docker rmi` | Remove one or more images |
| `docker image prune` | Remove all dangling (untagged, unreferenced) images |
| `docker tag` | Add a tag to an image, or create a renamed reference to it |
| `docker history` | Show the layer-by-layer build history of an image |
| `docker inspect` | Full image metadata as JSON |
| `docker save` / `docker load` | Export an image to a `.tar` file / import it back |
| `docker import` | Create an image from a filesystem tarball |
| `docker pull` / `docker push` | Download from / upload to a registry |
| `docker search` | Search a configured registry for images |
| `docker login` / `docker logout` | Authenticate to a registry (default `https://index.docker.io/v1/`) |

## Examples

```bash
# Build an image from the Dockerfile in the current directory
docker build -t myimage:latest .
docker build -t [username/]<image-name>[:tag] <dockerfile-path>

# Build without using Docker's layer cache
docker build -t <image_name> . --no-cache

# List local images
docker images

# Remove an image; remove all unused (dangling) images
docker rmi myimage:latest
docker image prune

# View the build history of an image
docker history jboss/wildfly

# Tag an image: create "myimage:v1" from "jboss/wildfly:latest"
docker tag jboss/wildfly myimage:v1
docker tag <image-name> <new-image-name>

# Export an image to a file, then re-import it elsewhere
docker save -o myimage.tar myimage:latest
docker load -i myimage.tar

# Authenticate, then push an image to a registry
docker login -u <username>
docker push <username>/<image-name>[:tag]

# Pull an image from Docker Hub; search Hub for one first
docker search <image-name>
docker pull <image-name>
```

## Images vs. containers, in one line

An **image** is the read-only template on disk (or in a registry); a **container** is
a live, writable instance of that template. `docker build` produces images, `docker
run` produces containers.
