---
kind: lesson
id_key: docker/compose-hub-registry/compose-basics
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: "Docker Compose: One File for the Whole App"
position: 0
estimated_minutes: 9
source:
  - Docker Command Cheat Sheet.pdf
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

A real app is an API, a database, a cache, maybe a worker. Starting each with
a long `docker run` line, in the right order, on the right network, with the
right volumes, is error-prone. **Docker Compose** describes the whole app in one
YAML file and starts it with one command. It is the standard tool for local
development and simple single-host deployments.

## Mental model: a sheet of music

Each `docker run` command is one musician playing from memory. A
`compose.yaml` file is the **sheet music** for the whole orchestra: who plays,
with which instrument, in what order. `docker compose up` is the conductor.

```
compose.yaml                         what Compose creates
------------                         --------------------
services:                            network   myapp_default
  web:   (image, ports)      --->    container myapp-web-1
  db:    (image, volume)     --->    container myapp-db-1
volumes:                             volume    myapp_dbdata
  dbdata:
```

Key words:

- **Service**: one component (web, db). Compose runs one or more containers per service.
- **Project**: the whole app. Its name defaults to the **folder name** and prefixes everything.
- Compose creates a **default network** for the project, so services reach each
  other **by service name** (`db`, `web`), exactly like the user-defined network from Section 5.

`docker compose` (a space, Compose v2, a Docker CLI plugin) is current.
`docker-compose` (hyphen) was the old Python v1 tool, retired in 2023. The
top-level `version:` key in old files is obsolete and ignored.

## See it work

Folder `myapp/` with one file, `compose.yaml`:

```yaml
services:
  web:
    image: nginx:1.27-alpine        # like: docker run nginx:1.27-alpine
    ports:
      - "8080:80"                   # like: -p 8080:80 (outside:inside)
    depends_on:
      - db                          # start db before web

  db:
    image: postgres:16
    environment:                    # like: -e
      POSTGRES_PASSWORD: devpass
    volumes:
      - dbdata:/var/lib/postgresql/data   # like: -v dbdata:/...

volumes:
  dbdata:                           # declare the named volume
```

Run it:

```bash
cd myapp
docker compose up -d        # create network, volume, containers; start them
docker compose ps           # status of this project's containers
```

Expected output of `ps` (shortened):

```
NAME          IMAGE               SERVICE   STATUS         PORTS
myapp-db-1    postgres:16         db        Up 5 seconds   5432/tcp
myapp-web-1   nginx:1.27-alpine   web       Up 4 seconds   0.0.0.0:8080->80/tcp
```

Notice the names: **project-service-number**.

Everyday commands:

```bash
docker compose logs -f web          # follow one service's logs
docker compose exec db psql -U postgres     # shell/command in a running service
docker compose run --rm web nginx -t        # one-off container for a service
docker compose stop                 # stop containers, keep them
docker compose start                # start them again
docker compose restart web          # restart one service
docker compose down                 # stop and REMOVE containers and the network
docker compose down -v              # ...and also delete named volumes (data!)
docker compose ls                   # list running Compose projects
```

`docker compose up -d` is **idempotent**: run it again after editing the file and
Compose recreates only the services whose configuration changed.

## Try it

Translate this into a `compose.yaml` service:

```bash
docker run -d --name cache -p 127.0.0.1:6379:6379 -v cachedata:/data redis:7-alpine
```

<details>
<summary>Show answer</summary>

```yaml
services:
  cache:
    image: redis:7-alpine
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - cachedata:/data

volumes:
  cachedata:
```

The container name becomes `<project>-cache-1` (set `container_name:` only if
you really need a fixed name; it prevents scaling).

</details>

## Common mistakes

- **`docker compose down -v` "to clean up".** It deletes your database volume.
  Plain `down` keeps volumes.
- **Using `localhost` between services.** Use the service name (`db:5432`).
- **Typing `docker-compose`** from old tutorials. Use `docker compose`.
- **Running from the wrong folder.** The project name comes from the folder, so a
  different folder means a different project (new network, new volumes).

## Remember

- `compose.yaml` describes services, networks and volumes; `docker compose up -d` creates them.
- Project name = folder name; containers are `project-service-N`.
- Services reach each other by **service name** on the project's default network.
- `down` removes containers + network; `down -v` also deletes volumes.
- It is `docker compose` (v2). `version:` is obsolete.

**Self-check:**

1. Which `docker run` flags do `ports`, `environment` and `volumes` correspond to?
2. What host name does `web` use to reach `db`?
3. What is the difference between `docker compose down` and `down -v`?
