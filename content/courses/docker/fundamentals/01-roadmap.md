---
kind: lesson
id_key: docker/fundamentals/roadmap
course: docker
section: fundamentals
section_title: Big Picture & Fundamentals
section_position: 1
title: "The Big Picture: Why Containers Exist"
position: 0
estimated_minutes: 7
source:
  - Docker Command Cheat Sheet.pdf
---

## Why this matters

"It works on my machine" is the oldest bug in software. Your laptop has Python 3.12,
the server has 3.9. Your app needs `libpq`, the server forgot to install it.
Docker fixes this by shipping the app **together with everything it needs**.

## Mental model: the shipping container

Before shipping containers, every cargo (barrels, sacks, cars) was loaded by hand,
differently on every ship. Then the world agreed on one steel box with a standard
size. Ships, cranes and trucks stopped caring what was inside.

Docker does the same for software:

```
Without Docker                         With Docker
--------------                         -----------
your code                              +-------------------------+
+ "install Python 3.12"                | container image         |
+ "apt install libpq"                  |  - your code            |
+ "set these 6 env vars"               |  - Python 3.12          |
+ "pray the server matches"            |  - libpq, config, ...   |
                                       +-------------------------+
                                        runs the same on laptop,
                                        CI server and cloud
```

> **One-sentence definition.** A **container** is a normal Linux process that
> Docker starts in an isolated box, with its own files, network and process list.

That is it. A container is not a tiny virtual machine. It is a process with
walls around it. You will see exactly how those walls work in lesson 3.

## See it work

Assume Docker is installed. Run this one line:

```bash
# Download a tiny Linux image (if needed) and run one command inside it
docker run --rm alpine:3.20 echo "hello from a container"
```

Expected output (the first time, Docker also prints download progress):

```
hello from a container
```

What happened, step by step:

1. `docker run` asked Docker to start a container.
2. `alpine:3.20` is the **image**: a frozen snapshot of a small Linux system.
3. Docker started a process (`echo ...`) inside an isolated box built from that image.
4. The process printed one line and exited, so the container stopped.
5. `--rm` told Docker to delete the stopped container afterwards.

## The course roadmap

Each section builds on the one before. Lessons are short; each teaches one idea.

| # | Section | You will be able to... |
|---|---|---|
| 1 | Big Picture & Fundamentals | Explain images, containers, registries, and how Linux isolates a process |
| 2 | Running Containers | Start, stop, inspect and debug containers; publish ports |
| 3 | Images & Layers | Explain layers and digests; tag, save and move images |
| 4 | Writing Dockerfiles | Write fast, small images with caching, multi-stage builds and BuildKit |
| 5 | Networking & Storage | Connect containers and keep data safe with volumes |
| 6 | Compose & Registries | Run multi-container apps from one file; push and pull images |
| 7 | Production-Ready Containers | Harden security, add healthchecks and resource limits |
| 8 | Troubleshooting & Cleanup | Debug a broken container fast; reclaim disk space |
| 9 | Capstone | Chain everything together end to end |

Every lesson has the same shape, so you always know where you are:
**Why this matters → Mental model → See it work → Try it → Common mistakes → Remember**.

Each section ends with a quiz. Later quizzes mix in earlier topics on purpose:
recalling old material at spaced intervals is what makes it stick.

## Try it

Without looking above, answer in your own words: what are the two things a
shipping container standardised, and what is the Docker equivalent of each?

<details>
<summary>Show answer</summary>

1. **The box format** (one standard size). Docker equivalent: the **image format**
   (an open standard called OCI), so any tool can run any image.
2. **The handling** (cranes and ships do not care what is inside). Docker equivalent:
   the **runtime**. `docker run` starts any image the same way, whatever language
   or libraries are inside.

</details>

## Common mistakes

- **"A container is a lightweight VM."** No. A VM runs its own kernel. A container
  shares the host's kernel and is just an isolated process. This matters for
  security and for why Linux containers need a Linux kernel.
- **"Docker makes my app portable to any CPU."** An image is built for a CPU
  architecture (`amd64`, `arm64`). An `amd64` image will not run natively on an
  ARM laptop without emulation. Section 4 shows multi-platform builds.
- **"Docker is the only way to run containers."** Docker popularised them, but
  the formats are open standards. Podman, containerd and Kubernetes run the same images.

## Remember

- Docker ships your app **with** its dependencies, so it runs the same everywhere.
- A **container** = an isolated Linux process. Not a VM.
- An **image** = the frozen template a container starts from.
- `docker run IMAGE COMMAND` is the one command that ties them together.

**Self-check (answer from memory):**

1. What problem does Docker solve, in one sentence?
2. Why is "a container is a small VM" wrong?
3. What did `--rm` do in the example above?
