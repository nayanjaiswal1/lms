---
kind: lesson
id_key: docker/dockerfile/cheatsheet
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "Reference: Dockerfile and Build Cheat Sheet"
position: 7
estimated_minutes: 5
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

Use this page to **look things up**. Every item was explained in this section.

## Instructions

| Instruction | Runs at | What it does |
|---|---|---|
| `FROM image[:tag] [AS name]` | Build | Base image; starts a new stage |
| `ARG NAME[=default]` | Build | Build-time variable (`--build-arg`); not in containers |
| `ENV KEY=value` | Build + run | Environment variable baked into the image |
| `WORKDIR /path` | Build + run | Working directory for later instructions and the container |
| `COPY [--from=stage] [--chown=u:g] src dest` | Build | Copy files from the context (or a stage/image) |
| `ADD src dest` | Build | Like COPY, plus auto-extracts local tarballs and fetches URLs |
| `RUN cmd` | Build | Run a command, commit the result as a layer |
| `RUN --mount=type=cache\|secret\|ssh,...` | Build | BuildKit mounts for caches and credentials |
| `USER name[:group]` | Build + run | User for later instructions and the container |
| `EXPOSE port[/proto]` | Metadata | Documents a port; `-P` publishes it |
| `VOLUME /path` | Run | Anonymous volume created at that path |
| `LABEL key=value` | Metadata | Image metadata (`org.opencontainers.image.*`) |
| `CMD ["exe", "arg"]` | Run | Default command / default ENTRYPOINT args; last one wins |
| `ENTRYPOINT ["exe"]` | Run | The program the container always runs |
| `HEALTHCHECK CMD ...` | Run | Health probe (Section 7) |
| `STOPSIGNAL SIGNAL` | Run | Signal `docker stop` sends |
| `SHELL ["bash", "-c"]` | Build | Shell for shell-form instructions |
| `ONBUILD INSTRUCTION` | Child build | Deferred instruction for images built `FROM` this one |
| `MAINTAINER` | - | Deprecated; use `LABEL org.opencontainers.image.authors` |

## Build commands

| Command | What it does |
|---|---|
| `docker build -t name:tag .` | Build from `./Dockerfile` with `.` as the context |
| `docker build -f path/Dockerfile .` | Use a different Dockerfile |
| `docker build --build-arg K=V .` | Set an `ARG` |
| `docker build --target stage .` | Stop at a named stage |
| `docker build --no-cache .` / `--pull` | Ignore cache / re-check the base image |
| `docker build --progress=plain .` | Full build logs |
| `docker build --secret id=x,src=file .` | Provide a build secret |
| `docker buildx build --platform linux/amd64,linux/arm64 --push .` | Multi-platform build |
| `docker buildx build --cache-to/--cache-from type=registry,ref=...` | Share build cache |
| `docker builder prune`, `docker buildx du` | Clean / measure build cache |

## Production Dockerfile template (Python)

```dockerfile
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

FROM base AS deps
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/install -r requirements.txt

FROM base AS runtime
COPY --from=deps /install /usr/local
RUN useradd -r -u 10001 app
COPY --chown=app:app . .
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["python", "app.py"]
```

## Checklist

- Pinned base image tag (or digest); slim/distroless final stage
- `.dockerignore` excludes `.git`, `node_modules`, `.env`, build output
- Dependency manifests copied and installed before source code
- `apt-get update && install && rm -rf /var/lib/apt/lists/*` in one `RUN`
- No secrets in `ARG`/`ENV`; use `--secret`
- Non-root `USER`; exec-form `CMD`/`ENTRYPOINT`
