---
kind: lesson
id_key: docker/container-commands/first-container
course: docker
section: container-commands
section_title: Running Containers
section_position: 2
title: "Your First Containers: docker run"
position: 0
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

`docker run` is the command you will type more than any other. It has dozens of
flags, but four of them cover most daily use: `-it`, `-d`, `--name` and `--rm`.
Learn those four well and the rest are details.

## Mental model: run = create + start

`docker run` is a shortcut for two steps:

```
docker run IMAGE [COMMAND]
     |
     +--> docker create IMAGE   (make the container: writable layer, config)
     +--> docker start  ID      (start its main process)
```

The general shape is:

```
docker run [OPTIONS] IMAGE[:TAG] [COMMAND] [ARG...]
           \_______/ \________/ \_______________/
           how to run  what to run  override the image's default command
```

**Key rule:** a container lives exactly as long as its **main process**. When
that process exits, the container stops. Keep this rule in mind; it explains
most "my container exited immediately" questions.

## See it work

### 1. Run a one-off command

```bash
# Run "echo" inside an Alpine container, then stop
docker run alpine:3.20 echo hi
```

Output: `hi`. The main process (`echo`) finished, so the container stopped. It
still exists, stopped, until you remove it.

### 2. Get an interactive shell: `-it`

```bash
# -i keeps STDIN open, -t gives you a terminal (TTY)
docker run -it alpine:3.20 sh
```

You get a prompt like `/ #`. Try `ls`, `cat /etc/os-release`. Type `exit` to
leave. Because `sh` was the main process, exiting the shell stops the container.

- `-i` (interactive): keep standard input open so you can type.
- `-t` (tty): allocate a terminal so the prompt and colours work.
- Almost always used together as `-it`.

### 3. Run in the background: `-d`

```bash
# -d = detached: start and return immediately; --name = pick a name
docker run -d --name myserver nginx:1.27-alpine
```

Output: a long container ID like `a1b2c3d4e5f6...`. The web server keeps running
in the background because nginx's main process never exits.

```bash
docker ps
```

You see `myserver` with status `Up ...`.

### 4. Clean up automatically: `--rm`

```bash
# --rm deletes the container as soon as it stops
docker run --rm alpine:3.20 date
```

Output: the current date. Afterwards, `docker ps -a` does not list it. Use
`--rm` for every throwaway command, or stopped containers pile up.

### 5. Names and IDs

Every container has an ID and a name. If you do not pass `--name`, Docker
invents one like `quirky_hopper`. Commands accept the name, the full ID, or a
unique prefix of the ID:

```bash
docker stop myserver      # by name
docker stop a1b2          # by ID prefix (if unique)
```

## Try it

Start an Alpine container in the background that stays alive for an hour,
named `napper`. Then confirm it is running. (Hint: Alpine's default command is
`sh`, which exits immediately when nothing is attached.)

<details>
<summary>Show answer</summary>

```bash
docker run -d --name napper alpine:3.20 sleep 3600
docker ps --filter name=napper
```

`sleep 3600` is a main process that lasts an hour, so the container stays up.
Clean up with `docker rm -f napper`.

</details>

## Common mistakes

- **`docker run -d alpine:3.20` and it "disappears".** The default command `sh`
  has no terminal attached, so it exits at once and the container stops. Give it
  a long-running command, or use `-it` for interactive work.
- **Putting options after the image name.** `docker run alpine:3.20 --rm echo hi`
  passes `--rm` to the container, not to Docker. Options go **before** the image.
- **Reusing a name.** `docker run --name myserver ...` twice fails with
  *"Conflict. The container name is already in use"*. Remove the old one first.
- **Running `docker run` to "get back into" a container.** That creates a
  *new* container. To enter an existing one, use `docker exec` (lesson 3).

## Remember

- `docker run` = `create` + `start`.
- A container lives as long as its main process.
- `-it` = interactive shell. `-d` = background. `--name` = readable name. `--rm` = auto-delete.
- Options go before the image name; anything after the image is the command.

**Self-check:**

1. What two commands does `docker run` combine?
2. Why does `docker run -d alpine:3.20` stop instantly?
3. Where do Docker options go relative to the image name?
