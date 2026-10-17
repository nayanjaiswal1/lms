---
kind: lesson
id_key: docker/production/best-practices
course: docker
section: production
section_title: Production-Ready Containers
section_position: 7
title: "Best Practices: The Production Checklist"
position: 3
estimated_minutes: 8
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

You have now seen each piece separately. This lesson pulls them into one
checklist you can run against any image or `docker run` command, in a code
review or an interview. Every item points back to the lesson that explains it.

## Mental model: the twelve-factor container

A good container is **disposable cattle, not a pet**: you can kill it, start a
new one anywhere, and nothing is lost. Everything below serves that idea.

```
  config from env/secret files   logs to stdout/stderr
              \                    /
         +--------------------------------+
         |  one process, stateless,       |  <- killable at any time
         |  fast start, clean SIGTERM     |
         +--------------------------------+
              /                    \
  data in volumes / databases   same image in dev, CI, prod
```

## The checklist

The "Lesson" column reads *section.lesson*: 4.5 = Section 4, lesson 5.

### Image (build time)

| Do | Why | Lesson |
|---|---|---|
| Pin base image versions (or digests) | Reproducible builds | 3.2 |
| Use a slim/distroless final stage via multi-stage builds | Smaller, fewer CVEs | 4.5 |
| Order Dockerfile for cache: manifests → install → source | Fast rebuilds | 4.4 |
| `.dockerignore` (`.git`, `node_modules`, `.env`) | Smaller context, no leaked secrets | 4.1 |
| No secrets in `ARG`/`ENV`/layers; use `--secret` | Images get shared | 4.3, 4.6 |
| Non-root `USER` | Limit damage if breached | 4.3, 7.1 |
| Exec-form `CMD`/`ENTRYPOINT`, handle SIGTERM or use `--init` | Clean, fast stops | 4.2 |
| `HEALTHCHECK` (or orchestrator probes) | Detect "running but broken" | 7.2 |
| OCI labels (`org.opencontainers.image.source`, `version`) | Traceability | 4.3 |
| Scan in CI (`docker scout`, `trivy`) and rebuild regularly | New CVEs appear daily | 7.1 |
| Tag with a version (and git SHA); never deploy `latest` | Know what runs; easy rollback | 3.2 |

### Runtime

| Do | Why | Lesson |
|---|---|---|
| Memory, CPU and PID limits | One container cannot sink the host | 7.3 |
| `--restart unless-stopped` (or an orchestrator) | Recover from crashes | 2.2 |
| `--read-only` + `--tmpfs` where possible | Attacker cannot modify the filesystem | 7.1 |
| `--cap-drop ALL`, add back the minimum; `no-new-privileges` | Least privilege | 7.1 |
| Never `--privileged`, never mount `docker.sock` into apps | Both equal host root | 1.4, 7.1 |
| Data in named volumes or managed databases | Containers are disposable | 5.2 |
| User-defined networks; publish only public ports | Isolation | 5.1 |
| Logs to stdout/stderr, with a log driver and rotation | `docker logs` works; disks do not fill | 8.1 |
| One main concern per container | Independent scaling and restarts | this lesson |

## See it work: before and after

Before:

```dockerfile
FROM node:latest
COPY . .
RUN npm install
ENV API_KEY=sk_live_123
CMD npm start
```

Problems: moving `latest` tag, huge base, cache-busting order, dev dependencies
and source shipped, secret baked in, root user, shell-form CMD (signals).

After:

```dockerfile
FROM node:22.11-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:22.11-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
USER node
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

Run it:

```bash
docker run -d --name api \
  -p 3000:3000 \
  --env-file /etc/api/env \
  --memory 512m --cpus 1 --pids-limit 200 \
  --read-only --tmpfs /tmp \
  --cap-drop ALL --security-opt no-new-privileges:true \
  --restart unless-stopped \
  myorg/api:1.8.0
```

`API_KEY` now comes from a file on the server (better still, a mounted secret), not the image.

## Try it

Review this command and list at least four problems:

```bash
docker run -d --privileged -v /var/run/docker.sock:/var/run/docker.sock \
  -e DB_PASSWORD=hunter2 -p 5432:5432 myorg/app:latest
```

<details>
<summary>Show answer</summary>

1. `--privileged`: disables isolation.
2. Docker socket mounted: the container controls the host.
3. Password in `-e`: visible in `inspect`; use a secret file.
4. `-p 5432:5432`: database port exposed to the network.
5. `:latest`: unknown version, no reliable rollback.
6. No memory/CPU/PID limits, no restart policy, no read-only FS, probably root.

</details>

## Common mistakes

- **Treating containers as pets**: SSH-ing in (or `docker exec`) to patch things by hand.
  Rebuild the image instead; manual changes vanish on the next deploy.
- **Several services in one container** (app + DB + cron with a supervisor).
  Split them; let Compose or an orchestrator wire them together.
- **Copying a checklist without measuring.** Check image size (`docker images`),
  CVEs (scanner) and startup time before and after.

## Remember

- Containers are disposable: config in, logs out, data elsewhere.
- Build: pinned, small, cached, no secrets, non-root, exec form, healthcheck, scanned.
- Run: limits, restart policy, read-only, dropped caps, no privileged/socket, minimal ports.
- Version tags (and digests), never `latest`, in production.

**Self-check:**

1. Name three build-time and three run-time hardening steps.
2. Why should logs go to stdout/stderr?
3. Why is "one concern per container" a good default?
