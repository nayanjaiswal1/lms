---
kind: lesson
id_key: docker/image-commands/moving-images
course: docker
section: image-commands
section_title: Images & Layers
section_position: 3
title: "Moving Images: pull, push, save, load"
position: 2
estimated_minutes: 7
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

An image built on your laptop is only useful once it reaches a server. Most of
the time that means a registry (`push`/`pull`). Sometimes there is no network
at all: an air-gapped factory, a secure lab. Then you carry the image as a file
(`save`/`load`).

## Mental model: two ways to send a parcel

```
  Via a registry (post office)           As a file (hand delivery)
  ---------------------------            -------------------------
  laptop: docker push  ---> registry     laptop: docker save -o app.tar
  server: docker pull  <--- registry     copy app.tar on a USB stick
                                         server: docker load -i app.tar
  only missing layers travel             the whole image travels
```

Do not confuse **save/load** with **export/import**:

| Pair | Works on | Keeps |
|---|---|---|
| `docker save` / `docker load` | **Images** | All layers, tags, history, metadata (CMD, ENV, ...) |
| `docker export` / `docker import` | **Containers** → image | One flattened filesystem only; metadata and history are lost |

Mnemonic: **S**ave is for **S**tacks of layers; **E**xport is for **E**verything flattened.

## See it work

### Registry round trip

```bash
docker login                               # Docker Hub; prompts for user and token
docker tag myimage:latest myuser/myimage:1.0   # name it for your namespace
docker push myuser/myimage:1.0             # upload only layers the registry lacks
docker pull myuser/myimage:1.0             # on another machine
docker search nginx                        # search Docker Hub from the CLI
docker logout
```

You must tag an image with the **registry/namespace** prefix before pushing.
Section 6 practices this against a private registry.

### Save and load

```bash
docker save -o myimage.tar myimage:latest   # image -> tar file
ls -lh myimage.tar
docker rmi myimage:latest                   # remove it locally
docker load -i myimage.tar                  # tar file -> image
```

Expected output of `load`:

```
Loaded image: myimage:latest
```

Save several images into one file: `docker save -o bundle.tar img1:1 img2:1`.
Compress if you like: `docker save myimage:latest | gzip > myimage.tar.gz`
(`docker load` reads gzip directly).

### Inspect before you ship

```bash
docker image inspect myimage:latest                       # full JSON
docker image inspect -f '{{.Config.Cmd}}' myimage:latest  # default command
docker image inspect -f '{{.Architecture}}' myimage:latest # amd64 or arm64?
```

### Export and import (rarely needed)

```bash
docker export mycontainer > fs.tar        # a container's flattened filesystem
docker import fs.tar myflat:1             # becomes a one-layer image, no CMD
```

The imported image has no default command, so you must give one: `docker run myflat:1 sh`.

## Try it

You must move `shop-api:2.0` (with its `CMD` and `ENV` settings intact) to a
server with no internet. Write the commands on both machines.

<details>
<summary>Show answer</summary>

```bash
# laptop
docker save -o shop-api-2.0.tar shop-api:2.0
# copy the file over (scp, USB, ...)
# server
docker load -i shop-api-2.0.tar
docker run -d shop-api:2.0
```

Not `export`/`import`: that would drop `CMD`, `ENV` and the layer history.

</details>

## Common mistakes

- **Pushing without the namespace.** `docker push myimage` tries
  `docker.io/library/myimage`, which you are not allowed to write to:
  *"denied: requested access to the resource is denied"*. Tag `myuser/myimage` first.
- **Using `export` to back up an image.** It works on containers and loses metadata.
- **Shipping an `amd64` image to an ARM server.** It fails with *"exec format error"*.
  Check `.Architecture`, or build multi-platform images (Section 4).
- **Logging in with your account password.** Use a personal access token instead.

## Remember

- Registry: `tag` with prefix → `push` → `pull`. Only missing layers travel.
- Offline: `save -o file.tar` → copy → `load -i file.tar`. Keeps everything.
- `export`/`import` flattens a **container** and drops metadata.
- `docker image inspect` tells you the command, env and architecture before you ship.

**Self-check:**

1. What is the difference between `save` and `export`?
2. Why does `docker push myimage` fail on Docker Hub?
3. What does "exec format error" usually mean?
