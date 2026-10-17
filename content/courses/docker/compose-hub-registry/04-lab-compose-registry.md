---
kind: lesson
id_key: docker/compose-hub-registry/lesson
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: "Lab: Compose Up and a Registry Round Trip"
position: 3
estimated_minutes: 20
source:
  - Docker Command Cheat Sheet.pdf
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 35
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: compose-up
      title: Bring up a service with Docker Compose
      points: 10
      description: Write the compose.yaml shown above into ~/work-compose/compose.yaml and bring it up with "docker compose up -d".
      verification_script: |
        docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
      hint_context: docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.
      explanation_context: Compose's whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.
      solution_script: |
        mkdir -p /home/labuser/work-compose && cd /home/labuser/work-compose
        cat > compose.yaml <<'EOF'
        services:
          web:
            image: nginx:1.27-alpine
            network_mode: host
            volumes:
              - webdata:/usr/share/nginx/html
        volumes:
          webdata:
        EOF
        docker compose up -d
    - id_key: registry-round-trip
      title: Push and pull through the offline registry
      points: 10
      description: Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.
      verification_script: |
        docker image inspect localhost:5000/myimage:latest >/dev/null 2>&1
      hint_context: docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.
      explanation_context: The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.
      solution_script: |
        docker tag alpine:3.20 localhost:5000/myimage:latest
        docker push localhost:5000/myimage:latest
        docker rmi localhost:5000/myimage:latest
        docker pull localhost:5000/myimage:latest
---

## Why this matters

Two skills from this section, done for real: bring up a service from a
`compose.yaml`, and push and pull an image through a registry.

## Sandbox notes

- Compose's equivalent of `--network host` is `network_mode: host`. This lab's
  nested Docker needs it for the same reason as every other lab here.
- The sandbox has no internet, so you cannot push to Docker Hub. Instead a
  private registry (the official `registry:2` image) runs at `localhost:5000`,
  with no login. Push and pull work exactly as with Hub; only the host differs.
- `docker push`/`pull`/`build` are carried out by the Docker daemon, which
  shares a network with that registry, so `localhost:5000` works directly from
  your terminal.

## Task 1: bring up a service with Compose

```bash
mkdir -p ~/work-compose && cd ~/work-compose
cat > compose.yaml <<'EOF'
services:
  web:
    image: nginx:1.27-alpine
    network_mode: host          # sandbox: instead of ports: ["8080:80"]
    volumes:
      - webdata:/usr/share/nginx/html

volumes:
  webdata:
EOF

docker compose up -d     # creates the volume and the container, starts it
docker compose ps        # web is running
docker compose logs web  # nginx startup lines
```

On a normal machine you would write `ports: ["8080:80"]` instead of
`network_mode: host` and open `http://localhost:8080`.

Check it serves:

```bash
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80 | head -n 4
```

When you are done (after the task is checked), `docker compose down` stops and
removes it. `docker compose down -v` would also delete the `webdata` volume.

[[lab-task:1]]

## Task 2: push and pull through the registry

```bash
# Name an existing image for the local registry
docker tag alpine:3.20 localhost:5000/myimage:latest

# Upload it
docker push localhost:5000/myimage:latest

# Delete your local copy so the next pull must really download it
docker rmi localhost:5000/myimage:latest

# Download it back
docker pull localhost:5000/myimage:latest
```

Expected end of the pull output:

```
Status: Downloaded newer image for localhost:5000/myimage:latest
```

With Docker Hub the flow is identical, plus a login:
`docker login -u myuser`, `docker tag myimage:latest myuser/myimage:latest`,
`docker push myuser/myimage:latest`.

[[lab-task:2]]

## Remember

- `docker compose up -d` / `ps` / `logs` / `down` is the daily Compose loop.
- Registry flow: tag with the registry host → push → (elsewhere) pull.
