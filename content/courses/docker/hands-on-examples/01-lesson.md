---
kind: lesson
id_key: docker/hands-on-examples/lesson
course: docker
section: hands-on-examples
section_title: Hands-On Examples
section_position: 8
title: Two Worked Examples
position: 0
estimated_minutes: 25
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

Two end-to-end walkthroughs that chain together commands from every earlier
lesson: building, running, networking, mounting, and inspecting.

## Example 1 — custom WildFly app server

Build the custom image from the [Dockerfile lesson](../dockerfile/01-lesson.md), run
it, and reach the admin console:

```bash
# Build the image
docker build -t mywildfly .

# Run it, publishing the app port (8080) and admin port (9990)
docker run -it -p 8080:8080 -p 9990:9990 mywildfly

# Open http://<docker-daemon-ip>:9990 and log in with admin / Admin#70635
```

## Example 2 — a simple Python web server

Runs a bare Python `SimpleHTTPServer`, serving a bind-mounted directory from the
host, with the container's working directory set to that mount.

> On RHEL, SELinux needs the mounted directory relabeled first:
> `chcon -Rt svirt_sandbox_file_t $(pwd)`

```bash
# Create a directory and a page to serve
mkdir -p www/
echo "Server is up" > www/index.html

# Run the container as a daemon:
#   -p 8000:8000        map host port 8000 to container port 8000
#   --name=pythonweb     name the container
#   -v $(pwd)/www:/var/www/html   mount host ./www into the container
#   -w /var/www/html      set the working directory
#   rhel7/rhel /bin/python -m SimpleHTTPServer 8000   start the server
docker run -d \
  -p 8000:8000 \
  --name=pythonweb \
  -v $(pwd)/www:/var/www/html \
  -w /var/www/html \
  rhel7/rhel \
  /bin/python \
  -m SimpleHTTPServer 8000

# Check it's serving
curl <container-daemon-ip>:8000

# Confirm it's running, inspect it, and look inside
docker ps
docker inspect pythonweb | less
docker exec -it pythonweb bash
```

## What each flag ties back to

| Flag / command | Covered in |
|---|---|
| `-p host:container` | [Container Commands](../container-commands/01-lesson.md) |
| `-v host:container` (bind mount) | [Networks & Volumes](../networking-volumes/01-lesson.md) |
| `-w /path` (working directory) | Same as Dockerfile's `WORKDIR` — see [Dockerfile](../dockerfile/01-lesson.md) |
| `docker build -t`, `docker run` | [Building & Managing Images](../image-commands/01-lesson.md), [Container Lifecycle & Commands](../container-commands/01-lesson.md) |
| `docker ps`, `docker inspect`, `docker exec` | [Container Lifecycle & Commands](../container-commands/01-lesson.md) |

Both examples are just combinations of the individual commands from earlier
lessons — once each command is familiar in isolation, reading a real `docker run`
invocation with five flags stops being intimidating.
