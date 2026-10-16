---
kind: lesson
id_key: docker/dockerfile/more-instructions
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "ENV, ARG, USER, COPY vs ADD and the Other Instructions"
position: 2
estimated_minutes: 9
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

You know the five core instructions. The rest fall into three groups: settings
(`ENV`, `ARG`, `LABEL`), safety (`USER`), and a few you will mostly read in
other people's Dockerfiles. Knowing which is which keeps you from leaking
secrets into images or running everything as root.

## Mental model: three groups

```
Build-time knobs    ARG                  (gone once the image is built*)
Runtime settings    ENV, USER, WORKDIR,  (baked into the image, apply to containers)
                    EXPOSE, VOLUME, STOPSIGNAL, HEALTHCHECK
Documentation       LABEL, EXPOSE        (metadata only)
                                         * but values can still leak into layers
```

### ENV vs ARG

| | `ARG` | `ENV` |
|---|---|---|
| Available during build | Yes | Yes |
| Available in running containers | **No** | **Yes** |
| Set from the CLI | `docker build --build-arg NAME=value` | `docker run -e NAME=value` (overrides) |
| Typical use | Versions to build with | App configuration defaults |

```dockerfile
ARG PY_VERSION=3.12               # ARG before FROM can parameterise the base image
FROM python:${PY_VERSION}-slim

ARG APP_VERSION=dev               # ARG after FROM: usable in the following RUN steps
ENV APP_ENV=production \
    PORT=8000                     # baked in; containers see these
LABEL org.opencontainers.image.version=$APP_VERSION
```

**Never pass secrets with `ARG` or `ENV`.** Both end up readable in
`docker history` or `docker inspect`. Use BuildKit secret mounts (lesson 6).

### COPY vs ADD

| | `COPY` | `ADD` |
|---|---|---|
| Copy local files | Yes | Yes |
| Auto-extract a local `.tar.gz` | No | **Yes** |
| Download from a URL | No | **Yes** (or a Git repo) |

Rule: **use `COPY`**. Reach for `ADD` only when you *want* auto-extraction or a
remote source, because its magic surprises people. Both accept `--chown=user:group`.

### USER: stop running as root

By default containers run as **root** (UID 0). If an attacker breaks your app,
they are root inside the container, one kernel bug away from the host.

```dockerfile
RUN addgroup -S app && adduser -S -G app app   # Alpine syntax
# Debian/Ubuntu: RUN groupadd -r app && useradd -r -g app app
COPY --chown=app:app . /app
USER app                                     # everything after, and the container, runs as app
```

Put `USER` **after** steps that need root (package installs), and before `CMD`.

### The rest, briefly

| Instruction | What it does |
|---|---|
| `LABEL key=value` | Metadata (owner, version, source URL). Prefer `org.opencontainers.image.*` keys |
| `EXPOSE 8000` | Documents the listening port; `-P` publishes it. Does not open anything |
| `VOLUME /data` | Marks a path as external data; Docker creates an anonymous volume there at run time |
| `STOPSIGNAL SIGQUIT` | Signal `docker stop` sends instead of SIGTERM |
| `HEALTHCHECK CMD ...` | How Docker checks the app is healthy (Section 7) |
| `SHELL ["bash", "-c"]` | Change the shell used by shell-form `RUN` |
| `ONBUILD RUN ...` | Instruction stored for a *child* image that uses this one as `FROM` (rare, confusing; avoid) |
| `MAINTAINER name` | **Deprecated.** Use `LABEL org.opencontainers.image.authors="..."` |

## See it work

```dockerfile
FROM alpine:3.20
ARG BUILD_NOTE=none
ENV GREETING=hello
RUN echo "built with note: $BUILD_NOTE" > /build.txt
RUN adduser -S -D app
USER app
CMD ["sh", "-c", "echo $GREETING from $(whoami); cat /build.txt; echo note=$BUILD_NOTE"]
```

```bash
docker build -t settings --build-arg BUILD_NOTE=ci-42 .
docker run --rm settings
docker run --rm -e GREETING=hi settings
```

Expected output:

```
hello from app
built with note: ci-42
note=
hi from app
built with note: ci-42
note=
```

Notice: `BUILD_NOTE` was used during the build (it is in `/build.txt`), but
the running container has no `BUILD_NOTE` variable. `GREETING` exists at run
time and `-e` overrides it.

## Try it

Your teammate wants to pass an npm token during the build with
`ARG NPM_TOKEN` and `RUN npm install`. What is the risk, and what should they do?

<details>
<summary>Show answer</summary>

Build args are recorded in the image history (`docker history --no-trunc` shows
them on the `RUN` lines that used them), so anyone who pulls the image can read
the token. Use a BuildKit secret mount instead:
`RUN --mount=type=secret,id=npm,env=NPM_TOKEN npm install` with
`docker build --secret id=npm,env=NPM_TOKEN .` (lesson 6).

</details>

## Common mistakes

- **Secrets in `ARG`/`ENV`.** Visible to anyone with the image.
- **Forgetting `USER`.** The app runs as root by default.
- **`USER app` too early**, then `RUN apk add ...` fails with permission denied.
- **Using `ADD` for plain files.** Works, but hides intent; reviewers expect `COPY`.

## Remember

- `ARG` = build-time only. `ENV` = baked in, visible to containers.
- Never put secrets in `ARG` or `ENV`.
- Prefer `COPY`; `ADD` also extracts tarballs and fetches URLs.
- Add a non-root `USER` after installs, before `CMD`.
- `EXPOSE` and `LABEL` are documentation; `MAINTAINER` is deprecated.

**Self-check:**

1. Which of `ARG` and `ENV` is visible inside a running container?
2. Name two things `ADD` does that `COPY` does not.
3. Where in a Dockerfile should `USER` go, and why?
