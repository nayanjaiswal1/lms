---
kind: lesson
id_key: docker/dockerfile/lesson
course: docker
section: dockerfile
section_title: Dockerfile
section_position: 4
title: Writing a Dockerfile
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
    - id_key: write-dockerfile
      title: Write the Dockerfile
      points: 10
      description: Write the example Dockerfile above to ~/work/Dockerfile — FROM nginx:1.27-alpine, a RUN that writes a custom index.html, and EXPOSE 80.
      verification_script: |
        test -f /home/labuser/work/Dockerfile && grep -q "FROM nginx" /home/labuser/work/Dockerfile
      hint_context: Use a heredoc or your terminal's editor to write the file — cat > Dockerfile <<'EOF' ... EOF is the quickest way from a plain shell.
      explanation_context: FROM sets the base image every later instruction builds on top of. RUN executes once at build time and bakes its result into a new layer — that's how the custom index.html ends up baked into the image itself, not written at container-start time.
      solution_script: |
        cat > /home/labuser/work/Dockerfile <<'EOF'
        FROM nginx:1.27-alpine
        RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html
        EXPOSE 80
        EOF
    - id_key: build-mysite
      title: Build the image
      points: 10
      description: Build the Dockerfile in ~/work as mysite:latest.
      verification_script: |
        docker image inspect mysite:latest >/dev/null 2>&1
      hint_context: docker build --network=host -t mysite:latest . builds using the Dockerfile in the current directory — cd into ~/work first. --network=host is needed because this Dockerfile's RUN instruction starts an internal build-time container, same as running any container in this sandbox.
      explanation_context: docker build reads your Dockerfile top to bottom, executing each instruction as a new layer — RUN specifically does this inside its own temporary container. The result is a new, immutable image tagged mysite:latest.
      solution_script: cd /home/labuser/work && docker build --network=host -t mysite:latest .
    - id_key: run-and-confirm
      title: Run it and confirm it serves your page
      points: 10
      description: Run mysite:latest detached with --network host, then confirm it's serving your custom page using a second --network host container.
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
      hint_context: docker run -d --name mysite --network host mysite:latest starts it; docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80 reaches it from a second host-networked container.
      explanation_context: This sandbox's Docker runs inside its own nested network, so the terminal itself can't curl a container's port directly — two --network host containers share the same network stack as each other, so one can reach the other via 127.0.0.1. That's the pattern this whole course uses in place of the usual "just curl localhost" you'd do on a normal machine.
      solution_script: |
        docker run -d --name mysite --network host mysite:latest
        docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
---

## What it is

A Dockerfile is the set of instructions `docker build` compiles into an image — the
same way a compiler turns source code into a binary. It always starts from a base
image (`FROM`), followed by whatever setup instructions the app needs.

```bash
docker build -t [username/]<image-name>[:tag] <dockerfile-path>
```

## Instruction reference

| Instruction | Description |
|---|---|
| `FROM` | Sets the base image for everything that follows |
| `MAINTAINER` | Sets the author field on the generated image (legacy — prefer a `LABEL`) |
| `RUN` | Executes a command in a new layer on top of the current image and commits the result |
| `CMD` | The default command to run when the container starts. Allowed once — if repeated, the last one wins |
| `LABEL` | Adds metadata (key/value) to an image |
| `EXPOSE` | Documents which network ports the container listens on at runtime |
| `ENV` | Sets an environment variable |
| `ADD` | Copies files, directories, or remote URLs into the image filesystem (also unpacks local tarballs) |
| `COPY` | Copies files/directories into the image filesystem (no URL fetching, no auto-unpacking) |
| `ENTRYPOINT` | Configures the container to run as an executable |
| `VOLUME` | Creates a mount point marked as holding externally-mounted data |
| `USER` | Sets the username/UID subsequent instructions and the container run as |
| `WORKDIR` | Sets the working directory for `RUN`, `CMD`, `ENTRYPOINT`, `COPY`, and `ADD` |
| `ARG` | Declares a build-time variable, settable via `--build-arg` |
| `ONBUILD` | Registers an instruction to run later, when this image is used as a base for another build |
| `STOPSIGNAL` | Sets the system call signal sent to the container to make it exit |

## Example Dockerfile

A custom nginx image that serves a static page and exposes port 80:

```dockerfile
# Use the existing nginx image as a base
FROM nginx:1.27-alpine

# Bake a custom page into the image at build time
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html

# Document which port the container listens on
EXPOSE 80

# nginx:1.27-alpine's own base image already sets the CMD that starts nginx
# in the foreground — no need to override it here.
```

Build and run it:

```bash
# Build the image. --network=host is needed here because the RUN instruction
# above starts an internal build-time container, and this sandbox's Docker
# runs inside its own nested network — same reason running any container
# here needs --network host (see the Container Commands lesson).
docker build --network=host -t mysite .

# Run it — --network host (not -p) is how a container here becomes reachable at all
docker run -d --name mysite --network host mysite

# Confirm it's serving your custom page, from a second --network host
# container (both share the same network stack, so this can reach it via
# 127.0.0.1 even though the terminal itself can't)
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

`RUN` vs. `CMD`/`ENTRYPOINT` is the instruction to internalize: `RUN` executes at
**build** time and bakes its result into a layer; `CMD`/`ENTRYPOINT` define what runs
at **container start** time and don't affect the image's layers at all.

[[lab-task:1]]

[[lab-task:2]]

[[lab-task:3]]
