---
kind: lesson
id_key: docker/hands-on-examples/lesson
course: docker
section: hands-on-examples
section_title: Hands-On Examples
section_position: 8
title: Two Worked Examples
position: 0
estimated_minutes: 40
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 40
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: example1-build-run-confirm
      title: "Example 1: build, run, and confirm the Dockerfile lesson's image"
      points: 15
      description: Write the Dockerfile from the Dockerfile lesson, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
      hint_context: This is the exact same sequence as the Dockerfile lesson's three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.
      explanation_context: Every real Docker workflow is a chain like this one — write, build, run, verify — never a single isolated command. Recognizing the chain matters more than memorizing any one flag in it.
      solution_script: |
        mkdir -p /home/labuser/work && cd /home/labuser/work
        cat > Dockerfile <<'EOF'
        FROM nginx:1.27-alpine
        RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html
        EXPOSE 80
        EOF
        docker build --network=host -t mysite .
        docker run -d --name mysite --network host mysite
    - id_key: example2-bind-mount-server
      title: "Example 2: a Python web server with a bind mount"
      points: 15
      description: Create ~/work/www/index.html with some content, run python:3.12-alpine's http.server bind-mounting that directory, and confirm it serves your file.
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:8000 2>/dev/null | grep -q "Server is up"
      hint_context: mkdir -p www && echo "Server is up" > www/index.html creates the content; docker run -d --name pythonweb -v $(pwd)/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000 serves it.
      explanation_context: -v host:container bind-mounts your directory straight into the container — the server process sees exactly the files you have on disk, live. -w sets the working directory http.server serves from, matching Dockerfile's WORKDIR at container-start time instead of build time.
      solution_script: |
        mkdir -p /home/labuser/work/www
        echo "Server is up" > /home/labuser/work/www/index.html
        docker run -d --name pythonweb -v /home/labuser/work/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000
---

Two end-to-end walkthroughs that chain together commands from every earlier
lesson: building, running, mounting, and inspecting. Both use `--network host`
throughout, same as every hands-on example in this course — see the
[Container Commands](../container-commands/01-lesson.md) lesson for why.

## Example 1 — the custom image from the Dockerfile lesson

Build the image from the [Dockerfile lesson](../dockerfile/01-lesson.md), run it, and
confirm it's serving:

```bash
# Build the image (--network=host: this Dockerfile has a RUN instruction)
docker build --network=host -t mysite .

# Run it
docker run -d --name mysite --network host mysite

# Confirm it's serving, from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

[[lab-task:1]]

## Example 2 — a simple Python web server with a bind mount

Runs a bare Python `http.server`, serving a bind-mounted directory from the host,
with the container's working directory set to that mount.

```bash
# Create a directory and a page to serve
mkdir -p www/
echo "Server is up" > www/index.html

# Run the container as a daemon:
#   --name=pythonweb              name the container
#   -v $(pwd)/www:/var/www/html   mount host ./www into the container
#   -w /var/www/html              set the working directory
#   --network host                reach it directly (see the note above)
#   python:3.12-alpine ... http.server 8000   start the server
docker run -d \
  --name=pythonweb \
  -v $(pwd)/www:/var/www/html \
  -w /var/www/html \
  --network host \
  python:3.12-alpine \
  python3 -m http.server 8000

# Check it's serving, from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8000

# Confirm it's running, inspect it, and look inside
docker ps
docker inspect pythonweb | less
docker exec -it pythonweb sh
```

## What each flag ties back to

| Flag / command | Covered in |
|---|---|
| `--network host` | [Container Commands](../container-commands/01-lesson.md) |
| `-v host:container` (bind mount) | [Networks & Volumes](../networking-volumes/01-lesson.md) |
| `-w /path` (working directory) | Same as Dockerfile's `WORKDIR` — see [Dockerfile](../dockerfile/01-lesson.md) |
| `docker build -t`, `docker run` | [Building & Managing Images](../image-commands/01-lesson.md), [Container Lifecycle & Commands](../container-commands/01-lesson.md) |
| `docker ps`, `docker inspect`, `docker exec` | [Container Lifecycle & Commands](../container-commands/01-lesson.md) |

[[lab-task:2]]

Both examples are just combinations of the individual commands from earlier
lessons — once each command is familiar in isolation, reading a real `docker run`
invocation with several flags stops being intimidating.
