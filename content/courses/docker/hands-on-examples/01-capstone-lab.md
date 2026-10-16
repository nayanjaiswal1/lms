---
kind: lesson
id_key: docker/hands-on-examples/lesson
course: docker
section: hands-on-examples
section_title: Capstone
section_position: 9
title: "Capstone Lab: Two End-to-End Workflows"
position: 0
estimated_minutes: 25
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
      title: "Example 1: build, run, and confirm your own image"
      points: 15
      description: Write the Dockerfile shown above, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
      hint_context: This is the exact same sequence as the Dockerfile lab's three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.
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

## Why this matters

Real Docker work is never one command. It is a **chain**: write, build, run,
check, inspect. This capstone strings together commands from every section, so
you practise recognising the chain instead of memorising single flags.

## Mental model: the delivery loop

```
 write (Dockerfile / files)  ->  build  ->  run  ->  verify  ->  inspect / debug
          Section 4               4         2,5        2,8           2,8
```

Both examples use `--network host` and check results from a second
`--network host` container, as in every lab of this course (see the Running
Containers lab for why).

## Example 1: build, run and verify your own image

Recall Section 4: a `RUN` step bakes the page into the image; nginx's own `CMD`
starts the server.

```bash
mkdir -p ~/work && cd ~/work
cat > Dockerfile <<'EOF'
FROM nginx:1.27-alpine
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html
EXPOSE 80
EOF

# Build (sandbox: --network=host because of the RUN step)
docker build --network=host -t mysite .

# Run in the background
docker run -d --name mysite --network host mysite

# Verify from a second container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Expected output of the last command:

```
<h1>Built from a Dockerfile</h1>
```

[[lab-task:1]]

## Example 2: a Python web server with a bind mount

Recall Section 5: a bind mount shows your host folder inside the container,
live. `-w` sets the working directory at run time, like `WORKDIR` at build time.

```bash
# Content to serve, on the "host"
mkdir -p ~/work/www
echo "Server is up" > ~/work/www/index.html

# Run python's built-in web server against that folder:
#   --name pythonweb                   readable name                (Section 2)
#   -v ~/work/www:/var/www/html        bind mount host -> container (Section 5)
#   -w /var/www/html                   working directory            (Section 4, WORKDIR)
#   --network host                     sandbox networking
#   python3 -m http.server 8000        the command (replaces the image's CMD)
docker run -d \
  --name pythonweb \
  -v ~/work/www:/var/www/html \
  -w /var/www/html \
  --network host \
  python:3.12-alpine \
  python3 -m http.server 8000

# Verify
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8000
```

Expected output: `Server is up`.

[[lab-task:2]]

**After the task is checked**, change the file and fetch again. The new text appears without restarting
anything, because the container reads your folder directly:

```bash
echo "Edited live" > ~/work/www/index.html
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8000
```

Inspect it with the Section 2 tools:

```bash
docker ps                                          # it is Up
docker logs pythonweb                              # one line per request
docker inspect -f '{{json .Mounts}}' pythonweb     # the bind mount
docker exec -it pythonweb sh                       # look inside; exit to leave
```

## Remember

- Every real workflow is a chain: write → build → run → verify → inspect.
- Bind mounts give live edits without rebuilds: ideal for development, not for shipping.
- Reading a long `docker run` line is easy once you can name each flag's section.
