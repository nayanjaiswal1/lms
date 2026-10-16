---
kind: lesson
id_key: docker/container-commands/lesson
course: docker
section: container-commands
section_title: Running Containers
section_position: 2
title: "Lab: Run, Stop, Exec and Inspect"
position: 4
estimated_minutes: 25
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
  workspace_layout: console
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: run-detached-named
      title: Run a detached, named container
      points: 10
      description: Start an nginx:1.27-alpine container named "myserver", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).
      verification_script: |
        docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx
      hint_context: docker run has a flag for detached mode and one for naming — check the "Starting containers" examples above.
      explanation_context: docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.
      solution_script: docker run --name myserver -d --network host nginx:1.27-alpine
    - id_key: stop-and-remove
      title: Stop and remove a container
      points: 10
      description: Start a second container named "tempbox" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in "docker ps -a".
      verification_script: |
        ! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox
      hint_context: docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.
      explanation_context: docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container's filesystem and metadata. docker rm -f does both in one step.
      solution_script: |
        docker run -d --network host --name tempbox alpine:3.20 sleep 3600
        docker rm -f tempbox
    - id_key: exec-and-logs
      title: Exec into a container and check its logs
      points: 10
      description: Using "docker exec", create a file /tmp/hello.txt inside myserver containing the word "hello". Then view myserver's logs.
      verification_script: |
        docker exec myserver test -f /tmp/hello.txt && docker exec myserver grep -q hello /tmp/hello.txt
      hint_context: docker exec myserver sh -c "echo hello > /tmp/hello.txt" runs a command inside the already-running container.
      explanation_context: docker exec runs a new process inside a container that's already running — unlike docker run, which always starts a fresh container. docker logs shows what the container's main process has printed to stdout/stderr.
      solution_script: docker exec myserver sh -c "echo hello > /tmp/hello.txt"
    - id_key: inspect-and-confirm
      title: Inspect the container and confirm it's serving
      points: 10
      description: Use "docker inspect myserver" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
      hint_context: docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox's terminal can't directly curl a container's port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.
      explanation_context: docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other's ports directly via 127.0.0.1 — the pattern this sandbox uses to check "is it really serving," in place of curl-ing the terminal's own localhost.
      solution_script: docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
---

## Why this matters

Reading about `docker run` is not the same as typing it. This lab makes you use
the four lessons you just read: start a container, stop and remove one, go
inside one, and inspect one. Each task is checked automatically.

## Before you start: one sandbox rule

On a normal machine you would publish a port with `-p 8080:80` and open
`localhost:8080`. This lab's Docker daemon runs **inside** your sandbox, in its
own nested network, so `-p` does not reach the terminal you type in.

The workaround used in every lab of this course:

- Start containers with `--network host`. The container then shares the
  sandbox's network directly; no publishing needed.
- To check that a server answers, run a **second** throwaway container with
  `--network host` and fetch `http://127.0.0.1:PORT` from it. Both share one
  network, so `127.0.0.1` reaches the server.

```bash
# Pattern: "is the server on port 80 answering?"
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Everything else (`ps`, `logs`, `exec`, `inspect`, `stop`, `rm`) works exactly as
on any machine.

## Task 1: run a detached, named container

Recall lesson 1: `-d` for background, `--name` for a name.

```bash
docker run --name myserver -d --network host nginx:1.27-alpine
docker ps          # myserver should show "Up ..."
```

[[lab-task:1]]

## Task 2: stop and remove a container

Recall lesson 2: `stop` is polite (SIGTERM, then SIGKILL after a grace period),
`rm` deletes, `rm -f` does both.

```bash
docker run -d --network host --name tempbox alpine:3.20 sleep 3600
docker stop -t 1 tempbox     # stop with a 1-second grace period
docker rm tempbox            # delete it
docker ps -a                 # tempbox is gone
```

Two bulk patterns you will meet in real scripts (careful: they affect **every** container):

```bash
docker rm $(docker ps -q -f "status=exited")   # remove all stopped containers
docker rm -f $(docker ps -aq)                  # force-remove ALL containers
```

[[lab-task:2]]

## Task 3: go inside and read the logs

Recall lesson 3: `exec` runs an extra process in a running container; `logs`
shows the main process's stdout/stderr.

```bash
docker exec -it myserver sh          # interactive shell; type exit to leave
docker exec myserver sh -c "echo hello > /tmp/hello.txt"   # one-shot command
docker logs myserver                 # nginx startup lines
```

[[lab-task:3]]

## Task 4: inspect it and prove it serves

```bash
docker inspect myserver                          # full JSON
docker inspect -f '{{.State.Status}}' myserver   # just: running
docker container stats --no-stream               # live resource usage, one sample

# Confirm it is serving, from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Expected output of the last command: the HTML of the nginx welcome page,
containing `Welcome to nginx!`.

[[lab-task:4]]

## Remember

- Lab sandbox: `--network host` instead of `-p`; check servers from a second
  `--network host` container.
- Real machines: `-p HOST:CONTAINER` and `curl localhost:HOST`.
- `docker rm -f $(docker ps -aq)` removes **everything**. Use it only in sandboxes.
