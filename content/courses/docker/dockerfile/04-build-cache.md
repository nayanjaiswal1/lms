---
kind: lesson
id_key: docker/dockerfile/build-cache
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "The Build Cache: Why Instruction Order Matters"
position: 3
estimated_minutes: 8
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

The same app can take 4 minutes or 4 seconds to rebuild. The difference is
almost always the order of a few lines in the Dockerfile. Fast rebuilds mean
fast feedback and cheaper CI.

## Mental model: a row of dominoes

Docker caches every layer. On a rebuild it walks the Dockerfile from the top
and asks, for each instruction: "Have I built exactly this before, on top of
exactly the same parent?" If yes, it reuses the cached layer (`CACHED`).

The moment one instruction misses the cache, **every instruction after it is
rebuilt too**. Like dominoes: one falls, all later ones fall.

```
FROM python:3.12-slim          CACHED
WORKDIR /app                   CACHED
COPY . .                       <-- you edited app.py: MISS
RUN pip install -r req.txt     rebuilt (slow!) even though req.txt is unchanged
CMD [...]                      rebuilt
```

How Docker decides "same as before":

- `RUN`: the **command text** is the same (it does not re-check the internet).
- `COPY`/`ADD`: the **checksums of the copied files** are the same.
- Everything: the **parent layer** is the same.

## The golden rule

**Order instructions from least-often-changed to most-often-changed.**
Copy dependency manifests and install dependencies **before** copying source code.

## See it work

Slow version:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .                                   # any code edit invalidates this...
RUN pip install --no-cache-dir -r requirements.txt   # ...so this reruns every time
CMD ["python", "app.py"]
```

Fast version:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .                    # changes rarely
RUN pip install --no-cache-dir -r requirements.txt   # cached until requirements change
COPY . .                                   # changes often; cheap to redo
CMD ["python", "app.py"]
```

Edit `app.py` and rebuild the fast version:

```bash
docker build -t pyweb:dev .
```

Expected output (shortened):

```
 => CACHED [2/5] WORKDIR /app
 => CACHED [3/5] COPY requirements.txt .
 => CACHED [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [5/5] COPY . .
```

Only the last `COPY` reran. The same pattern applies everywhere:

| Stack | Copy first | Install | Then copy the rest |
|---|---|---|---|
| Node | `package.json package-lock.json` | `npm ci` | `COPY . .` |
| Python | `requirements.txt` (or `pyproject.toml` + lock) | `pip install` | `COPY . .` |
| Go | `go.mod go.sum` | `go mod download` | `COPY . .` |

### Combine install and cleanup in one RUN

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```

Why one line: `apt-get update` alone in its own cached layer can go stale, and a
later `apt-get install` would then use an old package index. Cleaning up in the
same `RUN` also keeps the deleted files out of the layer (Section 3).

### Forcing a rebuild

```bash
docker build --no-cache -t pyweb:dev .     # ignore the cache entirely
docker build --pull -t pyweb:dev .         # also re-check the base image for updates
```

Use these for security-patch builds: a cached `RUN apt-get upgrade` never re-runs by itself.

## Try it

This Node Dockerfile rebuilds `npm ci` on every code change. Reorder it.

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY . .
RUN npm ci
CMD ["node", "server.js"]
```

<details>
<summary>Show answer</summary>

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
CMD ["node", "server.js"]
```

Also add `node_modules` to `.dockerignore`, so `COPY . .` does not overwrite the
installed modules with your local ones.

</details>

## Common mistakes

- **`COPY . .` before installing dependencies.** Every edit reinstalls everything.
- **`RUN apt-get update` on its own line.** Stale package index later.
- **Expecting the cache to notice upstream changes.** `RUN curl ...` or
  `RUN pip install flask` (unpinned) is cached forever by its text. Pin versions;
  use `--no-cache`/`--pull` for refresh builds.
- **Volatile values early.** `ARG BUILD_TIME` used near the top busts the cache for everything below.

## Remember

- Cache hit = same instruction text (or same file checksums) on the same parent.
- One miss rebuilds everything below it.
- Least-changed first: manifests → install → source code.
- `apt-get update && install && cleanup` in one `RUN`.
- `--no-cache` and `--pull` force fresh builds.

**Self-check:**

1. How does Docker decide a `COPY` step is cached?
2. Why copy `package.json` separately from the rest of the code?
3. Why won't a cached `RUN apt-get upgrade -y` pick up new security patches?
