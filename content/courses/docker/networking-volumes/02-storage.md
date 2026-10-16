---
kind: lesson
id_key: docker/networking-volumes/storage
course: docker
section: networking-volumes
section_title: Networking & Storage
section_position: 5
title: "Keeping Data: Volumes, Bind Mounts and tmpfs"
position: 1
estimated_minutes: 10
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

A container's writable layer dies with the container. Run a database without a
volume, upgrade it with `docker rm` + `docker run`, and your data is gone.
Storage is where Docker mistakes cost the most, so learn the three options and
when to use each.

## Mental model: where do you keep your stuff?

- **Writable layer** = a hotel room. Comfortable, but cleaned out when you check out.
- **Volume** = a storage unit managed by Docker. Survives any number of guests.
- **Bind mount** = a door from the room straight into **your own house** (a host folder).
- **tmpfs** = a whiteboard. In memory only, wiped when the container stops.

```
               container filesystem
   /app   (image layers + writable layer: lost on docker rm)
   /data  <-- volume "pgdata"   -> /var/lib/docker/volumes/pgdata/_data
   /src   <-- bind mount        -> /home/you/project   (your exact folder)
   /tmp   <-- tmpfs             -> RAM
```

| | Volume | Bind mount | tmpfs |
|---|---|---|---|
| Who manages the location | Docker | You (any host path) | Kernel memory |
| Survives `docker rm` | Yes | Yes (it is your folder) | No |
| Portable across hosts | Yes | No (depends on host paths) | n/a |
| Best for | Databases, app data | Source code in development, config files | Secrets/caches that must not touch disk |

## See it work

### Named volume

```bash
docker volume create pgdata
docker run -d --name db -e POSTGRES_PASSWORD=devpass \
  -v pgdata:/var/lib/postgresql/data postgres:16

docker rm -f db                  # delete the container...
docker run -d --name db -e POSTGRES_PASSWORD=devpass \
  -v pgdata:/var/lib/postgresql/data postgres:16   # ...data is still there
```

Volume commands:

```bash
docker volume ls
docker volume inspect pgdata     # shows the Mountpoint on the host
docker volume rm pgdata          # delete (not while a container uses it)
docker volume prune              # delete unused volumes (careful!)
```

If the volume is empty when first mounted, Docker **copies in** whatever the
image already had at that path. Bind mounts never do this: they hide the image's files.

### Bind mount

```bash
mkdir -p site && echo "hello from my laptop" > site/index.html
docker run -d --name web -p 8080:80 \
  -v "$(pwd)/site":/usr/share/nginx/html:ro nginx:1.27-alpine
curl -s localhost:8080            # hello from my laptop
echo "edited live" > site/index.html
curl -s localhost:8080            # edited live  (no rebuild!)
```

- `$(pwd)/site` must be an **absolute** path (otherwise Docker treats it as a volume name).
- `:ro` makes it read-only inside the container.

### The `--mount` syntax (explicit, preferred in scripts)

```bash
docker run --mount type=volume,src=pgdata,dst=/var/lib/postgresql/data ...
docker run --mount type=bind,src="$(pwd)/site",dst=/usr/share/nginx/html,readonly ...
docker run --mount type=tmpfs,dst=/tmp,tmpfs-size=64m ...
```

Same results as `-v`, with one useful difference: with `-v`, a missing host
path is silently **created** as an empty directory; with `--mount type=bind` it
is an **error**, which catches typos.

### Anonymous volumes

`-v /data` (no name) or a `VOLUME /data` line in a Dockerfile creates an
**anonymous volume** with a random ID. It survives `docker rm` unless you use
`docker rm -v` or `--rm`, and then piles up. Prefer named volumes.

### Back up a volume

```bash
docker run --rm -v pgdata:/data -v "$(pwd)":/backup alpine:3.20 \
  tar czf /backup/pgdata.tgz -C /data .
```

A throwaway container mounts both the volume and a host folder, then archives one into the other.

## Try it

For each case, choose volume, bind mount or tmpfs:
(a) MySQL data in production, (b) live-editing React source during development,
(c) a session cache that must never be written to disk.

<details>
<summary>Show answer</summary>

(a) **Named volume**: managed, portable, survives container replacement.
(b) **Bind mount** of the source folder: edits show up instantly.
(c) **tmpfs**: memory only, gone when the container stops.

</details>

## Common mistakes

- **No volume for a database.** `docker rm` deletes the data with the container.
- **Relative paths with `-v`.** `-v site:/usr/share/nginx/html` creates a volume
  named `site`, not a bind mount of `./site`.
- **`docker volume prune` / `docker compose down -v` on a machine with real data.**
  They delete volumes. Read before you press Enter.
- **Permission denied on bind mounts.** The container user's UID must be allowed
  to read/write the host folder. Match UIDs or adjust ownership.

## Remember

- Writable layer = temporary. Data you care about goes in a **volume**.
- Volume (Docker-managed, portable) vs bind mount (your host path) vs tmpfs (RAM).
- `-v name:/path` = volume, `-v /abs/host:/path` = bind mount, `:ro` = read-only.
- `--mount` is explicit and errors on missing bind paths.
- Back up a volume with a throwaway container + `tar`.

**Self-check:**

1. What happens to files in a container's writable layer after `docker rm`?
2. How does Docker tell a volume name from a bind-mount path in `-v`?
3. Why are anonymous volumes a cleanup problem?
