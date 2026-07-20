---
kind: lesson
id_key: interview-prep-45/day-13-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 13 — Docker and Containerization"
position: 13
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Docker questions in backend interviews aren't really about Docker syntax — they're about whether you understand image layering, why image size matters in production, and how to compose a multi-service local environment. Today: networking and volumes, a real multi-stage Dockerfile for a Python app, and docker-compose wiring app + database + Redis together.

## Images are layers; layers are cached

Every instruction in a Dockerfile (`RUN`, `COPY`, `ADD`) creates a new, immutable layer stacked on the previous one. Docker caches layers by content hash — if a layer's inputs haven't changed, Docker reuses the cached layer instead of re-running the instruction. This is the entire reason Dockerfile *instruction order* matters:

```dockerfile
# BAD: any source code change invalidates the pip install cache layer,
# forcing a full dependency reinstall on every build
COPY . .
RUN pip install -r requirements.txt

# GOOD: dependencies only reinstall when requirements.txt itself changes
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

This ordering trick — copy the least-frequently-changing files first — is close to universally asked in some form ("how would you speed up this Dockerfile") and is worth having memorized as a pattern, not just this one example.

## Multi-stage build for a Python app

```dockerfile
# --- Stage 1: build dependencies ---
FROM python:3.12-slim AS builder

WORKDIR /app

# System deps needed only to COMPILE some Python packages (e.g. psycopg2, cryptography) —
# these do not need to exist in the final image
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# --- Stage 2: runtime image ---
FROM python:3.12-slim AS runtime

WORKDIR /app

# Only runtime system deps — no compiler, no build headers
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy only the installed Python packages from the builder stage, not the build toolchain
COPY --from=builder /root/.local /root/.local
COPY . .

ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Run as a non-root user — a container running as root is a real security finding in any review
RUN useradd --create-home appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

The compiler toolchain (`build-essential`, `-dev` headers) needed to build `psycopg2` or `cryptography` from source is only present in the `builder` stage — the final `runtime` image copies just the compiled `.local` package directory, not gcc, not the headers, not the apt cache. This is the mechanism behind "how do you reduce image size": multi-stage builds let you use a full build environment without shipping any of it.

## COPY vs ADD

`COPY` copies files/directories from the build context into the image, literally, nothing more. `ADD` does everything `COPY` does, plus: it can fetch a **remote URL** as a source, and it **auto-extracts** local tar archives into the destination. The extra behavior is exactly why `ADD` is generally discouraged — the implicit auto-extraction and remote-fetch behavior are easy to trigger by accident and make the build step non-obvious from reading the Dockerfile. **Rule to state in an interview: use `COPY` unless you specifically need tar auto-extraction, and never use `ADD` for a remote URL — use an explicit `RUN curl`/`wget` instead, so the fetch and its error handling are visible in the Dockerfile.**

```dockerfile
# COPY: explicit, no surprises
COPY requirements.txt .

# ADD: auto-extracts local .tar.gz — sometimes genuinely useful
ADD app-bundle.tar.gz /app/

# Prefer this over `ADD https://...` for remote files — visible, and you control error handling
RUN curl -fsSL https://example.com/tool.tar.gz -o /tmp/tool.tar.gz \
    && tar -xzf /tmp/tool.tar.gz -C /usr/local/bin \
    && rm /tmp/tool.tar.gz
```

## Reducing image size — the full checklist

- Multi-stage builds (above) — the single biggest lever.
- `python:3.12-slim` or `-alpine` base instead of the full `python:3.12` image (hundreds of MB difference); note Alpine uses `musl` libc, which occasionally breaks binary wheels that expect `glibc` — `slim` (Debian-based) is the safer default for Python.
- `--no-cache-dir` on `pip install` — pip caches downloaded wheels by default, which is dead weight in an image that's built once and never reused for incremental installs.
- `rm -rf /var/lib/apt/lists/*` after any `apt-get install`, in the *same* `RUN` layer (a separate `RUN rm` doesn't shrink earlier layers — layers are immutable once committed).
- `.dockerignore` excluding `.git`, `__pycache__`, `.venv`, test fixtures, local env files — keeps the build context small and prevents accidentally baking secrets or dev artifacts into a layer.

```
# .dockerignore
.git
__pycache__
*.pyc
.venv
.env
tests/
*.md
```

## Docker networking and volumes

**Networking:** containers on the same user-defined `bridge` network (which `docker-compose` creates automatically per project) can reach each other by **service name** as a DNS hostname — `db`, `redis`, `web` resolve automatically, no manual IP wiring. Containers are isolated from the host and from other Docker networks by default; you explicitly `EXPOSE`/publish (`-p`) only the ports that need host access.

**Volumes:** a named volume (`docker volume create` or declared in compose) persists data outside any single container's writable layer — essential for a database container, since the container's own filesystem is ephemeral and destroyed on `docker rm`. A bind mount (`./src:/app/src`) maps a host directory directly into the container, mainly used for local dev hot-reload; avoid bind-mounting source code in production images — production images should be immutable, self-contained builds.

## docker-compose: app + database + Redis

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://appuser:apppass@db:5432/appdb
      REDIS_URL: redis://redis:6379/0
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./:/app  # dev-only bind mount for hot reload — remove for a production compose file

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: apppass
      POSTGRES_DB: appdb
    volumes:
      - postgres_data:/var/lib/postgresql/data  # named volume — survives `docker compose down`
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
```

`depends_on` with `condition: service_healthy` (not just plain `depends_on`, which only waits for the container to *start*, not to be *ready*) is the detail that prevents the classic "web container crashes on startup because Postgres hasn't finished initializing yet" race — plain `depends_on` guarantees start order, not readiness order, and a database container is "started" well before it's accepting connections.

## Key takeaways

- Docker layers are cached by content hash — order Dockerfile instructions from least- to most-frequently-changing to maximize cache hits.
- Multi-stage builds let you use a full compiler toolchain to build dependencies, then ship only the compiled output in the final runtime image — the main lever for image size.
- `COPY` is explicit and predictable; `ADD`'s extra behaviors (remote fetch, auto-extract) are surprising in a Dockerfile review — default to `COPY`.
- Clean up `apt-get` cache in the *same* `RUN` layer as the install, since layers are immutable once committed — a later `rm` in a new layer doesn't shrink the old one.
- Compose services reach each other by service name over the auto-created bridge network; named volumes persist data beyond a container's lifecycle, bind mounts are for dev-only hot reload.
- `depends_on: condition: service_healthy` waits for actual readiness (via a healthcheck), not just container start — use it for any service with a startup lag, like Postgres.

## Today's checklist

- [ ] Read: Docker networking and volumes
- [ ] Write a multi-stage Dockerfile for a Python app
- [ ] Write docker-compose for app + database + Redis
- [ ] Write a production-ready Dockerfile for a Django/FastAPI app
- [ ] Be ready to answer: what is the difference between COPY and ADD? How do you reduce image size?
