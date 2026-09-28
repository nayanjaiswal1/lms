---
kind: lesson
id_key: interview-prep-45/day-13-backend
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "Docker and Containers"
position: 5
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Docker questions in a backend interview aren't really about Docker syntax. They're about whether you understand image layering, why image size matters in production, and how to wire a multi-service local environment together. This lesson covers layer caching, a real multi-stage Dockerfile for a Python app, `COPY` versus `ADD`, shrinking an image, networking and volumes, and a docker-compose file wiring an app, a database, and Redis together.

## Images are layers, and layers are cached

Every instruction in a Dockerfile, `RUN`, `COPY`, `ADD`, creates a new, immutable layer stacked on the one before it. Docker caches each layer by the hash of its inputs: if a layer's inputs haven't changed, Docker reuses the cached layer instead of re-running the instruction. This is the entire reason instruction *order* matters:

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

Copy the files that change the least often first. In the bad version, editing a single line of application code invalidates the cache for the `pip install` layer too, since Docker sees `COPY . .` as changed and everything after it as no longer trustworthy. In the good version, `requirements.txt` only changes when a dependency actually changes, so the expensive install step stays cached across ordinary code edits. "How would you speed up this Dockerfile" is close to a guaranteed question, and this ordering trick is the answer almost every time.

> **Remember:** copy your least-frequently-changing files first. A source code change should never force a dependency reinstall.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-docker-layers-q1", "type": "mcq",
      "prompt": "A Dockerfile does COPY . . before RUN pip install -r requirements.txt. Why does this slow down every build after the first one?",
      "options": [
        {"id":"a","text":"Docker cannot cache the pip install layer under any ordering"},
        {"id":"b","text":"Any source file change invalidates the COPY . . layer, which invalidates every layer after it, including the pip install, forcing a full reinstall even when requirements.txt never changed"},
        {"id":"c","text":"pip install always re-downloads packages regardless of caching"},
        {"id":"d","text":"COPY . . is slower than COPY requirements.txt . by itself"}
      ],
      "correct": "b",
      "explanation": "Docker's layer cache is invalidated the moment any layer's inputs change, and every layer after an invalidated one is rebuilt too. Copying the whole source tree before installing dependencies means any code edit forces a fresh dependency install." }
] }
```

## A multi-stage build for a Python app

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

The compiler toolchain (`build-essential`, the `-dev` headers) needed to build `psycopg2` or `cryptography` from source lives only in the `builder` stage. The final `runtime` image copies just the compiled `.local` package directory: not gcc, not the headers, not the apt cache. This is the mechanism behind "how do you reduce image size": a multi-stage build lets you use a full build environment during the build without shipping any of it in the final image.

> **Remember:** the build toolchain lives only in the builder stage. The runtime stage copies the compiled result, not the compiler that produced it.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-docker-multistage-q1", "type": "mcq",
      "prompt": "Why does the final runtime image never include build-essential, even though it was needed to install some Python packages?",
      "options": [
        {"id":"a","text":"build-essential is automatically deleted at the end of every Dockerfile"},
        {"id":"b","text":"The multi-stage build only installs it in the separate builder stage; the runtime stage copies just the compiled package files, leaving the compiler and headers behind entirely"},
        {"id":"c","text":"Python packages never actually need build-essential to install"},
        {"id":"d","text":"apt-get install always removes itself after running"}
      ],
      "correct": "b",
      "explanation": "A multi-stage build isolates the compiler toolchain in one stage. The runtime stage only copies the already-compiled output (COPY --from=builder), so the heavy build dependencies never make it into the final image." }
] }
```

## COPY vs ADD

`COPY` copies files or directories from the build context into the image, literally, nothing more. `ADD` does everything `COPY` does, plus two extra tricks: it can fetch a **remote URL** as a source, and it **auto-extracts** local tar archives into the destination. That extra behavior is exactly why `ADD` is generally discouraged: the implicit auto-extraction and remote-fetch behavior are easy to trigger by accident, and make a build step non-obvious just from reading the Dockerfile.

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

The rule to state in an interview: use `COPY` unless you specifically need tar auto-extraction, and never use `ADD` for a remote URL. An explicit `RUN curl`/`wget` makes the fetch and its error handling visible in the Dockerfile itself.

