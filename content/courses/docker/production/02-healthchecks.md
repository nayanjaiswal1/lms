---
kind: lesson
id_key: docker/production/healthchecks
course: docker
section: production
section_title: Production-Ready Containers
section_position: 7
title: "Healthchecks: Running Is Not the Same as Working"
position: 1
estimated_minutes: 8
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

`docker ps` says `Up 3 days`, yet every request returns 500 because the app's
database pool is dead. Docker only knows the **process is alive**. A
**healthcheck** teaches Docker how to ask "are you actually working?", and
Compose, Swarm and load balancers can act on the answer.

## Mental model: a pulse versus a conversation

- "Running" = the patient has a pulse.
- "Healthy" = the patient answers a question correctly.

A healthcheck is a small command Docker runs **inside** the container on a
schedule. Exit code `0` = healthy, `1` = unhealthy.

```
 container starts
      |
      v
  [starting] --(check passes)--> [healthy] --(retries failures in a row)--> [unhealthy]
      |                              ^                                          |
      +-- start-period: failures     +------------(check passes again)----------+
          here do not count
```

## See it work

### In a Dockerfile

```dockerfile
FROM nginx:1.27-alpine
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ || exit 1
```

| Option | Default | Meaning |
|---|---|---|
| `--interval` | 30s | Time between checks |
| `--timeout` | 30s | A check taking longer counts as a failure |
| `--start-period` | 0s | Grace time at startup; failures do not count yet |
| `--start-interval` | 5s | Check interval during the start period (newer engines) |
| `--retries` | 3 | Consecutive failures before `unhealthy` |

`HEALTHCHECK NONE` disables a check inherited from the base image.

```bash
docker build -t web-hc .
docker run -d --name hc web-hc
docker ps --filter name=hc
```

Expected `STATUS` column, first `(health: starting)`, then:

```
Up 15 seconds (healthy)
```

Read the details:

```bash
docker inspect -f '{{.State.Health.Status}}' hc
docker inspect -f '{{json .State.Health.Log}}' hc     # last results with output
```

### At run time, without changing the image

```bash
docker run -d --name hc2 \
  --health-cmd "wget -qO- http://127.0.0.1/ || exit 1" \
  --health-interval 10s --health-retries 3 \
  nginx:1.27-alpine
```

### In Compose

```yaml
services:
  api:
    image: myorg/api:1.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 20s
```

`test` forms: `["CMD", ...]` runs the program directly; `["CMD-SHELL", "..."]` runs through `sh -c`.

### What a good health endpoint checks

- Cheap and fast (it runs every few seconds).
- Checks what **this** service needs to serve requests (it can open its DB pool).
- Does not cascade: if a downstream API is down, report degraded in logs, but do
  not make every service unhealthy at once.

### What Docker does with "unhealthy"

**Plain Docker does not restart unhealthy containers.** It only reports the
status (and emits a `health_status` event). Acting on it is the job of:

- **Compose**: `depends_on: condition: service_healthy` gates startup.
- **Docker Swarm**: replaces unhealthy tasks.
- **Kubernetes**: ignores Docker's `HEALTHCHECK` and uses its own liveness/readiness probes.
- Your monitoring, alerting on `docker events --filter event=health_status`.

## Try it

A Dockerfile uses `HEALTHCHECK CMD curl -f http://localhost:8080/ || exit 1` on
a `distroless` image, and the container is always `unhealthy` even though the
app works. Why?

<details>
<summary>Show answer</summary>

The check runs **inside** the container, and distroless images have no `curl`
(and no shell for `||`). The command fails every time. Use a tool that exists
in the image, ship a tiny health binary, or build the check into the app
(for example `CMD ["/app", "healthcheck"]`).

</details>

## Common mistakes

- **Expecting Docker to restart an unhealthy container.** It does not (outside Swarm).
- **Using a tool the image lacks** (`curl` on Alpine or distroless). Alpine has `wget` via busybox.
- **Checks that are too heavy** (full DB queries every 2 s) or **too strict**
  (no `start-period` for an app that boots in 30 s).
- **Healthcheck on `localhost` when the app binds another interface** only. Match the listen address.

## Remember

- Running = process alive. Healthy = the check command exits 0.
- States: `starting` → `healthy` ⇄ `unhealthy` (after `retries` failures).
- Set it in the Dockerfile (`HEALTHCHECK`), at run (`--health-cmd`) or in Compose (`healthcheck:`).
- Docker reports health; Compose/Swarm/monitoring act on it. Kubernetes uses its own probes.
- The check runs inside the container: use tools the image has.

**Self-check:**

1. What does `--start-period` protect against?
2. Does plain Docker restart a container that turns unhealthy?
3. Which command shows the output of the last health checks?
