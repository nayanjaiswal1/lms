---
kind: lesson
id_key: docker/dockerfile/lesson
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "Lab: Write, Build and Run a Dockerfile"
position: 6
estimated_minutes: 20
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

## Why this matters

You have read how `RUN`, `CMD`, layers and the cache work. Now write a
Dockerfile, build it, and prove the result serves your own page. Each task is
checked automatically.

## The Dockerfile

A custom nginx image that serves a page baked in at build time:

```dockerfile
# Base image: nginx already installed and configured
FROM nginx:1.27-alpine

# Build time: write a custom page into the image (this becomes a layer)
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html

# Documentation: the container listens on 80
EXPOSE 80

# No CMD needed: nginx:1.27-alpine already sets one that starts nginx in the foreground
```

Recall from lesson 1: `RUN` executes **once, at build time**, and its result is
saved in a layer. `CMD`/`ENTRYPOINT` decide what runs **at container start**
and add no files.

## Task 1: write the Dockerfile

The quickest way from a plain shell is a heredoc:

```bash
cd ~/work
cat > Dockerfile <<'EOF'
FROM nginx:1.27-alpine
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html
EXPOSE 80
EOF
cat Dockerfile     # check it
```

[[lab-task:1]]

## Task 2: build the image

```bash
cd ~/work
docker build --network=host -t mysite:latest .
docker history mysite:latest    # your RUN line is the newest layer
```

**Sandbox note:** the `RUN` step starts a temporary build container, and in
this nested sandbox that needs `--network=host`. On a normal machine:
`docker build -t mysite:latest .`

Build it a second time and notice every step says `CACHED` (lesson 4).

[[lab-task:2]]

## Task 3: run it and confirm your page

```bash
# Sandbox: --network host instead of -p (see the Running Containers lab)
docker run -d --name mysite --network host mysite:latest

# Fetch the page from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Expected output:

```
<h1>Built from a Dockerfile</h1>
```

On a normal machine you would run `docker run -d -p 8080:80 mysite` and open
`http://localhost:8080`.

[[lab-task:3]]

## Remember

- Write → build → run → verify is the loop for every image you make.
- `RUN` bakes results into the image; `CMD` is inherited from the base if you do not set one.
- A second identical build is fully `CACHED`.