> **Remember:** COPY is explicit and predictable. ADD hides two extra behaviors (remote fetch, auto-extract) inside one instruction, which is exactly why it's the one to avoid by default.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-docker-copyadd-q1", "type": "mcq",
      "prompt": "Why is ADD https://example.com/file.tar.gz /app/ generally discouraged compared to an explicit RUN curl command?",
      "options": [
        {"id":"a","text":"ADD cannot fetch files over HTTPS"},
        {"id":"b","text":"ADD's remote-fetch and auto-extract behavior is implicit and easy to miss when reading the Dockerfile, and it gives you no control over error handling the way an explicit RUN curl does"},
        {"id":"c","text":"ADD is always slower than curl regardless of network conditions"},
        {"id":"d","text":"Docker deprecated ADD entirely and it no longer functions"}
      ],
      "correct": "b",
      "explanation": "ADD bundles fetching and extraction into one instruction with hidden behavior, making the build step harder to reason about and harder to handle errors for. An explicit RUN curl/tar sequence makes every step visible and controllable." }
] }
```

## Reducing image size: the full checklist

- **Multi-stage builds**, above: the single biggest lever.
- **`python:3.12-slim` or `-alpine`** instead of the full `python:3.12` image, a difference of hundreds of megabytes. Alpine uses `musl` libc instead of `glibc`, which occasionally breaks binary wheels that expect `glibc`, so `slim` (Debian-based) is the safer default for Python.
- **`--no-cache-dir` on `pip install`**: pip caches downloaded wheels by default, which is dead weight in an image that's built once and never reused for incremental installs.
- **`rm -rf /var/lib/apt/lists/*`** right after any `apt-get install`, in the *same* `RUN` layer. A separate `RUN rm` in a later instruction doesn't shrink the earlier layer, since layers are immutable once committed.
- **A `.dockerignore`** excluding `.git`, `__pycache__`, `.venv`, test fixtures, and local env files. This keeps the build context small and stops secrets or dev artifacts from accidentally getting baked into a layer.

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

> **Remember:** `rm -rf /var/lib/apt/lists/*` only shrinks the image if it runs in the same RUN layer as the apt-get install it's cleaning up after. A later, separate RUN can't undo an earlier committed layer.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-docker-imagesize-q1", "type": "mcq",
      "prompt": "A Dockerfile runs apt-get install in one RUN instruction, then rm -rf /var/lib/apt/lists/* in a separate, later RUN instruction. Does this shrink the final image?",
      "options": [
        {"id":"a","text":"Yes, deleted files never count toward image size regardless of which layer removes them"},
        {"id":"b","text":"No, because layers are immutable once committed; the apt cache is already permanently part of the earlier layer, and a later RUN rm only adds a new layer marking the files as deleted, not removing them from the image"},
        {"id":"c","text":"Yes, but only if the image uses Alpine as its base"},
        {"id":"d","text":"No, because apt-get install cannot be cleaned up at all"}
      ],
      "correct": "b",
      "explanation": "Each RUN instruction commits an immutable layer. Files added in an earlier layer still take up space in the image even if a later layer deletes them; only cleaning up within the same RUN as the install actually shrinks the image." }
] }
```

## Docker networking and volumes

**Networking.** Containers on the same user-defined `bridge` network, which `docker-compose` creates automatically per project, can reach each other by **service name** as a DNS hostname: `db`, `redis`, `web` resolve automatically, with no manual IP wiring needed. Containers stay isolated from the host and from other Docker networks by default; you explicitly `EXPOSE`/publish (`-p`) only the ports that actually need host access.

**Volumes.** A named volume (`docker volume create`, or declared in compose) persists data outside any single container's writable layer. This matters for a database container specifically, since the container's own filesystem is ephemeral and gets destroyed on `docker rm`. A bind mount (`./src:/app/src`) maps a host directory directly into the container, mainly used for local dev hot-reload. Avoid bind-mounting source code in production images; production images should be immutable, self-contained builds.

> **Remember:** service names resolve automatically as DNS hostnames on a compose network. A named volume survives `docker rm`; the container's own writable layer does not.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-docker-networking-q1", "type": "mcq",
      "prompt": "A Postgres container is removed with docker rm and recreated. What happens to its data if it was only stored in the container's own writable layer, with no volume?",
      "options": [
        {"id":"a","text":"The data survives automatically since Docker preserves container filesystems by default"},
        {"id":"b","text":"The data is lost, since the writable layer is destroyed with the container; only a named volume or bind mount persists data across a container removal"},
        {"id":"c","text":"The data moves automatically into a new anonymous volume"},
        {"id":"d","text":"docker rm only removes the container's metadata, never its filesystem"}
      ],
      "correct": "b",
      "explanation": "A container's own writable layer is ephemeral and disappears with the container. A named volume exists independently of any one container's lifecycle, which is why a database container always needs one for real data." }
] }
```

## docker-compose: app, database, and Redis together

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

`depends_on` with `condition: service_healthy`, not plain `depends_on`, is what prevents the classic "web container crashes on startup because Postgres isn't ready yet" race. Plain `depends_on` only guarantees start *order*, not readiness order, and a database container is considered "started" well before it's actually accepting connections. The `healthcheck` block is what makes `service_healthy` mean something concrete: without it, there's nothing for `condition: service_healthy` to check.

> **Remember:** plain `depends_on` waits for a container to start, not to be ready. `condition: service_healthy` waits for the healthcheck to pass, which is what actually prevents the startup race.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-docker-compose-q1", "type": "mcq",
      "prompt": "A web service uses plain depends_on: db with no condition, and crashes on startup because Postgres isn't accepting connections yet. What's the fix?",
      "options": [
        {"id":"a","text":"Add a longer sleep at the start of the web container's entrypoint"},
        {"id":"b","text":"Use depends_on with condition: service_healthy plus a healthcheck on the db service, so web waits for Postgres to actually be ready, not just started"},
        {"id":"c","text":"Remove depends_on entirely, since it doesn't help anyway"},
        {"id":"d","text":"Switch the database image to a faster-starting one"}
      ],
      "correct": "b",
      "explanation": "Plain depends_on only orders container start, not readiness. condition: service_healthy combined with a real healthcheck makes Compose wait until the database is actually accepting connections before starting the dependent service." }
] }
```
