---
kind: lesson
id_key: docker/production/security
course: docker
section: production
section_title: Production-Ready Containers
section_position: 7
title: "Container Security: Least Privilege, Rootless and Scanning"
position: 0
estimated_minutes: 10
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

Containers share the host kernel (Section 1). A container running as root, with
every capability and a writable filesystem, gives an attacker who breaks your
app a very short path to the host. A handful of defaults closes most of that path.

## Mental model: layers of a castle

No single wall stops every attack. You stack defences so a breach of one does
not mean a breach of all.

```
  [ 1. small, scanned, pinned image     ]  less to attack
  [ 2. non-root USER                    ]  attacker is not root
  [ 3. drop capabilities, no-new-privs  ]  root powers removed anyway
  [ 4. read-only filesystem             ]  cannot drop tools or modify code
  [ 5. secrets not in image or env      ]  nothing to steal from layers
  [ 6. rootless daemon / userns         ]  even container-root is a normal host user
```

Terms:

- **Capabilities**: Linux splits root's powers into ~40 pieces (`NET_BIND_SERVICE`,
  `CHOWN`, `SYS_ADMIN`, ...). Docker gives containers a reduced default set; you can drop more.
- **no-new-privileges**: stops a process from gaining privileges via setuid binaries (like `sudo`).
- **Rootless mode**: the Docker daemon and containers run as an ordinary user, so
  "root in the container" maps to an unprivileged user on the host.

## See it work

### 1. Run as a non-root user

In the Dockerfile (Section 4):

```dockerfile
RUN addgroup -S app && adduser -S -G app app
USER app
```

Or at run time, for images that support it:

```bash
docker run --rm -u 10001:10001 alpine:3.20 id
```

Output: `uid=10001 gid=10001 groups=10001`.

### 2. Drop capabilities and block privilege escalation

```bash
docker run -d --name web \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  --security-opt no-new-privileges:true \
  nginx:1.27-alpine
```

- `--cap-drop ALL` removes every capability.
- `--cap-add NET_BIND_SERVICE` gives back only "bind ports below 1024".
- (Some images need a few more, such as `CHOWN`, `SETUID`, `SETGID` for nginx's
  worker processes; add exactly what the logs say is missing.)

Never use `--privileged` for an app: it disables nearly all isolation.

### 3. Read-only root filesystem

```bash
docker run --rm --read-only --tmpfs /tmp alpine:3.20 sh -c 'touch /tmp/ok && echo tmp-ok; touch /etc/x'
```

Expected output:

```
tmp-ok
touch: /etc/x: Read-only file system
```

The app can write only where you allow it: `--tmpfs` for scratch space, volumes for data.

### 4. Keep secrets out of images and env vars

| Where | Safe? |
|---|---|
| `ENV`/`ARG` in a Dockerfile, `COPY .env` | No: anyone with the image can read it |
| `docker run -e PASSWORD=...` | Weak: visible in `docker inspect` and to child processes |
| Mounted secret file (`-v ./secret:/run/secrets/db:ro`, Compose/Swarm `secrets:`, Kubernetes Secrets) | Better |
| Build-time: `RUN --mount=type=secret` | Yes, for builds |

### 5. Scan and pin images

```bash
docker scout cves myimage:1.0        # Docker Scout: known vulnerabilities (CVEs)
trivy image myimage:1.0              # Trivy: a popular open-source alternative
```

Pin base images by version or digest, rebuild regularly (`--pull`) to pick up
patches, and prefer minimal bases (slim, distroless) so there is less to patch.

### 6. Protect the daemon

- Never mount `/var/run/docker.sock` into an app container: that is root on the host.
- The `docker` group is root-equivalent; keep it small.
- Consider **rootless Docker** (`dockerd-rootless-setuptool.sh install`) or
  user-namespace remapping (`userns-remap` in `daemon.json`) on shared hosts.

## Try it

Harden this command as far as you can without breaking a typical app that
listens on port 8080 and writes temp files to `/tmp`:

```bash
docker run -d -p 8080:8080 myapp:1.0
```

<details>
<summary>Show answer</summary>

```bash
docker run -d -p 8080:8080 \
  -u 10001:10001 \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --read-only --tmpfs /tmp \
  --memory 512m --pids-limit 200 \
  myapp:1.0@sha256:<pinned digest>
```

Port 8080 is above 1024, so no `NET_BIND_SERVICE` is needed. Resource limits
(lesson 3) also stop one container from starving the host.

</details>

## Common mistakes

- **`--privileged` "to make it work".** Find the one capability or device it actually needs.
- **Running as root because the base image does.** Add `USER`.
- **Secrets baked into images** (`COPY .env`, `ENV API_KEY=`). Rotate them; they are public now.
- **Scanning once.** New CVEs appear daily against old images; scan in CI and rebuild.

## Remember

- Defence in depth: small scanned image, non-root, drop caps, no-new-privileges, read-only FS, secrets as files.
- `--cap-drop ALL` + add back only what is needed. Never `--privileged`.
- `--read-only` + `--tmpfs /tmp` + volumes for real data.
- Docker socket access = host root. Rootless mode reduces the blast radius.
- Scan (`docker scout`, `trivy`), pin, and rebuild often.

**Self-check:**

1. What does `--cap-drop ALL --cap-add NET_BIND_SERVICE` allow?
2. Why is `-e DB_PASSWORD=...` weaker than a mounted secret file?
3. What does rootless mode change about "root inside the container"?
