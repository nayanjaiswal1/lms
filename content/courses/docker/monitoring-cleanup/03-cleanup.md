---
kind: lesson
id_key: docker/monitoring-cleanup/cleanup
course: docker
section: monitoring-cleanup
section_title: Troubleshooting & Cleanup
section_position: 8
title: "Disk Usage and Cleanup: system df and prune"
position: 2
estimated_minutes: 7
source:
  - Docker Command Cheat Sheet.pdf
---

## Why this matters

Docker never deletes anything on its own. Old images, stopped containers,
anonymous volumes and build cache pile up until a CI runner or laptop reports
*"no space left on device"*. Cleaning up is easy, but one wrong flag deletes a
database. Know exactly what each prune removes.

## Mental model: clearing out a garage

- **Measure first** (`docker system df`): what is taking the space?
- **Throw out junk** (`prune`): things nobody uses any more.
- **Never throw out the family photos** (volumes with real data) by accident.

What counts as junk:

| Thing | "Unused" means |
|---|---|
| Container | Stopped |
| Image | **Dangling** (`<none>` tag), or with `-a`: not used by any container |
| Volume | Not mounted by any container (running **or stopped**) |
| Network | No containers attached |
| Build cache | Not needed by... anything right now (it is a cache) |

## See it work

### Measure

```bash
docker system df
```

Expected output (values vary):

```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          14        3         3.21GB    2.48GB (77%)
Containers      9         2         120MB     98MB (81%)
Local Volumes   6         2         1.9GB     1.1GB (57%)
Build Cache     88        0         2.75GB    2.75GB
```

`docker system df -v` lists every item.

### Prune by type

```bash
docker container prune     # remove all stopped containers
docker image prune         # remove dangling images
docker image prune -a      # remove ALL images not used by any container
docker volume prune        # remove unused volumes (on current engines: anonymous ones only; add -a for named)
docker network prune       # remove unused networks
docker builder prune       # remove build cache
```

Each asks for confirmation; `-f` skips it (scripts), `--filter "until=24h"` keeps recent items.

### Prune everything unused at once

```bash
docker system prune                 # stopped containers, unused networks, dangling images, build cache
docker system prune -a              # ...and every image not used by a container
docker system prune --volumes       # ...and unused anonymous volumes too
```

`docker system prune` skips anything a **running** container still references,
so it is safe to run routinely without checking `docker ps` first. Volumes are
**not** touched unless you add `--volumes`.

```knowledge-check
{
  "questions": [
    {
      "id": "docker-monitoring-prune-q1",
      "type": "mcq",
      "prompt": "Is it safe to run plain docker system prune without first checking docker ps?",
      "options": [
        { "id": "a", "text": "No, it can delete a running container" },
        { "id": "b", "text": "Yes, it only removes resources not associated with a running container" },
        { "id": "c", "text": "Only if --volumes is omitted" },
        { "id": "d", "text": "Only on a freshly restarted daemon" }
      ],
      "correct": "b",
      "explanation": "docker system prune skips anything a running container still references. Whatever it removes was already stopped, dangling or unused, so it's safe to run routinely."
    },
    {
      "id": "docker-monitoring-prune-q2",
      "type": "mcq",
      "prompt": "What does adding -a to docker system prune change?",
      "options": [
        { "id": "a", "text": "It also stops running containers first" },
        { "id": "b", "text": "It also removes images not referenced by any container, running or not" },
        { "id": "c", "text": "It also removes named volumes" },
        { "id": "d", "text": "It runs the prune faster" }
      ],
      "correct": "b",
      "explanation": "Plain prune only touches dangling (untagged) images. -a widens that to every image not currently used by any container. --volumes is the separate flag that additionally reclaims unused volumes."
    }
  ]
}
```

### Do not forget the logs

`docker system df` does not show container log files. If `/var/lib/docker`
is still huge, check them:

```bash
sudo du -sh /var/lib/docker/containers/*/*-json.log | sort -h | tail
```

Fix the cause with log rotation (lesson 1), not by deleting files under a running container.

## Try it

A CI runner is out of disk. It runs only builds, no long-lived services, and
no data needs to survive. Which single command frees the most space? What would
you run instead on a developer laptop with a local database volume?

<details>
<summary>Show answer</summary>

CI runner: `docker system prune -a --volumes -f` (everything unused, including
build cache and volumes), ideally on a schedule.

Laptop: `docker system prune -a` (no `--volumes`), so the database volume stays.
Check `docker volume ls` and remove specific volumes by name if needed.

</details>

## Common mistakes

- **`--volumes` (or `docker compose down -v`) on a machine with real data.** Gone for good.
- **Thinking `docker rmi` freed space** when another tag or a stopped container still uses the image.
- **Forgetting build cache.** On build machines it is often the biggest item: `docker builder prune`.
- **Deleting files in `/var/lib/docker` by hand.** It corrupts Docker's state. Use the CLI.

## Remember

- Measure with `docker system df` (`-v` for detail).
- `container/image/volume/network/builder prune` clean one type; `system prune` cleans them together.
- `-a` = also unused (not just dangling) images. `--volumes` = also volumes. Both are opt-in.
- Running containers' resources are never pruned.
- Log files are separate: rotate them.

**Self-check:**

1. What is a dangling image?
2. Which flag makes `docker system prune` remove volumes?
3. Why is build cache often the largest item on CI machines?
