---
kind: lesson
id_key: docker/dockerfile/buildkit
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "BuildKit and buildx: Cache Mounts, Secrets, Multi-Platform"
position: 5
estimated_minutes: 9
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

Modern Docker builds run on **BuildKit**, the build engine that has been the
default since Docker Engine 23. It adds three features you will want in real
projects: package caches that survive rebuilds, secrets that never land in an
image, and one build that produces images for both Intel and ARM machines.

## Mental model: a smarter workshop manager

The old builder ran instructions one by one and only knew "layer cache: hit or
miss". BuildKit is a manager who:

- builds independent stages **in parallel** and skips unused ones,
- keeps a **toolbox shelf** (cache mounts) that is not part of any layer,
- hands over **keys** (secrets) for one step and takes them back,
- can build for **other CPU types**.

`docker build` already uses BuildKit. `docker buildx` is the CLI plugin that
exposes all of its options (builders, platforms, cache export).

## See it work

### 1. Cache mounts: keep package downloads between builds

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

When `requirements.txt` changes, the `RUN` step reruns (the layer cache missed),
but pip finds already-downloaded packages in `/root/.cache/pip`. The cache
directory is **not** stored in the image.

Common targets: `/root/.npm` (npm), `/go/pkg/mod` and `/root/.cache/go-build` (Go),
`/var/cache/apt` (apt).

### 2. Secret mounts: use a token without baking it in

```dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci
```

```bash
docker build --secret id=npmrc,src=$HOME/.npmrc -t web:1.0 .
```

The file exists only while that `RUN` executes. It is not in any layer, not in
`docker history`. Compare with `ARG NPM_TOKEN`, which is visible to anyone with the image.

SSH keys work the same way: `RUN --mount=type=ssh git clone git@github.com:org/private.git`
with `docker build --ssh default .`.

### 3. Multi-platform images

```bash
# One-time: create a builder that can target several platforms
docker buildx create --name multi --use

# Build for Intel and ARM, push both under one tag
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myuser/web:1.0 --push .
```

The registry stores an **image index** (a manifest list). An ARM server pulling
`myuser/web:1.0` automatically gets the `arm64` variant. Non-native platforms
build under QEMU emulation (slower) or on a remote native builder.

### 4. Sharing cache in CI

CI machines start empty, so nothing is cached. Export and import the build cache:

```bash
docker buildx build \
  --cache-from type=registry,ref=myuser/web:buildcache \
  --cache-to   type=registry,ref=myuser/web:buildcache,mode=max \
  -t myuser/web:1.0 --push .
```

(GitHub Actions can also use `type=gha`.)

### 5. Handy everyday flags

```bash
docker build --progress=plain .        # full, uncollapsed logs (great for debugging)
docker build --target test .           # build only up to a stage
docker builder prune                   # clear the build cache
docker buildx du                       # how much space the build cache uses
```

### The syntax directive

The first line of a Dockerfile may pin the Dockerfile language version:

```dockerfile
# syntax=docker/dockerfile:1
```

This tells BuildKit to fetch the latest stable 1.x Dockerfile frontend, which
enables newer features (for example heredocs: `RUN <<EOF ... EOF`) even on an older
engine. It needs network access to fetch the frontend image. Basic `RUN --mount`
already works without it on current engines.

## Try it

Your CI build installs 400 npm packages from scratch on every run and uses an
`ARG GITHUB_TOKEN` to fetch a private package. Name the two BuildKit features
that fix speed and safety.

<details>
<summary>Show answer</summary>

1. **Cache** (`RUN --mount=type=cache,target=/root/.npm` for local reuse, plus
   `--cache-to/--cache-from` so CI runners share layer cache).
2. **Secret mount** (`RUN --mount=type=secret,id=gh ...` and
   `docker build --secret id=gh,env=GITHUB_TOKEN`) so the token never lands in the image.

</details>

## Common mistakes

- **Expecting cache mount contents in the image.** They are deliberately excluded;
  copy what you need into a normal path.
- **Secrets through `ARG`/`ENV`.** Use `--secret`.
- **Building on an M-series Mac and deploying to amd64 servers** without
  `--platform linux/amd64`: *exec format error* in production.
- **Setting `DOCKER_BUILDKIT=0`** to "fix" something. The legacy builder is deprecated; fix the Dockerfile instead.

## Remember

- BuildKit is the default builder; `docker buildx` exposes everything.
- `RUN --mount=type=cache` keeps package caches across builds, outside the image.
- `RUN --mount=type=secret` / `--ssh` give credentials to one step only.
- `--platform linux/amd64,linux/arm64 --push` builds multi-arch images.
- `--cache-to/--cache-from` share cache between CI runs.

**Self-check:**

1. Where does a cache mount's data live: in the image or outside it?
2. Why is `--secret` safer than `--build-arg` for a token?
3. What does an ARM server get when it pulls a multi-platform tag?
