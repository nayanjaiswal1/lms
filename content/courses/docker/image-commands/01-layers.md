---
kind: lesson
id_key: docker/image-commands/layers
course: docker
section: image-commands
section_title: Images & Layers
section_position: 3
title: "What an Image Really Is: Layers and Copy-on-Write"
position: 0
estimated_minutes: 9
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

Layers explain three things you will care about every day: why pulling a second
image is often almost instant, why your builds are fast or slow (Section 4), and
why deleting a file in a later step does **not** make an image smaller.

## Mental model: a stack of transparent sheets

Picture an overhead projector with transparent sheets stacked on top of each
other. Each sheet adds or covers some drawings. Looking from the top, you see
one combined picture.

An image is a stack of read-only **layers**. Each layer is a set of file
changes (added, changed, deleted files). Docker merges them into one view
using a **union filesystem** (on Linux, the `overlay2` storage driver).

```
            container view (what the process sees)
   +---------------------------------------------+
   | writable container layer   (per container)  |  <- your changes go here
   +=============================================+
   | layer 3: COPY app.py /app       (read-only)  |
   | layer 2: RUN pip install flask  (read-only)  |  image
   | layer 1: python:3.12-slim base  (read-only)  |  (shared)
   +---------------------------------------------+
```

When a container starts, Docker adds one thin **writable layer** on top.

**Copy-on-write (CoW):** when the container modifies a file that lives in a
lower read-only layer, Docker first **copies** that file up into the writable
layer, then changes the copy. The original stays untouched for everyone else.

> **One-sentence definition.** An image is an ordered stack of read-only file-change
> layers plus metadata (default command, env vars, ports); a container is that
> stack plus one writable layer.

Two big consequences:

1. **Sharing.** Ten containers from the same image share the same read-only
   layers on disk. Only their thin writable layers differ.
2. **Layers are content-addressed.** Each layer is identified by a SHA-256 hash
   of its content (a **digest**). If two images use the same base layer,
   Docker stores and downloads it once.

## See it work

```bash
docker pull python:3.12-alpine
```

Expected output (shortened):

```
3.12-alpine: Pulling from library/python
1f3e46996e29: Pull complete
...
Digest: sha256:...
Status: Downloaded newer image for python:3.12-alpine
```

Each `Pull complete` line is **one layer**. If you already have some layers
(for example the same Alpine base), you see `Already exists` instead.

```bash
# Show the layers and the instruction that created each
docker history python:3.12-alpine
```

Output (shortened; dates, IDs and sizes vary):

```
IMAGE          CREATED        CREATED BY                                      SIZE
2893cf9f584f   4 months ago   CMD ["python3"]                                 0B
<missing>      4 months ago   RUN /bin/sh -c set -eux;   apk add --no-cach…   39.5MB
...
<missing>      4 months ago   CMD ["/bin/sh"]                                 0B
<missing>      4 months ago   ADD alpine-minirootfs-3.24.1-x86_64.tar.gz /…   8.42MB
```

Read it bottom to top: base filesystem first, newest instruction on top.
Instructions like `CMD` or `ENV` create **0B** entries: they change metadata only.
`<missing>` just means that layer was built elsewhere; it is normal.

### See copy-on-write

```bash
docker run -d --name cow nginx:1.27-alpine
docker exec cow sh -c "echo changed >> /etc/nginx/nginx.conf"
docker diff cow
```

Output includes:

```
C /etc
C /etc/nginx
C /etc/nginx/nginx.conf
```

`C` = changed. The file was copied up into `cow`'s writable layer. Start a new
container from the same image and its `nginx.conf` is the original.

### Size on disk

```bash
docker ps -s --filter name=cow
```

The `SIZE` column shows something like `1.2kB (virtual 48.2MB)`: the writable
layer is tiny; the "virtual" part is the shared image.

## Try it

A Dockerfile does `RUN download-1GB-dataset.sh` and then, in the next line,
`RUN rm -rf /dataset`. Is the final image about 1 GB smaller than without the
`rm`? Explain using layers.

<details>
<summary>Show answer</summary>

No. The 1 GB lives in the first `RUN` layer forever. The second `RUN` only adds a
layer that marks the files as deleted (a "whiteout"). The container cannot see
them, but they are still shipped and stored. Fix: download, use and delete in
**the same** `RUN` step, or use a multi-stage build (Section 4).

</details>

## Common mistakes

- **Deleting files in a later layer to "save space".** It hides them, it does not
  remove them (see Try it).
- **Writing heavy data into the container layer.** CoW makes big writes slow and
  the data dies with the container. Use volumes for data.
- **Thinking every image costs its full size on disk.** Shared layers are stored once.
  `docker system df` shows the real total.

## Remember

- Image = stack of read-only layers + metadata. Container = image + one writable layer.
- Union filesystem (`overlay2`) merges layers into one view.
- Copy-on-write: modifying a lower-layer file copies it up first.
- Layers are content-addressed (SHA-256), so identical layers are shared and downloaded once.
- Files deleted in a later layer still take space.

**Self-check:**

1. What does `docker history` show, and in which order?
2. What happens, step by step, when a container edits a file from the image?
3. Why does pulling a second Alpine-based image often finish faster?
