---
kind: lesson
id_key: docker/compose-hub-registry/compose-in-depth
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: "Compose in Depth: Builds, Health-Gated Startup, Env Files, Overrides"
position: 1
estimated_minutes: 10
source:
  - Docker Command Cheat Sheet.pdf
---

## Why this matters

The basic file gets an app running. Real projects need more: build your own
image, wait until the database is actually **ready** (not just started), keep
secrets out of the file, and use one file for dev and another for prod. These
features are what separate a toy `compose.yaml` from a team's working one.

## Mental model: one base score, many arrangements

Think of `compose.yaml` as the base music score. Variables (`${VAR}`) are the
blanks you fill in per performance. Override files are alternative
arrangements layered on top. Healthchecks are the conductor waiting for each
section to be **in tune** before the next one starts.

## See it work

A realistic file:

```yaml
services:
  api:
    build:                             # build from a Dockerfile instead of pulling
      context: ./api
      target: runtime                  # a multi-stage target (Section 4)
    image: myorg/api:${API_TAG:-dev}   # name for the built image; default tag "dev"
    ports:
      - "${API_PORT:-8000}:8000"
    env_file: .env.api                 # load KEY=value lines into the container
    environment:
      DATABASE_URL: postgres://app:${DB_PASSWORD:?set DB_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy     # wait until db's healthcheck passes
    restart: unless-stopped

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD}
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      timeout: 3s
      retries: 10

  adminer:
    image: adminer
    profiles: ["debug"]                # only starts with --profile debug
    ports: ["8081:8080"]

volumes:
  dbdata:
```

### 1. Variables and the `.env` file

Compose reads a file named `.env` next to `compose.yaml` and substitutes
`${VAR}` in the YAML:

```
# .env  (do not commit real secrets)
DB_PASSWORD=devpass
API_TAG=1.4.0
```

| Syntax | Meaning |
|---|---|
| `${VAR}` | Value of VAR (empty if unset) |
| `${VAR:-default}` | VAR, or `default` if unset/empty |
| `${VAR:?message}` | VAR, or **fail** with `message` if unset/empty |

Two different things, often confused:

- **`.env`** fills `${...}` placeholders **in the YAML**.
- **`env_file:`** passes variables **into the container**.

`docker compose config` prints the final file with every variable resolved. Use it whenever something looks wrong.

### 2. Startup order that actually waits

Plain `depends_on: [db]` only waits until the db **container has started**,
not until Postgres accepts connections. Add a `healthcheck` to `db` and use
`condition: service_healthy`. Other conditions: `service_started` (default) and
`service_completed_successfully` (for one-shot jobs like migrations).

### 3. Build and run in one step

```bash
docker compose up -d --build     # rebuild images whose build context changed, then start
docker compose build api         # just build
```

### 4. Profiles

Services with `profiles:` start only when asked:

```bash
docker compose --profile debug up -d     # also starts adminer
```

### 5. Override files: dev vs prod

Compose automatically merges `compose.override.yaml` on top of `compose.yaml`.
Put dev-only settings there (bind-mounted source, debug ports):

```yaml
# compose.override.yaml  (dev only, merged automatically)
services:
  api:
    volumes:
      - ./api:/app          # live code
    environment:
      LOG_LEVEL: debug
```

For other environments, list files explicitly; later files win:

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

### 6. Scale and watch

```bash
docker compose up -d --scale worker=3   # three containers for the worker service
docker compose watch                     # sync/rebuild on file changes (needs a develop.watch section)
```

A minimal `develop.watch` block:

```yaml
services:
  api:
    build: ./api
    develop:
      watch:
        - action: sync           # copy changed files into the running container
          path: ./api/src
          target: /app/src
        - action: rebuild        # rebuild the image when dependencies change
          path: ./api/requirements.txt
```

## Try it

Your API crashes on startup with "connection refused" to the database about one
time in three, even though it has `depends_on: [db]`. Fix the file.

<details>
<summary>Show answer</summary>

`depends_on` only waited for the container to start. Add a healthcheck and a condition:

```yaml
services:
  api:
    depends_on:
      db:
        condition: service_healthy
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      retries: 10
```

Also make the API retry its connection: databases can restart later too.

</details>

## Common mistakes

- **Committing `.env` with real passwords.** Commit a `.env.example` instead; use
  a secrets manager or Compose `secrets:` for production.
- **Confusing `.env` with `env_file:`.** One feeds the YAML, the other feeds the container.
- **`depends_on` without a healthcheck**, then "random" startup failures.
- **Forgetting `--build`.** `up -d` reuses an existing image even after you edited the code.

## Remember

- `.env` + `${VAR:-default}` / `${VAR:?err}` parameterise the YAML; `docker compose config` shows the result.
- `env_file:` / `environment:` set variables **inside** containers.
- `depends_on` + `condition: service_healthy` + a `healthcheck` = real readiness ordering.
- `compose.override.yaml` merges automatically; `-f a -f b` merges explicitly, later wins.
- `profiles`, `--scale`, `up --build` and `watch` cover the rest of daily use.

**Self-check:**

1. What does `${DB_PASSWORD:?set DB_PASSWORD}` do when the variable is missing?
2. Why is `depends_on: [db]` alone not enough for a database?
3. Which file does Compose merge automatically on top of `compose.yaml`?
