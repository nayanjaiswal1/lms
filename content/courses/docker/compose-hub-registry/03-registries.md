---
kind: lesson
id_key: docker/compose-hub-registry/registries
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: "Registries: Docker Hub, Private Registries and Logins"
position: 2
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

Your CI builds an image; your servers must pull it. In between sits a
**registry**. Choosing one, logging in safely and naming images so they land in
the right place is daily work, and a broken login is a classic deploy failure.

## Mental model: a library with branches

A registry is a library. **Docker Hub** is the big public central branch.
Companies run **private branches** (GitHub Container Registry, AWS ECR, Google
Artifact Registry, Azure ACR, Harbor, or a self-hosted `registry:2`). The
**first part of the image name** tells Docker which branch to go to.

```
nginx:1.27                          -> docker.io (Docker Hub), library/nginx
myuser/api:1.0                      -> docker.io, namespace myuser
ghcr.io/acme/api:1.0                -> GitHub Container Registry
123456789012.dkr.ecr.eu-west-1.amazonaws.com/api:1.0  -> AWS ECR
localhost:5000/api:1.0              -> a registry on this machine, port 5000
```

Rule: **if the first part contains a `.` or a `:` (or is `localhost`), it is a registry host.**
Otherwise Docker assumes Docker Hub.

## See it work

### Docker Hub

```bash
docker login -u myuser                       # prompts for a password or access token
docker tag myimage:latest myuser/myimage:1.0 # name it for your namespace
docker push myuser/myimage:1.0
docker search nginx                          # search Hub from the CLI
docker logout
```

Expected end of `push` output:

```
1.0: digest: sha256:... size: 1234
```

### Any other registry

Same three steps, with the host in front:

```bash
docker login ghcr.io -u my-github-user       # token with write:packages scope
docker tag myimage:latest ghcr.io/acme/myimage:1.0
docker push ghcr.io/acme/myimage:1.0
```

### Run your own registry

```bash
docker run -d --name registry -p 5000:5000 registry:2
docker tag alpine:3.20 localhost:5000/alpine:3.20
docker push localhost:5000/alpine:3.20
```

Docker allows plain HTTP only for `localhost`. Any other host must use HTTPS
(or be listed in the daemon's `insecure-registries`, which you should avoid).

### Where credentials live

`docker login` stores credentials in `~/.docker/config.json`, or better, in your
OS keychain through a **credential helper** (`credsStore`). In CI, log in
non-interactively and never echo the token:

```bash
echo "$REGISTRY_TOKEN" | docker login ghcr.io -u ci-bot --password-stdin
```

### Things to know about Docker Hub

- **Pull rate limits**: anonymous pulls are limited per IP; authenticated pulls
  get more. Busy CI farms should log in or use a pull-through cache/mirror.
- **Official images** (`library/...`) and **Verified Publisher** images are
  maintained and scanned; random user images are not.
- Use **access tokens**, not your account password, for CLI and CI logins.

## Try it

You built `api:2.1` locally. Write the commands to push it to
`registry.example.com` under the `payments` namespace, logged in as user `ci`.

<details>
<summary>Show answer</summary>

```bash
docker login registry.example.com -u ci
docker tag api:2.1 registry.example.com/payments/api:2.1
docker push registry.example.com/payments/api:2.1
```

</details>

## Common mistakes

- **Forgetting the host prefix.** `docker push payments/api:2.1` goes to Docker Hub.
- **"denied: requested access to the resource is denied".** Not logged in, wrong
  namespace, or a token without push permission.
- **Passwords on the command line** (`-p secret`): saved in shell history and
  visible in `ps`. Use `--password-stdin`.
- **Pulling random public images into production.** Prefer official or verified
  images, pin digests, and scan them (Section 7).

## Remember

- The first part of an image name selects the registry; no host means Docker Hub.
- Push flow: `login` → `tag` with host/namespace → `push`.
- Plain HTTP is allowed only for `localhost` registries.
- Use access tokens, `--password-stdin` and credential helpers.
- Docker Hub rate-limits anonymous pulls.

**Self-check:**

1. Which registry does `myteam/web:3` go to? And `ghcr.io/myteam/web:3`?
2. Why use `--password-stdin` in CI?
3. What does a registry store that lets an ARM and an Intel server pull the same tag?
