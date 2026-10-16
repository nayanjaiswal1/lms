---
kind: lesson
id_key: docker/dockerfile/multi-stage
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "Multi-Stage Builds: Small, Clean Images"
position: 4
estimated_minutes: 9
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

Building an app needs compilers, dev dependencies and source code. Running it
needs none of that. A Go service built the naive way can produce a ~800 MB image;
with a multi-stage build the same service ships in ~10 MB. Smaller images pull
faster, start faster and give attackers fewer tools.

## Mental model: the workshop and the delivery van

You build furniture in a **workshop** full of saws and glue. You deliver only
the finished chair in a **van**. You never ship the workshop.

```
  Stage "build" (workshop)                Final stage (van)
  ------------------------                -----------------
  FROM golang:1.23 AS build               FROM gcr.io/distroless/static
  compilers, source, caches   --COPY-->   just the binary
  ~800 MB, thrown away                    ~10 MB, shipped
```

A Dockerfile can contain several `FROM` lines. Each `FROM` starts a new
**stage**. Only the **last** stage becomes the image, unless you choose
another with `--target`. `COPY --from=<stage>` pulls files out of an earlier stage.

## See it work

### Go: compile, then ship only the binary

```dockerfile
# ---- Stage 1: build ----
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download                     # cached dependency layer
COPY . .
RUN CGO_ENABLED=0 go build -o /out/server .   # static binary

# ---- Stage 2: run ----
FROM gcr.io/distroless/static-debian12
COPY --from=build /out/server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

Line by line:

- `AS build` names the first stage.
- `CGO_ENABLED=0` makes a static binary that needs no C libraries at run time.
- `distroless/static` contains no shell and no package manager: almost nothing to attack.
- `COPY --from=build` takes one file from the build stage. Everything else is discarded.

```bash
docker build -t goapp:1.0 .
docker images goapp
```

Expected: a size in the low tens of MB, not hundreds.

### Node: install with dev tools, ship production deps only

```dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS build
COPY . .
RUN npm run build                       # needs dev dependencies

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev                   # production deps only
COPY --from=build /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

### Static site: build with Node, serve with nginx

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY . .
RUN npm ci && npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
```

### Useful extras

```bash
docker build --target build -t goapp:debug .   # stop at the "build" stage (for tests/debugging)
```

```dockerfile
# copy from any image, not just a stage
COPY --from=nginx:1.27-alpine /etc/nginx/nginx.conf /tmp/
```

With BuildKit (the default builder), stages the final image does not need are
skipped, and independent stages build in parallel.

### Picking the final base image

| Base | Size | Has a shell? | Good for |
|---|---|---|---|
| `debian:bookworm-slim`, `python:3.12-slim` | ~30-130 MB | Yes | Apps needing glibc and debugging tools |
| `alpine` | ~8 MB | Yes (busybox) | Small images; uses musl libc (rare compatibility issues) |
| `gcr.io/distroless/*`, Chainguard images | ~2-30 MB | No | Hardened production runtimes |
| `scratch` | 0 MB | No | Fully static binaries only |

## Try it

A Python image includes `gcc` because one dependency compiles a C extension.
Sketch a two-stage Dockerfile that keeps `gcc` out of the final image.

<details>
<summary>Show answer</summary>

```dockerfile
FROM python:3.12-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends gcc \
 && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim
COPY --from=build /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels
COPY . /app
WORKDIR /app
CMD ["python", "app.py"]
```

Build wheels where the compiler lives; install the prebuilt wheels in a clean stage.

</details>

## Common mistakes

- **Copying the whole build stage** (`COPY --from=build / /`). You ship the workshop again.
- **Dynamic binary on `scratch`/distroless static.** Fails with *"no such file or
  directory"* because libc is missing. Build static (`CGO_ENABLED=0`) or use a base with libc.
- **No shell to debug distroless.** Use `--target build` for debugging, or
  `docker debug` / an ephemeral debug container, instead of adding a shell to production.
- **Musl surprises on Alpine** (DNS quirks, slower Python wheels). Use `-slim` if it bites.

## Remember

- Several `FROM` lines = several stages; only the last one ships.
- `COPY --from=stage` takes just the artifacts you need.
- Build tools, source and caches stay behind: smaller and safer images.
- `--target NAME` builds an intermediate stage.
- Final base: slim → alpine → distroless → scratch, from most to least convenient.

**Self-check:**

1. What decides which stage becomes the final image?
2. Why is a distroless or scratch final stage more secure?
3. What does `--target` do?
