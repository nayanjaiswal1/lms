---
kind: lesson
id_key: docker/container-commands/lifecycle
course: docker
section: container-commands
section_title: Running Containers
section_position: 2
title: "Container Lifecycle: Stop, Kill, Restart and Exit Codes"
position: 1
estimated_minutes: 9
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

Production containers get stopped all the time: deploys, scaling, host reboots.
If your app does not shut down cleanly, users see dropped requests and data can
be half-written. Knowing the lifecycle, the signals and the exit codes lets you
read what happened to any container.

## Mental model: a traffic light of states

```
            docker create          docker start
  (image) --------------> Created -------------> Running <---> Paused
                                                   |      pause/unpause
                         docker start / restart    |
                    +------------------------------+ main process exits,
                    |                              v docker stop, docker kill
                    +------------------------ Exited
                                                   |
                                                   | docker rm
                                                   v
                                                (gone)
```

- **Created**: exists, never started.
- **Running**: main process is alive.
- **Paused**: processes frozen (cgroup freezer), memory kept.
- **Exited**: main process ended. Files in its writable layer are **still there**.
- **Removed**: container and its writable layer are deleted.

## See it work

### Polite stop vs hard kill

```bash
docker run -d --name web nginx:1.27-alpine

# Polite: send SIGTERM, wait up to 10 s, then SIGKILL
docker stop web

# Same, but only wait 1 second before SIGKILL
docker stop -t 1 web
```

```bash
docker start web
# Immediate: send SIGKILL right away (no cleanup chance)
docker kill web
```

**Signals in plain words:**

- **SIGTERM** = "please finish up and exit". The app can close connections and save state.
- **SIGKILL** = "you are dead now". The kernel ends the process; no cleanup runs.

`docker stop` gives your app a grace period (default **10 seconds**). Good apps
handle SIGTERM and exit quickly. `docker kill` skips the grace period.

### Read the exit code

```bash
docker run --name fail alpine:3.20 sh -c "exit 3"
docker ps -a --filter name=fail --format "{{.Names}}: {{.Status}}"
```

Expected output:

```
fail: Exited (3) 2 seconds ago
```

```bash
# Or ask for just the code
docker inspect -f '{{.State.ExitCode}}' fail
```

Output: `3`.

Exit codes worth memorising:

| Code | Meaning | Typical cause |
|---|---|---|
| 0 | Success | Process finished normally |
| 1 (or other small number) | App error | Your code failed |
| 125 | Docker itself failed | Bad `docker run` flag |
| 126 | Command not executable | Missing execute permission |
| 127 | Command not found | Typo in the command, binary not in image |
| 137 | Killed by SIGKILL (128+9) | `docker kill`, or **out of memory** |
| 143 | Ended by SIGTERM (128+15) | `docker stop` and the app exited on the signal |

Mnemonic: **128 + signal number**. 137 = 128 + 9 (KILL). 143 = 128 + 15 (TERM).

### Pause, restart, wait, remove

```bash
docker pause web && docker unpause web   # freeze, then thaw
docker restart web                       # stop + start
docker wait fail                         # block until it stops, print exit code
docker rm fail                           # delete a stopped container
docker rm -f web                         # stop (SIGKILL) and delete in one go
```

### Restart policies: let Docker revive crashed containers

```bash
docker run -d --name api --restart unless-stopped nginx:1.27-alpine
```

| Policy | Restarts when... |
|---|---|
| `no` (default) | Never |
| `on-failure[:N]` | Exit code is non-zero (optionally at most N times) |
| `always` | Always. A manual `docker stop` holds until the daemon restarts, then it comes back |
| `unless-stopped` | Like `always`, but if **you** stopped it, it stays stopped even after a daemon restart |

Change it on a running container with `docker update --restart on-failure:5 api`.

## Try it

A container shows `Exited (137)`. Name two different things that could have
caused it, and one command to tell them apart.

<details>
<summary>Show answer</summary>

137 = SIGKILL. Causes: someone ran `docker kill` (or `docker stop` hit the grace
timeout), **or** the kernel's out-of-memory killer ended it. Check:

```bash
docker inspect -f '{{.State.OOMKilled}}' <name>
```

`true` means out of memory.

</details>

## Common mistakes

- **App ignores SIGTERM.** Every `docker stop` then waits the full 10 seconds and
  ends in SIGKILL (exit 137). Usually caused by running the app via a shell
  wrapper that does not forward signals (Section 4 explains exec form).
- **Thinking an exited container is gone.** It still holds its files and its
  name. `docker ps -a` shows it; `docker rm` deletes it.
- **Using `--restart always` to hide a crash loop.** A container restarting every
  2 seconds is a bug to fix, not a feature. Check `docker logs`.

## Remember

- States: Created → Running ⇄ Paused → Exited → Removed.
- `stop` = SIGTERM, grace period (10 s), then SIGKILL. `kill` = SIGKILL now.
- Exit code above 128 = killed by signal (code − 128). 137 = KILL/OOM, 143 = TERM.
- Restart policies: `no`, `on-failure`, `always`, `unless-stopped`.

**Self-check:**

1. What is the difference between `docker stop` and `docker kill`?
2. What does exit code 143 tell you?
3. Which restart policy keeps a container down after you stop it by hand?
