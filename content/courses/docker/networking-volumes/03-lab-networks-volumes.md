---
kind: lesson
id_key: docker/networking-volumes/lesson
course: docker
section: networking-volumes
section_title: Networking & Storage
section_position: 5
title: "Lab: Networks and Volumes"
position: 2
estimated_minutes: 15
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 35
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: create-and-inspect-network
      title: Create and inspect a custom network
      points: 10
      description: Create a bridge network named "mynetwork" and confirm it exists with the right driver.
      verification_script: |
        docker network inspect mynetwork --format '{{.Driver}}' 2>/dev/null | grep -q bridge
      hint_context: docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.
      explanation_context: docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.
      solution_script: docker network create mynetwork
    - id_key: named-volume-persists
      title: Prove a named volume survives its container
      points: 10
      description: Create a named volume "mydata", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.
      verification_script: |
        docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2>/dev/null | grep -q "still here"
      hint_context: docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo 'still here' > /data/proof.txt" writes the file (--network host is needed for any container to start at all in this sandbox — see the Running Containers lab); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what's persisting the data.
      explanation_context: A named volume's data lives independently of any one container — that's the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.
      solution_script: |
        docker volume create mydata
        docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo 'still here' > /data/proof.txt"
---

## Why this matters

Two hands-on checks for this section: create and inspect a network, and prove
with your own eyes that a named volume outlives the container that wrote to it.

## Sandbox note

This sandbox's Docker daemon runs inside its own nested network, and attaching
containers to a **new** bridge network is not reliable here. So Task 1 checks
that you can create and inspect a network correctly. Try the
"two containers resolve each other by name" demo from lesson 1 on your own
machine. Containers in this lab use `--network host`, as in every lab of this course.

## Task 1: create and inspect a custom network

```bash
docker network create mynetwork
docker network ls                     # mynetwork, driver bridge
docker network inspect mynetwork      # subnet, gateway, Driver: "bridge"
docker network inspect -f '{{.Driver}}' mynetwork   # just: bridge
```

On a normal machine you would then attach containers to it:

```bash
docker run --name myserver-net -d --network mynetwork nginx:1.27-alpine
```

[[lab-task:1]]

## Task 2: prove a named volume survives its container

Recall lesson 2: a named volume lives outside any container.

```bash
# 1. Create the volume
docker volume create mydata

# 2. Write a file into it from a throwaway container (--rm deletes the container afterwards)
docker run --rm --network host -v mydata:/data busybox:1.36 \
  sh -c "echo 'still here' > /data/proof.txt"

# 3. The writing container is gone. Read the file from a brand-new container
docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt
```

Expected output of step 3:

```
still here
```

The container that wrote the file no longer exists; the volume kept the data.

For comparison, a bind mount uses a host path instead of a volume name:

```bash
mkdir -p ~/work/myfolder
docker run --name myserver-bind -d --network host \
  -v ~/work/myfolder:/usr/share/nginx/html nginx:1.27-alpine
```

[[lab-task:2]]

## Remember

- `docker network create` / `inspect` / `ls` manage networks.
- Data written to a named volume survives `docker rm` and is visible to the next container that mounts it.
