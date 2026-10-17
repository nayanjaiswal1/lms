---
kind: lesson
id_key: docker/monitoring-cleanup/troubleshooting
course: docker
section: monitoring-cleanup
section_title: Troubleshooting & Cleanup
section_position: 8
title: "Troubleshooting Playbook: The Ten Classic Failures"
position: 1
estimated_minutes: 10
source:
  - Docker Command Cheat Sheet.pdf
---

## Why this matters

Most Docker problems are the same ten problems. If you can recognise the
symptom and know the first command to run, you fix in minutes what otherwise
takes an afternoon. This is also a favourite interview topic.

## Mental model: a doctor's triage

Always the same four questions, in order. Mnemonic: **S-L-I-N**.

```
1. State    docker ps -a                      Is it running? Exit code?
2. Logs     docker logs --tail 50 NAME        What did it say before dying?
3. Inspect  docker inspect NAME (-f ...)      Config, mounts, network, OOMKilled, health
4. iNside   docker exec -it NAME sh           Look around (only if running)
            or: docker run -it --rm --entrypoint sh IMAGE   (if it will not stay up)
```

## The playbook

| # | Symptom | Likely cause | First check / fix |
|---|---|---|---|
| 1 | Container exits immediately, `Exited (0)` | Main process finished (e.g. `sh` with no TTY, a daemon that forks to background) | Run the app in the **foreground**; give a long-running CMD |
| 2 | `Exited (1)` or another small code | App error: missing env var, bad config | `docker logs`; check `-e`/`env_file` |
| 3 | "executable file not found", `Exited (127)` / `(126)` | Command not found / not executable (typo, wrong base image, missing `chmod +x`, Windows line endings in a script) | `docker run -it --entrypoint sh IMAGE` and look |
| 4 | `Exited (137)`, `OOMKilled: true` | Memory limit hit | Raise `--memory` or fix the leak; size runtime heaps below the limit |
| 5 | Restart loop (`Restarting (1) 3 seconds ago`) | Any of the above plus a restart policy | Read `docker logs` of the last attempt; `docker events` |
| 6 | Port not reachable from the host | No `-p`; ports reversed; app listens on `127.0.0.1` inside; host firewall | `docker port NAME`; inside: `netstat -tln` or `ss -tln` |
| 7 | Container cannot reach another by name | Default bridge (no DNS) or different networks | `docker network inspect NET`; put both on one user-defined network |
| 8 | `permission denied` on a volume/bind mount | Container user's UID cannot access host files | Compare `id` inside with `ls -ln` on the host; `chown` or `--user` |
| 9 | `exec format error` | Image built for another CPU architecture | `docker image inspect -f '{{.Architecture}}'`; build with `--platform` |
| 10 | `no space left on device` | Images, build cache, volumes, logs | `docker system df`; prune (next lesson); log rotation |

Two more you will meet:

- **"port is already allocated"**: another container or host process holds that
  host port. `docker ps --filter publish=8080` or `ss -ltnp | grep 8080`.
- **Pull fails with `toomanyrequests`**: Docker Hub rate limit. Log in, or use a mirror.

## See it work: three quick diagnoses

### Exited at once

```bash
docker run -d --name t1 alpine:3.20
docker ps -a --filter name=t1 --format "{{.Status}}"
```

Output: `Exited (0) 1 second ago`. Diagnosis: `sh` had nothing to do. Fix: give a
real long-running command, or use `-it` for interactive work.

### Command not found

```bash
docker run --name t2 alpine:3.20 bash
```

Output:

```
docker: Error response from daemon: failed to create task for container: ... exec: "bash": executable file not found in $PATH
```

The `docker run` command itself exits with code 127, and `docker ps -a` shows
`t2` stuck in `Created`: it never started. Alpine has `sh`, not `bash`. (When a
shell script inside the container calls a missing command, you see
`Exited (127)` instead.)

### Debug an image that will not stay up

```bash
docker run -it --rm --entrypoint sh myapp:1.0    # bypass the failing entrypoint
# inside: ls -l /app ; cat /app/start.sh ; env ; which python
```

For minimal images without a shell, borrow tools from another container that
shares the target's namespaces:

```bash
docker run -it --rm --pid container:api --network container:api busybox:1.36 sh
```

Now `ps` shows `api`'s processes and `wget localhost:8000` hits `api`'s network.

## Try it

`docker run -d -p 8080:3000 web:1.0` is `Up`, logs say `listening on
http://localhost:3000`, but `curl localhost:8080` fails with "connection reset".
Diagnose.

<details>
<summary>Show answer</summary>

Symptom 6. The app listens on `localhost` (127.0.0.1) **inside** the container,
which published traffic cannot reach. Make it listen on `0.0.0.0` (often a
`HOST=0.0.0.0` env var or a `--host 0.0.0.0` flag).

</details>

## Common mistakes

- **Restarting before reading.** `docker restart` throws away the clue. Read
  `logs`, `inspect` and `events` first.
- **Debugging inside a crash-looping container.** `exec` races the restarts. Stop
  it and run the image with `--entrypoint sh` instead.
- **Fixing things by hand inside a container.** The fix vanishes on the next
  deploy. Reproduce, then change the Dockerfile or config.

## Remember

- Triage **S-L-I-N**: State → Logs → Inspect → iNside.
- Exit codes: 0 finished, 1 app error, 126/127 command problem, 137 killed/OOM.
- Unreachable port: check `-p` order and that the app listens on `0.0.0.0`.
- Name resolution needs a shared user-defined network.
- `--entrypoint sh` and `--pid/--network container:NAME` are your debug escape hatches.

**Self-check:**

1. What are the four triage steps, in order?
2. What do exit codes 127 and 137 mean?
3. How do you debug an image whose entrypoint crashes immediately?
