---
kind: lesson
id_key: docker/production/lab-production-image
course: docker
section: production
section_title: Production-Ready Containers
section_position: 7
title: "Lab: Build and Run a Hardened Image"
position: 4
estimated_minutes: 25
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 40
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: build-multistage-nonroot
      title: Build a multi-stage, non-root image with a healthcheck
      points: 15
      is_stateful: true
      description: Write the Dockerfile shown above to ~/work/prod/Dockerfile and build it as webapp:1.0. The image must come from a multi-stage build whose final stage is busybox (no apk), run as user 1000, and define a HEALTHCHECK.
      verification_script: |
        docker image inspect webapp:1.0 >/dev/null 2>&1 \
          && test "$(docker image inspect -f '{{.Config.User}}' webapp:1.0)" = "1000:1000" \
          && test -n "$(docker image inspect -f '{{if .Config.Healthcheck}}yes{{end}}' webapp:1.0)" \
          && ! docker run --rm --network host --entrypoint sh webapp:1.0 -c 'test -e /sbin/apk' \
          && docker run --rm --network host --entrypoint cat webapp:1.0 /www/index.html | grep -q "multi-stage ok"
      hint_context: cd ~/work/prod and run docker build --network=host -t webapp:1.0 . — the first stage (FROM alpine:3.20 AS build) writes /out/index.html, and the final stage (FROM busybox:1.36) copies it with COPY --from=build /out /www, then sets USER 1000:1000 and a HEALTHCHECK.
      explanation_context: Only the final stage ships. The alpine build stage (with apk) is thrown away; the busybox runtime gets just the one file it needs. USER makes the server run unprivileged, and HEALTHCHECK records how Docker should probe it, all baked into the image config you can read with docker image inspect.
      solution_script: |
        mkdir -p /home/labuser/work/prod && cd /home/labuser/work/prod
        cat > Dockerfile <<'EOF'
        FROM alpine:3.20 AS build
        RUN mkdir -p /out && echo "<h1>multi-stage ok</h1>" > /out/index.html

        FROM busybox:1.36
        COPY --from=build /out /www
        USER 1000:1000
        EXPOSE 8080
        HEALTHCHECK --interval=5s --timeout=3s --start-period=2s --retries=3 CMD wget -qO- http://127.0.0.1:8080/ || exit 1
        CMD ["httpd", "-f", "-p", "8080", "-h", "/www"]
        EOF
        docker build --network=host -t webapp:1.0 .
    - id_key: run-limited-healthy
      title: Run it with resource limits until it reports healthy
      points: 15
      description: Run webapp:1.0 as a container named "webapp" (with --network host) limited to 64 MB of memory and half a CPU, read-only root filesystem, and wait until docker reports it healthy.
      verification_script: |
        # A daemon without cgroup memory/CPU support (some rootless setups) discards
        # limits with a warning, so only check the limits it can actually enforce.
        test "$(docker inspect -f '{{.State.Health.Status}}' webapp 2>/dev/null)" = healthy \
          && test "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' webapp)" = true \
          && { [ "$(docker info -f '{{.MemoryLimit}}')" != true ] || test "$(docker inspect -f '{{.HostConfig.Memory}}' webapp)" = 67108864; } \
          && { [ "$(docker info -f '{{.CPUCfsQuota}}')" != true ] || test "$(docker inspect -f '{{.HostConfig.NanoCpus}}' webapp)" = 500000000; }
      hint_context: docker run -d --name webapp --network host --memory 64m --cpus 0.5 --read-only webapp:1.0, then watch docker ps until the STATUS column shows (healthy) — the healthcheck runs every 5 seconds.
      explanation_context: --memory and --cpus become cgroup limits (stored in HostConfig as bytes and billionths of a CPU), --read-only makes the root filesystem immutable, and the HEALTHCHECK from the image turns "running" into "healthy" once wget gets a page back.
      solution_script: |
        docker run -d --name webapp --network host --memory 64m --cpus 0.5 --read-only webapp:1.0
        sleep 8
---

## Why this matters

This lab combines the whole section into one image and one `docker run`: a
multi-stage build, a non-root user, a healthcheck, resource limits and a
read-only filesystem. It is the shape of a real production container, at toy size.

## Sandbox note

As in every lab here, containers use `--network host` and the build uses
`--network=host`. Everything else is exactly what you would type on a server.

## The Dockerfile

```dockerfile
# ---- build stage: has apk and a full toolset; thrown away ----
FROM alpine:3.20 AS build
RUN mkdir -p /out && echo "<h1>multi-stage ok</h1>" > /out/index.html

# ---- runtime stage: tiny busybox, only the built file ----
FROM busybox:1.36
COPY --from=build /out /www
# run unprivileged
USER 1000:1000
# >1024, so no root needed to bind
EXPOSE 8080
HEALTHCHECK --interval=5s --timeout=3s --start-period=2s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ || exit 1
# exec form, foreground
CMD ["httpd", "-f", "-p", "8080", "-h", "/www"]
```

## Task 1: build it

```bash
mkdir -p ~/work/prod && cd ~/work/prod
# write the Dockerfile above (cat > Dockerfile <<'EOF' ... EOF)
docker build --network=host -t webapp:1.0 .

docker images webapp                                   # a few MB
docker image inspect -f '{{.Config.User}}' webapp:1.0  # 1000:1000
docker history webapp:1.0                              # no apk/alpine layers on top of busybox
```

[[lab-task:1]]

## Task 2: run it hardened and limited

```bash
docker run -d --name webapp --network host \
  --memory 64m --cpus 0.5 \
  --read-only \
  webapp:1.0

docker ps --filter name=webapp     # STATUS: Up ... (health: starting), then (healthy)
docker stats --no-stream webapp    # MEM USAGE / LIMIT shows 64MiB
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8080
```

Expected output of the last command:

```
<h1>multi-stage ok</h1>
```

If `docker run` prints a warning like *"Your kernel does not support memory
limit capabilities ... Limitation discarded"*, the daemon you are talking to
(some rootless setups) has no cgroup control over memory or CPU, so it ignored
that limit. The check accepts that; on a normal Linux server the limits apply.

Extra credit (not graded): run a second copy with `--cap-drop ALL
--security-opt no-new-privileges:true` on another port and confirm it still serves.

[[lab-task:2]]

## Remember

- Multi-stage + non-root + healthcheck are image properties: check them with `docker image inspect`.
- Limits and read-only are run-time properties: check them in `docker inspect` under `HostConfig`.
- `(healthy)` in `docker ps` is the goal, not just `Up`.
