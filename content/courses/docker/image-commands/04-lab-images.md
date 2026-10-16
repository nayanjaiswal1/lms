---
kind: lesson
id_key: docker/image-commands/lesson
course: docker
section: image-commands
section_title: Image Commands
section_position: 3
title: Building & Managing Images
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
    - id_key: build-image
      title: Build an image from a Dockerfile
      points: 10
      description: Write the Dockerfile from the example above to ~/work/Dockerfile and build it as myimage:latest.
      verification_script: |
        docker image inspect myimage:latest >/dev/null 2>&1
      hint_context: docker build --network=host -t myimage:latest . builds using the Dockerfile in the current directory (--network=host is this sandbox's requirement for any build step that starts a container internally — see the note below the examples).
      explanation_context: docker build reads a Dockerfile and produces a new image, layer by layer. -t names (tags) the resulting image so you can reference it later.
      solution_script: |
        printf 'FROM alpine:3.20\nCMD ["echo", "hello from myimage"]\n' > /home/labuser/work/Dockerfile
        cd /home/labuser/work && docker build --network=host -t myimage:latest .
    - id_key: tag-image
      title: Tag an image with a second reference
      points: 10
      description: Create a second tag, myimage:v1, pointing at the same image as myimage:latest.
      verification_script: |
        docker image inspect myimage:v1 >/dev/null 2>&1
      hint_context: docker tag doesn't copy anything — it just adds another name pointing at the same image content.
      explanation_context: An image can have any number of tags pointing at the same underlying layers. docker tag myimage:latest myimage:v1 makes "v1" a second name for the exact same image.
      solution_script: docker tag myimage:latest myimage:v1
    - id_key: save-and-load
      title: Export an image to a tarball and reload it
      points: 10
      description: Save myimage:latest to ~/work/myimage.tar with "docker save", then load it back with "docker load".
      verification_script: |
        test -f /home/labuser/work/myimage.tar && docker image inspect myimage:latest >/dev/null 2>&1
      hint_context: docker save -o myimage.tar myimage:latest writes the tarball; docker load -i myimage.tar reads it back in.
      explanation_context: docker save/load round-trips an image through a plain .tar file — no registry needed. This is how you'd move an image to a machine with no network access at all.
      solution_script: |
        docker save -o /home/labuser/work/myimage.tar myimage:latest
        docker load -i /home/labuser/work/myimage.tar
    - id_key: remove-tag
      title: Remove one tag without deleting the image
      points: 10
      description: Remove the myimage:v1 tag with "docker rmi", while myimage:latest keeps working.
      verification_script: |
        ! docker image inspect myimage:v1 >/dev/null 2>&1 && docker image inspect myimage:latest >/dev/null 2>&1
      hint_context: docker rmi myimage:v1 removes only that tag — the underlying image stays as long as another tag (myimage:latest) still references it.
      explanation_context: docker rmi removes a tag reference, not necessarily the image data. The image's layers are only actually deleted once its last tag is removed (or you use docker image prune for dangling/untagged ones).
      solution_script: docker rmi myimage:v1
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

### Building & tagging

```bash
# A minimal Dockerfile to build from — write this to ./Dockerfile
FROM alpine:3.20
CMD ["echo", "hello from myimage"]
```

```bash
# Build an image from the Dockerfile in the current directory
docker build -t myimage:latest .
docker build -t [username/]<image-name>[:tag] <dockerfile-path>

# Build without using Docker's layer cache
docker build -t <image_name> . --no-cache
```

> This lab sandbox's Docker runs inside its own nested network — any RUN instruction
> in a Dockerfile starts an internal build-time container, and that needs
> `--network=host` here to work at all (`docker build --network=host -t ...`), the
> same way running any container does. A Dockerfile with no RUN steps builds fine
> either way; add the flag as a habit once your Dockerfile has one.

```bash
# List local images
docker images

# View the build history of an image
docker history myimage:latest

# Tag an image: create a second reference to the same image
docker tag myimage:latest myimage:v1
docker tag <image-name> <new-image-name>
```

[[lab-task:1]]

[[lab-task:2]]

### Save, load & clean up

```bash
# Export an image to a file, then re-import it elsewhere
docker save -o myimage.tar myimage:latest
docker load -i myimage.tar

# Remove a specific tag; remove all unused (dangling) images
docker rmi myimage:v1
docker image prune
```

[[lab-task:3]]

[[lab-task:4]]

### Registries (Docker Hub, in real usage)

```bash
# Authenticate, then push an image to a registry
docker login -u <username>
docker push <username>/<image-name>[:tag]

# Pull an image from Docker Hub; search Hub for one first
docker search <image-name>
docker pull <image-name>
```

These three (`login`/`push`/`search`) target Docker Hub in real usage — the
[Compose, Hub & Registry](../compose-hub-registry/01-lesson.md) lesson runs the same
push/pull flow against an offline registry so you can practice it hands-on.

## Images vs. containers, in one line

An **image** is the read-only template on disk (or in a registry); a **container** is
a live, writable instance of that template. `docker build` produces images, `docker
run` produces containers.
