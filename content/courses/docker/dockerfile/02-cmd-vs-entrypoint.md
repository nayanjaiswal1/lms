---
kind: lesson
id_key: docker/dockerfile/cmd-entrypoint
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "CMD vs ENTRYPOINT, Shell Form vs Exec Form"
position: 1
estimated_minutes: 9
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

This is the most-asked Dockerfile interview question, and it causes a real
production bug: containers that ignore `docker stop` and get killed after
10 seconds. Two small rules prevent both the confusion and the bug.

## Mental model: the program and its default arguments

- **ENTRYPOINT** = the **program** the container always runs.
- **CMD** = the **default arguments** (or, without ENTRYPOINT, the default command).
- Anything you type after the image name in `docker run` **replaces CMD**.

```
final command  =  ENTRYPOINT  +  (docker run args  OR  CMD)
```

| Dockerfile | `docker run img` runs | `docker run img --help` runs |
|---|---|---|
| `CMD ["curl", "-s", "example.com"]` | `curl -s example.com` | `--help` (fails: not a command) |
| `ENTRYPOINT ["curl", "-s"]` + `CMD ["example.com"]` | `curl -s example.com` | `curl -s --help` |

Rule 1: **ENTRYPOINT for "this image *is* a tool", CMD for sensible defaults.**
To replace the ENTRYPOINT itself, use `docker run --entrypoint`.

## Shell form vs exec form

Both instructions can be written two ways:

```dockerfile
CMD python app.py            # shell form
CMD ["python", "app.py"]     # exec form (a JSON array)
```

| | Shell form | Exec form |
|---|---|---|
| Actually runs | `/bin/sh -c "python app.py"` | `python app.py` directly |
| PID 1 is | `sh` | `python` (your app) |
| `docker stop` SIGTERM reaches the app? | Often **no** (sh may not forward it) | **Yes** (the app still has to handle it, see below) |
| `$VAR` expansion | Yes (the shell does it) | No (no shell) |

Rule 2: **Use exec form (JSON array) for CMD and ENTRYPOINT.**

Why it matters: Docker sends SIGTERM to **PID 1**. If PID 1 is `sh`, your app may
never hear it. Docker waits 10 seconds, then SIGKILLs everything: exit code 137,
dropped requests, no cleanup.

## See it work

```dockerfile
# Dockerfile.tool: an image that IS the ping tool
FROM alpine:3.20
ENTRYPOINT ["ping", "-c", "2"]
CMD ["localhost"]
```

```bash
docker build -t pinger -f Dockerfile.tool .
docker run --rm pinger              # ping -c 2 localhost
docker run --rm pinger 127.0.0.1    # ping -c 2 127.0.0.1  (CMD replaced)
docker run --rm --entrypoint echo pinger hi   # echo hi  (ENTRYPOINT replaced)
```

Expected output of the last line: `hi`.

### Watch the signal problem

```dockerfile
# Dockerfile.shell: shell form, PID 1 is sh
FROM alpine:3.20
CMD sleep 300; echo done
```

```bash
docker build -t shellform -f Dockerfile.shell .
docker run -d --name s1 shellform
docker top s1          # PID 1 is "/bin/sh -c sleep 300; echo done"
time docker stop s1    # real 0m10.2s
docker inspect -f '{{.State.ExitCode}}' s1   # 137: it was SIGKILLed
```

The shell is PID 1 and did not pass SIGTERM on to `sleep`, so Docker waited the
full grace period and killed it.

**A second trap: PID 1 is special.** The Linux kernel does not apply a signal's
default action ("terminate") to PID 1. A process that is PID 1 only reacts to
SIGTERM if it **installs a handler** for it. Servers like nginx and Postgres do;
`sleep`, and many scripts and small apps, do not. So even exec form can hang:

```bash
docker run -d --name s2 alpine:3.20 sleep 300
time docker stop s2            # still ~10 s, exit 137
docker run -d --init --name s3 alpine:3.20 sleep 300
time docker stop s3            # ~0.1 s, exit 143
```

`--init` makes a tiny init process (`tini`) PID 1. It forwards signals to your
app (which is now not PID 1, so default actions apply) and reaps zombie child
processes. So the full recipe is: **exec form, plus either a SIGTERM handler in
your app or `--init`.**

### The entrypoint-script pattern

Many official images run a setup script, then hand over to the real program:

```sh
#!/bin/sh
# docker-entrypoint.sh
set -e
echo "preparing config..."
exec "$@"      # replace this shell with CMD, so the app becomes PID 1
```

```dockerfile
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["python", "app.py"]
```

The key is **`exec "$@"`**: it replaces the shell with the app, so signals reach it.

## Try it

An image has `ENTRYPOINT ["python", "manage.py"]` and `CMD ["runserver", "0.0.0.0:8000"]`.
What runs for `docker run img migrate`? And how do you get a shell instead?

<details>
<summary>Show answer</summary>

- `python manage.py migrate` (your argument replaced CMD).
- `docker run -it --entrypoint sh img` (replaces ENTRYPOINT).

</details>

## Common mistakes

- **Shell-form `CMD` for long-running apps.** Slow stops, exit 137, lost requests.
- **Expecting `$PORT` to expand in exec form.** `CMD ["app", "--port", "$PORT"]`
  passes the literal text `$PORT`. Use `CMD ["sh", "-c", "exec app --port $PORT"]`.
- **Multiple `CMD` lines.** Only the **last** one counts.
- **Forgetting `exec` in entrypoint scripts.** The shell stays PID 1 and swallows signals.

## Remember

- Final command = ENTRYPOINT + (run args or CMD). Run args replace CMD.
- ENTRYPOINT = the program; CMD = default args. `--entrypoint` overrides the program.
- Always use **exec form** `["a", "b"]` so SIGTERM goes to your app, not a shell.
- PID 1 ignores SIGTERM unless it handles it: add a handler or run with `--init`.
- Entrypoint scripts must end with `exec "$@"`.

**Self-check:**

1. What does `docker run img arg1` replace?
2. Why can shell-form CMD make `docker stop` take 10 seconds?
3. What does `exec "$@"` do at the end of an entrypoint script?
