---
kind: lesson
id_key: docker/container-commands/look-inside
course: docker
section: container-commands
section_title: Running Containers
section_position: 2
title: "Looking Inside: ps, logs, exec, inspect"
position: 2
estimated_minutes: 9
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

A container is a black box until you learn to open it. Four commands answer
almost every "what is going on in there?" question. They are also step one of
every debugging session in Section 8.

## Mental model: four questions, four commands

| Question | Command | Analogy |
|---|---|---|
| **Which** containers exist? | `docker ps` | The building directory |
| What did it **say**? | `docker logs` | Reading its diary |
| Let me **go in** and look | `docker exec` | Walking into the apartment |
| What is its exact **config**? | `docker inspect` | The building's blueprint file |

Mnemonic: **P-L-E-I** ("please"): **P**s, **L**ogs, **E**xec, **I**nspect.

## See it work

Start something to look at:

```bash
docker run -d --name myserver nginx:1.27-alpine
```

### ps: which containers exist

```bash
docker ps                 # running only
docker ps -a              # running AND stopped
docker ps -q              # only IDs (handy in scripts)
docker ps --filter "status=exited"   # filter by state
```

### logs: what the main process printed

Docker captures everything the main process writes to **stdout** and **stderr**.

```bash
docker logs myserver             # everything so far
docker logs -f myserver          # follow live, like tail -f (Ctrl+C to stop)
docker logs --tail 20 myserver   # last 20 lines
docker logs --since 5m myserver  # last 5 minutes
```

Expected output: nginx startup lines such as
`/docker-entrypoint.sh: Configuration complete; ready for start up`.

If your app writes logs only to a **file** inside the container, `docker logs`
shows nothing. Apps in containers should log to stdout/stderr.

### exec: run a new command inside a running container

```bash
# Open a shell inside the running container
docker exec -it myserver sh

# Or run a single command and return
docker exec myserver cat /etc/nginx/conf.d/default.conf
```

`exec` starts an **extra** process next to the main one. Exiting that shell does
not stop the container. Compare with `docker attach myserver`, which connects
your terminal to the **main** process: pressing Ctrl+C there can stop the
container. Prefer `exec`.

### inspect: the full truth, as JSON

```bash
docker inspect myserver                                    # everything
docker inspect -f '{{.State.Status}}' myserver             # one field
docker inspect -f '{{.NetworkSettings.IPAddress}}' myserver
docker inspect -f '{{json .Config.Env}}' myserver          # env vars as JSON
```

Expected output of the first `-f`: `running`. The `-f` flag takes a **Go
template**: dot-separated paths into the JSON.

### More windows into a container

```bash
docker top myserver                 # processes inside it
docker stats --no-stream myserver   # CPU, memory, network right now
docker diff myserver                # files changed vs the image (A=added, C=changed, D=deleted)
docker cp myserver:/etc/nginx/nginx.conf ./nginx.conf   # copy out
docker cp ./index.html myserver:/usr/share/nginx/html/  # copy in
```

## Try it

A container named `api` keeps restarting. Which two P-L-E-I commands do you
run first, and what are you looking for in each?

<details>
<summary>Show answer</summary>

1. `docker ps -a` (or `docker inspect -f '{{.State.ExitCode}} {{.State.OOMKilled}}' api`):
   confirm the state and the **exit code** (for example 1 = app error, 137 = killed/OOM).
2. `docker logs --tail 50 api`: read the **error message** the app printed just before dying.

`exec` is useless here: you cannot enter a container that is not running.

</details>

## Common mistakes

- **Trying `exec` on a stopped container.** It fails with *"container ... is not
  running"*. Read `logs` instead, or start a debug copy with
  `docker run -it --entrypoint sh IMAGE`.
- **Using `attach` and pressing Ctrl+C.** That signals the main process and may
  stop your production container. Use `exec`.
- **Scrolling raw `inspect` output by eye.** Use `-f` templates, or pipe to `jq`.
- **Expecting `docker logs` to show file logs.** It only captures stdout/stderr.

## Remember

- **P-L-E-I**: `ps` (which), `logs` (what it said), `exec` (go in), `inspect` (exact config).
- `exec` adds a process; exiting it leaves the container running.
- `logs` = stdout/stderr of the main process only.
- `inspect -f '{{.Path.To.Field}}'` extracts one value.

**Self-check:**

1. Which command shows a container's environment variables?
2. Why is `docker exec` safer than `docker attach`?
3. What does `docker diff` show?
