---
kind: lesson
id_key: docker/container-commands/ports-env
course: docker
section: container-commands
section_title: Running Containers
section_position: 2
title: "Ports and Environment Variables"
position: 3
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

A web server in a container is useless if nobody can reach it, and an app with a
hard-coded database password cannot move between dev and prod. Port publishing
and environment variables solve both. They are the two flags you will add to
almost every real `docker run`.

## Mental model: an office switchboard

The container has its own network, like an office with internal extensions.
Outsiders dial the **main number** (a host port). The switchboard forwards the
call to an **extension** (the container port).

```
browser --> localhost:8080 (host port)
                 |
                 |  -p 8080:80   "host 8080 forwards to container 80"
                 v
           container port 80  --> nginx
```

The flag reads **left = host (outside), right = container (inside)**:

```
-p HOST_PORT:CONTAINER_PORT
```

Mnemonic: **"outside:inside"**, the same order as `-v` for volumes later.

## See it work

### Publish a port

```bash
# Host port 8080 -> container port 80
docker run -d --name web -p 8080:80 nginx:1.27-alpine

# Which ports are published?
docker port web
```

Expected output of `docker port web`:

```
80/tcp -> 0.0.0.0:8080
```

Now `curl http://localhost:8080` (or a browser) shows the nginx welcome page.

Variations:

```bash
docker run -d -p 127.0.0.1:8080:80 nginx:1.27-alpine  # only reachable from this machine
docker run -d -p 8081:80/udp some-image               # UDP instead of TCP
docker run -d -P nginx:1.27-alpine                    # publish every EXPOSEd port to random host ports
```

`-p 8080:80` listens on **all** host interfaces (`0.0.0.0`), so it is reachable
from your network. Binding to `127.0.0.1` keeps a dev database private.

**EXPOSE vs publish:** a Dockerfile's `EXPOSE 80` is only **documentation** (and
the list `-P` uses). It does not open anything. Only `-p`/`-P` publishes.

### Pass environment variables

```bash
# -e sets one variable
docker run --rm -e GREETING=hello alpine:3.20 sh -c 'echo $GREETING'
```

Output: `hello`.

```bash
# --env-file loads many from a file (KEY=value per line)
printf 'APP_ENV=dev\nLOG_LEVEL=debug\n' > app.env
docker run --rm --env-file app.env alpine:3.20 env
```

Output includes `APP_ENV=dev` and `LOG_LEVEL=debug`.

```bash
# -e NAME without a value copies it from your shell
export API_TOKEN=abc123
docker run --rm -e API_TOKEN alpine:3.20 sh -c 'echo $API_TOKEN'
```

Output: `abc123`.

Many official images are configured entirely by env vars. For example:

```bash
docker run -d --name db -e POSTGRES_PASSWORD=devpass -p 127.0.0.1:5432:5432 postgres:16
```

## Try it

Run nginx so that it is reachable on host port **9000** but **only from your
own machine**, and set an env var `TEAM=blue` inside it. Then prove the env var is set.

<details>
<summary>Show answer</summary>

```bash
docker run -d --name blue -p 127.0.0.1:9000:80 -e TEAM=blue nginx:1.27-alpine
docker exec blue printenv TEAM        # prints: blue
curl -s localhost:9000 | head -n 4    # nginx page
```

</details>

## Common mistakes

- **Reversing the port order.** `-p 80:8080` maps host 80 to container 8080, where
  nothing listens. Remember: **outside:inside**.
- **"Port is already allocated".** Another container or host program already uses
  that host port. Pick another host port; the container port can stay the same.
- **App listens on `127.0.0.1` inside the container.** Then publishing cannot
  reach it, because the container's localhost is private. Make the app listen on `0.0.0.0`.
- **Secrets in `-e`.** Anyone who can run `docker inspect` sees them. Fine for
  dev; in production prefer secret files or a secrets manager (Section 7).

## Remember

- `-p HOST:CONTAINER` (outside:inside) publishes a port. `docker port` shows mappings.
- `EXPOSE` documents; `-p` publishes.
- `-e KEY=value`, `--env-file file`, and `-e KEY` (copy from shell) set env vars.
- Apps must listen on `0.0.0.0` inside the container to be reachable.

**Self-check:**

1. Write the flag to map host port 3000 to container port 8000.
2. Does `EXPOSE 80` in a Dockerfile make the port reachable from the host?
3. Why can `-e DB_PASSWORD=...` be a security problem?
