---
kind: lesson
id_key: docker/image-commands/names-tags-digests
course: docker
section: image-commands
section_title: Images & Layers
section_position: 3
title: "Image Names, Tags and Digests"
position: 1
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

`nginx`, `nginx:latest`, `docker.io/library/nginx:1.27` and
`nginx@sha256:...` can all point to the same image, or to different ones next
week. Production outages have been caused by `latest` silently changing.
Reading an image name correctly tells you exactly what you will get.

## Mental model: a postal address

```
  ghcr.io / acme / shop-api : 2.4.1 @ sha256:9f1c...
  \_____/   \__/   \______/   \___/   \__________/
  registry  namespace  repo   tag      digest
  (city)    (street)  (house) (sticky  (GPS coordinates:
                              note)     exact and permanent)
```

- **Registry**: the server. Default when omitted: `docker.io` (Docker Hub).
- **Namespace**: a user or organisation. Official Hub images use `library`.
- **Repository**: the image name.
- **Tag**: a **movable** label, like a sticky note. Default when omitted: `latest`.
- **Digest**: `sha256:` hash of the image's content. **Immutable**: same digest,
  same bytes, forever.

So `nginx` expands to `docker.io/library/nginx:latest`.

> **Tags move, digests don't.** A tag is a pointer someone can re-point; a digest
> is a fingerprint of the content.

`latest` is just the default tag **name**. It does not mean "newest". It means
"whatever was last pushed with the tag `latest`", or nothing at all if the
maintainers never use it.

## See it work

### List and tag

```bash
docker images
```

Expected output (shortened):

```
REPOSITORY   TAG           IMAGE ID       CREATED        SIZE
nginx        1.27-alpine   6769dc3a703c   18 months ago  48.2MB
alpine       3.20          bf8527eb54c3   6 months ago   7.81MB
```

```bash
# Add a second name for the same image (no copy is made)
docker tag alpine:3.20 myorg/base:v1
docker images | grep -E "alpine|myorg"
```

Both lines show the **same IMAGE ID**. A tag is just another pointer.

```bash
# Remove one name; the image stays while another name points to it
docker rmi myorg/base:v1
```

Output: `Untagged: myorg/base:v1`. No layers are deleted, because `alpine:3.20`
still points at the image.

### See and use digests

```bash
docker images --digests alpine
docker inspect -f '{{index .RepoDigests 0}}' alpine:3.20
```

Output looks like `alpine@sha256:` followed by 64 hex characters. (An image
built locally and never pushed or pulled has no repo digest yet, so this prints an error.)

Pin by digest for reproducible builds and deploys:

```bash
docker pull alpine@sha256:<digest-from-above>
```

```dockerfile
FROM alpine:3.20@sha256:<digest>   # human-readable tag + exact content
```

### Dangling images

When you rebuild `myapp:dev`, the tag moves to the new image. The old image
loses its name and shows up as `<none>:<none>`. That is a **dangling** image.

```bash
docker images -f dangling=true   # list them
docker image prune               # delete them
```

## Try it

Your Dockerfile says `FROM python:3.12`. Last month's build and today's build
behave differently even though you changed nothing. Explain why, and give two
ways to make the build reproducible.

<details>
<summary>Show answer</summary>

`3.12` is a tag; maintainers re-point it on every patch release and OS update,
so "the same" tag gave you different content. Fixes:

1. Pin a more specific tag (`python:3.12.11-slim-bookworm`), which moves less often.
2. Pin the digest (`python:3.12-slim@sha256:...`), which never moves. Use a bot
   (Renovate/Dependabot) to bump it on purpose.

</details>

## Common mistakes

- **Deploying `:latest` to production.** You cannot tell which version runs, and
  rollbacks are guesswork. Use explicit version tags or digests.
- **Assuming `docker rmi` frees space.** It only removes a **tag** if other tags
  still point to the image. Layers go when the last reference goes.
- **Re-pushing the same tag with different content** (for example `v1.0`), then
  wondering why servers disagree. Treat release tags as immutable; many registries can enforce it.

## Remember

- Full name: `registry/namespace/repo:tag@digest`. Defaults: `docker.io`, `library`, `latest`.
- Tags are movable pointers; digests are immutable content hashes.
- `latest` means "default tag name", not "newest".
- `docker tag` adds a name (no copy). `docker rmi` removes a name; data goes with the last name.
- `<none>:<none>` = dangling; `docker image prune` cleans them.

**Self-check:**

1. Expand `redis` into its full image reference.
2. Why is a digest safer than a tag for production?
3. What creates a dangling image?
