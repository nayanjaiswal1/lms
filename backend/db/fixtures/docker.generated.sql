-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-16T15:22:19Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Docker Essentials ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('27527dc6-807c-51bf-beb9-a499519888d9', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Docker Essentials', 'docker', 'Learn Docker from first principles to production in short, one-idea lessons: what a container really is (namespaces, cgroups), images and layers, running and debugging containers, writing fast and small Dockerfiles (build cache, multi-stage builds, BuildKit), networking and volumes, Docker Compose and registries, then security, healthchecks and resource limits, a troubleshooting playbook and cleanup. Every lesson ends with self-check questions, every section with a quiz, and hands-on labs run real Docker commands in a sandbox.', '/course-covers/docker.svg', 'beginner', ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 'published', true, false, 9.2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

UPDATE course_sections SET position = position + 100000 WHERE course_id = '27527dc6-807c-51bf-beb9-a499519888d9';
UPDATE course_modules SET position = position + 100000 WHERE course_id = '27527dc6-807c-51bf-beb9-a499519888d9';

-- Section: Big Picture & Fundamentals
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('35aeeb53-49c4-50de-a1ec-f1b34e695109', '27527dc6-807c-51bf-beb9-a499519888d9', 'Big Picture & Fundamentals', 1, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('dc39d161-9502-5abb-b9e0-18ac27659353', '27527dc6-807c-51bf-beb9-a499519888d9', '35aeeb53-49c4-50de-a1ec-f1b34e695109', 'The Big Picture: Why Containers Exist', 'notes', 0, $md$## Why this matters

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
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2531d509-05f1-5c52-93d5-e38ad14e08ba', '27527dc6-807c-51bf-beb9-a499519888d9', '35aeeb53-49c4-50de-a1ec-f1b34e695109', 'Images, Containers and Registries', 'notes', 1, $md$## Why this matters

Almost every Docker confusion comes from mixing up three words: **image**,
**container** and **registry**. Get these straight now and every later command
reads like plain English.

## Mental model: recipe, cake, cookbook shop

| Docker word | Kitchen analogy | What it really is |
|---|---|---|
| **Image** | A recipe card | A read-only template: base OS files, libraries, your app, env vars, default command |
| **Container** | A cake baked from the recipe | A running (or stopped) instance of an image, with its own writable scratch space |
| **Registry** | A shop that sells recipe cards | A server that stores images so other machines can download them (Docker Hub is the default) |

One recipe can bake many cakes. One image can start many containers, and all of
them start out identical. Eating one cake does not change the recipe: a
container writing files never changes its image.

```
             push                     pull
  [your PC] -------> [ Registry ] -------> [ server ]
     |               (Docker Hub)              |
   build                                     run
     v                                         v
  [ Image ]                       [ Image ] --> [Container 1]
                                            --> [Container 2]
```

> **One-sentence definitions.**
> **Image:** a read-only, versioned template for a container.
> **Container:** a live, writable instance of an image.
> **Registry:** a remote store you **push** images to and **pull** images from.

## See it work

```bash
# 1. Pull an image from the registry (Docker Hub) onto your machine
docker pull nginx:1.27-alpine

# 2. List images you have locally
docker images

# 3. Start two containers from the SAME image
docker run -d --name web1 nginx:1.27-alpine
docker run -d --name web2 nginx:1.27-alpine

# 4. List running containers
docker ps
```

Expected output of step 4 (IDs and times will differ):

```
CONTAINER ID   IMAGE               COMMAND                  STATUS         NAMES
3f2a1c9e7b10   nginx:1.27-alpine   "/docker-entrypoint.…"   Up 3 seconds   web2
9b8d7e6f5a43   nginx:1.27-alpine   "/docker-entrypoint.…"   Up 5 seconds   web1
```

Line by line:

- `nginx:1.27-alpine` is an **image name**. `nginx` is the repository, `1.27-alpine` is
  the **tag** (a version label).
- `docker images` shows the one image. `docker ps` shows **two** containers made from it.
- `-d` means *detached*: run in the background. `--name` gives the container a
  human-friendly name instead of a random one.

Clean up:

```bash
docker rm -f web1 web2   # force-stop and delete both containers
```

```knowledge-check
{
  "questions": [
    {
      "id": "docker-fundamentals-concepts-q1",
      "type": "mcq",
      "prompt": "What is the relationship between an image and a container?",
      "options": [
        { "id": "a", "text": "They are interchangeable names for the same thing" },
        { "id": "b", "text": "An image is a runtime instance of a container" },
        { "id": "c", "text": "A container is a runtime instance created from an image; many containers can run from one image" },
        { "id": "d", "text": "An image can only ever produce one container" }
      ],
      "correct": "c",
      "explanation": "The image is the standalone, executable template. A container is what you get when that template is actually run, and any number of containers can be started from the same image, all sharing identical starting behavior."
    },
    {
      "id": "docker-fundamentals-concepts-q2",
      "type": "mcq",
      "prompt": "What is a registry for?",
      "options": [
        { "id": "a", "text": "Running containers from images" },
        { "id": "b", "text": "Storing images remotely so they can be pushed to and pulled from other machines" },
        { "id": "c", "text": "Compiling application source code into an image" },
        { "id": "d", "text": "Monitoring container CPU and memory usage" }
      ],
      "correct": "b",
      "explanation": "A registry (Docker Hub by default) is a remote store for named, tagged images: the mechanism for moving an image between machines via push/pull."
    }
  ]
}
```

## Try it

You run `docker run -d --name app1 myapp:1.0`, then inside `app1` you delete
`/etc/hosts`. Next you run `docker run -d --name app2 myapp:1.0`.
Does `app2` have `/etc/hosts`? Why?

<details>
<summary>Show answer</summary>

Yes. `app1` only changed its **own writable layer**. The image `myapp:1.0` is
read-only and untouched, so `app2` starts from the original files. (Section 3
explains the layer mechanics.)

</details>

## Common mistakes

- **Deleting an image that a container still uses.** `docker rmi nginx:1.27-alpine`
  fails while a container (even a stopped one) references it. Remove the container first.
- **Thinking `docker ps` shows everything.** It shows only *running* containers.
  Stopped ones still exist and use disk. Use `docker ps -a`.
- **Saving important data inside a container.** When the container is removed,
  its writable layer is gone. Use volumes (Section 5).

## Remember

- **Image** = recipe (read-only). **Container** = cake (writable instance). **Registry** = shop.
- One image → many identical containers.
- `pull` downloads, `push` uploads, `run` turns an image into a container.
- `docker images` lists images; `docker ps` lists running containers (`-a` for all).

**Self-check:**

1. Name the three core Docker objects and define each in one sentence.
2. Which command lists stopped containers too?
3. Why can two containers from the same image have different files after a while?
$md$, 8, $json$[{"id":"docker-fundamentals-concepts-q1","type":"mcq","correct":"c"},{"id":"docker-fundamentals-concepts-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('30ffb6ba-46a7-53e9-bf63-7635c7939d8a', '27527dc6-807c-51bf-beb9-a499519888d9', '35aeeb53-49c4-50de-a1ec-f1b34e695109', 'Under the Hood: Namespaces, cgroups and Containers vs VMs', 'notes', 2, $md$## Why this matters

Interviewers love "how is a container different from a VM?". More importantly,
the answer explains real behaviour you will hit: why a container starts in
milliseconds, why it can see only its own processes, and why one container can
starve the host of memory if you do not set limits.

## Mental model: an apartment building

A **virtual machine** is a separate house. It has its own foundation, plumbing
and power plant (its own **kernel**, the core of the operating system).

A **container** is an apartment in one building. Every apartment shares the same
foundation and plumbing (the **host kernel**), but each has its own locked door,
its own mailbox and a fixed share of electricity.

```
     Virtual machines                     Containers
+----------+ +----------+        +----------+ +----------+
|  App A   | |  App B   |        |  App A   | |  App B   |
| libs     | | libs     |        | libs     | | libs     |
| Guest OS | | Guest OS |        +----------+ +----------+
| (kernel) | | (kernel) |        |  container runtime     |
+----------+ +----------+        +------------------------+
|      Hypervisor        |       |  Host OS (ONE kernel)  |
+------------------------+       +------------------------+
|       Hardware         |       |       Hardware         |
+------------------------+       +------------------------+
```

Linux builds the "apartment walls" from two kernel features:

| Feature | Plain-words job | Analogy |
|---|---|---|
| **Namespaces** | Control what a process can **see** (its own process list, network, hostname, mounts, users) | The locked door and private mailbox |
| **cgroups** (control groups) | Control how much a process can **use** (CPU, memory, number of processes, disk I/O) | The fixed share of electricity |

Mnemonic: **Namespaces = what you See. cgroups = what you Consume.**

The main namespaces Docker uses:

- **pid**: the container sees its own process tree; its main process is PID 1.
- **net**: its own network interfaces, IP address and ports.
- **mnt**: its own filesystem view (built from the image).
- **uts**: its own hostname.
- **ipc**: its own shared-memory area.
- **user**: maps users inside to different users outside (used by rootless mode).

## See it work

```bash
# Inside a container, the process list contains only the container's processes
docker run --rm alpine:3.20 ps
```

Expected output:

```
PID   USER     TIME  COMMAND
    1 root      0:00 ps
```

The `ps` command is PID 1 and sees nothing else. That is the **pid namespace**.

```bash
# The container has its own hostname (the uts namespace)
docker run --rm alpine:3.20 hostname
```

Expected output: a random 12-character ID such as `5c1f0e2a9d3b` (the container ID).

```bash
# But the kernel is the host's own kernel: same version inside and outside
uname -r
docker run --rm alpine:3.20 uname -r
```

Both lines print the **same** kernel version. That is the "shared foundation".

On Linux you can even see the container from the host: run a long sleep and look for it.

```bash
docker run -d --name sleeper alpine:3.20 sleep 300
ps aux | grep "sleep 300"     # visible on the host as an ordinary process
docker rm -f sleeper
```

(On macOS and Windows, Docker Desktop runs a small Linux VM behind the scenes, so
you would see it inside that VM, not on your Mac.)

## Containers vs VMs at a glance

| | Container | Virtual machine |
|---|---|---|
| Kernel | Shares host kernel | Own guest kernel |
| Start time | Milliseconds to seconds | Tens of seconds to minutes |
| Size | MBs (just app + libs) | GBs (whole OS) |
| Isolation | Process-level; weaker | Hardware-level; stronger |
| Runs a different OS kernel? | No (Linux images need a Linux kernel) | Yes |

They are not rivals. In the cloud, containers usually run **inside** VMs.

## Try it

Your teammate says: "I set up a container with 2 GB of memory and it can only
see its own processes." Which kernel feature does each half of that sentence use?

<details>
<summary>Show answer</summary>

- "2 GB of memory" is a limit on consumption: **cgroups**.
- "only see its own processes" is a visibility rule: the **pid namespace**.

</details>

## Common mistakes

- **Assuming containers are as isolated as VMs.** A kernel bug affects every
  container on the host. That is why you run as non-root and drop privileges
  (Section 7).
- **Forgetting cgroup limits.** By default a container has **no** memory or CPU
  limit. One leaky container can slow down the whole host.
- **Expecting a Windows or macOS kernel inside a Linux container.** The image's
  userland (Alpine, Debian) changes, the kernel does not.

## Remember

- A container is a host process wrapped in **namespaces** (what it sees) and
  **cgroups** (what it uses).
- Containers share the host kernel; VMs bring their own.
- That is why containers are small and fast, and also why their isolation is weaker.
- No limits are set by default. You add them (Section 7).

**Self-check:**

1. Which kernel feature makes PID 1 inside a container?
2. Why does `uname -r` print the same value inside and outside a container?
3. Give one advantage of a VM over a container.
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8c756c3f-1a2d-5c2d-bd4c-d85c4f772575', '27527dc6-807c-51bf-beb9-a499519888d9', '35aeeb53-49c4-50de-a1ec-f1b34e695109', 'Docker''s Architecture: Client, Daemon, Runtime', 'notes', 3, $md$## Why this matters

When you type `docker run`, the `docker` program does **not** run your
container. It sends a request to a background service. Knowing this explains
errors like *"Cannot connect to the Docker daemon"* and why access to Docker
is as powerful as root access.

## Mental model: a restaurant

- **You** order from a **waiter** (the `docker` **client**, the CLI you type into).
- The waiter passes the order to the **kitchen** (the Docker **daemon**, `dockerd`).
- The kitchen gets ingredients from the **supplier** (the **registry**).
- Inside the kitchen, a **head chef** (`containerd`) hands each dish to a **line
  cook** (`runc`) who actually cooks it (creates the namespaces and cgroups).

```
 you
  |  docker run nginx
  v
+--------+   REST API over      +---------+     +------------+     +------+
| docker | -------------------> | dockerd | --> | containerd | --> | runc | --> container
| client |  /var/run/docker.sock| (daemon)|     | (lifecycle)|     |(OCI) |     process
+--------+                      +---------+     +------------+     +------+
                                     |
                                     | pull / push
                                     v
                                +----------+
                                | registry |
                                +----------+
```

Terms:

- **Client** (`docker`): turns your command into an API request.
- **Daemon** (`dockerd`): long-running service that manages images, containers,
  networks and volumes. Listens on a Unix socket, usually `/var/run/docker.sock`.
- **containerd**: manages container lifecycles and image storage. Kubernetes uses it directly too.
- **runc**: tiny tool that creates the container (namespaces + cgroups) and exits.
- **OCI** (Open Container Initiative): the open standard for image format and
  runtime behaviour. It is why Docker-built images run on Podman or Kubernetes.

## See it work

```bash
# Version of the client AND the server (daemon)
docker version
```

Expected output (shortened; versions vary):

```
Client:
 Version:           27.5.1
 API version:       1.47
Server: Docker Engine - Community
 Engine:
  Version:          27.5.1
 containerd:
  Version:          1.7.25
 runc:
  Version:          1.2.4
```

Notice the two halves: **Client** and **Server**. You can see containerd and
runc listed as server components.

```bash
# System-wide information from the daemon
docker info
```

Look for these lines (values vary):

```
 Containers: 3
  Running: 1
  Stopped: 2
 Images: 5
 Storage Driver: overlay2
 Cgroup Version: 2
```

```bash
# Help for Docker, or any subcommand
docker --help
docker run --help
```

If the daemon is not running, every command fails like this:

```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

The fix is to start the service (for example `sudo systemctl start docker` on
Linux, or open Docker Desktop on macOS/Windows). Old tutorials show `docker -d`
to start the daemon; that flag was removed long ago. The daemon binary is `dockerd`.

```knowledge-check
{
  "questions": [
    {
      "id": "docker-fundamentals-architecture-q1",
      "type": "mcq",
      "prompt": "Which component actually builds and runs containers and images?",
      "options": [
        { "id": "a", "text": "The docker client binary" },
        { "id": "b", "text": "The runtime (daemon)" },
        { "id": "c", "text": "The registry" },
        { "id": "d", "text": "The Dockerfile" }
      ],
      "correct": "b",
      "explanation": "The client is just how you send commands (build/pull/run) to the daemon, over a local socket or remote API. The daemon is the runtime that actually manages containers and images; the registry only stores images."
    },
    {
      "id": "docker-fundamentals-commands-q1",
      "type": "mcq",
      "prompt": "You want to see the daemon's storage driver, and how many containers and images currently exist. Which command shows that?",
      "options": [
        { "id": "a", "text": "docker version" },
        { "id": "b", "text": "docker info" },
        { "id": "c", "text": "docker --help" },
        { "id": "d", "text": "docker -d" }
      ],
      "correct": "b",
      "explanation": "docker version only reports the client/server version numbers. docker info is the one that shows system-wide daemon state: storage driver, container counts, image counts, and more."
    }
  ]
}
```

## Why the socket is a security boundary

Whoever can talk to `/var/run/docker.sock` can tell the daemon to start a
container that mounts the host's `/` and runs as root. So:

- Being in the `docker` group is **equivalent to root** on that machine.
- Never mount `docker.sock` into a container unless you fully trust it.
- **Rootless mode** runs the daemon itself as a normal user to reduce this risk (Section 7).

## Try it

A teammate runs `docker ps` and gets *"permission denied while trying to connect
to the Docker daemon socket"*. Docker is running. What is likely wrong, and what
is the security trade-off of the usual fix?

<details>
<summary>Show answer</summary>

Their user cannot access `/var/run/docker.sock`. The usual fix is adding them to
the `docker` group (`sudo usermod -aG docker $USER`, then log out and in). Trade-off:
that grants root-equivalent power. Rootless Docker is the safer alternative.

</details>

## Common mistakes

- **Thinking the CLI and daemon must be on the same machine.** The client can
  talk to a remote daemon (`DOCKER_HOST=ssh://user@server`, or `docker context`).
- **Reading only the client version.** `docker version` shows both; a server
  error there means the daemon is down or unreachable.
- **Using `sudo docker` everywhere** instead of fixing group membership or using
  rootless mode.

## Remember

- `docker` (client) → API → `dockerd` (daemon) → `containerd` → `runc` → your process.
- `docker version` = client and server versions. `docker info` = daemon state.
- Access to the Docker socket = root on the host.
- OCI standards make images portable across Docker, Podman and Kubernetes.

**Self-check:**

1. Which component creates the namespaces and cgroups for a container?
2. What does the error "Cannot connect to the Docker daemon" tell you?
3. Why is the `docker` group a security concern?
$md$, 8, $json$[{"id":"docker-fundamentals-architecture-q1","type":"mcq","correct":"b"},{"id":"docker-fundamentals-commands-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ba1d8272-80be-5e00-8056-908f08ed9da1', '00000000-0000-0000-0000-000000000001', 'mcq', 'A colleague''s app runs fine on their laptop but crashes on the server because...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('be736666-fd44-5a23-ab0b-abfcd1f889ff', 'ba1d8272-80be-5e00-8056-908f08ed9da1', 1, $json${"prompt":"A colleague's app runs fine on their laptop but crashes on the server because the server has an older OpenSSL. How does Docker prevent this class of problem?","multiple":false,"options":[{"id":"a","text":"Docker upgrades the server's OpenSSL automatically when you run a container","is_correct":false},{"id":"b","text":"The image ships the app together with its own libraries, so the server's installed packages no longer matter","is_correct":true},{"id":"c","text":"Docker runs the app inside a full virtual machine with its own kernel","is_correct":false},{"id":"d","text":"Docker compiles the app into a static binary","is_correct":false}],"explanation":"An image bundles the app's userland dependencies (libraries, runtimes, config). Docker never touches host packages, so option 1 is wrong. Containers do not bring their own kernel (that is a VM), so option 3 is wrong. Docker does not compile anything, so option 4 is wrong."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('268b55da-d570-57a3-9f2c-9b4005bb3a51', '00000000-0000-0000-0000-000000000001', 'mcq', 'You start three containers from the image shop:2.1. One of them deletes /app/...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fd4ee72e-78f1-52c6-ac94-319165ecc3c7', '268b55da-d570-57a3-9f2c-9b4005bb3a51', 1, $json${"prompt":"You start three containers from the image shop:2.1. One of them deletes /app/config.yml. What happens to the other two and to the image?","multiple":false,"options":[{"id":"a","text":"All three containers and the image lose the file","is_correct":false},{"id":"b","text":"The image loses the file, so the next container started will not have it","is_correct":false},{"id":"c","text":"Only that one container loses the file; the image and the other containers are unchanged","is_correct":true},{"id":"d","text":"Docker refuses the delete because images are read-only","is_correct":false}],"explanation":"Each container gets its own writable layer on top of the read-only image. The delete is recorded only in that container's layer. The image is never modified by a running container, and the delete is allowed because it happens in the writable layer, not the image."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('40e3427a-d763-5dac-8fdc-02d8cd52d548', '00000000-0000-0000-0000-000000000001', 'mcq', 'Inside a container, `ps` shows only two processes and the first one is PID 1....', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('6c000fed-6917-5519-aa1d-d7df71f18fb4', '40e3427a-d763-5dac-8fdc-02d8cd52d548', 1, $json${"prompt":"Inside a container, `ps` shows only two processes and the first one is PID 1. Which Linux kernel feature causes this?","multiple":false,"options":[{"id":"a","text":"cgroups","is_correct":false},{"id":"b","text":"The pid namespace","is_correct":true},{"id":"c","text":"The overlay2 storage driver","is_correct":false},{"id":"d","text":"The hypervisor","is_correct":false}],"explanation":"Namespaces control what a process can see; the pid namespace gives the container its own process tree. cgroups limit what it can consume (CPU, memory), not what it sees. overlay2 handles files, and there is no hypervisor in plain containers."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bd89ed1c-3c65-5aaf-9991-6867a6149963', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container with no flags slowly leaks memory until the whole host becomes un...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('72c330f5-5a14-5fe9-aa8a-5c7ee094b75b', 'bd89ed1c-3c65-5aaf-9991-6867a6149963', 1, $json${"prompt":"A container with no flags slowly leaks memory until the whole host becomes unresponsive. What was missing?","multiple":false,"options":[{"id":"a","text":"A user namespace","is_correct":false},{"id":"b","text":"A cgroup memory limit (for example --memory 512m)","is_correct":true},{"id":"c","text":"A registry login","is_correct":false},{"id":"d","text":"The --rm flag","is_correct":false}],"explanation":"By default containers have no memory limit, so a leak can eat host memory. Memory limits are enforced by cgroups. A user namespace changes user mapping, not resource use. --rm only deletes the container after it exits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d74ca643-9876-5e4b-aa5f-c034348faa37', '00000000-0000-0000-0000-000000000001', 'mcq', '`docker ps` prints "Cannot connect to the Docker daemon at unix:///var/run/do...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ee32d3f9-8002-5d41-903a-80166282d862', 'd74ca643-9876-5e4b-aa5f-c034348faa37', 1, $json${"prompt":"`docker ps` prints \"Cannot connect to the Docker daemon at unix:///var/run/docker.sock\". What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"The image you want does not exist on Docker Hub","is_correct":false},{"id":"b","text":"The dockerd service is not running (or your client points at the wrong host)","is_correct":true},{"id":"c","text":"The container crashed","is_correct":false},{"id":"d","text":"Your Dockerfile has a syntax error","is_correct":false}],"explanation":"The client could not reach the daemon's socket at all, so no command can work. Missing images, crashed containers and Dockerfile errors all produce different errors that come back from a reachable daemon."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('645449ba-11e0-5469-a654-975639fc2101', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why do security teams treat membership of the `docker` group as equivalent to...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cdc95255-1c3c-5666-9296-bdb06af6e644', '645449ba-11e0-5469-a654-975639fc2101', 1, $json${"prompt":"Why do security teams treat membership of the `docker` group as equivalent to root?","multiple":false,"options":[{"id":"a","text":"Because the docker group can edit /etc/passwd directly","is_correct":false},{"id":"b","text":"Because anyone who can talk to the Docker socket can start a container that mounts the host filesystem as root","is_correct":true},{"id":"c","text":"Because docker group members can read all container logs","is_correct":false},{"id":"d","text":"It is not; the docker group is unprivileged","is_correct":false}],"explanation":"The daemon runs as root (in standard mode) and does whatever the socket tells it, including bind-mounting / into a privileged container. Reading logs is a minor risk compared to this, and the group has no direct /etc/passwd access."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c1fe5ea1-6243-5065-ae2c-90ea8e05b207', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which statement about containers and VMs is correct?', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0ea832b1-840b-5c4e-9565-91142dfed5df', 'c1fe5ea1-6243-5065-ae2c-90ea8e05b207', 1, $json${"prompt":"Which statement about containers and VMs is correct?","multiple":false,"options":[{"id":"a","text":"Containers and VMs both run their own kernel","is_correct":false},{"id":"b","text":"A container can run a Windows kernel on a Linux host","is_correct":false},{"id":"c","text":"Containers share the host kernel, so they start faster but isolate less strongly than VMs","is_correct":true},{"id":"d","text":"Containers cannot run inside VMs","is_correct":false}],"explanation":"Only VMs have their own kernel; that is why containers start in milliseconds and why their isolation is weaker. A container cannot swap kernels, and in the cloud containers usually do run inside VMs."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('05580832-45fd-5fef-a978-445141008d7d', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the chain docker CLI -> dockerd -> containerd -> runc, which component act...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a47dcb76-67d2-511e-bbbb-1980f2a67d45', '05580832-45fd-5fef-a978-445141008d7d', 1, $json${"prompt":"In the chain docker CLI -\u003e dockerd -\u003e containerd -\u003e runc, which component actually creates the namespaces and cgroups and then exits?","multiple":false,"options":[{"id":"a","text":"docker CLI","is_correct":false},{"id":"b","text":"dockerd","is_correct":false},{"id":"c","text":"containerd","is_correct":false},{"id":"d","text":"runc","is_correct":true}],"explanation":"runc is the low-level OCI runtime that sets up the isolation and starts the process. The CLI only sends API calls, dockerd manages Docker objects, and containerd supervises lifecycles and images."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('23a29661-d4ce-5978-8eab-bc89a84b3dee', '00000000-0000-0000-0000-000000000001', 'Quiz: Big Picture & Fundamentals', 'docker-fundamentals-quiz', 'Quiz covering Big Picture & Fundamentals.', 'mcq', 'published', 'module', '3116d636-ac04-5bc8-9b29-9ab048aafae2', 10, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '23a29661-d4ce-5978-8eab-bc89a84b3dee' AND question_id NOT IN ('ba1d8272-80be-5e00-8056-908f08ed9da1', '268b55da-d570-57a3-9f2c-9b4005bb3a51', '40e3427a-d763-5dac-8fdc-02d8cd52d548', 'bd89ed1c-3c65-5aaf-9991-6867a6149963', 'd74ca643-9876-5e4b-aa5f-c034348faa37', '645449ba-11e0-5469-a654-975639fc2101', 'c1fe5ea1-6243-5065-ae2c-90ea8e05b207', '05580832-45fd-5fef-a978-445141008d7d');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('424418bd-8b2d-5300-83aa-bdfc1b9eaff3', '23a29661-d4ce-5978-8eab-bc89a84b3dee', 'ba1d8272-80be-5e00-8056-908f08ed9da1', 'be736666-fd44-5a23-ab0b-abfcd1f889ff', 0, 2),
('6fcf5ad5-fa07-52cb-a72c-502b838bb422', '23a29661-d4ce-5978-8eab-bc89a84b3dee', '268b55da-d570-57a3-9f2c-9b4005bb3a51', 'fd4ee72e-78f1-52c6-ac94-319165ecc3c7', 1, 2),
('8610b9ee-3f20-5d30-ae26-db2f677d28ef', '23a29661-d4ce-5978-8eab-bc89a84b3dee', '40e3427a-d763-5dac-8fdc-02d8cd52d548', '6c000fed-6917-5519-aa1d-d7df71f18fb4', 2, 2),
('7a81c20b-1799-59c1-9ef0-fc494e7b7be5', '23a29661-d4ce-5978-8eab-bc89a84b3dee', 'bd89ed1c-3c65-5aaf-9991-6867a6149963', '72c330f5-5a14-5fe9-aa8a-5c7ee094b75b', 3, 2),
('2c949717-953d-5524-adf6-81cc41a6bf5f', '23a29661-d4ce-5978-8eab-bc89a84b3dee', 'd74ca643-9876-5e4b-aa5f-c034348faa37', 'ee32d3f9-8002-5d41-903a-80166282d862', 4, 2),
('bfc8652f-b35c-59b8-bfa5-38a26fba0bb6', '23a29661-d4ce-5978-8eab-bc89a84b3dee', '645449ba-11e0-5469-a654-975639fc2101', 'cdc95255-1c3c-5666-9296-bdb06af6e644', 5, 2),
('ad3fa12d-ff09-55dc-817e-670643691f4a', '23a29661-d4ce-5978-8eab-bc89a84b3dee', 'c1fe5ea1-6243-5065-ae2c-90ea8e05b207', '0ea832b1-840b-5c4e-9565-91142dfed5df', 6, 2),
('8f53779c-605d-5dc5-b86c-69e52610fde1', '23a29661-d4ce-5978-8eab-bc89a84b3dee', '05580832-45fd-5fef-a978-445141008d7d', 'a47dcb76-67d2-511e-bbbb-1980f2a67d45', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('3116d636-ac04-5bc8-9b29-9ab048aafae2', '27527dc6-807c-51bf-beb9-a499519888d9', '35aeeb53-49c4-50de-a1ec-f1b34e695109', 'Quiz: Big Picture & Fundamentals', 'assessment', 4, 10, '23a29661-d4ce-5978-8eab-bc89a84b3dee')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Running Containers
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('aafccd23-0abe-53b5-a951-5b01f113868c', '27527dc6-807c-51bf-beb9-a499519888d9', 'Running Containers', 2, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a178e7db-37ff-5eaa-ae37-875087041171', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Your First Containers: docker run', 'notes', 0, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7efd9428-1ac7-5426-a93e-a8d1c997cbb9', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Container Lifecycle: Stop, Kill, Restart and Exit Codes', 'notes', 1, $md$## Why this matters

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
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('742cdd1c-acd4-5809-a6c3-493026af4687', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Looking Inside: ps, logs, exec, inspect', 'notes', 2, $md$## Why this matters

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
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7c5d1a24-f9cb-5794-91a4-e34cf6c0fae6', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Ports and Environment Variables', 'notes', 3, $md$## Why this matters

A web server in a container is useless if nobody can reach it, and an app with a
hard-coded database password cannot move between dev and prod. Port publishing
and environment variables solve both. They are the two flags you will add to
almost every real `docker run`.

## Mental model: an office switchboard

The container has its own network, like an office with internal extensions.
Outsiders dial the **main number** (a host port). The switchboard forwards the
call to an **extension** (the container port).

```
browser --> localhost:8080 (host port)
                 |
                 |  -p 8080:80   "host 8080 forwards to container 80"
                 v
           container port 80  --> nginx
```

The flag reads **left = host (outside), right = container (inside)**:

```
-p HOST_PORT:CONTAINER_PORT
```

Mnemonic: **"outside:inside"**, the same order as `-v` for volumes later.

## See it work

### Publish a port

```bash
# Host port 8080 -> container port 80
docker run -d --name web -p 8080:80 nginx:1.27-alpine

# Which ports are published?
docker port web
```

Expected output of `docker port web`:

```
80/tcp -> 0.0.0.0:8080
```

Now `curl http://localhost:8080` (or a browser) shows the nginx welcome page.

Variations:

```bash
docker run -d -p 127.0.0.1:8080:80 nginx:1.27-alpine  # only reachable from this machine
docker run -d -p 8081:80/udp some-image               # UDP instead of TCP
docker run -d -P nginx:1.27-alpine                    # publish every EXPOSEd port to random host ports
```

`-p 8080:80` listens on **all** host interfaces (`0.0.0.0`), so it is reachable
from your network. Binding to `127.0.0.1` keeps a dev database private.

**EXPOSE vs publish:** a Dockerfile's `EXPOSE 80` is only **documentation** (and
the list `-P` uses). It does not open anything. Only `-p`/`-P` publishes.

### Pass environment variables

```bash
# -e sets one variable
docker run --rm -e GREETING=hello alpine:3.20 sh -c 'echo $GREETING'
```

Output: `hello`.

```bash
# --env-file loads many from a file (KEY=value per line)
printf 'APP_ENV=dev\nLOG_LEVEL=debug\n' > app.env
docker run --rm --env-file app.env alpine:3.20 env
```

Output includes `APP_ENV=dev` and `LOG_LEVEL=debug`.

```bash
# -e NAME without a value copies it from your shell
export API_TOKEN=abc123
docker run --rm -e API_TOKEN alpine:3.20 sh -c 'echo $API_TOKEN'
```

Output: `abc123`.

Many official images are configured entirely by env vars. For example:

```bash
docker run -d --name db -e POSTGRES_PASSWORD=devpass -p 127.0.0.1:5432:5432 postgres:16
```

## Try it

Run nginx so that it is reachable on host port **9000** but **only from your
own machine**, and set an env var `TEAM=blue` inside it. Then prove the env var is set.

<details>
<summary>Show answer</summary>

```bash
docker run -d --name blue -p 127.0.0.1:9000:80 -e TEAM=blue nginx:1.27-alpine
docker exec blue printenv TEAM        # prints: blue
curl -s localhost:9000 | head -n 4    # nginx page
```

</details>

## Common mistakes

- **Reversing the port order.** `-p 80:8080` maps host 80 to container 8080, where
  nothing listens. Remember: **outside:inside**.
- **"Port is already allocated".** Another container or host program already uses
  that host port. Pick another host port; the container port can stay the same.
- **App listens on `127.0.0.1` inside the container.** Then publishing cannot
  reach it, because the container's localhost is private. Make the app listen on `0.0.0.0`.
- **Secrets in `-e`.** Anyone who can run `docker inspect` sees them. Fine for
  dev; in production prefer secret files or a secrets manager (Section 7).

## Remember

- `-p HOST:CONTAINER` (outside:inside) publishes a port. `docker port` shows mappings.
- `EXPOSE` documents; `-p` publishes.
- `-e KEY=value`, `--env-file file`, and `-e KEY` (copy from shell) set env vars.
- Apps must listen on `0.0.0.0` inside the container to be reachable.

**Self-check:**

1. Write the flag to map host port 3000 to container port 8000.
2. Does `EXPOSE 80` in a Dockerfile make the port reachable from the host?
3. Why can `-e DB_PASSWORD=...` be a security problem?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('50cc2134-9259-58f1-b58c-e745804d8042', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Lab: Run, Stop, Exec and Inspect', 'notes', 4, $md$## Why this matters

Reading about `docker run` is not the same as typing it. This lab makes you use
the four lessons you just read: start a container, stop and remove one, go
inside one, and inspect one. Each task is checked automatically.

## Before you start: one sandbox rule

On a normal machine you would publish a port with `-p 8080:80` and open
`localhost:8080`. This lab's Docker daemon runs **inside** your sandbox, in its
own nested network, so `-p` does not reach the terminal you type in.

The workaround used in every lab of this course:

- Start containers with `--network host`. The container then shares the
  sandbox's network directly; no publishing needed.
- To check that a server answers, run a **second** throwaway container with
  `--network host` and fetch `http://127.0.0.1:PORT` from it. Both share one
  network, so `127.0.0.1` reaches the server.

```bash
# Pattern: "is the server on port 80 answering?"
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Everything else (`ps`, `logs`, `exec`, `inspect`, `stop`, `rm`) works exactly as
on any machine.

## Task 1: run a detached, named container

Recall lesson 1: `-d` for background, `--name` for a name.

```bash
docker run --name myserver -d --network host nginx:1.27-alpine
docker ps          # myserver should show "Up ..."
```

[[lab-task:1]]

## Task 2: stop and remove a container

Recall lesson 2: `stop` is polite (SIGTERM, then SIGKILL after a grace period),
`rm` deletes, `rm -f` does both.

```bash
docker run -d --network host --name tempbox alpine:3.20 sleep 3600
docker stop -t 1 tempbox     # stop with a 1-second grace period
docker rm tempbox            # delete it
docker ps -a                 # tempbox is gone
```

Two bulk patterns you will meet in real scripts (careful: they affect **every** container):

```bash
docker rm $(docker ps -q -f "status=exited")   # remove all stopped containers
docker rm -f $(docker ps -aq)                  # force-remove ALL containers
```

[[lab-task:2]]

## Task 3: go inside and read the logs

Recall lesson 3: `exec` runs an extra process in a running container; `logs`
shows the main process's stdout/stderr.

```bash
docker exec -it myserver sh          # interactive shell; type exit to leave
docker exec myserver sh -c "echo hello > /tmp/hello.txt"   # one-shot command
docker logs myserver                 # nginx startup lines
```

[[lab-task:3]]

## Task 4: inspect it and prove it serves

```bash
docker inspect myserver                          # full JSON
docker inspect -f '{{.State.Status}}' myserver   # just: running
docker container stats --no-stream               # live resource usage, one sample

# Confirm it is serving, from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Expected output of the last command: the HTML of the nginx welcome page,
containing `Welcome to nginx!`.

[[lab-task:4]]

## Remember

- Lab sandbox: `--network host` instead of `-p`; check servers from a second
  `--network host` container.
- Real machines: `-p HOST:CONTAINER` and `curl localhost:HOST`.
- `docker rm -f $(docker ps -aq)` removes **everything**. Use it only in sandboxes.
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f9f516ae-38a5-5f99-ac05-eecb4b3457a4', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '50cc2134-9259-58f1-b58c-e745804d8042', 'module', 'Lab: Run, Stop, Exec and Inspect', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '76a8d19f-7cf6-5751-91aa-ec3139d3db58' AND id NOT IN ('f0a35b0f-eb6c-50b1-9248-77f2e1fad366', '43b5ab0c-428d-55ad-a0d6-f141bda94a7d', '25f58c35-b87e-5f76-8686-b3f04c350978', '0b946792-cb44-56dd-a527-b0bbe1d99ff2');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '76a8d19f-7cf6-5751-91aa-ec3139d3db58';
DELETE FROM lab_tasks WHERE lab_id = 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4' AND id NOT IN ('305e159f-d3f1-5664-ba80-90a794042cac', '6ca687da-2d6c-5a4f-8d12-ef1bab717ef7', '6ad892e5-1554-57fb-bb9d-af5074f5ba3b', 'b7c3a69d-fde0-5f4d-96d8-887c936aa0f5');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('305e159f-d3f1-5664-ba80-90a794042cac', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 1, 'Run a detached, named container', $md$Start an nginx:1.27-alpine container named "myserver", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).$md$, $script$docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx
$script$, 'docker run has a flag for detached mode and one for naming — check the "Starting containers" examples above.', 'docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.', 10, false, false),
('6ca687da-2d6c-5a4f-8d12-ef1bab717ef7', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 2, 'Stop and remove a container', $md$Start a second container named "tempbox" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in "docker ps -a".$md$, $script$! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox \
  && docker events --since 6h --until "$(( $(date +%s) + 1 ))" --filter type=container --filter event=destroy --format '{{.Actor.Attributes.name}}' | grep -qx tempbox
$script$, 'docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.', 'docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container''s filesystem and metadata. docker rm -f does both in one step.', 10, false, false),
('6ad892e5-1554-57fb-bb9d-af5074f5ba3b', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 3, 'Exec into a container and check its logs', $md$Using "docker exec", create a file /tmp/hello.txt inside myserver containing the word "hello". Then view myserver's logs.$md$, $script$docker exec myserver test -f /tmp/hello.txt && docker exec myserver grep -q hello /tmp/hello.txt
$script$, 'docker exec myserver sh -c "echo hello > /tmp/hello.txt" runs a command inside the already-running container.', 'docker exec runs a new process inside a container that''s already running — unlike docker run, which always starts a fresh container. docker logs shows what the container''s main process has printed to stdout/stderr.', 10, false, false),
('b7c3a69d-fde0-5f4d-96d8-887c936aa0f5', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 4, 'Inspect the container and confirm it''s serving', $md$Use "docker inspect myserver" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox''s terminal can''t directly curl a container''s port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.', 'docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other''s ports directly via 127.0.0.1 — the pattern this sandbox uses to check "is it really serving," in place of curl-ing the terminal''s own localhost.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('76a8d19f-7cf6-5751-91aa-ec3139d3db58', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 1, $json$[{"id":"305e159f-d3f1-5664-ba80-90a794042cac","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":1,"title":"Run a detached, named container","description":"Start an nginx:1.27-alpine container named \"myserver\", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).","verification_script":"docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx\n","hint_context":"docker run has a flag for detached mode and one for naming — check the \"Starting containers\" examples above.","explanation_context":"docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.","points":10,"is_optional":false,"is_stateful":false},{"id":"6ca687da-2d6c-5a4f-8d12-ef1bab717ef7","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":2,"title":"Stop and remove a container","description":"Start a second container named \"tempbox\" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in \"docker ps -a\".","verification_script":"! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox \\\n  \u0026\u0026 docker events --since 6h --until \"$(( $(date +%s) + 1 ))\" --filter type=container --filter event=destroy --format '{{.Actor.Attributes.name}}' | grep -qx tempbox\n","hint_context":"docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.","explanation_context":"docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container's filesystem and metadata. docker rm -f does both in one step.","points":10,"is_optional":false,"is_stateful":false},{"id":"6ad892e5-1554-57fb-bb9d-af5074f5ba3b","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":3,"title":"Exec into a container and check its logs","description":"Using \"docker exec\", create a file /tmp/hello.txt inside myserver containing the word \"hello\". Then view myserver's logs.","verification_script":"docker exec myserver test -f /tmp/hello.txt \u0026\u0026 docker exec myserver grep -q hello /tmp/hello.txt\n","hint_context":"docker exec myserver sh -c \"echo hello \u003e /tmp/hello.txt\" runs a command inside the already-running container.","explanation_context":"docker exec runs a new process inside a container that's already running — unlike docker run, which always starts a fresh container. docker logs shows what the container's main process has printed to stdout/stderr.","points":10,"is_optional":false,"is_stateful":false},{"id":"b7c3a69d-fde0-5f4d-96d8-887c936aa0f5","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":4,"title":"Inspect the container and confirm it's serving","description":"Use \"docker inspect myserver\" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2\u003e/dev/null | grep -qi \"Welcome to nginx\"\n","hint_context":"docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox's terminal can't directly curl a container's port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.","explanation_context":"docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other's ports directly via 127.0.0.1 — the pattern this sandbox uses to check \"is it really serving,\" in place of curl-ing the terminal's own localhost.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f0a35b0f-eb6c-50b1-9248-77f2e1fad366', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', '305e159f-d3f1-5664-ba80-90a794042cac', 1, 'Run a detached, named container', $md$Start an nginx:1.27-alpine container named "myserver", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).$md$, $script$docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx
$script$, 'docker run has a flag for detached mode and one for naming — check the "Starting containers" examples above.', 'docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.', 10, false, false),
('43b5ab0c-428d-55ad-a0d6-f141bda94a7d', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', '6ca687da-2d6c-5a4f-8d12-ef1bab717ef7', 2, 'Stop and remove a container', $md$Start a second container named "tempbox" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in "docker ps -a".$md$, $script$! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox \
  && docker events --since 6h --until "$(( $(date +%s) + 1 ))" --filter type=container --filter event=destroy --format '{{.Actor.Attributes.name}}' | grep -qx tempbox
$script$, 'docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.', 'docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container''s filesystem and metadata. docker rm -f does both in one step.', 10, false, false),
('25f58c35-b87e-5f76-8686-b3f04c350978', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', '6ad892e5-1554-57fb-bb9d-af5074f5ba3b', 3, 'Exec into a container and check its logs', $md$Using "docker exec", create a file /tmp/hello.txt inside myserver containing the word "hello". Then view myserver's logs.$md$, $script$docker exec myserver test -f /tmp/hello.txt && docker exec myserver grep -q hello /tmp/hello.txt
$script$, 'docker exec myserver sh -c "echo hello > /tmp/hello.txt" runs a command inside the already-running container.', 'docker exec runs a new process inside a container that''s already running — unlike docker run, which always starts a fresh container. docker logs shows what the container''s main process has printed to stdout/stderr.', 10, false, false),
('0b946792-cb44-56dd-a527-b0bbe1d99ff2', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', 'b7c3a69d-fde0-5f4d-96d8-887c936aa0f5', 4, 'Inspect the container and confirm it''s serving', $md$Use "docker inspect myserver" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox''s terminal can''t directly curl a container''s port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.', 'docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other''s ports directly via 127.0.0.1 — the pattern this sandbox uses to check "is it really serving," in place of curl-ing the terminal''s own localhost.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '76a8d19f-7cf6-5751-91aa-ec3139d3db58', updated_at = now()
WHERE id = 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b9b25580-f1da-5867-91b9-0102884cf409', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Reference: Container Commands Cheat Sheet', 'notes', 5, $md$Use this page to **look things up**, not to learn from. Every command here was
explained in this section's lessons. Syntax: `docker [COMMAND] [OPTIONS] [CONTAINER]`.
Most commands also exist in the long form `docker container COMMAND`
(for example `docker container ls` = `docker ps`).

## Lifecycle

| Command | What it does |
|---|---|
| `docker create IMAGE` | Create a container but do not start it |
| `docker run IMAGE` | Create **and** start a container |
| `docker start NAME` | Start a stopped container |
| `docker stop NAME` | SIGTERM, wait 10 s (`-t N` to change), then SIGKILL |
| `docker restart NAME` | Stop then start |
| `docker pause` / `unpause NAME` | Freeze / thaw all processes |
| `docker kill NAME` | SIGKILL now (or `-s SIGNAL`) |
| `docker wait NAME` | Block until it stops, print exit code |
| `docker rm NAME` | Delete a stopped container (`-f` to force-stop first) |
| `docker update NAME` | Change resource limits or restart policy of a live container |
| `docker rename OLD NEW` | Rename a container |

## Inspect and interact

| Command | What it does |
|---|---|
| `docker ps` | List running containers (`-a` all, `-q` IDs only, `--filter`, `--format`) |
| `docker logs NAME` | stdout/stderr (`-f` follow, `--tail N`, `--since 10m`, `-t` timestamps) |
| `docker exec -it NAME sh` | Run a new process (shell) inside a running container |
| `docker attach NAME` | Connect your terminal to the main process (Ctrl+P Ctrl+Q detaches) |
| `docker inspect NAME` | Full JSON config/state (`-f '{{.State.Status}}'` for one field) |
| `docker top NAME` | Processes inside |
| `docker stats` | Live CPU/memory/network/IO (`--no-stream` for one sample) |
| `docker port NAME` | Published port mappings |
| `docker diff NAME` | Files added (A), changed (C), deleted (D) vs the image |
| `docker cp SRC DEST` | Copy files between container and host (`NAME:/path`) |
| `docker commit NAME IMAGE` | Snapshot a container into a new image (prefer Dockerfiles) |
| `docker export NAME > fs.tar` | Export a container's filesystem as a tar |

## Most-used `docker run` flags

| Flag | Meaning |
|---|---|
| `-d` | Detached (background) |
| `-it` | Interactive + terminal |
| `--name NAME` | Container name |
| `--rm` | Delete container when it exits |
| `-p HOST:CONTAINER` | Publish port (outside:inside); `-P` publishes all EXPOSEd ports |
| `-e KEY=VAL`, `--env-file F` | Environment variables |
| `-v SRC:DEST`, `--mount` | Volumes and bind mounts (Section 5) |
| `--network NAME` | Attach to a network (Section 5) |
| `-w /path` | Working directory |
| `--entrypoint CMD` | Override the image's ENTRYPOINT |
| `-u UID:GID` | Run as this user |
| `--restart POLICY` | `no`, `on-failure[:N]`, `always`, `unless-stopped` |
| `--memory`, `--cpus`, `--pids-limit` | Resource limits (Section 7) |
| `--read-only`, `--cap-drop`, `--security-opt` | Hardening (Section 7) |

## Handy one-liners

```bash
docker rm $(docker ps -q -f "status=exited")      # remove all stopped containers
docker rm -f $(docker ps -aq)                     # remove ALL containers (careful)
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"   # custom columns
docker inspect -f '{{.State.ExitCode}} {{.State.OOMKilled}}' NAME # why did it die?
docker run -it --rm --entrypoint sh IMAGE         # poke around an image's filesystem
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1-124 | Application error |
| 125 | `docker run` itself failed |
| 126 / 127 | Command not executable / not found |
| 137 | SIGKILL (kill or out of memory) |
| 143 | SIGTERM (normal `docker stop`) |
$md$, 5, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0ce9a916-a1ce-55fa-9029-de0f3f243054', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run `docker run -d ubuntu:24.04` and `docker ps` shows nothing. What happ...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9c951241-12b6-5025-bf2b-2be5fcbeb27d', '0ce9a916-a1ce-55fa-9029-de0f3f243054', 1, $json${"prompt":"You run `docker run -d ubuntu:24.04` and `docker ps` shows nothing. What happened?","multiple":false,"options":[{"id":"a","text":"The image failed to download","is_correct":false},{"id":"b","text":"The default command (bash) had no terminal attached, exited immediately, and the container stopped","is_correct":true},{"id":"c","text":"-d hides containers from docker ps","is_correct":false},{"id":"d","text":"Detached containers only appear in docker images","is_correct":false}],"explanation":"A container lives only as long as its main process. bash with no TTY or stdin exits at once. A failed download prints an error instead, -d does not hide containers, and docker images lists images, not containers. `docker ps -a` would show it as Exited (0)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('628ff669-4bed-5269-bc03-49ab79e62f07', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command correctly runs a throwaway Alpine container that prints the dat...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bb94115f-9b27-5d65-aaf7-747ff3756490', '628ff669-4bed-5269-bc03-49ab79e62f07', 1, $json${"prompt":"Which command correctly runs a throwaway Alpine container that prints the date and deletes itself afterwards?","multiple":false,"options":[{"id":"a","text":"docker run alpine:3.20 --rm date","is_correct":false},{"id":"b","text":"docker run --rm alpine:3.20 date","is_correct":true},{"id":"c","text":"docker exec --rm alpine:3.20 date","is_correct":false},{"id":"d","text":"docker start --rm alpine:3.20 date","is_correct":false}],"explanation":"Docker options must come before the image name; anything after the image is the container's command, so option 1 passes --rm to the container. exec works on existing running containers and start works on existing containers; neither creates one from an image."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9ffc2975-4333-5c93-acb4-492fba81b3ca', '00000000-0000-0000-0000-000000000001', 'mcq', 'Every `docker stop` of your app takes exactly 10 seconds and ends with exit c...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a1f46291-7c03-5dd8-8ed3-ad467b6dbd36', '9ffc2975-4333-5c93-acb4-492fba81b3ca', 1, $json${"prompt":"Every `docker stop` of your app takes exactly 10 seconds and ends with exit code 137. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"The app ignores SIGTERM, so Docker waits the grace period and then sends SIGKILL","is_correct":true},{"id":"b","text":"The container ran out of memory","is_correct":false},{"id":"c","text":"The restart policy is set to always","is_correct":false},{"id":"d","text":"The image is too large","is_correct":false}],"explanation":"10 seconds is the default stop grace period; 137 is 128+9 (SIGKILL). A clean SIGTERM exit would give 143 or 0 quickly. OOM would happen while running, not exactly at each stop. Restart policy and image size do not affect stop timing."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5765cb59-b340-5182-ae5b-400d48e782c8', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container keeps exiting. You want to see the error message it printed befor...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c4263a8f-ae2d-5b67-bd47-885c84402ea8', '5765cb59-b340-5182-ae5b-400d48e782c8', 1, $json${"prompt":"A container keeps exiting. You want to see the error message it printed before dying. What do you run?","multiple":false,"options":[{"id":"a","text":"docker exec -it NAME sh","is_correct":false},{"id":"b","text":"docker logs NAME","is_correct":true},{"id":"c","text":"docker attach NAME","is_correct":false},{"id":"d","text":"docker top NAME","is_correct":false}],"explanation":"docker logs shows stdout/stderr even for stopped containers. exec, attach and top all need a running container, so they fail on one that has exited."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('96efa14c-d6d3-59e0-9081-379819b1a06d', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want a browser on your laptop to reach nginx (listening on port 80 in the...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c9c30d35-5386-5a15-9f1c-6830e514598c', '96efa14c-d6d3-59e0-9081-379819b1a06d', 1, $json${"prompt":"You want a browser on your laptop to reach nginx (listening on port 80 in the container) at http://localhost:8080. Which flag is right?","multiple":false,"options":[{"id":"a","text":"-p 80:8080","is_correct":false},{"id":"b","text":"-p 8080:80","is_correct":true},{"id":"c","text":"--expose 8080","is_correct":false},{"id":"d","text":"-e PORT=8080","is_correct":false}],"explanation":"The order is HOST:CONTAINER (outside:inside). -p 80:8080 forwards to container port 8080 where nothing listens. --expose only documents a port, and an env var does not change which port nginx listens on."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('82eec972-d25f-58bd-8e7d-c2290c9fbd8b', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your Flask app inside a container works with `docker exec NAME curl localhost...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('be64699d-7bcb-5005-8204-86d72f2de625', '82eec972-d25f-58bd-8e7d-c2290c9fbd8b', 1, $json${"prompt":"Your Flask app inside a container works with `docker exec NAME curl localhost:5000`, but `-p 5000:5000` from the host gets 'connection reset'. Why?","multiple":false,"options":[{"id":"a","text":"Flask is listening on 127.0.0.1 inside the container, which is not reachable through port publishing","is_correct":true},{"id":"b","text":"Port 5000 is reserved by Docker","is_correct":false},{"id":"c","text":"You forgot EXPOSE 5000 in the Dockerfile","is_correct":false},{"id":"d","text":"Containers cannot publish ports above 1024","is_correct":false}],"explanation":"The container's localhost is private to the container. Published traffic arrives on the container's network interface, so the app must listen on 0.0.0.0. EXPOSE is documentation only, port 5000 is not reserved, and high ports publish fine."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e663a342-8f95-5223-bc98-e7913407cc8d', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want a database container to come back after crashes and after a server r...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d54da57d-483b-52e2-9b3b-582866183b75', 'e663a342-8f95-5223-bc98-e7913407cc8d', 1, $json${"prompt":"You want a database container to come back after crashes and after a server reboot, but stay down if an operator stops it on purpose. Which restart policy?","multiple":false,"options":[{"id":"a","text":"no","is_correct":false},{"id":"b","text":"on-failure","is_correct":false},{"id":"c","text":"always","is_correct":false},{"id":"d","text":"unless-stopped","is_correct":true}],"explanation":"unless-stopped restarts on crashes and on daemon start, but respects a manual stop. always comes back after a daemon restart even if stopped manually. on-failure ignores clean exits and the daemon-restart case for stopped containers. no never restarts."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('070a6e30-3c53-53be-99d7-f37fa31ed2f4', '00000000-0000-0000-0000-000000000001', 'mcq', '(Review: Fundamentals) Inside a container, `ps` shows only the container''s pr...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('593eeaa8-361f-5ebe-ae6d-0ec3ea1a70ac', '070a6e30-3c53-53be-99d7-f37fa31ed2f4', 1, $json${"prompt":"(Review: Fundamentals) Inside a container, `ps` shows only the container's processes, but `uname -r` matches the host. Which explanation is correct?","multiple":false,"options":[{"id":"a","text":"The pid namespace hides other processes; the kernel is shared with the host","is_correct":true},{"id":"b","text":"cgroups hide other processes; the container ships its own kernel","is_correct":false},{"id":"c","text":"The container is a VM with a copied kernel","is_correct":false},{"id":"d","text":"Docker rewrites the uname output","is_correct":false}],"explanation":"Namespaces control visibility (pid namespace), and containers share the host kernel, which is why uname matches. cgroups limit resource use, containers have no kernel of their own, and Docker does not fake uname."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('3da1dc7b-d05b-576c-91a8-bcaeaba02807', '00000000-0000-0000-0000-000000000001', 'Quiz: Running Containers', 'docker-container-commands-quiz', 'Quiz covering Running Containers.', 'mcq', 'published', 'module', '472312dd-6846-5e0d-b561-1510db9d6037', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '3da1dc7b-d05b-576c-91a8-bcaeaba02807' AND question_id NOT IN ('0ce9a916-a1ce-55fa-9029-de0f3f243054', '628ff669-4bed-5269-bc03-49ab79e62f07', '9ffc2975-4333-5c93-acb4-492fba81b3ca', '5765cb59-b340-5182-ae5b-400d48e782c8', '96efa14c-d6d3-59e0-9081-379819b1a06d', '82eec972-d25f-58bd-8e7d-c2290c9fbd8b', 'e663a342-8f95-5223-bc98-e7913407cc8d', '070a6e30-3c53-53be-99d7-f37fa31ed2f4');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('84de05bb-9b4a-5e3a-a25d-9e4187eab9ac', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', '0ce9a916-a1ce-55fa-9029-de0f3f243054', '9c951241-12b6-5025-bf2b-2be5fcbeb27d', 0, 2),
('3a6f2d8b-f665-5875-aba0-f6f8e7324091', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', '628ff669-4bed-5269-bc03-49ab79e62f07', 'bb94115f-9b27-5d65-aaf7-747ff3756490', 1, 2),
('9bbbde2a-b6d9-59a3-8475-97a8b8ed1bf1', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', '9ffc2975-4333-5c93-acb4-492fba81b3ca', 'a1f46291-7c03-5dd8-8ed3-ad467b6dbd36', 2, 2),
('64d61899-d12e-5970-ba39-0047f1e22391', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', '5765cb59-b340-5182-ae5b-400d48e782c8', 'c4263a8f-ae2d-5b67-bd47-885c84402ea8', 3, 2),
('95a883ca-2230-59b6-8024-f153028780de', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', '96efa14c-d6d3-59e0-9081-379819b1a06d', 'c9c30d35-5386-5a15-9f1c-6830e514598c', 4, 2),
('6f746498-752c-5882-82af-d1387b21400d', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', '82eec972-d25f-58bd-8e7d-c2290c9fbd8b', 'be64699d-7bcb-5005-8204-86d72f2de625', 5, 2),
('659f9ad6-227d-5ecd-97a0-ee7270cca8e6', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', 'e663a342-8f95-5223-bc98-e7913407cc8d', 'd54da57d-483b-52e2-9b3b-582866183b75', 6, 2),
('9269903e-dbad-5865-a6a7-c1388393e5a0', '3da1dc7b-d05b-576c-91a8-bcaeaba02807', '070a6e30-3c53-53be-99d7-f37fa31ed2f4', '593eeaa8-361f-5ebe-ae6d-0ec3ea1a70ac', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('472312dd-6846-5e0d-b561-1510db9d6037', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Quiz: Running Containers', 'assessment', 6, 12, '3da1dc7b-d05b-576c-91a8-bcaeaba02807')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Images & Layers
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('a78c1c7b-0f90-5144-98fd-18f96bedea51', '27527dc6-807c-51bf-beb9-a499519888d9', 'Images & Layers', 3, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6fdd3661-f499-56ea-aa73-720b41025027', '27527dc6-807c-51bf-beb9-a499519888d9', 'a78c1c7b-0f90-5144-98fd-18f96bedea51', 'What an Image Really Is: Layers and Copy-on-Write', 'notes', 0, $md$## Why this matters

Layers explain three things you will care about every day: why pulling a second
image is often almost instant, why your builds are fast or slow (Section 4), and
why deleting a file in a later step does **not** make an image smaller.

## Mental model: a stack of transparent sheets

Picture an overhead projector with transparent sheets stacked on top of each
other. Each sheet adds or covers some drawings. Looking from the top, you see
one combined picture.

An image is a stack of read-only **layers**. Each layer is a set of file
changes (added, changed, deleted files). Docker merges them into one view
using a **union filesystem** (on Linux, the `overlay2` storage driver).

```
            container view (what the process sees)
   +---------------------------------------------+
   | writable container layer   (per container)  |  <- your changes go here
   +=============================================+
   | layer 3: COPY app.py /app       (read-only)  |
   | layer 2: RUN pip install flask  (read-only)  |  image
   | layer 1: python:3.12-slim base  (read-only)  |  (shared)
   +---------------------------------------------+
```

When a container starts, Docker adds one thin **writable layer** on top.

**Copy-on-write (CoW):** when the container modifies a file that lives in a
lower read-only layer, Docker first **copies** that file up into the writable
layer, then changes the copy. The original stays untouched for everyone else.

> **One-sentence definition.** An image is an ordered stack of read-only file-change
> layers plus metadata (default command, env vars, ports); a container is that
> stack plus one writable layer.

Two big consequences:

1. **Sharing.** Ten containers from the same image share the same read-only
   layers on disk. Only their thin writable layers differ.
2. **Layers are content-addressed.** Each layer is identified by a SHA-256 hash
   of its content (a **digest**). If two images use the same base layer,
   Docker stores and downloads it once.

## See it work

```bash
docker pull python:3.12-alpine
```

Expected output (shortened):

```
3.12-alpine: Pulling from library/python
1f3e46996e29: Pull complete
...
Digest: sha256:...
Status: Downloaded newer image for python:3.12-alpine
```

Each `Pull complete` line is **one layer**. If you already have some layers
(for example the same Alpine base), you see `Already exists` instead.

```bash
# Show the layers and the instruction that created each
docker history python:3.12-alpine
```

Output (shortened; dates, IDs and sizes vary):

```
IMAGE          CREATED        CREATED BY                                      SIZE
2893cf9f584f   4 months ago   CMD ["python3"]                                 0B
<missing>      4 months ago   RUN /bin/sh -c set -eux;   apk add --no-cach…   39.5MB
...
<missing>      4 months ago   CMD ["/bin/sh"]                                 0B
<missing>      4 months ago   ADD alpine-minirootfs-3.24.1-x86_64.tar.gz /…   8.42MB
```

Read it bottom to top: base filesystem first, newest instruction on top.
Instructions like `CMD` or `ENV` create **0B** entries: they change metadata only.
`<missing>` just means that layer was built elsewhere; it is normal.

### See copy-on-write

```bash
docker run -d --name cow nginx:1.27-alpine
docker exec cow sh -c "echo changed >> /etc/nginx/nginx.conf"
docker diff cow
```

Output includes:

```
C /etc
C /etc/nginx
C /etc/nginx/nginx.conf
```

`C` = changed. The file was copied up into `cow`'s writable layer. Start a new
container from the same image and its `nginx.conf` is the original.

### Size on disk

```bash
docker ps -s --filter name=cow
```

The `SIZE` column shows something like `1.2kB (virtual 48.2MB)`: the writable
layer is tiny; the "virtual" part is the shared image.

## Try it

A Dockerfile does `RUN download-1GB-dataset.sh` and then, in the next line,
`RUN rm -rf /dataset`. Is the final image about 1 GB smaller than without the
`rm`? Explain using layers.

<details>
<summary>Show answer</summary>

No. The 1 GB lives in the first `RUN` layer forever. The second `RUN` only adds a
layer that marks the files as deleted (a "whiteout"). The container cannot see
them, but they are still shipped and stored. Fix: download, use and delete in
**the same** `RUN` step, or use a multi-stage build (Section 4).

</details>

## Common mistakes

- **Deleting files in a later layer to "save space".** It hides them, it does not
  remove them (see Try it).
- **Writing heavy data into the container layer.** CoW makes big writes slow and
  the data dies with the container. Use volumes for data.
- **Thinking every image costs its full size on disk.** Shared layers are stored once.
  `docker system df` shows the real total.

## Remember

- Image = stack of read-only layers + metadata. Container = image + one writable layer.
- Union filesystem (`overlay2`) merges layers into one view.
- Copy-on-write: modifying a lower-layer file copies it up first.
- Layers are content-addressed (SHA-256), so identical layers are shared and downloaded once.
- Files deleted in a later layer still take space.

**Self-check:**

1. What does `docker history` show, and in which order?
2. What happens, step by step, when a container edits a file from the image?
3. Why does pulling a second Alpine-based image often finish faster?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7ce61692-fdb2-5280-b68e-30fd5dce6533', '27527dc6-807c-51bf-beb9-a499519888d9', 'a78c1c7b-0f90-5144-98fd-18f96bedea51', 'Image Names, Tags and Digests', 'notes', 1, $md$## Why this matters

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
# human-readable tag + exact content
FROM alpine:3.20@sha256:<digest>
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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('697257e9-c37f-5e19-a1ed-f971bd9c3640', '27527dc6-807c-51bf-beb9-a499519888d9', 'a78c1c7b-0f90-5144-98fd-18f96bedea51', 'Moving Images: pull, push, save, load', 'notes', 2, $md$## Why this matters

An image built on your laptop is only useful once it reaches a server. Most of
the time that means a registry (`push`/`pull`). Sometimes there is no network
at all: an air-gapped factory, a secure lab. Then you carry the image as a file
(`save`/`load`).

## Mental model: two ways to send a parcel

```
  Via a registry (post office)           As a file (hand delivery)
  ---------------------------            -------------------------
  laptop: docker push  ---> registry     laptop: docker save -o app.tar
  server: docker pull  <--- registry     copy app.tar on a USB stick
                                         server: docker load -i app.tar
  only missing layers travel             the whole image travels
```

Do not confuse **save/load** with **export/import**:

| Pair | Works on | Keeps |
|---|---|---|
| `docker save` / `docker load` | **Images** | All layers, tags, history, metadata (CMD, ENV, ...) |
| `docker export` / `docker import` | **Containers** → image | One flattened filesystem only; metadata and history are lost |

Mnemonic: **S**ave is for **S**tacks of layers; **E**xport is for **E**verything flattened.

## See it work

### Registry round trip

```bash
docker login                               # Docker Hub; prompts for user and token
docker tag myimage:latest myuser/myimage:1.0   # name it for your namespace
docker push myuser/myimage:1.0             # upload only layers the registry lacks
docker pull myuser/myimage:1.0             # on another machine
docker search nginx                        # search Docker Hub from the CLI
docker logout
```

You must tag an image with the **registry/namespace** prefix before pushing.
Section 6 practices this against a private registry.

### Save and load

```bash
docker save -o myimage.tar myimage:latest   # image -> tar file
ls -lh myimage.tar
docker rmi myimage:latest                   # remove it locally
docker load -i myimage.tar                  # tar file -> image
```

Expected output of `load`:

```
Loaded image: myimage:latest
```

Save several images into one file: `docker save -o bundle.tar img1:1 img2:1`.
Compress if you like: `docker save myimage:latest | gzip > myimage.tar.gz`
(`docker load` reads gzip directly).

### Inspect before you ship

```bash
docker image inspect myimage:latest                       # full JSON
docker image inspect -f '{{.Config.Cmd}}' myimage:latest  # default command
docker image inspect -f '{{.Architecture}}' myimage:latest # amd64 or arm64?
```

### Export and import (rarely needed)

```bash
docker export mycontainer > fs.tar        # a container's flattened filesystem
docker import fs.tar myflat:1             # becomes a one-layer image, no CMD
```

The imported image has no default command, so you must give one: `docker run myflat:1 sh`.

## Try it

You must move `shop-api:2.0` (with its `CMD` and `ENV` settings intact) to a
server with no internet. Write the commands on both machines.

<details>
<summary>Show answer</summary>

```bash
# laptop
docker save -o shop-api-2.0.tar shop-api:2.0
# copy the file over (scp, USB, ...)
# server
docker load -i shop-api-2.0.tar
docker run -d shop-api:2.0
```

Not `export`/`import`: that would drop `CMD`, `ENV` and the layer history.

</details>

## Common mistakes

- **Pushing without the namespace.** `docker push myimage` tries
  `docker.io/library/myimage`, which you are not allowed to write to:
  *"denied: requested access to the resource is denied"*. Tag `myuser/myimage` first.
- **Using `export` to back up an image.** It works on containers and loses metadata.
- **Shipping an `amd64` image to an ARM server.** It fails with *"exec format error"*.
  Check `.Architecture`, or build multi-platform images (Section 4).
- **Logging in with your account password.** Use a personal access token instead.

## Remember

- Registry: `tag` with prefix → `push` → `pull`. Only missing layers travel.
- Offline: `save -o file.tar` → copy → `load -i file.tar`. Keeps everything.
- `export`/`import` flattens a **container** and drops metadata.
- `docker image inspect` tells you the command, env and architecture before you ship.

**Self-check:**

1. What is the difference between `save` and `export`?
2. Why does `docker push myimage` fail on Docker Hub?
3. What does "exec format error" usually mean?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8688da8c-d6a3-53d3-9307-8f12ab174b02', '27527dc6-807c-51bf-beb9-a499519888d9', 'a78c1c7b-0f90-5144-98fd-18f96bedea51', 'Lab: Build, Tag, Save and Load Images', 'notes', 3, $md$## Why this matters

This lab practises the image life cycle you just read about: build an image,
give it a second tag, carry it through a tar file, and remove one tag without
losing the image. Each task is checked automatically.

## The image you will use

A minimal Dockerfile. You will learn every instruction properly in Section 4;
for now, read it as "start from Alpine, and by default print a message".

```dockerfile
FROM alpine:3.20
CMD ["echo", "hello from myimage"]
```

## Task 1: build an image

```bash
cd ~/work
printf 'FROM alpine:3.20\nCMD ["echo", "hello from myimage"]\n' > Dockerfile

# Build from the Dockerfile in "." and name (tag) the result myimage:latest
docker build --network=host -t myimage:latest .

docker images myimage            # it is listed
docker history myimage:latest    # its layers (lesson 1)
docker run --rm myimage:latest   # prints: hello from myimage
```

**Sandbox note:** any `RUN` step in a Dockerfile starts a temporary build
container. In this nested sandbox that needs `--network=host`, the same reason
running containers here needs `--network host`. This Dockerfile has no `RUN`,
so the flag is optional here; keep it as a habit in labs. On a normal machine
you would just type `docker build -t myimage:latest .`

Two more build flags worth knowing:

```bash
docker build -t myimage:latest --no-cache .           # ignore the build cache
docker build -t myuser/myimage:1.0 path/to/context    # tag with a namespace, other folder
```

[[lab-task:1]]

## Task 2: add a second tag

Recall lesson 2: a tag is a pointer; `docker tag` makes no copy.

```bash
docker tag myimage:latest myimage:v1
docker images myimage     # two rows, SAME image ID
```

[[lab-task:2]]

## Task 3: save to a file and load it back

Recall lesson 3: `save`/`load` move a whole image (layers + metadata) as a tar file.

```bash
docker save -o ~/work/myimage.tar myimage:latest
ls -lh ~/work/myimage.tar
docker load -i ~/work/myimage.tar     # prints: Loaded image: myimage:latest
```

[[lab-task:3]]

## Task 4: remove one tag, keep the image

```bash
docker rmi myimage:v1          # prints: Untagged: myimage:v1
docker images myimage          # only latest remains, same ID as before
docker image prune             # optional: delete dangling <none> images
```

[[lab-task:4]]

## Remember

- `docker build -t name:tag .` turns a Dockerfile into an image.
- `docker tag` adds a pointer; `docker rmi` removes one. Layers go with the last pointer.
- `docker save`/`docker load` carry an image without a registry.
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('176a62d7-cf17-5b81-8d01-33a4ee89f337', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '8688da8c-d6a3-53d3-9307-8f12ab174b02', 'module', 'Lab: Build, Tag, Save and Load Images', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 45, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '692dc45a-14ec-5424-8980-133670eadf3a' AND id NOT IN ('02f2c660-aa82-5e61-9364-42269a124067', 'e74ed747-e9c8-5d19-b9f0-34d359f669cf', 'f3add46e-e435-5012-80d0-b79caa23fbd8', '8befac48-7dda-5630-9914-b5d9c8ba3fbd');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '692dc45a-14ec-5424-8980-133670eadf3a';
DELETE FROM lab_tasks WHERE lab_id = '176a62d7-cf17-5b81-8d01-33a4ee89f337' AND id NOT IN ('37a3255e-1fe8-5ff7-9ab1-e5fd12999a68', 'e7421f17-a57e-5997-809a-7e884f01cbfc', 'c05a2aab-4c1e-5a1e-b9ce-7a79f5c500b8', '22a9dcf5-0c19-5cba-a156-8239c75fd4e2');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '176a62d7-cf17-5b81-8d01-33a4ee89f337';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('37a3255e-1fe8-5ff7-9ab1-e5fd12999a68', '176a62d7-cf17-5b81-8d01-33a4ee89f337', 1, 'Build an image from a Dockerfile', $md$Write the Dockerfile from the example above to ~/work/Dockerfile and build it as myimage:latest.$md$, $script$docker image inspect myimage:latest >/dev/null 2>&1
$script$, 'docker build --network=host -t myimage:latest . builds using the Dockerfile in the current directory (--network=host is this sandbox''s requirement for any build step that starts a container internally — see the note below the examples).', 'docker build reads a Dockerfile and produces a new image, layer by layer. -t names (tags) the resulting image so you can reference it later.', 10, false, false),
('e7421f17-a57e-5997-809a-7e884f01cbfc', '176a62d7-cf17-5b81-8d01-33a4ee89f337', 2, 'Tag an image with a second reference', $md$Create a second tag, myimage:v1, pointing at the same image as myimage:latest.$md$, $script$docker image inspect myimage:v1 >/dev/null 2>&1
$script$, 'docker tag doesn''t copy anything — it just adds another name pointing at the same image content.', 'An image can have any number of tags pointing at the same underlying layers. docker tag myimage:latest myimage:v1 makes "v1" a second name for the exact same image.', 10, false, false),
('c05a2aab-4c1e-5a1e-b9ce-7a79f5c500b8', '176a62d7-cf17-5b81-8d01-33a4ee89f337', 3, 'Export an image to a tarball and reload it', $md$Save myimage:latest to ~/work/myimage.tar with "docker save", then load it back with "docker load".$md$, $script$test -f /home/labuser/work/myimage.tar && docker image inspect myimage:latest >/dev/null 2>&1
$script$, 'docker save -o myimage.tar myimage:latest writes the tarball; docker load -i myimage.tar reads it back in.', 'docker save/load round-trips an image through a plain .tar file — no registry needed. This is how you''d move an image to a machine with no network access at all.', 10, false, false),
('22a9dcf5-0c19-5cba-a156-8239c75fd4e2', '176a62d7-cf17-5b81-8d01-33a4ee89f337', 4, 'Remove one tag without deleting the image', $md$Remove the myimage:v1 tag with "docker rmi", while myimage:latest keeps working.$md$, $script$! docker image inspect myimage:v1 >/dev/null 2>&1 && docker image inspect myimage:latest >/dev/null 2>&1
$script$, 'docker rmi myimage:v1 removes only that tag — the underlying image stays as long as another tag (myimage:latest) still references it.', 'docker rmi removes a tag reference, not necessarily the image data. The image''s layers are only actually deleted once its last tag is removed (or you use docker image prune for dangling/untagged ones).', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('692dc45a-14ec-5424-8980-133670eadf3a', '176a62d7-cf17-5b81-8d01-33a4ee89f337', 1, $json$[{"id":"37a3255e-1fe8-5ff7-9ab1-e5fd12999a68","lab_id":"176a62d7-cf17-5b81-8d01-33a4ee89f337","position":1,"title":"Build an image from a Dockerfile","description":"Write the Dockerfile from the example above to ~/work/Dockerfile and build it as myimage:latest.","verification_script":"docker image inspect myimage:latest \u003e/dev/null 2\u003e\u00261\n","hint_context":"docker build --network=host -t myimage:latest . builds using the Dockerfile in the current directory (--network=host is this sandbox's requirement for any build step that starts a container internally — see the note below the examples).","explanation_context":"docker build reads a Dockerfile and produces a new image, layer by layer. -t names (tags) the resulting image so you can reference it later.","points":10,"is_optional":false,"is_stateful":false},{"id":"e7421f17-a57e-5997-809a-7e884f01cbfc","lab_id":"176a62d7-cf17-5b81-8d01-33a4ee89f337","position":2,"title":"Tag an image with a second reference","description":"Create a second tag, myimage:v1, pointing at the same image as myimage:latest.","verification_script":"docker image inspect myimage:v1 \u003e/dev/null 2\u003e\u00261\n","hint_context":"docker tag doesn't copy anything — it just adds another name pointing at the same image content.","explanation_context":"An image can have any number of tags pointing at the same underlying layers. docker tag myimage:latest myimage:v1 makes \"v1\" a second name for the exact same image.","points":10,"is_optional":false,"is_stateful":false},{"id":"c05a2aab-4c1e-5a1e-b9ce-7a79f5c500b8","lab_id":"176a62d7-cf17-5b81-8d01-33a4ee89f337","position":3,"title":"Export an image to a tarball and reload it","description":"Save myimage:latest to ~/work/myimage.tar with \"docker save\", then load it back with \"docker load\".","verification_script":"test -f /home/labuser/work/myimage.tar \u0026\u0026 docker image inspect myimage:latest \u003e/dev/null 2\u003e\u00261\n","hint_context":"docker save -o myimage.tar myimage:latest writes the tarball; docker load -i myimage.tar reads it back in.","explanation_context":"docker save/load round-trips an image through a plain .tar file — no registry needed. This is how you'd move an image to a machine with no network access at all.","points":10,"is_optional":false,"is_stateful":false},{"id":"22a9dcf5-0c19-5cba-a156-8239c75fd4e2","lab_id":"176a62d7-cf17-5b81-8d01-33a4ee89f337","position":4,"title":"Remove one tag without deleting the image","description":"Remove the myimage:v1 tag with \"docker rmi\", while myimage:latest keeps working.","verification_script":"! docker image inspect myimage:v1 \u003e/dev/null 2\u003e\u00261 \u0026\u0026 docker image inspect myimage:latest \u003e/dev/null 2\u003e\u00261\n","hint_context":"docker rmi myimage:v1 removes only that tag — the underlying image stays as long as another tag (myimage:latest) still references it.","explanation_context":"docker rmi removes a tag reference, not necessarily the image data. The image's layers are only actually deleted once its last tag is removed (or you use docker image prune for dangling/untagged ones).","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('02f2c660-aa82-5e61-9364-42269a124067', '692dc45a-14ec-5424-8980-133670eadf3a', '37a3255e-1fe8-5ff7-9ab1-e5fd12999a68', 1, 'Build an image from a Dockerfile', $md$Write the Dockerfile from the example above to ~/work/Dockerfile and build it as myimage:latest.$md$, $script$docker image inspect myimage:latest >/dev/null 2>&1
$script$, 'docker build --network=host -t myimage:latest . builds using the Dockerfile in the current directory (--network=host is this sandbox''s requirement for any build step that starts a container internally — see the note below the examples).', 'docker build reads a Dockerfile and produces a new image, layer by layer. -t names (tags) the resulting image so you can reference it later.', 10, false, false),
('e74ed747-e9c8-5d19-b9f0-34d359f669cf', '692dc45a-14ec-5424-8980-133670eadf3a', 'e7421f17-a57e-5997-809a-7e884f01cbfc', 2, 'Tag an image with a second reference', $md$Create a second tag, myimage:v1, pointing at the same image as myimage:latest.$md$, $script$docker image inspect myimage:v1 >/dev/null 2>&1
$script$, 'docker tag doesn''t copy anything — it just adds another name pointing at the same image content.', 'An image can have any number of tags pointing at the same underlying layers. docker tag myimage:latest myimage:v1 makes "v1" a second name for the exact same image.', 10, false, false),
('f3add46e-e435-5012-80d0-b79caa23fbd8', '692dc45a-14ec-5424-8980-133670eadf3a', 'c05a2aab-4c1e-5a1e-b9ce-7a79f5c500b8', 3, 'Export an image to a tarball and reload it', $md$Save myimage:latest to ~/work/myimage.tar with "docker save", then load it back with "docker load".$md$, $script$test -f /home/labuser/work/myimage.tar && docker image inspect myimage:latest >/dev/null 2>&1
$script$, 'docker save -o myimage.tar myimage:latest writes the tarball; docker load -i myimage.tar reads it back in.', 'docker save/load round-trips an image through a plain .tar file — no registry needed. This is how you''d move an image to a machine with no network access at all.', 10, false, false),
('8befac48-7dda-5630-9914-b5d9c8ba3fbd', '692dc45a-14ec-5424-8980-133670eadf3a', '22a9dcf5-0c19-5cba-a156-8239c75fd4e2', 4, 'Remove one tag without deleting the image', $md$Remove the myimage:v1 tag with "docker rmi", while myimage:latest keeps working.$md$, $script$! docker image inspect myimage:v1 >/dev/null 2>&1 && docker image inspect myimage:latest >/dev/null 2>&1
$script$, 'docker rmi myimage:v1 removes only that tag — the underlying image stays as long as another tag (myimage:latest) still references it.', 'docker rmi removes a tag reference, not necessarily the image data. The image''s layers are only actually deleted once its last tag is removed (or you use docker image prune for dangling/untagged ones).', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '692dc45a-14ec-5424-8980-133670eadf3a', updated_at = now()
WHERE id = '176a62d7-cf17-5b81-8d01-33a4ee89f337' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('13c86bc6-6732-574c-a3c6-8f85d66482f6', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Dockerfile downloads a 2 GB file in one RUN step and deletes it in the next...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d496c7ac-fe83-53bb-af02-a7e43628ee8a', '13c86bc6-6732-574c-a3c6-8f85d66482f6', 1, $json${"prompt":"A Dockerfile downloads a 2 GB file in one RUN step and deletes it in the next RUN step. Why is the image still about 2 GB larger?","multiple":false,"options":[{"id":"a","text":"Docker caches downloads in a hidden folder","is_correct":false},{"id":"b","text":"The first RUN layer still contains the file; the later layer only hides it with a whiteout","is_correct":true},{"id":"c","text":"rm does not work inside Docker builds","is_correct":false},{"id":"d","text":"The deletion only applies when the container starts","is_correct":false}],"explanation":"Layers are immutable and stacked. A later layer can only mask files from earlier layers, not remove their bytes. There is no hidden download cache, rm works fine, and image layers are fixed at build time. Fix: download, use and delete in one RUN, or use multi-stage builds."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a3a08153-18fd-5fc5-9a9a-560efae0df49', '00000000-0000-0000-0000-000000000001', 'mcq', 'Twenty containers run from the same 300 MB image. Roughly how much disk do th...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d13146a2-0187-5df2-ab5f-e6a4d721c1e3', 'a3a08153-18fd-5fc5-9a9a-560efae0df49', 1, $json${"prompt":"Twenty containers run from the same 300 MB image. Roughly how much disk do the image layers use?","multiple":false,"options":[{"id":"a","text":"6 GB (20 x 300 MB)","is_correct":false},{"id":"b","text":"About 300 MB, plus each container's small writable layer","is_correct":true},{"id":"c","text":"Nothing; layers are streamed from the registry","is_correct":false},{"id":"d","text":"300 MB per running container, 0 for stopped ones","is_correct":false}],"explanation":"Read-only layers are shared by every container from that image; each container adds only its own thin writable layer. Layers are stored locally, not streamed, and stopped containers still keep their writable layers."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('199f262f-b55d-5f82-b184-2af730c5009c', '00000000-0000-0000-0000-000000000001', 'mcq', 'Inside a running container you edit /etc/app.conf, a file that came from the ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b6c8c01d-a77f-5733-9a5f-9843e592b56a', '199f262f-b55d-5f82-b184-2af730c5009c', 1, $json${"prompt":"Inside a running container you edit /etc/app.conf, a file that came from the image. What does Docker do?","multiple":false,"options":[{"id":"a","text":"Edits the file in the image, affecting all containers","is_correct":false},{"id":"b","text":"Copies the file into the container's writable layer and edits the copy","is_correct":true},{"id":"c","text":"Refuses because image files are read-only","is_correct":false},{"id":"d","text":"Creates a new image automatically","is_correct":false}],"explanation":"This is copy-on-write: the file is copied up to the writable layer first. The image is never changed by a container, the write is allowed, and new images are only created by build or commit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('59ac388a-7259-5f52-bcab-b2703dc37f96', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does the image reference `redis` expand to?', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cc1f4450-27a8-5606-954b-cbc9b208ba83', '59ac388a-7259-5f52-bcab-b2703dc37f96', 1, $json${"prompt":"What does the image reference `redis` expand to?","multiple":false,"options":[{"id":"a","text":"redis:newest from the closest mirror","is_correct":false},{"id":"b","text":"docker.io/library/redis:latest","is_correct":true},{"id":"c","text":"localhost/redis:stable","is_correct":false},{"id":"d","text":"hub.docker.com/redis:1","is_correct":false}],"explanation":"Defaults are registry docker.io, namespace library (official images) and tag latest. There is no 'newest' or 'stable' default, and hub.docker.com is the website, not the registry host."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('beb8e4ef-e3cb-510d-8b2e-dadab24bd549', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your team wants a deploy to run byte-for-byte the same image that passed CI, ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d69c73e3-aa8b-5f82-a2cd-af7b90a8a806', 'beb8e4ef-e3cb-510d-8b2e-dadab24bd549', 1, $json${"prompt":"Your team wants a deploy to run byte-for-byte the same image that passed CI, even if someone re-pushes the tag. What should the deploy reference?","multiple":false,"options":[{"id":"a","text":"myapp:latest","is_correct":false},{"id":"b","text":"myapp:1.4","is_correct":false},{"id":"c","text":"myapp@sha256:\u003cdigest from CI\u003e","is_correct":true},{"id":"d","text":"The image ID shown by docker images","is_correct":false}],"explanation":"A digest is a content hash, so it cannot point to different bytes. Tags, including version tags and latest, are movable pointers. The local image ID is not a registry reference other machines can pull."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('279aa067-ffa8-50c4-8fc4-ecb0aeeaa832', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run `docker tag app:1.0 app:stable` and then `docker rmi app:stable`. Wha...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('eb8cda68-8e04-5c0d-a1f6-55acc27997b7', '279aa067-ffa8-50c4-8fc4-ecb0aeeaa832', 1, $json${"prompt":"You run `docker tag app:1.0 app:stable` and then `docker rmi app:stable`. What happens to app:1.0?","multiple":false,"options":[{"id":"a","text":"It is deleted too because they share layers","is_correct":false},{"id":"b","text":"Nothing; only the stable tag is removed","is_correct":true},{"id":"c","text":"It becomes a dangling \u003cnone\u003e image","is_correct":false},{"id":"d","text":"docker rmi fails because the image has two tags","is_correct":false}],"explanation":"docker tag only adds a pointer, and docker rmi removes that pointer. Layers are deleted only when the last reference is gone. A dangling image is one with no tags at all, which is not the case here."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('de64278c-27af-5e40-bd90-21a76c36f493', '00000000-0000-0000-0000-000000000001', 'mcq', 'You must move an image with its CMD and ENV intact to an air-gapped server. W...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('85087c44-db73-592f-b878-4e870bd0bdac', 'de64278c-27af-5e40-bd90-21a76c36f493', 1, $json${"prompt":"You must move an image with its CMD and ENV intact to an air-gapped server. Which pair of commands?","multiple":false,"options":[{"id":"a","text":"docker export / docker import","is_correct":false},{"id":"b","text":"docker save / docker load","is_correct":true},{"id":"c","text":"docker commit / docker push","is_correct":false},{"id":"d","text":"docker cp / docker run","is_correct":false}],"explanation":"save/load keep layers, tags and metadata. export/import flatten a container's filesystem and drop CMD/ENV. push needs a reachable registry, and docker cp copies individual files, not images."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ca69cb6a-9565-5a0e-92ad-a5afbbe8ff84', '00000000-0000-0000-0000-000000000001', 'mcq', '(Review: Running Containers) A container built from your image exits with cod...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1b5c745b-e81a-5a63-afe0-7d43429786fe', 'ca69cb6a-9565-5a0e-92ad-a5afbbe8ff84', 1, $json${"prompt":"(Review: Running Containers) A container built from your image exits with code 127 right after start. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"Out of memory","is_correct":false},{"id":"b","text":"The command in CMD/ENTRYPOINT is not found in the image","is_correct":true},{"id":"c","text":"Docker stop timed out","is_correct":false},{"id":"d","text":"The port is already allocated","is_correct":false}],"explanation":"127 is the shell's 'command not found'. OOM shows as 137, a stop timeout ends in 137 too, and a port conflict makes docker run fail before the container starts (exit 125 from the CLI)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('68c1c574-d743-5f71-8cad-f3d4d79d50f7', '00000000-0000-0000-0000-000000000001', 'Quiz: Images & Layers', 'docker-image-commands-quiz', 'Quiz covering Images & Layers.', 'mcq', 'published', 'module', 'fce64ff8-0530-5470-bf41-a46815ca2e8a', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '68c1c574-d743-5f71-8cad-f3d4d79d50f7' AND question_id NOT IN ('13c86bc6-6732-574c-a3c6-8f85d66482f6', 'a3a08153-18fd-5fc5-9a9a-560efae0df49', '199f262f-b55d-5f82-b184-2af730c5009c', '59ac388a-7259-5f52-bcab-b2703dc37f96', 'beb8e4ef-e3cb-510d-8b2e-dadab24bd549', '279aa067-ffa8-50c4-8fc4-ecb0aeeaa832', 'de64278c-27af-5e40-bd90-21a76c36f493', 'ca69cb6a-9565-5a0e-92ad-a5afbbe8ff84');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('f390e4c4-1a9a-58a9-9296-6bbb5440f1b4', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', '13c86bc6-6732-574c-a3c6-8f85d66482f6', 'd496c7ac-fe83-53bb-af02-a7e43628ee8a', 0, 2),
('5666f407-8ec2-5dbe-920c-3de9556faa24', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', 'a3a08153-18fd-5fc5-9a9a-560efae0df49', 'd13146a2-0187-5df2-ab5f-e6a4d721c1e3', 1, 2),
('aa1840fc-f62e-504b-8414-de9a32ad09aa', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', '199f262f-b55d-5f82-b184-2af730c5009c', 'b6c8c01d-a77f-5733-9a5f-9843e592b56a', 2, 2),
('9a849d97-b654-5123-97b1-a0b1cf2ff8f5', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', '59ac388a-7259-5f52-bcab-b2703dc37f96', 'cc1f4450-27a8-5606-954b-cbc9b208ba83', 3, 2),
('23a644f9-9dd6-5fed-9236-a605f557c1e4', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', 'beb8e4ef-e3cb-510d-8b2e-dadab24bd549', 'd69c73e3-aa8b-5f82-a2cd-af7b90a8a806', 4, 2),
('b307c5be-91ce-5f8d-a1b3-68f960fd49bc', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', '279aa067-ffa8-50c4-8fc4-ecb0aeeaa832', 'eb8cda68-8e04-5c0d-a1f6-55acc27997b7', 5, 2),
('2c68cfe5-ed2d-5913-a870-bf63ca715755', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', 'de64278c-27af-5e40-bd90-21a76c36f493', '85087c44-db73-592f-b878-4e870bd0bdac', 6, 2),
('4578968c-4d6f-5787-ad9a-111dcc2d7026', '68c1c574-d743-5f71-8cad-f3d4d79d50f7', 'ca69cb6a-9565-5a0e-92ad-a5afbbe8ff84', '1b5c745b-e81a-5a63-afe0-7d43429786fe', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('fce64ff8-0530-5470-bf41-a46815ca2e8a', '27527dc6-807c-51bf-beb9-a499519888d9', 'a78c1c7b-0f90-5144-98fd-18f96bedea51', 'Quiz: Images & Layers', 'assessment', 4, 12, '68c1c574-d743-5f71-8cad-f3d4d79d50f7')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Writing Dockerfiles
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('18aaecad-38b6-53ef-86ff-4ed976c8bbad', '27527dc6-807c-51bf-beb9-a499519888d9', 'Writing Dockerfiles', 4, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('83aa82b8-4d05-5c58-b28f-8b9f20e1dd7a', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'Your First Dockerfile: FROM, WORKDIR, COPY, RUN, CMD', 'notes', 0, $md$## Why this matters

Pulling other people's images only gets you so far. To ship **your** app you
write a Dockerfile: a short text file that says exactly how to build your
image. Five instructions are enough for most real apps.

## Mental model: a recipe executed top to bottom

A **Dockerfile** is a recipe. `docker build` follows it line by line, and every
instruction that changes files produces a new **layer** (Section 3).

```
Dockerfile                     image layers (bottom = first)
----------                     -----------------------------
FROM python:3.12-slim   --->   [ base image layers        ]
WORKDIR /app            --->   [ create /app              ]
COPY requirements.txt . --->   [ requirements.txt         ]
RUN pip install -r ...  --->   [ installed packages       ]
COPY . .                --->   [ your source code         ]
CMD ["python","app.py"] --->   metadata only (no files)
```

The five core instructions:

| Instruction | Plain meaning | Runs when? |
|---|---|---|
| `FROM` | Start from this base image | Build |
| `WORKDIR` | `cd` into this folder (creates it if missing) | Build (and sets start folder) |
| `COPY` | Copy files from your project into the image | Build |
| `RUN` | Run a shell command and save the result as a layer | Build |
| `CMD` | Default command when a container starts | **Run** (container start) |

The single most important distinction: **`RUN` happens at build time, once.
`CMD` happens at container start, every time.**

## See it work

A tiny Python web app. Create a folder with three files:

`app.py`:

```python
from http.server import HTTPServer, SimpleHTTPRequestHandler
print("serving on 8000", flush=True)
HTTPServer(("0.0.0.0", 8000), SimpleHTTPRequestHandler).serve_forever()
```

`requirements.txt` (empty is fine for this example, real apps list packages here).

`Dockerfile`:

```dockerfile
# 1. Base image: Python already installed, small Debian userland
FROM python:3.12-slim

# 2. All following paths are relative to /app
WORKDIR /app

# 3. Copy the dependency list first (lesson 4 explains why)
COPY requirements.txt .

# 4. Install dependencies at build time; --no-cache-dir keeps the layer small
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy the rest of the source code
COPY . .

# 6. Document the port the app listens on (does not publish it)
EXPOSE 8000

# 7. What runs when a container starts
CMD ["python", "app.py"]
```

Build and run:

```bash
docker build -t pyweb:1.0 .
docker run -d --name pyweb -p 8000:8000 pyweb:1.0
docker logs pyweb            # serving on 8000
curl -s localhost:8000 | head -n 3
```

Build output shows one numbered step per instruction:

```
 => [1/5] FROM docker.io/library/python:3.12-slim
 => [2/5] WORKDIR /app
 => [3/5] COPY requirements.txt .
 => [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [5/5] COPY . .
 => naming to docker.io/library/pyweb:1.0
```

### The build context and `.dockerignore`

The `.` at the end of `docker build -t pyweb:1.0 .` is the **build context**:
the folder whose files Docker may `COPY`. Everything in it is sent to the
builder. Exclude what the image should not contain with a `.dockerignore` file,
which works like `.gitignore`:

```
.git
node_modules
__pycache__
*.log
.env
```

This makes builds faster and stops secrets (`.env`) and junk from leaking into images.

## Try it

Write a Dockerfile for a static website in `site/` served by nginx. The nginx
image serves files from `/usr/share/nginx/html` and already has a default `CMD`.

<details>
<summary>Show answer</summary>

```dockerfile
FROM nginx:1.27-alpine
COPY site/ /usr/share/nginx/html/
EXPOSE 80
```

No `CMD` needed: it is inherited from the base image. Build with
`docker build -t mysite .` and run with `docker run -d -p 8080:80 mysite`.

</details>

## Common mistakes

- **Using `RUN` to start the app.** `RUN python app.py` runs during the build (and
  hangs it). Use `CMD` for what runs at container start.
- **`RUN cd /app`.** Each `RUN` is a fresh shell; the `cd` is forgotten on the
  next line. Use `WORKDIR`.
- **No `.dockerignore`.** Your `.git` folder, local `node_modules` and `.env` secrets end up in the image.
- **Comments at the end of a line.** `#` starts a comment only at the **start**
  of a line. `USER app  # comment` makes Docker read `# comment` as part of the
  instruction. Put comments on their own line.
- **`COPY` paths outside the context.** `COPY ../shared .` fails: only files inside
  the build context are visible.

## Remember

- `FROM` → `WORKDIR` → `COPY` → `RUN` → `CMD` covers most apps.
- `RUN` = build time, once. `CMD` = container start, every time.
- Each file-changing instruction = one layer.
- The build context (the `.`) is all `COPY` can see; trim it with `.dockerignore`.

**Self-check:**

1. Why does `RUN cd /app` not work as expected?
2. What is the build context?
3. Which instruction sets the default command, and when does it run?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e7c368fe-5d6f-5a54-8d3f-3a6540400ee5', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'CMD vs ENTRYPOINT, Shell Form vs Exec Form', 'notes', 1, $md$## Why this matters

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
# shell form
CMD python app.py
# exec form (a JSON array)
CMD ["python", "app.py"]
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
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4d5f4a7e-858d-5844-b7c7-f3395b2f839c', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'ENV, ARG, USER, COPY vs ADD and the Other Instructions', 'notes', 2, $md$## Why this matters

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
# ARG before FROM can parameterise the base image
ARG PY_VERSION=3.12
FROM python:${PY_VERSION}-slim

# ARG after FROM: usable in the following RUN steps
ARG APP_VERSION=dev
# Baked in; containers see these
ENV APP_ENV=production \
    PORT=8000
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
# everything after, and the container, runs as app
USER app
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
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('071c024b-3911-5ad2-ad69-b128b9e30631', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'The Build Cache: Why Instruction Order Matters', 'notes', 3, $md$## Why this matters

The same app can take 4 minutes or 4 seconds to rebuild. The difference is
almost always the order of a few lines in the Dockerfile. Fast rebuilds mean
fast feedback and cheaper CI.

## Mental model: a row of dominoes

Docker caches every layer. On a rebuild it walks the Dockerfile from the top
and asks, for each instruction: "Have I built exactly this before, on top of
exactly the same parent?" If yes, it reuses the cached layer (`CACHED`).

The moment one instruction misses the cache, **every instruction after it is
rebuilt too**. Like dominoes: one falls, all later ones fall.

```
FROM python:3.12-slim          CACHED
WORKDIR /app                   CACHED
COPY . .                       <-- you edited app.py: MISS
RUN pip install -r req.txt     rebuilt (slow!) even though req.txt is unchanged
CMD [...]                      rebuilt
```

How Docker decides "same as before":

- `RUN`: the **command text** is the same (it does not re-check the internet).
- `COPY`/`ADD`: the **checksums of the copied files** are the same.
- Everything: the **parent layer** is the same.

## The golden rule

**Order instructions from least-often-changed to most-often-changed.**
Copy dependency manifests and install dependencies **before** copying source code.

## See it work

Slow version:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
# any code edit invalidates this...
COPY . .
RUN pip install --no-cache-dir -r requirements.txt   # ...so this reruns every time
CMD ["python", "app.py"]
```

Fast version:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
# changes rarely
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt   # cached until requirements change
# changes often; cheap to redo
COPY . .
CMD ["python", "app.py"]
```

Edit `app.py` and rebuild the fast version:

```bash
docker build -t pyweb:dev .
```

Expected output (shortened):

```
 => CACHED [2/5] WORKDIR /app
 => CACHED [3/5] COPY requirements.txt .
 => CACHED [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [5/5] COPY . .
```

Only the last `COPY` reran. The same pattern applies everywhere:

| Stack | Copy first | Install | Then copy the rest |
|---|---|---|---|
| Node | `package.json package-lock.json` | `npm ci` | `COPY . .` |
| Python | `requirements.txt` (or `pyproject.toml` + lock) | `pip install` | `COPY . .` |
| Go | `go.mod go.sum` | `go mod download` | `COPY . .` |

### Combine install and cleanup in one RUN

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```

Why one line: `apt-get update` alone in its own cached layer can go stale, and a
later `apt-get install` would then use an old package index. Cleaning up in the
same `RUN` also keeps the deleted files out of the layer (Section 3).

### Forcing a rebuild

```bash
docker build --no-cache -t pyweb:dev .     # ignore the cache entirely
docker build --pull -t pyweb:dev .         # also re-check the base image for updates
```

Use these for security-patch builds: a cached `RUN apt-get upgrade` never re-runs by itself.

## Try it

This Node Dockerfile rebuilds `npm ci` on every code change. Reorder it.

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY . .
RUN npm ci
CMD ["node", "server.js"]
```

<details>
<summary>Show answer</summary>

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
CMD ["node", "server.js"]
```

Also add `node_modules` to `.dockerignore`, so `COPY . .` does not overwrite the
installed modules with your local ones.

</details>

## Common mistakes

- **`COPY . .` before installing dependencies.** Every edit reinstalls everything.
- **`RUN apt-get update` on its own line.** Stale package index later.
- **Expecting the cache to notice upstream changes.** `RUN curl ...` or
  `RUN pip install flask` (unpinned) is cached forever by its text. Pin versions;
  use `--no-cache`/`--pull` for refresh builds.
- **Volatile values early.** `ARG BUILD_TIME` used near the top busts the cache for everything below.

## Remember

- Cache hit = same instruction text (or same file checksums) on the same parent.
- One miss rebuilds everything below it.
- Least-changed first: manifests → install → source code.
- `apt-get update && install && cleanup` in one `RUN`.
- `--no-cache` and `--pull` force fresh builds.

**Self-check:**

1. How does Docker decide a `COPY` step is cached?
2. Why copy `package.json` separately from the rest of the code?
3. Why won't a cached `RUN apt-get upgrade -y` pick up new security patches?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1a0b1a96-0b7a-5908-9df1-7251a89e96d8', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'Multi-Stage Builds: Small, Clean Images', 'notes', 4, $md$## Why this matters

Building an app needs compilers, dev dependencies and source code. Running it
needs none of that. A Go service built the naive way can produce a ~800 MB image;
with a multi-stage build the same service ships in ~10 MB. Smaller images pull
faster, start faster and give attackers fewer tools.

## Mental model: the workshop and the delivery van

You build furniture in a **workshop** full of saws and glue. You deliver only
the finished chair in a **van**. You never ship the workshop.

```
  Stage "build" (workshop)                Final stage (van)
  ------------------------                -----------------
  FROM golang:1.23 AS build               FROM gcr.io/distroless/static
  compilers, source, caches   --COPY-->   just the binary
  ~800 MB, thrown away                    ~10 MB, shipped
```

A Dockerfile can contain several `FROM` lines. Each `FROM` starts a new
**stage**. Only the **last** stage becomes the image, unless you choose
another with `--target`. `COPY --from=<stage>` pulls files out of an earlier stage.

## See it work

### Go: compile, then ship only the binary

```dockerfile
# ---- Stage 1: build ----
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download                     # cached dependency layer
COPY . .
RUN CGO_ENABLED=0 go build -o /out/server .   # static binary

# ---- Stage 2: run ----
FROM gcr.io/distroless/static-debian12
COPY --from=build /out/server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

Line by line:

- `AS build` names the first stage.
- `CGO_ENABLED=0` makes a static binary that needs no C libraries at run time.
- `distroless/static` contains no shell and no package manager: almost nothing to attack.
- `COPY --from=build` takes one file from the build stage. Everything else is discarded.

```bash
docker build -t goapp:1.0 .
docker images goapp
```

Expected: a size in the low tens of MB, not hundreds.

### Node: install with dev tools, ship production deps only

```dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS build
COPY . .
RUN npm run build                       # needs dev dependencies

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev                   # production deps only
COPY --from=build /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

### Static site: build with Node, serve with nginx

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY . .
RUN npm ci && npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
```

### Useful extras

```bash
docker build --target build -t goapp:debug .   # stop at the "build" stage (for tests/debugging)
```

```dockerfile
# copy from any image, not just a stage
COPY --from=nginx:1.27-alpine /etc/nginx/nginx.conf /tmp/
```

With BuildKit (the default builder), stages the final image does not need are
skipped, and independent stages build in parallel.

### Picking the final base image

| Base | Size | Has a shell? | Good for |
|---|---|---|---|
| `debian:bookworm-slim`, `python:3.12-slim` | ~30-130 MB | Yes | Apps needing glibc and debugging tools |
| `alpine` | ~8 MB | Yes (busybox) | Small images; uses musl libc (rare compatibility issues) |
| `gcr.io/distroless/*`, Chainguard images | ~2-30 MB | No | Hardened production runtimes |
| `scratch` | 0 MB | No | Fully static binaries only |

## Try it

A Python image includes `gcc` because one dependency compiles a C extension.
Sketch a two-stage Dockerfile that keeps `gcc` out of the final image.

<details>
<summary>Show answer</summary>

```dockerfile
FROM python:3.12-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends gcc \
 && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim
COPY --from=build /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels
COPY . /app
WORKDIR /app
CMD ["python", "app.py"]
```

Build wheels where the compiler lives; install the prebuilt wheels in a clean stage.

</details>

## Common mistakes

- **Copying the whole build stage** (`COPY --from=build / /`). You ship the workshop again.
- **Dynamic binary on `scratch`/distroless static.** Fails with *"no such file or
  directory"* because libc is missing. Build static (`CGO_ENABLED=0`) or use a base with libc.
- **No shell to debug distroless.** Use `--target build` for debugging, or
  `docker debug` / an ephemeral debug container, instead of adding a shell to production.
- **Musl surprises on Alpine** (DNS quirks, slower Python wheels). Use `-slim` if it bites.

## Remember

- Several `FROM` lines = several stages; only the last one ships.
- `COPY --from=stage` takes just the artifacts you need.
- Build tools, source and caches stay behind: smaller and safer images.
- `--target NAME` builds an intermediate stage.
- Final base: slim → alpine → distroless → scratch, from most to least convenient.

**Self-check:**

1. What decides which stage becomes the final image?
2. Why is a distroless or scratch final stage more secure?
3. What does `--target` do?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1ca73668-d795-59ca-a6ee-a23b57b3d520', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'BuildKit and buildx: Cache Mounts, Secrets, Multi-Platform', 'notes', 5, $md$## Why this matters

Modern Docker builds run on **BuildKit**, the build engine that has been the
default since Docker Engine 23. It adds three features you will want in real
projects: package caches that survive rebuilds, secrets that never land in an
image, and one build that produces images for both Intel and ARM machines.

## Mental model: a smarter workshop manager

The old builder ran instructions one by one and only knew "layer cache: hit or
miss". BuildKit is a manager who:

- builds independent stages **in parallel** and skips unused ones,
- keeps a **toolbox shelf** (cache mounts) that is not part of any layer,
- hands over **keys** (secrets) for one step and takes them back,
- can build for **other CPU types**.

`docker build` already uses BuildKit. `docker buildx` is the CLI plugin that
exposes all of its options (builders, platforms, cache export).

## See it work

### 1. Cache mounts: keep package downloads between builds

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

When `requirements.txt` changes, the `RUN` step reruns (the layer cache missed),
but pip finds already-downloaded packages in `/root/.cache/pip`. The cache
directory is **not** stored in the image.

Common targets: `/root/.npm` (npm), `/go/pkg/mod` and `/root/.cache/go-build` (Go),
`/var/cache/apt` (apt).

### 2. Secret mounts: use a token without baking it in

```dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci
```

```bash
docker build --secret id=npmrc,src=$HOME/.npmrc -t web:1.0 .
```

The file exists only while that `RUN` executes. It is not in any layer, not in
`docker history`. Compare with `ARG NPM_TOKEN`, which is visible to anyone with the image.

SSH keys work the same way: `RUN --mount=type=ssh git clone git@github.com:org/private.git`
with `docker build --ssh default .`.

### 3. Multi-platform images

```bash
# One-time: create a builder that can target several platforms
docker buildx create --name multi --use

# Build for Intel and ARM, push both under one tag
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myuser/web:1.0 --push .
```

The registry stores an **image index** (a manifest list). An ARM server pulling
`myuser/web:1.0` automatically gets the `arm64` variant. Non-native platforms
build under QEMU emulation (slower) or on a remote native builder.

### 4. Sharing cache in CI

CI machines start empty, so nothing is cached. Export and import the build cache:

```bash
docker buildx build \
  --cache-from type=registry,ref=myuser/web:buildcache \
  --cache-to   type=registry,ref=myuser/web:buildcache,mode=max \
  -t myuser/web:1.0 --push .
```

(GitHub Actions can also use `type=gha`.)

### 5. Handy everyday flags

```bash
docker build --progress=plain .        # full, uncollapsed logs (great for debugging)
docker build --target test .           # build only up to a stage
docker builder prune                   # clear the build cache
docker buildx du                       # how much space the build cache uses
```

### The syntax directive

The first line of a Dockerfile may pin the Dockerfile language version:

```dockerfile
# syntax=docker/dockerfile:1
```

This tells BuildKit to fetch the latest stable 1.x Dockerfile frontend, which
enables newer features (for example heredocs: `RUN <<EOF ... EOF`) even on an older
engine. It needs network access to fetch the frontend image. Basic `RUN --mount`
already works without it on current engines.

## Try it

Your CI build installs 400 npm packages from scratch on every run and uses an
`ARG GITHUB_TOKEN` to fetch a private package. Name the two BuildKit features
that fix speed and safety.

<details>
<summary>Show answer</summary>

1. **Cache** (`RUN --mount=type=cache,target=/root/.npm` for local reuse, plus
   `--cache-to/--cache-from` so CI runners share layer cache).
2. **Secret mount** (`RUN --mount=type=secret,id=gh ...` and
   `docker build --secret id=gh,env=GITHUB_TOKEN`) so the token never lands in the image.

</details>

## Common mistakes

- **Expecting cache mount contents in the image.** They are deliberately excluded;
  copy what you need into a normal path.
- **Secrets through `ARG`/`ENV`.** Use `--secret`.
- **Building on an M-series Mac and deploying to amd64 servers** without
  `--platform linux/amd64`: *exec format error* in production.
- **Setting `DOCKER_BUILDKIT=0`** to "fix" something. The legacy builder is deprecated; fix the Dockerfile instead.

## Remember

- BuildKit is the default builder; `docker buildx` exposes everything.
- `RUN --mount=type=cache` keeps package caches across builds, outside the image.
- `RUN --mount=type=secret` / `--ssh` give credentials to one step only.
- `--platform linux/amd64,linux/arm64 --push` builds multi-arch images.
- `--cache-to/--cache-from` share cache between CI runs.

**Self-check:**

1. Where does a cache mount's data live: in the image or outside it?
2. Why is `--secret` safer than `--build-arg` for a token?
3. What does an ARM server get when it pulls a multi-platform tag?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e473f1c5-c300-5a6f-bdd3-84e5c2d8ff24', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'Lab: Write, Build and Run a Dockerfile', 'notes', 6, $md$## Why this matters

You have read how `RUN`, `CMD`, layers and the cache work. Now write a
Dockerfile, build it, and prove the result serves your own page. Each task is
checked automatically.

## The Dockerfile

A custom nginx image that serves a page baked in at build time:

```dockerfile
# Base image: nginx already installed and configured
FROM nginx:1.27-alpine

# Build time: write a custom page into the image (this becomes a layer)
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html

# Documentation: the container listens on 80
EXPOSE 80

# No CMD needed: nginx:1.27-alpine already sets one that starts nginx in the foreground
```

Recall from lesson 1: `RUN` executes **once, at build time**, and its result is
saved in a layer. `CMD`/`ENTRYPOINT` decide what runs **at container start**
and add no files.

## Task 1: write the Dockerfile

The quickest way from a plain shell is a heredoc:

```bash
cd ~/work
cat > Dockerfile <<'EOF'
FROM nginx:1.27-alpine
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html
EXPOSE 80
EOF
cat Dockerfile     # check it
```

[[lab-task:1]]

## Task 2: build the image

```bash
cd ~/work
docker build --network=host -t mysite:latest .
docker history mysite:latest    # your RUN line is the newest layer
```

**Sandbox note:** the `RUN` step starts a temporary build container, and in
this nested sandbox that needs `--network=host`. On a normal machine:
`docker build -t mysite:latest .`

Build it a second time and notice every step says `CACHED` (lesson 4).

[[lab-task:2]]

## Task 3: run it and confirm your page

```bash
# Sandbox: --network host instead of -p (see the Running Containers lab)
docker run -d --name mysite --network host mysite:latest

# Fetch the page from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Expected output:

```
<h1>Built from a Dockerfile</h1>
```

On a normal machine you would run `docker run -d -p 8080:80 mysite` and open
`http://localhost:8080`.

[[lab-task:3]]

## Remember

- Write → build → run → verify is the loop for every image you make.
- `RUN` bakes results into the image; `CMD` is inherited from the base if you do not set one.
- A second identical build is fully `CACHED`.
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('066ee5fe-29dd-5dce-b852-52ee85e60bca', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', 'e473f1c5-c300-5a6f-bdd3-84e5c2d8ff24', 'module', 'Lab: Write, Build and Run a Dockerfile', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 40, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '84b8359d-5354-597c-ad45-437228d9bf6e' AND id NOT IN ('8e7ed849-abb9-5247-b888-9aeb6af4ef63', '8a246782-83ae-56de-8625-d5920537b000', '9bce8d2a-2114-54d6-96ba-88f0ee0b66c6');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '84b8359d-5354-597c-ad45-437228d9bf6e';
DELETE FROM lab_tasks WHERE lab_id = '066ee5fe-29dd-5dce-b852-52ee85e60bca' AND id NOT IN ('4c0968e9-2015-59d5-8cec-5441943f6eb7', 'a8f224be-119c-545b-9485-3fa2b02f2742', '5e297ce4-f570-5a40-8de6-0c73f35c9c7f');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '066ee5fe-29dd-5dce-b852-52ee85e60bca';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4c0968e9-2015-59d5-8cec-5441943f6eb7', '066ee5fe-29dd-5dce-b852-52ee85e60bca', 1, 'Write the Dockerfile', $md$Write the example Dockerfile above to ~/work/Dockerfile — FROM nginx:1.27-alpine, a RUN that writes a custom index.html, and EXPOSE 80.$md$, $script$test -f /home/labuser/work/Dockerfile && grep -q "FROM nginx" /home/labuser/work/Dockerfile
$script$, 'Use a heredoc or your terminal''s editor to write the file — cat > Dockerfile <<''EOF'' ... EOF is the quickest way from a plain shell.', 'FROM sets the base image every later instruction builds on top of. RUN executes once at build time and bakes its result into a new layer — that''s how the custom index.html ends up baked into the image itself, not written at container-start time.', 10, false, false),
('a8f224be-119c-545b-9485-3fa2b02f2742', '066ee5fe-29dd-5dce-b852-52ee85e60bca', 2, 'Build the image', $md$Build the Dockerfile in ~/work as mysite:latest.$md$, $script$docker image inspect mysite:latest >/dev/null 2>&1
$script$, 'docker build --network=host -t mysite:latest . builds using the Dockerfile in the current directory — cd into ~/work first. --network=host is needed because this Dockerfile''s RUN instruction starts an internal build-time container, same as running any container in this sandbox.', 'docker build reads your Dockerfile top to bottom, executing each instruction as a new layer — RUN specifically does this inside its own temporary container. The result is a new, immutable image tagged mysite:latest.', 10, false, false),
('5e297ce4-f570-5a40-8de6-0c73f35c9c7f', '066ee5fe-29dd-5dce-b852-52ee85e60bca', 3, 'Run it and confirm it serves your page', $md$Run mysite:latest detached with --network host, then confirm it's serving your custom page using a second --network host container.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
$script$, 'docker run -d --name mysite --network host mysite:latest starts it; docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80 reaches it from a second host-networked container.', 'This sandbox''s Docker runs inside its own nested network, so the terminal itself can''t curl a container''s port directly — two --network host containers share the same network stack as each other, so one can reach the other via 127.0.0.1. That''s the pattern this whole course uses in place of the usual "just curl localhost" you''d do on a normal machine.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('84b8359d-5354-597c-ad45-437228d9bf6e', '066ee5fe-29dd-5dce-b852-52ee85e60bca', 1, $json$[{"id":"4c0968e9-2015-59d5-8cec-5441943f6eb7","lab_id":"066ee5fe-29dd-5dce-b852-52ee85e60bca","position":1,"title":"Write the Dockerfile","description":"Write the example Dockerfile above to ~/work/Dockerfile — FROM nginx:1.27-alpine, a RUN that writes a custom index.html, and EXPOSE 80.","verification_script":"test -f /home/labuser/work/Dockerfile \u0026\u0026 grep -q \"FROM nginx\" /home/labuser/work/Dockerfile\n","hint_context":"Use a heredoc or your terminal's editor to write the file — cat \u003e Dockerfile \u003c\u003c'EOF' ... EOF is the quickest way from a plain shell.","explanation_context":"FROM sets the base image every later instruction builds on top of. RUN executes once at build time and bakes its result into a new layer — that's how the custom index.html ends up baked into the image itself, not written at container-start time.","points":10,"is_optional":false,"is_stateful":false},{"id":"a8f224be-119c-545b-9485-3fa2b02f2742","lab_id":"066ee5fe-29dd-5dce-b852-52ee85e60bca","position":2,"title":"Build the image","description":"Build the Dockerfile in ~/work as mysite:latest.","verification_script":"docker image inspect mysite:latest \u003e/dev/null 2\u003e\u00261\n","hint_context":"docker build --network=host -t mysite:latest . builds using the Dockerfile in the current directory — cd into ~/work first. --network=host is needed because this Dockerfile's RUN instruction starts an internal build-time container, same as running any container in this sandbox.","explanation_context":"docker build reads your Dockerfile top to bottom, executing each instruction as a new layer — RUN specifically does this inside its own temporary container. The result is a new, immutable image tagged mysite:latest.","points":10,"is_optional":false,"is_stateful":false},{"id":"5e297ce4-f570-5a40-8de6-0c73f35c9c7f","lab_id":"066ee5fe-29dd-5dce-b852-52ee85e60bca","position":3,"title":"Run it and confirm it serves your page","description":"Run mysite:latest detached with --network host, then confirm it's serving your custom page using a second --network host container.","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2\u003e/dev/null | grep -q \"Built from a Dockerfile\"\n","hint_context":"docker run -d --name mysite --network host mysite:latest starts it; docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80 reaches it from a second host-networked container.","explanation_context":"This sandbox's Docker runs inside its own nested network, so the terminal itself can't curl a container's port directly — two --network host containers share the same network stack as each other, so one can reach the other via 127.0.0.1. That's the pattern this whole course uses in place of the usual \"just curl localhost\" you'd do on a normal machine.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('8e7ed849-abb9-5247-b888-9aeb6af4ef63', '84b8359d-5354-597c-ad45-437228d9bf6e', '4c0968e9-2015-59d5-8cec-5441943f6eb7', 1, 'Write the Dockerfile', $md$Write the example Dockerfile above to ~/work/Dockerfile — FROM nginx:1.27-alpine, a RUN that writes a custom index.html, and EXPOSE 80.$md$, $script$test -f /home/labuser/work/Dockerfile && grep -q "FROM nginx" /home/labuser/work/Dockerfile
$script$, 'Use a heredoc or your terminal''s editor to write the file — cat > Dockerfile <<''EOF'' ... EOF is the quickest way from a plain shell.', 'FROM sets the base image every later instruction builds on top of. RUN executes once at build time and bakes its result into a new layer — that''s how the custom index.html ends up baked into the image itself, not written at container-start time.', 10, false, false),
('8a246782-83ae-56de-8625-d5920537b000', '84b8359d-5354-597c-ad45-437228d9bf6e', 'a8f224be-119c-545b-9485-3fa2b02f2742', 2, 'Build the image', $md$Build the Dockerfile in ~/work as mysite:latest.$md$, $script$docker image inspect mysite:latest >/dev/null 2>&1
$script$, 'docker build --network=host -t mysite:latest . builds using the Dockerfile in the current directory — cd into ~/work first. --network=host is needed because this Dockerfile''s RUN instruction starts an internal build-time container, same as running any container in this sandbox.', 'docker build reads your Dockerfile top to bottom, executing each instruction as a new layer — RUN specifically does this inside its own temporary container. The result is a new, immutable image tagged mysite:latest.', 10, false, false),
('9bce8d2a-2114-54d6-96ba-88f0ee0b66c6', '84b8359d-5354-597c-ad45-437228d9bf6e', '5e297ce4-f570-5a40-8de6-0c73f35c9c7f', 3, 'Run it and confirm it serves your page', $md$Run mysite:latest detached with --network host, then confirm it's serving your custom page using a second --network host container.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
$script$, 'docker run -d --name mysite --network host mysite:latest starts it; docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80 reaches it from a second host-networked container.', 'This sandbox''s Docker runs inside its own nested network, so the terminal itself can''t curl a container''s port directly — two --network host containers share the same network stack as each other, so one can reach the other via 127.0.0.1. That''s the pattern this whole course uses in place of the usual "just curl localhost" you''d do on a normal machine.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '84b8359d-5354-597c-ad45-437228d9bf6e', updated_at = now()
WHERE id = '066ee5fe-29dd-5dce-b852-52ee85e60bca' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3afb2453-2a2b-587a-8e42-d2ef98e457a0', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'Reference: Dockerfile and Build Cheat Sheet', 'notes', 7, $md$Use this page to **look things up**. Every item was explained in this section.

## Instructions

| Instruction | Runs at | What it does |
|---|---|---|
| `FROM image[:tag] [AS name]` | Build | Base image; starts a new stage |
| `ARG NAME[=default]` | Build | Build-time variable (`--build-arg`); not in containers |
| `ENV KEY=value` | Build + run | Environment variable baked into the image |
| `WORKDIR /path` | Build + run | Working directory for later instructions and the container |
| `COPY [--from=stage] [--chown=u:g] src dest` | Build | Copy files from the context (or a stage/image) |
| `ADD src dest` | Build | Like COPY, plus auto-extracts local tarballs and fetches URLs |
| `RUN cmd` | Build | Run a command, commit the result as a layer |
| `RUN --mount=type=cache\|secret\|ssh,...` | Build | BuildKit mounts for caches and credentials |
| `USER name[:group]` | Build + run | User for later instructions and the container |
| `EXPOSE port[/proto]` | Metadata | Documents a port; `-P` publishes it |
| `VOLUME /path` | Run | Anonymous volume created at that path |
| `LABEL key=value` | Metadata | Image metadata (`org.opencontainers.image.*`) |
| `CMD ["exe", "arg"]` | Run | Default command / default ENTRYPOINT args; last one wins |
| `ENTRYPOINT ["exe"]` | Run | The program the container always runs |
| `HEALTHCHECK CMD ...` | Run | Health probe (Section 7) |
| `STOPSIGNAL SIGNAL` | Run | Signal `docker stop` sends |
| `SHELL ["bash", "-c"]` | Build | Shell for shell-form instructions |
| `ONBUILD INSTRUCTION` | Child build | Deferred instruction for images built `FROM` this one |
| `MAINTAINER` | - | Deprecated; use `LABEL org.opencontainers.image.authors` |

## Build commands

| Command | What it does |
|---|---|
| `docker build -t name:tag .` | Build from `./Dockerfile` with `.` as the context |
| `docker build -f path/Dockerfile .` | Use a different Dockerfile |
| `docker build --build-arg K=V .` | Set an `ARG` |
| `docker build --target stage .` | Stop at a named stage |
| `docker build --no-cache .` / `--pull` | Ignore cache / re-check the base image |
| `docker build --progress=plain .` | Full build logs |
| `docker build --secret id=x,src=file .` | Provide a build secret |
| `docker buildx build --platform linux/amd64,linux/arm64 --push .` | Multi-platform build |
| `docker buildx build --cache-to/--cache-from type=registry,ref=...` | Share build cache |
| `docker builder prune`, `docker buildx du` | Clean / measure build cache |

## Production Dockerfile template (Python)

```dockerfile
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

FROM base AS deps
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/install -r requirements.txt

FROM base AS runtime
COPY --from=deps /install /usr/local
RUN useradd -r -u 10001 app
COPY --chown=app:app . .
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["python", "app.py"]
```

## Checklist

- Pinned base image tag (or digest); slim/distroless final stage
- `.dockerignore` excludes `.git`, `node_modules`, `.env`, build output
- Dependency manifests copied and installed before source code
- `apt-get update && install && rm -rf /var/lib/apt/lists/*` in one `RUN`
- No secrets in `ARG`/`ENV`; use `--secret`
- Non-root `USER`; exec-form `CMD`/`ENTRYPOINT`
$md$, 5, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a61a89e9-0162-513d-937a-9f897af9d425', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Dockerfile ends with `RUN python app.py`. The build hangs forever. Why?', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('078270ad-42c7-561a-9fa3-1db14ee8520f', 'a61a89e9-0162-513d-937a-9f897af9d425', 1, $json${"prompt":"A Dockerfile ends with `RUN python app.py`. The build hangs forever. Why?","multiple":false,"options":[{"id":"a","text":"RUN executes at build time, so the server starts during the build and never exits","is_correct":true},{"id":"b","text":"Python is not allowed in RUN","is_correct":false},{"id":"c","text":"RUN needs exec form","is_correct":false},{"id":"d","text":"The image is missing EXPOSE","is_correct":false}],"explanation":"RUN runs during the build and waits for the command to finish; a server never finishes. The app should start with CMD at container start. RUN works with any program in either form, and EXPOSE is only documentation."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ab145279-8f5d-59bd-a7b2-8b6820c4859c', '00000000-0000-0000-0000-000000000001', 'mcq', 'Every small code change makes `pip install` rerun for 3 minutes. The Dockerfi...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('deef9add-b90e-50c2-ab4d-d6806f426061', 'ab145279-8f5d-59bd-a7b2-8b6820c4859c', 1, $json${"prompt":"Every small code change makes `pip install` rerun for 3 minutes. The Dockerfile has `COPY . .` followed by `RUN pip install -r requirements.txt`. What is the fix?","multiple":false,"options":[{"id":"a","text":"Add --no-cache to docker build","is_correct":false},{"id":"b","text":"Copy requirements.txt and install before copying the rest of the code","is_correct":true},{"id":"c","text":"Use ADD instead of COPY","is_correct":false},{"id":"d","text":"Combine both lines into one RUN","is_correct":false}],"explanation":"A cache miss on COPY . . (any file changed) invalidates every later step. Copying only the manifest first keeps the install layer cached until requirements change. --no-cache makes it worse, ADD has the same cache behaviour, and COPY cannot be merged into RUN."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bc770a7a-cf91-5e1b-9810-7d17be958336', '00000000-0000-0000-0000-000000000001', 'mcq', 'An image has `ENTRYPOINT ["python", "cli.py"]` and `CMD ["--help"]`. What run...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f113e4cc-0fd0-5762-b8dc-c7b3d60065f4', 'bc770a7a-cf91-5e1b-9810-7d17be958336', 1, $json${"prompt":"An image has `ENTRYPOINT [\"python\", \"cli.py\"]` and `CMD [\"--help\"]`. What runs for `docker run img report --month 5`?","multiple":false,"options":[{"id":"a","text":"report --month 5","is_correct":false},{"id":"b","text":"python cli.py --help report --month 5","is_correct":false},{"id":"c","text":"python cli.py report --month 5","is_correct":true},{"id":"d","text":"python cli.py --help","is_correct":false}],"explanation":"Arguments after the image name replace CMD and are appended to ENTRYPOINT. They do not replace ENTRYPOINT (that needs --entrypoint) and they are not added to CMD."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dfa8bcd8-dcab-5139-afc7-38b9a9189319', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container uses `CMD node server.js` (shell form). `docker stop` always take...', 'advanced', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('08c34bd5-75f9-5aba-b55f-8fe010e4eb1b', 'dfa8bcd8-dcab-5139-afc7-38b9a9189319', 1, $json${"prompt":"A container uses `CMD node server.js` (shell form). `docker stop` always takes 10 seconds and the app never runs its shutdown handler. Which change fixes it?","multiple":false,"options":[{"id":"a","text":"Increase the stop timeout with -t 30","is_correct":false},{"id":"b","text":"Switch to exec form CMD [\"node\", \"server.js\"] so node receives SIGTERM, and make sure node handles SIGTERM (or run with --init)","is_correct":true},{"id":"c","text":"Add EXPOSE so Docker can reach the process","is_correct":false},{"id":"d","text":"Use RUN instead of CMD","is_correct":false}],"explanation":"With shell form, sh is PID 1 and may not forward SIGTERM. Exec form makes node the target; as PID 1 it must handle SIGTERM itself or run under an init like tini (--init). A longer timeout only delays the SIGKILL, EXPOSE is unrelated, and RUN is build time."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('248cec4b-7c68-52ec-9d72-2ffb69b34c08', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which statement about ARG and ENV is correct?', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e18c44a6-dea0-5e76-b855-82c182f702de', '248cec4b-7c68-52ec-9d72-2ffb69b34c08', 1, $json${"prompt":"Which statement about ARG and ENV is correct?","multiple":false,"options":[{"id":"a","text":"ARG values are visible in running containers; ENV values are not","is_correct":false},{"id":"b","text":"ENV values are available in running containers; ARG values exist only during the build, but can still leak into image history","is_correct":true},{"id":"c","text":"Both are safe places for secrets because images are private","is_correct":false},{"id":"d","text":"ARG cannot be used before FROM","is_correct":false}],"explanation":"ENV is baked into the image config; ARG is build-time only, yet values used in RUN steps show up in docker history. Neither is safe for secrets. ARG before FROM is allowed and is how you parameterise the base image."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3aab8dfc-9670-5f5c-aa09-77ef88a76a39', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Go service image is 900 MB because it contains the Go toolchain. What is th...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2cdedbb1-a444-5dba-907e-f4e3802b8723', '3aab8dfc-9670-5f5c-aa09-77ef88a76a39', 1, $json${"prompt":"A Go service image is 900 MB because it contains the Go toolchain. What is the standard fix?","multiple":false,"options":[{"id":"a","text":"Run `go clean` at the end of the Dockerfile","is_correct":false},{"id":"b","text":"A multi-stage build: compile in a golang stage, then COPY --from that stage only the binary into a small runtime image","is_correct":true},{"id":"c","text":"Use docker export and import to flatten it","is_correct":false},{"id":"d","text":"Compress the image with gzip before pushing","is_correct":false}],"explanation":"Multi-stage builds leave the toolchain in a discarded stage. go clean in a later layer cannot shrink earlier layers, flattening still includes the toolchain files, and registries already compress layers."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('24938180-e724-5370-9f8f-a41310b8f31d', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need an npm token to install private packages during a build, without the...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('604b0ea2-a832-5088-9077-b0691147c83b', '24938180-e724-5370-9f8f-a41310b8f31d', 1, $json${"prompt":"You need an npm token to install private packages during a build, without the token ending up in the image. What do you use?","multiple":false,"options":[{"id":"a","text":"ARG NPM_TOKEN and --build-arg","is_correct":false},{"id":"b","text":"ENV NPM_TOKEN in the Dockerfile, removed with unset later","is_correct":false},{"id":"c","text":"RUN --mount=type=secret plus docker build --secret","is_correct":true},{"id":"d","text":"COPY .npmrc and delete it in the next RUN","is_correct":false}],"explanation":"A secret mount exists only during that RUN step and is never written to a layer. ARG values appear in history, ENV is baked into the config, and a file copied then deleted still lives in the earlier layer."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4a8059be-8d13-568f-b6ce-374800902284', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your team builds on Apple Silicon laptops and deploys to amd64 servers, where...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ea2b5888-bfaf-5af8-8e0b-e6f6dc42c8c2', '4a8059be-8d13-568f-b6ce-374800902284', 1, $json${"prompt":"Your team builds on Apple Silicon laptops and deploys to amd64 servers, where containers fail with 'exec format error'. What fixes it?","multiple":false,"options":[{"id":"a","text":"docker buildx build --platform linux/amd64 (or linux/amd64,linux/arm64 for a multi-platform image)","is_correct":true},{"id":"b","text":"Use the --no-cache flag","is_correct":false},{"id":"c","text":"Switch the base image to alpine","is_correct":false},{"id":"d","text":"Set CGO_ENABLED=0 in every Dockerfile","is_correct":false}],"explanation":"exec format error means the binary's CPU architecture does not match the host. Building for the target platform fixes it. Cache, base distro and CGO settings do not change the target architecture."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1c861d35-1373-5401-bdb9-8ad9959a5e63', '00000000-0000-0000-0000-000000000001', 'mcq', '(Review: Images & Layers) Why put `apt-get update`, `apt-get install` and `rm...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7596b397-7c89-5cfd-b52d-7874f695014c', '1c861d35-1373-5401-bdb9-8ad9959a5e63', 1, $json${"prompt":"(Review: Images \u0026 Layers) Why put `apt-get update`, `apt-get install` and `rm -rf /var/lib/apt/lists/*` in a single RUN?","multiple":false,"options":[{"id":"a","text":"Docker allows only one RUN per Dockerfile","is_correct":false},{"id":"b","text":"So the package index is never stale from cache and the deleted lists never get stored in a layer","is_correct":true},{"id":"c","text":"Because apt-get only works in shell form","is_correct":false},{"id":"d","text":"To make the build output shorter","is_correct":false}],"explanation":"Separate layers would cache an old index and keep the deleted files in an earlier layer. Dockerfiles can have many RUN lines, and the form or output length is not the reason."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('1068a74d-c327-514d-bb73-d848e305484e', '00000000-0000-0000-0000-000000000001', 'Quiz: Writing Dockerfiles', 'docker-dockerfile-quiz', 'Quiz covering Writing Dockerfiles.', 'mcq', 'published', 'module', 'e4397d58-c3b5-50f5-8fc7-4fb1f0dd3833', 15, 70, 5, 18, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '1068a74d-c327-514d-bb73-d848e305484e' AND question_id NOT IN ('a61a89e9-0162-513d-937a-9f897af9d425', 'ab145279-8f5d-59bd-a7b2-8b6820c4859c', 'bc770a7a-cf91-5e1b-9810-7d17be958336', 'dfa8bcd8-dcab-5139-afc7-38b9a9189319', '248cec4b-7c68-52ec-9d72-2ffb69b34c08', '3aab8dfc-9670-5f5c-aa09-77ef88a76a39', '24938180-e724-5370-9f8f-a41310b8f31d', '4a8059be-8d13-568f-b6ce-374800902284', '1c861d35-1373-5401-bdb9-8ad9959a5e63');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('588c12bc-0680-52a8-9cd1-06f53443a585', '1068a74d-c327-514d-bb73-d848e305484e', 'a61a89e9-0162-513d-937a-9f897af9d425', '078270ad-42c7-561a-9fa3-1db14ee8520f', 0, 2),
('93afbd3b-03bb-5847-b575-82122d4f9fc7', '1068a74d-c327-514d-bb73-d848e305484e', 'ab145279-8f5d-59bd-a7b2-8b6820c4859c', 'deef9add-b90e-50c2-ab4d-d6806f426061', 1, 2),
('827d6170-2f2a-56ae-802b-708e890ba702', '1068a74d-c327-514d-bb73-d848e305484e', 'bc770a7a-cf91-5e1b-9810-7d17be958336', 'f113e4cc-0fd0-5762-b8dc-c7b3d60065f4', 2, 2),
('235360e9-1971-57c2-853f-a9c536a7f162', '1068a74d-c327-514d-bb73-d848e305484e', 'dfa8bcd8-dcab-5139-afc7-38b9a9189319', '08c34bd5-75f9-5aba-b55f-8fe010e4eb1b', 3, 2),
('1cb3c463-7e58-5818-a4c4-8fd66e1f4d3f', '1068a74d-c327-514d-bb73-d848e305484e', '248cec4b-7c68-52ec-9d72-2ffb69b34c08', 'e18c44a6-dea0-5e76-b855-82c182f702de', 4, 2),
('019f1efb-fcc0-5153-805a-38ee357373d1', '1068a74d-c327-514d-bb73-d848e305484e', '3aab8dfc-9670-5f5c-aa09-77ef88a76a39', '2cdedbb1-a444-5dba-907e-f4e3802b8723', 5, 2),
('1aa67aca-0419-5f99-b001-15f6d8bc220c', '1068a74d-c327-514d-bb73-d848e305484e', '24938180-e724-5370-9f8f-a41310b8f31d', '604b0ea2-a832-5088-9077-b0691147c83b', 6, 2),
('576a23f7-dad1-5319-945c-aea5ce34dc3c', '1068a74d-c327-514d-bb73-d848e305484e', '4a8059be-8d13-568f-b6ce-374800902284', 'ea2b5888-bfaf-5af8-8e0b-e6f6dc42c8c2', 7, 2),
('3a2113a2-199a-56bd-b7c1-08165f0f581c', '1068a74d-c327-514d-bb73-d848e305484e', '1c861d35-1373-5401-bdb9-8ad9959a5e63', '7596b397-7c89-5cfd-b52d-7874f695014c', 8, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('e4397d58-c3b5-50f5-8fc7-4fb1f0dd3833', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'Quiz: Writing Dockerfiles', 'assessment', 8, 15, '1068a74d-c327-514d-bb73-d848e305484e')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Networking & Storage
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', '27527dc6-807c-51bf-beb9-a499519888d9', 'Networking & Storage', 5, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b040bf53-c4fd-55bd-b660-9e7db2dae45a', '27527dc6-807c-51bf-beb9-a499519888d9', '6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', 'Container Networking: Bridge, Host, None and DNS', 'notes', 0, $md$## Why this matters

Real apps are several containers: an API, a database, a cache. They must find
each other by **name**, while the database stays hidden from the internet.
Docker networks give you exactly that, once you know which network type to use.

## Mental model: private office floors

Each **user-defined bridge network** is a private office floor. Containers on
the same floor can call each other by name (an internal phone book). Containers
on different floors cannot talk at all. The only way in from the street is a
published port (`-p`), a receptionist forwarding calls.

```
                host machine (the building)
   +---------------------------------------------------+
   |  network "shop" (floor 1)      network "admin"    |
   |  +-------+     +------+        +---------+        |
   |  |  api  |---->|  db  |        | grafana |        |
   |  +-------+     +------+        +---------+        |
   |      ^  "db" resolves via Docker's built-in DNS   |
   +------|--------------------------------------------+
          |  -p 8080:8000 (published port)
      the internet
```

## The network drivers

| Driver | What it is | Use it for |
|---|---|---|
| `bridge` (user-defined) | A private virtual network on one host, with **DNS by container name** | Almost everything on a single host |
| `bridge` (the default one, named `bridge`) | Where containers go if you pass no `--network`. **No DNS by name** | Quick one-off tests only |
| `host` | No network isolation: the container uses the host's network directly | Max performance, or tools that need the host's interfaces (Linux only) |
| `none` | No network at all (only loopback) | Batch jobs that must not talk to anything |
| `overlay` | A network spanning several hosts | Docker Swarm |
| `macvlan` / `ipvlan` | Container gets its own address on the physical LAN | Legacy apps that expect to be "a machine" on the network |

> **One-sentence rule.** Always create your own bridge network for containers
> that need to talk; the default bridge has no name resolution.

## See it work

```bash
# 1. Create a user-defined bridge network
docker network create shop

# 2. Start a "database" on it (nginx stands in for any server)
docker run -d --name db --network shop nginx:1.27-alpine

# 3. From another container on the same network, reach it BY NAME
docker run --rm --network shop busybox:1.36 wget -qO- http://db | head -n 4
```

Expected output: the first lines of the nginx welcome page HTML. The name `db`
was resolved by Docker's embedded DNS server (at `127.0.0.11` inside each container).

Now try from the default bridge:

```bash
docker run --rm busybox:1.36 wget -qO- -T 3 http://db
```

Expected: `wget: bad address 'db'`. Different network, and no DNS there anyway.

### Inspect and manage

```bash
docker network ls                      # bridge, host, none, shop
docker network inspect shop            # subnet, gateway, attached containers
docker network connect shop web        # attach a running container to another network
docker network disconnect shop web     # detach it
docker network rm shop                 # delete (no containers may be attached)
docker network prune                   # delete all unused networks
```

A container can be on **several** networks at once. That is how you build tiers:
the API joins both `frontend` and `backend`; the database joins only `backend`.

### Aliases

```bash
docker run -d --name pg-16 --network shop --network-alias database postgres:16
```

Other containers can now use `pg-16` or `database`.

### Ports, again

Containers on the same network talk on the **container** port directly
(`http://db:80`). You only need `-p` for traffic coming from **outside** Docker
(your browser, other machines). Do **not** publish your database port in
production unless something outside needs it.

## Try it

You run `api` and `postgres` with no `--network` flags. The API cannot connect to
`postgres:5432` ("could not translate host name"). Explain why and fix it.

<details>
<summary>Show answer</summary>

Both are on the **default** bridge, which has no DNS by container name. Fix:

```bash
docker network create app
docker network connect app postgres
docker network connect app api
```

(or recreate both with `--network app`). Now `postgres` resolves.

</details>

## Common mistakes

- **Relying on the default bridge** and container IPs. IPs change on restart;
  names on a user-defined network do not.
- **Using `localhost` to reach another container.** `localhost` inside a
  container is the container itself. Use the other container's name.
- **Publishing every port "just in case".** `-p 5432:5432` exposes your database
  to the network. Internal traffic does not need `-p`.
- **Expecting `--network host` on Docker Desktop to behave like Linux.** On
  macOS/Windows the "host" is Docker's VM; host networking support there is limited.

## Remember

- Create a **user-defined bridge** per app; containers on it resolve each other by name.
- The **default** bridge has no name-based DNS.
- `host` = share the host network; `none` = no network.
- `localhost` in a container means that container.
- `-p` is only for traffic from outside Docker.

**Self-check:**

1. Which network type gives you DNS by container name?
2. How do you put a container on two networks?
3. Does `api` need `-p` to reach `db` on the same network?
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('074a526d-564e-5fc1-8433-21664c101fc9', '27527dc6-807c-51bf-beb9-a499519888d9', '6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', 'Keeping Data: Volumes, Bind Mounts and tmpfs', 'notes', 1, $md$## Why this matters

A container's writable layer dies with the container. Run a database without a
volume, upgrade it with `docker rm` + `docker run`, and your data is gone.
Storage is where Docker mistakes cost the most, so learn the three options and
when to use each.

## Mental model: where do you keep your stuff?

- **Writable layer** = a hotel room. Comfortable, but cleaned out when you check out.
- **Volume** = a storage unit managed by Docker. Survives any number of guests.
- **Bind mount** = a door from the room straight into **your own house** (a host folder).
- **tmpfs** = a whiteboard. In memory only, wiped when the container stops.

```
               container filesystem
   /app   (image layers + writable layer: lost on docker rm)
   /data  <-- volume "pgdata"   -> /var/lib/docker/volumes/pgdata/_data
   /src   <-- bind mount        -> /home/you/project   (your exact folder)
   /tmp   <-- tmpfs             -> RAM
```

| | Volume | Bind mount | tmpfs |
|---|---|---|---|
| Who manages the location | Docker | You (any host path) | Kernel memory |
| Survives `docker rm` | Yes | Yes (it is your folder) | No |
| Portable across hosts | Yes | No (depends on host paths) | n/a |
| Best for | Databases, app data | Source code in development, config files | Secrets/caches that must not touch disk |

## See it work

### Named volume

```bash
docker volume create pgdata
docker run -d --name db -e POSTGRES_PASSWORD=devpass \
  -v pgdata:/var/lib/postgresql/data postgres:16

docker rm -f db                  # delete the container...
docker run -d --name db -e POSTGRES_PASSWORD=devpass \
  -v pgdata:/var/lib/postgresql/data postgres:16   # ...data is still there
```

Volume commands:

```bash
docker volume ls
docker volume inspect pgdata     # shows the Mountpoint on the host
docker volume rm pgdata          # delete (not while a container uses it)
docker volume prune              # delete unused volumes (careful!)
```

If the volume is empty when first mounted, Docker **copies in** whatever the
image already had at that path. Bind mounts never do this: they hide the image's files.

### Bind mount

```bash
mkdir -p site && echo "hello from my laptop" > site/index.html
docker run -d --name web -p 8080:80 \
  -v "$(pwd)/site":/usr/share/nginx/html:ro nginx:1.27-alpine
curl -s localhost:8080            # hello from my laptop
echo "edited live" > site/index.html
curl -s localhost:8080            # edited live  (no rebuild!)
```

- `$(pwd)/site` must be an **absolute** path (otherwise Docker treats it as a volume name).
- `:ro` makes it read-only inside the container.

### The `--mount` syntax (explicit, preferred in scripts)

```bash
docker run --mount type=volume,src=pgdata,dst=/var/lib/postgresql/data ...
docker run --mount type=bind,src="$(pwd)/site",dst=/usr/share/nginx/html,readonly ...
docker run --mount type=tmpfs,dst=/tmp,tmpfs-size=64m ...
```

Same results as `-v`, with one useful difference: with `-v`, a missing host
path is silently **created** as an empty directory; with `--mount type=bind` it
is an **error**, which catches typos.

### Anonymous volumes

`-v /data` (no name) or a `VOLUME /data` line in a Dockerfile creates an
**anonymous volume** with a random ID. It survives `docker rm` unless you use
`docker rm -v` or `--rm`, and then piles up. Prefer named volumes.

### Back up a volume

```bash
docker run --rm -v pgdata:/data -v "$(pwd)":/backup alpine:3.20 \
  tar czf /backup/pgdata.tgz -C /data .
```

A throwaway container mounts both the volume and a host folder, then archives one into the other.

## Try it

For each case, choose volume, bind mount or tmpfs:
(a) MySQL data in production, (b) live-editing React source during development,
(c) a session cache that must never be written to disk.

<details>
<summary>Show answer</summary>

(a) **Named volume**: managed, portable, survives container replacement.
(b) **Bind mount** of the source folder: edits show up instantly.
(c) **tmpfs**: memory only, gone when the container stops.

</details>

## Common mistakes

- **No volume for a database.** `docker rm` deletes the data with the container.
- **Relative paths with `-v`.** `-v site:/usr/share/nginx/html` creates a volume
  named `site`, not a bind mount of `./site`.
- **`docker volume prune` / `docker compose down -v` on a machine with real data.**
  They delete volumes. Read before you press Enter.
- **Permission denied on bind mounts.** The container user's UID must be allowed
  to read/write the host folder. Match UIDs or adjust ownership.

## Remember

- Writable layer = temporary. Data you care about goes in a **volume**.
- Volume (Docker-managed, portable) vs bind mount (your host path) vs tmpfs (RAM).
- `-v name:/path` = volume, `-v /abs/host:/path` = bind mount, `:ro` = read-only.
- `--mount` is explicit and errors on missing bind paths.
- Back up a volume with a throwaway container + `tar`.

**Self-check:**

1. What happens to files in a container's writable layer after `docker rm`?
2. How does Docker tell a volume name from a bind-mount path in `-v`?
3. Why are anonymous volumes a cleanup problem?
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('45110f93-674a-54e1-9bea-c54ec8fb73c4', '27527dc6-807c-51bf-beb9-a499519888d9', '6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', 'Lab: Networks and Volumes', 'notes', 2, $md$## Why this matters

Two hands-on checks for this section: create and inspect a network, and prove
with your own eyes that a named volume outlives the container that wrote to it.

## Sandbox note

This sandbox's Docker daemon runs inside its own nested network, and attaching
containers to a **new** bridge network is not reliable here. So Task 1 checks
that you can create and inspect a network correctly. Try the
"two containers resolve each other by name" demo from lesson 1 on your own
machine. Containers in this lab use `--network host`, as in every lab of this course.

## Task 1: create and inspect a custom network

```bash
docker network create mynetwork
docker network ls                     # mynetwork, driver bridge
docker network inspect mynetwork      # subnet, gateway, Driver: "bridge"
docker network inspect -f '{{.Driver}}' mynetwork   # just: bridge
```

On a normal machine you would then attach containers to it:

```bash
docker run --name myserver-net -d --network mynetwork nginx:1.27-alpine
```

[[lab-task:1]]

## Task 2: prove a named volume survives its container

Recall lesson 2: a named volume lives outside any container.

```bash
# 1. Create the volume
docker volume create mydata

# 2. Write a file into it from a throwaway container (--rm deletes the container afterwards)
docker run --rm --network host -v mydata:/data busybox:1.36 \
  sh -c "echo 'still here' > /data/proof.txt"

# 3. The writing container is gone. Read the file from a brand-new container
docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt
```

Expected output of step 3:

```
still here
```

The container that wrote the file no longer exists; the volume kept the data.

For comparison, a bind mount uses a host path instead of a volume name:

```bash
mkdir -p ~/work/myfolder
docker run --name myserver-bind -d --network host \
  -v ~/work/myfolder:/usr/share/nginx/html nginx:1.27-alpine
```

[[lab-task:2]]

## Remember

- `docker network create` / `inspect` / `ls` manage networks.
- Data written to a named volume survives `docker rm` and is visible to the next container that mounts it.
$md$, 15, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('85ace03d-4a36-536d-bd8b-63043a0c295f', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '45110f93-674a-54e1-9bea-c54ec8fb73c4', 'module', 'Lab: Networks and Volumes', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 35, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '6b132d62-f23c-5236-beb5-2f0c742f9acb' AND id NOT IN ('c16eb049-e584-57e0-b222-b3f25a216aaa', '39c9670e-3898-54e7-a913-01581a5d0db3');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '6b132d62-f23c-5236-beb5-2f0c742f9acb';
DELETE FROM lab_tasks WHERE lab_id = '85ace03d-4a36-536d-bd8b-63043a0c295f' AND id NOT IN ('b6d9e652-34f8-5504-a612-f05935a53ad9', '88be1661-d9d3-5e7a-8d89-895cdbcb027a');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '85ace03d-4a36-536d-bd8b-63043a0c295f';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('b6d9e652-34f8-5504-a612-f05935a53ad9', '85ace03d-4a36-536d-bd8b-63043a0c295f', 1, 'Create and inspect a custom network', $md$Create a bridge network named "mynetwork" and confirm it exists with the right driver.$md$, $script$docker network inspect mynetwork --format '{{.Driver}}' 2>/dev/null | grep -q bridge
$script$, 'docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.', 'docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.', 10, false, false),
('88be1661-d9d3-5e7a-8d89-895cdbcb027a', '85ace03d-4a36-536d-bd8b-63043a0c295f', 2, 'Prove a named volume survives its container', $md$Create a named volume "mydata", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.$md$, $script$docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2>/dev/null | grep -q "still here"
$script$, 'docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo ''still here'' > /data/proof.txt" writes the file (--network host is needed for any container to start at all in this sandbox — see the Running Containers lab); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what''s persisting the data.', 'A named volume''s data lives independently of any one container — that''s the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('6b132d62-f23c-5236-beb5-2f0c742f9acb', '85ace03d-4a36-536d-bd8b-63043a0c295f', 1, $json$[{"id":"b6d9e652-34f8-5504-a612-f05935a53ad9","lab_id":"85ace03d-4a36-536d-bd8b-63043a0c295f","position":1,"title":"Create and inspect a custom network","description":"Create a bridge network named \"mynetwork\" and confirm it exists with the right driver.","verification_script":"docker network inspect mynetwork --format '{{.Driver}}' 2\u003e/dev/null | grep -q bridge\n","hint_context":"docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.","explanation_context":"docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.","points":10,"is_optional":false,"is_stateful":false},{"id":"88be1661-d9d3-5e7a-8d89-895cdbcb027a","lab_id":"85ace03d-4a36-536d-bd8b-63043a0c295f","position":2,"title":"Prove a named volume survives its container","description":"Create a named volume \"mydata\", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.","verification_script":"docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2\u003e/dev/null | grep -q \"still here\"\n","hint_context":"docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c \"echo 'still here' \u003e /data/proof.txt\" writes the file (--network host is needed for any container to start at all in this sandbox — see the Running Containers lab); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what's persisting the data.","explanation_context":"A named volume's data lives independently of any one container — that's the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('c16eb049-e584-57e0-b222-b3f25a216aaa', '6b132d62-f23c-5236-beb5-2f0c742f9acb', 'b6d9e652-34f8-5504-a612-f05935a53ad9', 1, 'Create and inspect a custom network', $md$Create a bridge network named "mynetwork" and confirm it exists with the right driver.$md$, $script$docker network inspect mynetwork --format '{{.Driver}}' 2>/dev/null | grep -q bridge
$script$, 'docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.', 'docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.', 10, false, false),
('39c9670e-3898-54e7-a913-01581a5d0db3', '6b132d62-f23c-5236-beb5-2f0c742f9acb', '88be1661-d9d3-5e7a-8d89-895cdbcb027a', 2, 'Prove a named volume survives its container', $md$Create a named volume "mydata", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.$md$, $script$docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2>/dev/null | grep -q "still here"
$script$, 'docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo ''still here'' > /data/proof.txt" writes the file (--network host is needed for any container to start at all in this sandbox — see the Running Containers lab); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what''s persisting the data.', 'A named volume''s data lives independently of any one container — that''s the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '6b132d62-f23c-5236-beb5-2f0c742f9acb', updated_at = now()
WHERE id = '85ace03d-4a36-536d-bd8b-63043a0c295f' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7c01605e-8073-5f0d-a631-bdae401bef05', '00000000-0000-0000-0000-000000000001', 'mcq', 'Two containers started with plain `docker run` (no --network) cannot reach ea...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4137d07c-8934-5c07-8b4e-20feafed3960', '7c01605e-8073-5f0d-a631-bdae401bef05', 1, $json${"prompt":"Two containers started with plain `docker run` (no --network) cannot reach each other by name. Why?","multiple":false,"options":[{"id":"a","text":"Containers can never talk to each other","is_correct":false},{"id":"b","text":"They are on the default bridge network, which has no DNS by container name","is_correct":true},{"id":"c","text":"They need -p to publish ports to each other","is_correct":false},{"id":"d","text":"Names only work with --network host","is_correct":false}],"explanation":"Only user-defined networks get Docker's embedded DNS for container names. Containers can talk over IP even on the default bridge, published ports are for traffic from outside Docker, and host networking is unrelated to name resolution."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7aad3006-6193-5054-a6fa-0921e6146ef8', '00000000-0000-0000-0000-000000000001', 'mcq', 'Inside the `api` container, the connection string is `postgres://localhost:54...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8cac8ff1-f86a-5da6-891b-b2663ed61916', '7aad3006-6193-5054-a6fa-0921e6146ef8', 1, $json${"prompt":"Inside the `api` container, the connection string is `postgres://localhost:5432`. The database runs in a separate container named `db` on the same user-defined network. What is wrong?","multiple":false,"options":[{"id":"a","text":"localhost inside api refers to api itself; use db:5432","is_correct":true},{"id":"b","text":"Port 5432 must be published with -p","is_correct":false},{"id":"c","text":"Postgres cannot run in a container","is_correct":false},{"id":"d","text":"The network needs the host driver","is_correct":false}],"explanation":"Each container has its own network namespace, so localhost is the container itself. Same-network containers talk on container ports directly by name; no -p or host driver needed."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7ba13572-f850-5c94-b0ca-2c22ce127c3d', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want the API reachable from the internet and the database reachable only ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('35a9925b-b874-5bdc-8b9e-8e361a07e513', '7ba13572-f850-5c94-b0ca-2c22ce127c3d', 1, $json${"prompt":"You want the API reachable from the internet and the database reachable only by the API. Which setup is right?","multiple":false,"options":[{"id":"a","text":"Publish both with -p and use a firewall","is_correct":false},{"id":"b","text":"Put both on one user-defined network; publish only the API's port","is_correct":true},{"id":"c","text":"Run both with --network host","is_correct":false},{"id":"d","text":"Run the database with --network none","is_correct":false}],"explanation":"Containers on the same network reach each other without publishing, so only the API needs -p. Publishing the DB widens exposure, host networking removes isolation, and --network none would cut the DB off from the API too."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f6f68e94-8b38-5c6d-9ce5-be75c32462a6', '00000000-0000-0000-0000-000000000001', 'mcq', 'You upgrade Postgres with `docker rm -f db` and a new `docker run`. All data ...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8e8acf16-e657-5908-954c-d012febcf759', 'f6f68e94-8b38-5c6d-9ce5-be75c32462a6', 1, $json${"prompt":"You upgrade Postgres with `docker rm -f db` and a new `docker run`. All data is gone. What should the original run have included?","multiple":false,"options":[{"id":"a","text":"--restart always","is_correct":false},{"id":"b","text":"A named volume, e.g. -v pgdata:/var/lib/postgresql/data","is_correct":true},{"id":"c","text":"--memory 2g","is_correct":false},{"id":"d","text":"-p 5432:5432","is_correct":false}],"explanation":"Data in the writable layer is deleted with the container; a named volume lives independently. Restart policies, memory limits and port publishing do not persist data."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('82274cde-c2f5-57a1-b188-0df8e4b77e5d', '00000000-0000-0000-0000-000000000001', 'mcq', '`docker run -v data:/app/data myimg` was meant to mount ./data from your proj...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('01993c2c-311f-518e-bef1-82b8468e3c70', '82274cde-c2f5-57a1-b188-0df8e4b77e5d', 1, $json${"prompt":"`docker run -v data:/app/data myimg` was meant to mount ./data from your project. What actually happened?","multiple":false,"options":[{"id":"a","text":"It mounted ./data as expected","is_correct":false},{"id":"b","text":"It created (or reused) a named volume called data, because the source is not an absolute path","is_correct":true},{"id":"c","text":"It failed with a syntax error","is_correct":false},{"id":"d","text":"It copied ./data into the image","is_correct":false}],"explanation":"With -v, a source without a leading / is treated as a volume name. Use \"$(pwd)/data\" for a bind mount. It is not an error, and nothing is copied into the image."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3545322e-050a-553f-b7b2-1c3e9c479047', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which storage type should hold short-lived secrets that must never be written...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('49063c99-fa05-5a2c-9c6d-eeb22e4228ec', '3545322e-050a-553f-b7b2-1c3e9c479047', 1, $json${"prompt":"Which storage type should hold short-lived secrets that must never be written to disk?","multiple":false,"options":[{"id":"a","text":"A named volume","is_correct":false},{"id":"b","text":"A bind mount","is_correct":false},{"id":"c","text":"tmpfs","is_correct":true},{"id":"d","text":"The container's writable layer","is_correct":false}],"explanation":"tmpfs lives in memory and disappears when the container stops. Volumes, bind mounts and the writable layer all write to disk."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('13294aac-d006-59e3-9c4b-9eec5462ee27', '00000000-0000-0000-0000-000000000001', 'mcq', 'A developer''s `docker run -v /home/dev/proj/src:/app/src` typo-ed the path, a...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2004448b-ddac-52ba-b9db-04d873709cb7', '13294aac-d006-59e3-9c4b-9eec5462ee27', 1, $json${"prompt":"A developer's `docker run -v /home/dev/proj/src:/app/src` typo-ed the path, and the app started with an empty /app/src. Which option would have failed loudly instead?","multiple":false,"options":[{"id":"a","text":"--mount type=bind,src=...,dst=/app/src","is_correct":true},{"id":"b","text":"-v with :ro","is_correct":false},{"id":"c","text":"VOLUME /app/src in the Dockerfile","is_correct":false},{"id":"d","text":"--tmpfs /app/src","is_correct":false}],"explanation":"With -v, a missing host path is silently created as an empty directory; --mount type=bind refuses a missing source. :ro only makes it read-only, VOLUME creates an anonymous volume, and tmpfs is memory."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('032164cb-8de0-5819-b274-630603631cbf', '00000000-0000-0000-0000-000000000001', 'mcq', '(Review: Dockerfiles) A Dockerfile has `VOLUME /var/lib/app`. Containers are ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5c7675fc-39d1-54cd-85af-9ae408449a1d', '032164cb-8de0-5819-b274-630603631cbf', 1, $json${"prompt":"(Review: Dockerfiles) A Dockerfile has `VOLUME /var/lib/app`. Containers are created and removed many times a day. What builds up over time?","multiple":false,"options":[{"id":"a","text":"Dangling images","is_correct":false},{"id":"b","text":"Anonymous volumes, unless containers are removed with -v or run with --rm","is_correct":true},{"id":"c","text":"Extra image layers","is_correct":false},{"id":"d","text":"Unused networks","is_correct":false}],"explanation":"VOLUME makes Docker create an anonymous volume for each new container, and plain docker rm leaves it behind. It does not create images, layers or networks."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '00000000-0000-0000-0000-000000000001', 'Quiz: Networking & Storage', 'docker-networking-volumes-quiz', 'Quiz covering Networking & Storage.', 'mcq', 'published', 'module', '3426d34f-6f9f-50dd-a867-9f614ec612f4', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '43a30e5f-f21e-5bdf-8168-ce00a8fd376c' AND question_id NOT IN ('7c01605e-8073-5f0d-a631-bdae401bef05', '7aad3006-6193-5054-a6fa-0921e6146ef8', '7ba13572-f850-5c94-b0ca-2c22ce127c3d', 'f6f68e94-8b38-5c6d-9ce5-be75c32462a6', '82274cde-c2f5-57a1-b188-0df8e4b77e5d', '3545322e-050a-553f-b7b2-1c3e9c479047', '13294aac-d006-59e3-9c4b-9eec5462ee27', '032164cb-8de0-5819-b274-630603631cbf');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('74a6ffcc-8c46-5090-95d8-ffd8c834fe5e', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '7c01605e-8073-5f0d-a631-bdae401bef05', '4137d07c-8934-5c07-8b4e-20feafed3960', 0, 2),
('0ec954d0-a2d5-5e2d-8739-a3659932ccb9', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '7aad3006-6193-5054-a6fa-0921e6146ef8', '8cac8ff1-f86a-5da6-891b-b2663ed61916', 1, 2),
('e28e39f3-a663-5f64-843a-c0a8f256fdca', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '7ba13572-f850-5c94-b0ca-2c22ce127c3d', '35a9925b-b874-5bdc-8b9e-8e361a07e513', 2, 2),
('a1f70608-ef94-5f79-aa73-7099db68a915', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', 'f6f68e94-8b38-5c6d-9ce5-be75c32462a6', '8e8acf16-e657-5908-954c-d012febcf759', 3, 2),
('69da9446-e10f-59af-9108-fadf3beffacb', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '82274cde-c2f5-57a1-b188-0df8e4b77e5d', '01993c2c-311f-518e-bef1-82b8468e3c70', 4, 2),
('05799b48-4ca1-55fa-833e-299e352bb016', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '3545322e-050a-553f-b7b2-1c3e9c479047', '49063c99-fa05-5a2c-9c6d-eeb22e4228ec', 5, 2),
('5fb686d9-123a-590d-9572-113594969729', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '13294aac-d006-59e3-9c4b-9eec5462ee27', '2004448b-ddac-52ba-b9db-04d873709cb7', 6, 2),
('7abaf07b-638b-5a4f-b9e3-3ab9dbdac3cd', '43a30e5f-f21e-5bdf-8168-ce00a8fd376c', '032164cb-8de0-5819-b274-630603631cbf', '5c7675fc-39d1-54cd-85af-9ae408449a1d', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('3426d34f-6f9f-50dd-a867-9f614ec612f4', '27527dc6-807c-51bf-beb9-a499519888d9', '6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', 'Quiz: Networking & Storage', 'assessment', 3, 12, '43a30e5f-f21e-5bdf-8168-ce00a8fd376c')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Compose & Registries
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('5a6f4fb1-d93e-5010-bf79-1c44730b36cc', '27527dc6-807c-51bf-beb9-a499519888d9', 'Compose & Registries', 6, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1efe97b4-e06c-57d2-9bea-2ad7fb2a127e', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Docker Compose: One File for the Whole App', 'notes', 0, $md$## Why this matters

A real app is an API, a database, a cache, maybe a worker. Starting each with
a long `docker run` line, in the right order, on the right network, with the
right volumes, is error-prone. **Docker Compose** describes the whole app in one
YAML file and starts it with one command. It is the standard tool for local
development and simple single-host deployments.

## Mental model: a sheet of music

Each `docker run` command is one musician playing from memory. A
`compose.yaml` file is the **sheet music** for the whole orchestra: who plays,
with which instrument, in what order. `docker compose up` is the conductor.

```
compose.yaml                         what Compose creates
------------                         --------------------
services:                            network   myapp_default
  web:   (image, ports)      --->    container myapp-web-1
  db:    (image, volume)     --->    container myapp-db-1
volumes:                             volume    myapp_dbdata
  dbdata:
```

Key words:

- **Service**: one component (web, db). Compose runs one or more containers per service.
- **Project**: the whole app. Its name defaults to the **folder name** and prefixes everything.
- Compose creates a **default network** for the project, so services reach each
  other **by service name** (`db`, `web`), exactly like the user-defined network from Section 5.

`docker compose` (a space, Compose v2, a Docker CLI plugin) is current.
`docker-compose` (hyphen) was the old Python v1 tool, retired in 2023. The
top-level `version:` key in old files is obsolete and ignored.

## See it work

Folder `myapp/` with one file, `compose.yaml`:

```yaml
services:
  web:
    image: nginx:1.27-alpine        # like: docker run nginx:1.27-alpine
    ports:
      - "8080:80"                   # like: -p 8080:80 (outside:inside)
    depends_on:
      - db                          # start db before web

  db:
    image: postgres:16
    environment:                    # like: -e
      POSTGRES_PASSWORD: devpass
    volumes:
      - dbdata:/var/lib/postgresql/data   # like: -v dbdata:/...

volumes:
  dbdata:                           # declare the named volume
```

Run it:

```bash
cd myapp
docker compose up -d        # create network, volume, containers; start them
docker compose ps           # status of this project's containers
```

Expected output of `ps` (shortened):

```
NAME          IMAGE               SERVICE   STATUS         PORTS
myapp-db-1    postgres:16         db        Up 5 seconds   5432/tcp
myapp-web-1   nginx:1.27-alpine   web       Up 4 seconds   0.0.0.0:8080->80/tcp
```

Notice the names: **project-service-number**.

Everyday commands:

```bash
docker compose logs -f web          # follow one service's logs
docker compose exec db psql -U postgres     # shell/command in a running service
docker compose run --rm web nginx -t        # one-off container for a service
docker compose stop                 # stop containers, keep them
docker compose start                # start them again
docker compose restart web          # restart one service
docker compose down                 # stop and REMOVE containers and the network
docker compose down -v              # ...and also delete named volumes (data!)
docker compose ls                   # list running Compose projects
```

`docker compose up -d` is **idempotent**: run it again after editing the file and
Compose recreates only the services whose configuration changed.

## Try it

Translate this into a `compose.yaml` service:

```bash
docker run -d --name cache -p 127.0.0.1:6379:6379 -v cachedata:/data redis:7-alpine
```

<details>
<summary>Show answer</summary>

```yaml
services:
  cache:
    image: redis:7-alpine
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - cachedata:/data

volumes:
  cachedata:
```

The container name becomes `<project>-cache-1` (set `container_name:` only if
you really need a fixed name; it prevents scaling).

</details>

## Common mistakes

- **`docker compose down -v` "to clean up".** It deletes your database volume.
  Plain `down` keeps volumes.
- **Using `localhost` between services.** Use the service name (`db:5432`).
- **Typing `docker-compose`** from old tutorials. Use `docker compose`.
- **Running from the wrong folder.** The project name comes from the folder, so a
  different folder means a different project (new network, new volumes).

## Remember

- `compose.yaml` describes services, networks and volumes; `docker compose up -d` creates them.
- Project name = folder name; containers are `project-service-N`.
- Services reach each other by **service name** on the project's default network.
- `down` removes containers + network; `down -v` also deletes volumes.
- It is `docker compose` (v2). `version:` is obsolete.

**Self-check:**

1. Which `docker run` flags do `ports`, `environment` and `volumes` correspond to?
2. What host name does `web` use to reach `db`?
3. What is the difference between `docker compose down` and `down -v`?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f2caeeff-6da0-5f10-a8b1-bb6e41e3e5c0', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Compose in Depth: Builds, Health-Gated Startup, Env Files, Overrides', 'notes', 1, $md$## Why this matters

The basic file gets an app running. Real projects need more: build your own
image, wait until the database is actually **ready** (not just started), keep
secrets out of the file, and use one file for dev and another for prod. These
features are what separate a toy `compose.yaml` from a team's working one.

## Mental model: one base score, many arrangements

Think of `compose.yaml` as the base music score. Variables (`${VAR}`) are the
blanks you fill in per performance. Override files are alternative
arrangements layered on top. Healthchecks are the conductor waiting for each
section to be **in tune** before the next one starts.

## See it work

A realistic file:

```yaml
services:
  api:
    build:                             # build from a Dockerfile instead of pulling
      context: ./api
      target: runtime                  # a multi-stage target (Section 4)
    image: myorg/api:${API_TAG:-dev}   # name for the built image; default tag "dev"
    ports:
      - "${API_PORT:-8000}:8000"
    env_file: .env.api                 # load KEY=value lines into the container
    environment:
      DATABASE_URL: postgres://app:${DB_PASSWORD:?set DB_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy     # wait until db's healthcheck passes
    restart: unless-stopped

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD}
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      timeout: 3s
      retries: 10

  adminer:
    image: adminer
    profiles: ["debug"]                # only starts with --profile debug
    ports: ["8081:8080"]

volumes:
  dbdata:
```

### 1. Variables and the `.env` file

Compose reads a file named `.env` next to `compose.yaml` and substitutes
`${VAR}` in the YAML:

```
# .env  (do not commit real secrets)
DB_PASSWORD=devpass
API_TAG=1.4.0
```

| Syntax | Meaning |
|---|---|
| `${VAR}` | Value of VAR (empty if unset) |
| `${VAR:-default}` | VAR, or `default` if unset/empty |
| `${VAR:?message}` | VAR, or **fail** with `message` if unset/empty |

Two different things, often confused:

- **`.env`** fills `${...}` placeholders **in the YAML**.
- **`env_file:`** passes variables **into the container**.

`docker compose config` prints the final file with every variable resolved. Use it whenever something looks wrong.

### 2. Startup order that actually waits

Plain `depends_on: [db]` only waits until the db **container has started**,
not until Postgres accepts connections. Add a `healthcheck` to `db` and use
`condition: service_healthy`. Other conditions: `service_started` (default) and
`service_completed_successfully` (for one-shot jobs like migrations).

### 3. Build and run in one step

```bash
docker compose up -d --build     # rebuild images whose build context changed, then start
docker compose build api         # just build
```

### 4. Profiles

Services with `profiles:` start only when asked:

```bash
docker compose --profile debug up -d     # also starts adminer
```

### 5. Override files: dev vs prod

Compose automatically merges `compose.override.yaml` on top of `compose.yaml`.
Put dev-only settings there (bind-mounted source, debug ports):

```yaml
# compose.override.yaml  (dev only, merged automatically)
services:
  api:
    volumes:
      - ./api:/app          # live code
    environment:
      LOG_LEVEL: debug
```

For other environments, list files explicitly; later files win:

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

### 6. Scale and watch

```bash
docker compose up -d --scale worker=3   # three containers for the worker service
docker compose watch                     # sync/rebuild on file changes (needs a develop.watch section)
```

A minimal `develop.watch` block:

```yaml
services:
  api:
    build: ./api
    develop:
      watch:
        - action: sync           # copy changed files into the running container
          path: ./api/src
          target: /app/src
        - action: rebuild        # rebuild the image when dependencies change
          path: ./api/requirements.txt
```

## Try it

Your API crashes on startup with "connection refused" to the database about one
time in three, even though it has `depends_on: [db]`. Fix the file.

<details>
<summary>Show answer</summary>

`depends_on` only waited for the container to start. Add a healthcheck and a condition:

```yaml
services:
  api:
    depends_on:
      db:
        condition: service_healthy
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      retries: 10
```

Also make the API retry its connection: databases can restart later too.

</details>

## Common mistakes

- **Committing `.env` with real passwords.** Commit a `.env.example` instead; use
  a secrets manager or Compose `secrets:` for production.
- **Confusing `.env` with `env_file:`.** One feeds the YAML, the other feeds the container.
- **`depends_on` without a healthcheck**, then "random" startup failures.
- **Forgetting `--build`.** `up -d` reuses an existing image even after you edited the code.

## Remember

- `.env` + `${VAR:-default}` / `${VAR:?err}` parameterise the YAML; `docker compose config` shows the result.
- `env_file:` / `environment:` set variables **inside** containers.
- `depends_on` + `condition: service_healthy` + a `healthcheck` = real readiness ordering.
- `compose.override.yaml` merges automatically; `-f a -f b` merges explicitly, later wins.
- `profiles`, `--scale`, `up --build` and `watch` cover the rest of daily use.

**Self-check:**

1. What does `${DB_PASSWORD:?set DB_PASSWORD}` do when the variable is missing?
2. Why is `depends_on: [db]` alone not enough for a database?
3. Which file does Compose merge automatically on top of `compose.yaml`?
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3c9ad4fc-634e-576d-aecd-5f544c34301b', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Registries: Docker Hub, Private Registries and Logins', 'notes', 2, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ccf2c203-70e2-536f-92f7-4cc6568329ca', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Lab: Compose Up and a Registry Round Trip', 'notes', 3, $md$## Why this matters

Two skills from this section, done for real: bring up a service from a
`compose.yaml`, and push and pull an image through a registry.

## Sandbox notes

- Compose's equivalent of `--network host` is `network_mode: host`. This lab's
  nested Docker needs it for the same reason as every other lab here.
- The sandbox has no internet, so you cannot push to Docker Hub. Instead a
  private registry (the official `registry:2` image) runs at `localhost:5000`,
  with no login. Push and pull work exactly as with Hub; only the host differs.
- `docker push`/`pull`/`build` are carried out by the Docker daemon, which
  shares a network with that registry, so `localhost:5000` works directly from
  your terminal.

## Task 1: bring up a service with Compose

```bash
mkdir -p ~/work-compose && cd ~/work-compose
cat > compose.yaml <<'EOF'
services:
  web:
    image: nginx:1.27-alpine
    network_mode: host          # sandbox: instead of ports: ["8080:80"]
    volumes:
      - webdata:/usr/share/nginx/html

volumes:
  webdata:
EOF

docker compose up -d     # creates the volume and the container, starts it
docker compose ps        # web is running
docker compose logs web  # nginx startup lines
```

On a normal machine you would write `ports: ["8080:80"]` instead of
`network_mode: host` and open `http://localhost:8080`.

Check it serves:

```bash
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80 | head -n 4
```

When you are done (after the task is checked), `docker compose down` stops and
removes it. `docker compose down -v` would also delete the `webdata` volume.

[[lab-task:1]]

## Task 2: push and pull through the registry

```bash
# Name an existing image for the local registry
docker tag alpine:3.20 localhost:5000/myimage:latest

# Upload it
docker push localhost:5000/myimage:latest

# Delete your local copy so the next pull must really download it
docker rmi localhost:5000/myimage:latest

# Download it back
docker pull localhost:5000/myimage:latest
```

Expected end of the pull output:

```
Status: Downloaded newer image for localhost:5000/myimage:latest
```

With Docker Hub the flow is identical, plus a login:
`docker login -u myuser`, `docker tag myimage:latest myuser/myimage:latest`,
`docker push myuser/myimage:latest`.

[[lab-task:2]]

## Remember

- `docker compose up -d` / `ps` / `logs` / `down` is the daily Compose loop.
- Registry flow: tag with the registry host → push → (elsewhere) pull.
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('871b5216-5e02-59e0-bdd1-db78f4e78d63', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', 'ccf2c203-70e2-536f-92f7-4cc6568329ca', 'module', 'Lab: Compose Up and a Registry Round Trip', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 35, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'c0055992-dbf7-5f9d-a52c-e5512d9c629e' AND id NOT IN ('00ab659d-a194-5e3e-9b97-70880674298b', '179f4db8-2f1a-552f-a755-0d6be480b185');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'c0055992-dbf7-5f9d-a52c-e5512d9c629e';
DELETE FROM lab_tasks WHERE lab_id = '871b5216-5e02-59e0-bdd1-db78f4e78d63' AND id NOT IN ('9371c5d9-e32e-5d21-aee8-74ea3009b389', '9d1d5416-abd8-5399-9492-76b27a6003eb');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '871b5216-5e02-59e0-bdd1-db78f4e78d63';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('9371c5d9-e32e-5d21-aee8-74ea3009b389', '871b5216-5e02-59e0-bdd1-db78f4e78d63', 1, 'Bring up a service with Docker Compose', $md$Write the compose.yaml shown above into ~/work-compose/compose.yaml and bring it up with "docker compose up -d".$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.', 'Compose''s whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.', 10, false, false),
('9d1d5416-abd8-5399-9492-76b27a6003eb', '871b5216-5e02-59e0-bdd1-db78f4e78d63', 2, 'Push and pull through the offline registry', $md$Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.$md$, $script$docker image inspect localhost:5000/myimage:latest >/dev/null 2>&1
$script$, 'docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.', 'The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('c0055992-dbf7-5f9d-a52c-e5512d9c629e', '871b5216-5e02-59e0-bdd1-db78f4e78d63', 1, $json$[{"id":"9371c5d9-e32e-5d21-aee8-74ea3009b389","lab_id":"871b5216-5e02-59e0-bdd1-db78f4e78d63","position":1,"title":"Bring up a service with Docker Compose","description":"Write the compose.yaml shown above into ~/work-compose/compose.yaml and bring it up with \"docker compose up -d\".","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2\u003e/dev/null | grep -qi \"Welcome to nginx\"\n","hint_context":"docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.","explanation_context":"Compose's whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.","points":10,"is_optional":false,"is_stateful":false},{"id":"9d1d5416-abd8-5399-9492-76b27a6003eb","lab_id":"871b5216-5e02-59e0-bdd1-db78f4e78d63","position":2,"title":"Push and pull through the offline registry","description":"Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.","verification_script":"docker image inspect localhost:5000/myimage:latest \u003e/dev/null 2\u003e\u00261\n","hint_context":"docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.","explanation_context":"The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('00ab659d-a194-5e3e-9b97-70880674298b', 'c0055992-dbf7-5f9d-a52c-e5512d9c629e', '9371c5d9-e32e-5d21-aee8-74ea3009b389', 1, 'Bring up a service with Docker Compose', $md$Write the compose.yaml shown above into ~/work-compose/compose.yaml and bring it up with "docker compose up -d".$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.', 'Compose''s whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.', 10, false, false),
('179f4db8-2f1a-552f-a755-0d6be480b185', 'c0055992-dbf7-5f9d-a52c-e5512d9c629e', '9d1d5416-abd8-5399-9492-76b27a6003eb', 2, 'Push and pull through the offline registry', $md$Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.$md$, $script$docker image inspect localhost:5000/myimage:latest >/dev/null 2>&1
$script$, 'docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.', 'The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'c0055992-dbf7-5f9d-a52c-e5512d9c629e', updated_at = now()
WHERE id = '871b5216-5e02-59e0-bdd1-db78f4e78d63' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2b326c59-0832-5671-97d1-8cd071a8156d', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Lab: A Health-Gated Two-Service Stack', 'notes', 4, $md$## Why this matters

Lesson 2 showed that `depends_on` alone does not wait for a service to be
**ready**, and that `.env` files parameterise the YAML. This lab makes you see
both happen: Compose holds back `web` until `api` is healthy, then a one-line
`.env` file changes `api`'s configuration without editing the YAML.

## Sandbox note

As in the other labs, services use `network_mode: host` instead of `ports:`.
`api` listens on port 8001 and `web` (nginx) on port 80 of the sandbox network.

## The stack

```yaml
services:
  api:
    image: python:3.12-alpine
    network_mode: host
    command: ["python3", "-m", "http.server", "8001"]   # a tiny web server
    environment:
      APP_ENV: ${APP_ENV:-dev}       # from .env, default "dev"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8001/"]
      interval: 3s
      timeout: 2s
      retries: 5
  web:
    image: nginx:1.27-alpine
    network_mode: host
    depends_on:
      api:
        condition: service_healthy   # wait for api's healthcheck to pass
```

## Task 1: start it and watch the gate

The folder name matters: it becomes the project name, so containers are named
`stack-api-1` and `stack-web-1`.

```bash
mkdir -p ~/work/stack && cd ~/work/stack
# write compose.yaml (paste the file above, e.g. with cat > compose.yaml <<'EOF' ... EOF)
docker compose up -d
```

Expected output (shortened). Notice `Waiting` then `Healthy` before web starts:

```
 Container stack-api-1  Started
 Container stack-api-1  Waiting
 Container stack-api-1  Healthy
 Container stack-web-1  Started
```

```bash
docker compose ps --format "{{.Service}} {{.State}} {{.Health}}"
```

Expected:

```
api running healthy
web running
```

[[lab-task:1]]

## Task 2: change configuration with `.env`

```bash
cd ~/work/stack
docker compose exec api printenv APP_ENV     # dev (the default)
echo "APP_ENV=staging" > .env
docker compose config | grep APP_ENV         # APP_ENV: staging  (resolved YAML)
docker compose up -d                         # recreates only api
docker compose exec api printenv APP_ENV     # staging
```

[[lab-task:2]]

## Remember

- `condition: service_healthy` + a `healthcheck` = start order that waits for readiness.
- `.env` fills `${VAR:-default}` in the YAML; `docker compose config` shows the result.
- `docker compose up -d` again recreates only what changed.

**Self-check:**

1. What would happen to `web` if `api`'s healthcheck never passed?
2. Which command shows the YAML after variable substitution?
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '2b326c59-0832-5671-97d1-8cd071a8156d', 'module', 'Lab: A Health-Gated Two-Service Stack', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 35, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '84661e5a-b590-5aea-90aa-8d5c0881d048' AND id NOT IN ('074ebe96-dbd2-596f-a5a8-b62ce351f852', 'fdd0bf33-9272-5037-afcb-1087d6d1ae6b');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '84661e5a-b590-5aea-90aa-8d5c0881d048';
DELETE FROM lab_tasks WHERE lab_id = '9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1' AND id NOT IN ('474396b7-82e8-5310-b8b7-07a6bf4a4fbb', 'b311d691-aec7-51d2-9486-feadbaabbd34');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('474396b7-82e8-5310-b8b7-07a6bf4a4fbb', '9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1', 1, 'Start a stack where web waits for a healthy api', $md$In ~/work/stack, write the compose.yaml shown above (an "api" service with a healthcheck, and a "web" service that depends on api with condition service_healthy), then run "docker compose up -d". Both containers must be running and api must report healthy.$md$, $script$test "$(docker inspect -f '{{.State.Health.Status}}' stack-api-1 2>/dev/null)" = healthy && test "$(docker inspect -f '{{.State.Running}}' stack-web-1 2>/dev/null)" = true
$script$, 'The project name comes from the folder name, so the folder must be ~/work/stack for the containers to be named stack-api-1 and stack-web-1. Run docker compose up -d from inside that folder, then docker compose ps to watch api go from "starting" to "healthy".', 'A plain depends_on only waits for the api container to start. condition service_healthy makes Compose wait until api''s healthcheck passes, so web never starts against an api that is not ready yet. That is the fix for "random" startup races between services.', 15, false, true),
('b311d691-aec7-51d2-9486-feadbaabbd34', '9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1', 2, 'Switch the api to staging with a .env file', $md$Without editing compose.yaml, create ~/work/stack/.env containing APP_ENV=staging and run "docker compose up -d" again, so that the api container's APP_ENV variable is "staging".$md$, $script$test "$(docker exec stack-api-1 printenv APP_ENV 2>/dev/null)" = staging
$script$, 'Compose reads .env from the project folder and substitutes ${APP_ENV:-dev} in the YAML. docker compose config shows the resolved value; docker compose up -d then recreates only the service whose configuration changed.', 'The .env file feeds ${...} placeholders in compose.yaml; the default after :- is used only when the variable is unset or empty. Because the api''s resolved environment changed, up -d recreated the api container and left everything else alone.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('84661e5a-b590-5aea-90aa-8d5c0881d048', '9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1', 1, $json$[{"id":"474396b7-82e8-5310-b8b7-07a6bf4a4fbb","lab_id":"9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1","position":1,"title":"Start a stack where web waits for a healthy api","description":"In ~/work/stack, write the compose.yaml shown above (an \"api\" service with a healthcheck, and a \"web\" service that depends on api with condition service_healthy), then run \"docker compose up -d\". Both containers must be running and api must report healthy.","verification_script":"test \"$(docker inspect -f '{{.State.Health.Status}}' stack-api-1 2\u003e/dev/null)\" = healthy \u0026\u0026 test \"$(docker inspect -f '{{.State.Running}}' stack-web-1 2\u003e/dev/null)\" = true\n","hint_context":"The project name comes from the folder name, so the folder must be ~/work/stack for the containers to be named stack-api-1 and stack-web-1. Run docker compose up -d from inside that folder, then docker compose ps to watch api go from \"starting\" to \"healthy\".","explanation_context":"A plain depends_on only waits for the api container to start. condition service_healthy makes Compose wait until api's healthcheck passes, so web never starts against an api that is not ready yet. That is the fix for \"random\" startup races between services.","points":15,"is_optional":false,"is_stateful":true},{"id":"b311d691-aec7-51d2-9486-feadbaabbd34","lab_id":"9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1","position":2,"title":"Switch the api to staging with a .env file","description":"Without editing compose.yaml, create ~/work/stack/.env containing APP_ENV=staging and run \"docker compose up -d\" again, so that the api container's APP_ENV variable is \"staging\".","verification_script":"test \"$(docker exec stack-api-1 printenv APP_ENV 2\u003e/dev/null)\" = staging\n","hint_context":"Compose reads .env from the project folder and substitutes ${APP_ENV:-dev} in the YAML. docker compose config shows the resolved value; docker compose up -d then recreates only the service whose configuration changed.","explanation_context":"The .env file feeds ${...} placeholders in compose.yaml; the default after :- is used only when the variable is unset or empty. Because the api's resolved environment changed, up -d recreated the api container and left everything else alone.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('074ebe96-dbd2-596f-a5a8-b62ce351f852', '84661e5a-b590-5aea-90aa-8d5c0881d048', '474396b7-82e8-5310-b8b7-07a6bf4a4fbb', 1, 'Start a stack where web waits for a healthy api', $md$In ~/work/stack, write the compose.yaml shown above (an "api" service with a healthcheck, and a "web" service that depends on api with condition service_healthy), then run "docker compose up -d". Both containers must be running and api must report healthy.$md$, $script$test "$(docker inspect -f '{{.State.Health.Status}}' stack-api-1 2>/dev/null)" = healthy && test "$(docker inspect -f '{{.State.Running}}' stack-web-1 2>/dev/null)" = true
$script$, 'The project name comes from the folder name, so the folder must be ~/work/stack for the containers to be named stack-api-1 and stack-web-1. Run docker compose up -d from inside that folder, then docker compose ps to watch api go from "starting" to "healthy".', 'A plain depends_on only waits for the api container to start. condition service_healthy makes Compose wait until api''s healthcheck passes, so web never starts against an api that is not ready yet. That is the fix for "random" startup races between services.', 15, false, true),
('fdd0bf33-9272-5037-afcb-1087d6d1ae6b', '84661e5a-b590-5aea-90aa-8d5c0881d048', 'b311d691-aec7-51d2-9486-feadbaabbd34', 2, 'Switch the api to staging with a .env file', $md$Without editing compose.yaml, create ~/work/stack/.env containing APP_ENV=staging and run "docker compose up -d" again, so that the api container's APP_ENV variable is "staging".$md$, $script$test "$(docker exec stack-api-1 printenv APP_ENV 2>/dev/null)" = staging
$script$, 'Compose reads .env from the project folder and substitutes ${APP_ENV:-dev} in the YAML. docker compose config shows the resolved value; docker compose up -d then recreates only the service whose configuration changed.', 'The .env file feeds ${...} placeholders in compose.yaml; the default after :- is used only when the variable is unset or empty. Because the api''s resolved environment changed, up -d recreated the api container and left everything else alone.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '84661e5a-b590-5aea-90aa-8d5c0881d048', updated_at = now()
WHERE id = '9a06dfb8-3923-5bb6-a1b1-7c9f3c7ed7f1' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('df8a4efb-b02f-5a6a-8c2d-a4c585b512af', '00000000-0000-0000-0000-000000000001', 'mcq', 'In a compose.yaml with services `web` and `db`, which hostname should web use...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9b159464-abba-57ae-acee-ad6eccc4ed4f', 'df8a4efb-b02f-5a6a-8c2d-a4c585b512af', 1, $json${"prompt":"In a compose.yaml with services `web` and `db`, which hostname should web use to connect to the database?","multiple":false,"options":[{"id":"a","text":"localhost","is_correct":false},{"id":"b","text":"db","is_correct":true},{"id":"c","text":"The db container's IP from docker inspect","is_correct":false},{"id":"d","text":"host.docker.internal","is_correct":false}],"explanation":"Compose puts services on a project network where each service name resolves via Docker's DNS. localhost is web itself, IPs change on recreate, and host.docker.internal points at the host machine, not another container."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cb222c70-fbe2-5a2b-b660-4918895d4c06', '00000000-0000-0000-0000-000000000001', 'mcq', 'A teammate ran `docker compose down -v` to ''reset the containers'' and the loc...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4efa18f8-032e-5692-b5b0-0e881bf44541', 'cb222c70-fbe2-5a2b-b660-4918895d4c06', 1, $json${"prompt":"A teammate ran `docker compose down -v` to 'reset the containers' and the local database is now empty. Why?","multiple":false,"options":[{"id":"a","text":"down always deletes data","is_correct":false},{"id":"b","text":"-v also removes the named volumes declared in the file","is_correct":true},{"id":"c","text":"-v means verbose and is unrelated","is_correct":false},{"id":"d","text":"Postgres wipes itself when stopped","is_correct":false}],"explanation":"Plain down removes containers and networks but keeps volumes; -v deletes volumes too. It does not mean verbose, and Postgres keeps its data on restart when a volume is used."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6d16053f-1c3f-5a26-ac13-d106fb74d4e1', '00000000-0000-0000-0000-000000000001', 'mcq', 'The API sometimes fails at startup with ''connection refused'' to Postgres desp...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('eba4f3a2-d319-5c34-9224-ce50cdc7b515', '6d16053f-1c3f-5a26-ac13-d106fb74d4e1', 1, $json${"prompt":"The API sometimes fails at startup with 'connection refused' to Postgres despite `depends_on: [db]`. What is the robust fix?","multiple":false,"options":[{"id":"a","text":"Add sleep 10 to the API's command","is_correct":false},{"id":"b","text":"Add a healthcheck to db and use depends_on with condition: service_healthy (and retry in the app)","is_correct":true},{"id":"c","text":"Use restart: always on db","is_correct":false},{"id":"d","text":"Start db manually first","is_correct":false}],"explanation":"depends_on alone waits only for container start, not readiness. A healthcheck-gated condition waits for Postgres to accept connections. Sleeps are guesses, restart policies do not order startup, and manual steps defeat the point of Compose."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bfe41158-154d-5571-a6cc-68eb9e907a01', '00000000-0000-0000-0000-000000000001', 'mcq', 'compose.yaml contains `image: myorg/api:${API_TAG:-dev}` and there is no API_...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ea683ba2-8f7f-5ab4-b189-fe3e72d0d84c', 'bfe41158-154d-5571-a6cc-68eb9e907a01', 1, $json${"prompt":"compose.yaml contains `image: myorg/api:${API_TAG:-dev}` and there is no API_TAG anywhere. Which tag is used?","multiple":false,"options":[{"id":"a","text":"latest","is_correct":false},{"id":"b","text":"dev","is_correct":true},{"id":"c","text":"Compose fails with an error","is_correct":false},{"id":"d","text":"An empty tag","is_correct":false}],"explanation":"${VAR:-default} falls back to the default when the variable is unset or empty. The ${VAR:?msg} form is the one that fails, and latest is only used when no tag is written at all."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4afffd28-ab3a-5ba8-8691-9ab0f69aeaf1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the difference between the `.env` file and the `env_file:` key?', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ad5c4444-7d39-5cdd-8ff8-3d078832638a', '4afffd28-ab3a-5ba8-8691-9ab0f69aeaf1', 1, $json${"prompt":"What is the difference between the `.env` file and the `env_file:` key?","multiple":false,"options":[{"id":"a","text":"They are the same thing","is_correct":false},{"id":"b","text":".env fills ${VAR} placeholders in compose.yaml; env_file: passes variables into the container","is_correct":true},{"id":"c","text":".env is for production, env_file is for development","is_correct":false},{"id":"d","text":"env_file fills placeholders; .env sets container variables","is_correct":false}],"explanation":".env is read by Compose for YAML interpolation; env_file lists KEY=value lines injected into the container's environment. They serve different layers and are not environment-specific."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b5126b04-ca5f-5f85-9f4d-93c80b0c9353', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command pushes your local image `api:2.0` to GitHub Container Registry ...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('921703fc-9f0d-5b11-9074-d347a3d199eb', 'b5126b04-ca5f-5f85-9f4d-93c80b0c9353', 1, $json${"prompt":"Which command pushes your local image `api:2.0` to GitHub Container Registry under org `acme`?","multiple":false,"options":[{"id":"a","text":"docker push api:2.0 --registry ghcr.io","is_correct":false},{"id":"b","text":"docker tag api:2.0 ghcr.io/acme/api:2.0, then docker push ghcr.io/acme/api:2.0","is_correct":true},{"id":"c","text":"docker push acme/api:2.0","is_correct":false},{"id":"d","text":"docker save api:2.0 | docker push ghcr.io","is_correct":false}],"explanation":"The registry is chosen by the image name, so you tag with the host prefix and push that name. There is no --registry flag, acme/api goes to Docker Hub, and push does not read tar streams."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d4dac911-8369-5744-a252-18a62ad20a2c', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your CI script logs in with `docker login -u bot -p $TOKEN`. What is the bett...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('169f13c9-5c87-548f-97ab-9f55e4da7e86', 'd4dac911-8369-5744-a252-18a62ad20a2c', 1, $json${"prompt":"Your CI script logs in with `docker login -u bot -p $TOKEN`. What is the better practice?","multiple":false,"options":[{"id":"a","text":"echo \"$TOKEN\" | docker login -u bot --password-stdin","is_correct":true},{"id":"b","text":"Hard-code the token in the Dockerfile","is_correct":false},{"id":"c","text":"Use the account password instead of a token","is_correct":false},{"id":"d","text":"Skip login and rely on anonymous pulls","is_correct":false}],"explanation":"--password-stdin keeps the secret out of process lists and shell history. Tokens in Dockerfiles leak into images, account passwords are broader than tokens, and anonymous access cannot push and is rate-limited."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5a1551f1-8d4b-5f1d-94fc-0887ccd818c7', '00000000-0000-0000-0000-000000000001', 'mcq', '(Review: Networking & Storage) Compose names your volume `shop_dbdata`. You m...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ce9813b6-4fb3-5ad9-a58c-c4e1c576b529', '5a1551f1-8d4b-5f1d-94fc-0887ccd818c7', 1, $json${"prompt":"(Review: Networking \u0026 Storage) Compose names your volume `shop_dbdata`. You move the project folder to `~/apps/shop-v2` and run `docker compose up -d`. The database is empty. Why?","multiple":false,"options":[{"id":"a","text":"Volumes are deleted when a folder moves","is_correct":false},{"id":"b","text":"The project name comes from the folder name, so Compose created a new volume shop-v2_dbdata","is_correct":true},{"id":"c","text":"Postgres needs a migration after moving","is_correct":false},{"id":"d","text":"Named volumes only work with bind mounts","is_correct":false}],"explanation":"Compose prefixes resources with the project name, which defaults to the folder name. The old volume still exists; set name: shop (or -p shop) to keep using it. Volumes are not tied to folder paths, and nothing needs migrating."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('ba72cb99-c384-5491-8534-3ffaf222916e', '00000000-0000-0000-0000-000000000001', 'Quiz: Compose & Registries', 'docker-compose-hub-registry-quiz', 'Quiz covering Compose & Registries.', 'mcq', 'published', 'module', '784678b7-85ef-5cc2-9575-fd8066409380', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'ba72cb99-c384-5491-8534-3ffaf222916e' AND question_id NOT IN ('df8a4efb-b02f-5a6a-8c2d-a4c585b512af', 'cb222c70-fbe2-5a2b-b660-4918895d4c06', '6d16053f-1c3f-5a26-ac13-d106fb74d4e1', 'bfe41158-154d-5571-a6cc-68eb9e907a01', '4afffd28-ab3a-5ba8-8691-9ab0f69aeaf1', 'b5126b04-ca5f-5f85-9f4d-93c80b0c9353', 'd4dac911-8369-5744-a252-18a62ad20a2c', '5a1551f1-8d4b-5f1d-94fc-0887ccd818c7');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('73820bb9-b617-5d56-920f-a5fce96ae5b5', 'ba72cb99-c384-5491-8534-3ffaf222916e', 'df8a4efb-b02f-5a6a-8c2d-a4c585b512af', '9b159464-abba-57ae-acee-ad6eccc4ed4f', 0, 2),
('026297a0-d070-5d13-9d61-9490ab152078', 'ba72cb99-c384-5491-8534-3ffaf222916e', 'cb222c70-fbe2-5a2b-b660-4918895d4c06', '4efa18f8-032e-5692-b5b0-0e881bf44541', 1, 2),
('32240ea1-1dc0-56d2-a092-d524e53a4dd4', 'ba72cb99-c384-5491-8534-3ffaf222916e', '6d16053f-1c3f-5a26-ac13-d106fb74d4e1', 'eba4f3a2-d319-5c34-9224-ce50cdc7b515', 2, 2),
('d0afc1f0-aa63-50a1-b5a2-d8ec59c637c6', 'ba72cb99-c384-5491-8534-3ffaf222916e', 'bfe41158-154d-5571-a6cc-68eb9e907a01', 'ea683ba2-8f7f-5ab4-b189-fe3e72d0d84c', 3, 2),
('03e838b2-0bbe-561b-b51c-22ea5d3f69d5', 'ba72cb99-c384-5491-8534-3ffaf222916e', '4afffd28-ab3a-5ba8-8691-9ab0f69aeaf1', 'ad5c4444-7d39-5cdd-8ff8-3d078832638a', 4, 2),
('5b5434d5-1aa9-50d3-bec3-52d62576c0a0', 'ba72cb99-c384-5491-8534-3ffaf222916e', 'b5126b04-ca5f-5f85-9f4d-93c80b0c9353', '921703fc-9f0d-5b11-9074-d347a3d199eb', 5, 2),
('2fd8ba92-66f5-5fbd-8404-114fc2363b97', 'ba72cb99-c384-5491-8534-3ffaf222916e', 'd4dac911-8369-5744-a252-18a62ad20a2c', '169f13c9-5c87-548f-97ab-9f55e4da7e86', 6, 2),
('223556ad-ea30-5a67-a41e-a53c96902017', 'ba72cb99-c384-5491-8534-3ffaf222916e', '5a1551f1-8d4b-5f1d-94fc-0887ccd818c7', 'ce9813b6-4fb3-5ad9-a58c-c4e1c576b529', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('784678b7-85ef-5cc2-9575-fd8066409380', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Quiz: Compose & Registries', 'assessment', 5, 12, 'ba72cb99-c384-5491-8534-3ffaf222916e')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Production-Ready Containers
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', '27527dc6-807c-51bf-beb9-a499519888d9', 'Production-Ready Containers', 7, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('cd29543a-819b-5a09-b50d-cf9cbac6a86f', '27527dc6-807c-51bf-beb9-a499519888d9', '1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', 'Container Security: Least Privilege, Rootless and Scanning', 'notes', 0, $md$## Why this matters

Containers share the host kernel (Section 1). A container running as root, with
every capability and a writable filesystem, gives an attacker who breaks your
app a very short path to the host. A handful of defaults closes most of that path.

## Mental model: layers of a castle

No single wall stops every attack. You stack defences so a breach of one does
not mean a breach of all.

```
  [ 1. small, scanned, pinned image     ]  less to attack
  [ 2. non-root USER                    ]  attacker is not root
  [ 3. drop capabilities, no-new-privs  ]  root powers removed anyway
  [ 4. read-only filesystem             ]  cannot drop tools or modify code
  [ 5. secrets not in image or env      ]  nothing to steal from layers
  [ 6. rootless daemon / userns         ]  even container-root is a normal host user
```

Terms:

- **Capabilities**: Linux splits root's powers into ~40 pieces (`NET_BIND_SERVICE`,
  `CHOWN`, `SYS_ADMIN`, ...). Docker gives containers a reduced default set; you can drop more.
- **no-new-privileges**: stops a process from gaining privileges via setuid binaries (like `sudo`).
- **Rootless mode**: the Docker daemon and containers run as an ordinary user, so
  "root in the container" maps to an unprivileged user on the host.

## See it work

### 1. Run as a non-root user

In the Dockerfile (Section 4):

```dockerfile
RUN addgroup -S app && adduser -S -G app app
USER app
```

Or at run time, for images that support it:

```bash
docker run --rm -u 10001:10001 alpine:3.20 id
```

Output: `uid=10001 gid=10001 groups=10001`.

### 2. Drop capabilities and block privilege escalation

```bash
docker run -d --name web \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  --security-opt no-new-privileges:true \
  nginx:1.27-alpine
```

- `--cap-drop ALL` removes every capability.
- `--cap-add NET_BIND_SERVICE` gives back only "bind ports below 1024".
- (Some images need a few more, such as `CHOWN`, `SETUID`, `SETGID` for nginx's
  worker processes; add exactly what the logs say is missing.)

Never use `--privileged` for an app: it disables nearly all isolation.

### 3. Read-only root filesystem

```bash
docker run --rm --read-only --tmpfs /tmp alpine:3.20 sh -c 'touch /tmp/ok && echo tmp-ok; touch /etc/x'
```

Expected output:

```
tmp-ok
touch: /etc/x: Read-only file system
```

The app can write only where you allow it: `--tmpfs` for scratch space, volumes for data.

### 4. Keep secrets out of images and env vars

| Where | Safe? |
|---|---|
| `ENV`/`ARG` in a Dockerfile, `COPY .env` | No: anyone with the image can read it |
| `docker run -e PASSWORD=...` | Weak: visible in `docker inspect` and to child processes |
| Mounted secret file (`-v ./secret:/run/secrets/db:ro`, Compose/Swarm `secrets:`, Kubernetes Secrets) | Better |
| Build-time: `RUN --mount=type=secret` | Yes, for builds |

### 5. Scan and pin images

```bash
docker scout cves myimage:1.0        # Docker Scout: known vulnerabilities (CVEs)
trivy image myimage:1.0              # Trivy: a popular open-source alternative
```

Pin base images by version or digest, rebuild regularly (`--pull`) to pick up
patches, and prefer minimal bases (slim, distroless) so there is less to patch.

### 6. Protect the daemon

- Never mount `/var/run/docker.sock` into an app container: that is root on the host.
- The `docker` group is root-equivalent; keep it small.
- Consider **rootless Docker** (`dockerd-rootless-setuptool.sh install`) or
  user-namespace remapping (`userns-remap` in `daemon.json`) on shared hosts.

## Try it

Harden this command as far as you can without breaking a typical app that
listens on port 8080 and writes temp files to `/tmp`:

```bash
docker run -d -p 8080:8080 myapp:1.0
```

<details>
<summary>Show answer</summary>

```bash
docker run -d -p 8080:8080 \
  -u 10001:10001 \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --read-only --tmpfs /tmp \
  --memory 512m --pids-limit 200 \
  myapp:1.0@sha256:<pinned digest>
```

Port 8080 is above 1024, so no `NET_BIND_SERVICE` is needed. Resource limits
(lesson 3) also stop one container from starving the host.

</details>

## Common mistakes

- **`--privileged` "to make it work".** Find the one capability or device it actually needs.
- **Running as root because the base image does.** Add `USER`.
- **Secrets baked into images** (`COPY .env`, `ENV API_KEY=`). Rotate them; they are public now.
- **Scanning once.** New CVEs appear daily against old images; scan in CI and rebuild.

## Remember

- Defence in depth: small scanned image, non-root, drop caps, no-new-privileges, read-only FS, secrets as files.
- `--cap-drop ALL` + add back only what is needed. Never `--privileged`.
- `--read-only` + `--tmpfs /tmp` + volumes for real data.
- Docker socket access = host root. Rootless mode reduces the blast radius.
- Scan (`docker scout`, `trivy`), pin, and rebuild often.

**Self-check:**

1. What does `--cap-drop ALL --cap-add NET_BIND_SERVICE` allow?
2. Why is `-e DB_PASSWORD=...` weaker than a mounted secret file?
3. What does rootless mode change about "root inside the container"?
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0982ab00-00c6-5191-a94f-e5d1d8c464ec', '27527dc6-807c-51bf-beb9-a499519888d9', '1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', 'Healthchecks: Running Is Not the Same as Working', 'notes', 1, $md$## Why this matters

`docker ps` says `Up 3 days`, yet every request returns 500 because the app's
database pool is dead. Docker only knows the **process is alive**. A
**healthcheck** teaches Docker how to ask "are you actually working?", and
Compose, Swarm and load balancers can act on the answer.

## Mental model: a pulse versus a conversation

- "Running" = the patient has a pulse.
- "Healthy" = the patient answers a question correctly.

A healthcheck is a small command Docker runs **inside** the container on a
schedule. Exit code `0` = healthy, `1` = unhealthy.

```
 container starts
      |
      v
  [starting] --(check passes)--> [healthy] --(retries failures in a row)--> [unhealthy]
      |                              ^                                          |
      +-- start-period: failures     +------------(check passes again)----------+
          here do not count
```

## See it work

### In a Dockerfile

```dockerfile
FROM nginx:1.27-alpine
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ || exit 1
```

| Option | Default | Meaning |
|---|---|---|
| `--interval` | 30s | Time between checks |
| `--timeout` | 30s | A check taking longer counts as a failure |
| `--start-period` | 0s | Grace time at startup; failures do not count yet |
| `--start-interval` | 5s | Check interval during the start period (newer engines) |
| `--retries` | 3 | Consecutive failures before `unhealthy` |

`HEALTHCHECK NONE` disables a check inherited from the base image.

```bash
docker build -t web-hc .
docker run -d --name hc web-hc
docker ps --filter name=hc
```

Expected `STATUS` column, first `(health: starting)`, then:

```
Up 15 seconds (healthy)
```

Read the details:

```bash
docker inspect -f '{{.State.Health.Status}}' hc
docker inspect -f '{{json .State.Health.Log}}' hc     # last results with output
```

### At run time, without changing the image

```bash
docker run -d --name hc2 \
  --health-cmd "wget -qO- http://127.0.0.1/ || exit 1" \
  --health-interval 10s --health-retries 3 \
  nginx:1.27-alpine
```

### In Compose

```yaml
services:
  api:
    image: myorg/api:1.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 20s
```

`test` forms: `["CMD", ...]` runs the program directly; `["CMD-SHELL", "..."]` runs through `sh -c`.

### What a good health endpoint checks

- Cheap and fast (it runs every few seconds).
- Checks what **this** service needs to serve requests (it can open its DB pool).
- Does not cascade: if a downstream API is down, report degraded in logs, but do
  not make every service unhealthy at once.

### What Docker does with "unhealthy"

**Plain Docker does not restart unhealthy containers.** It only reports the
status (and emits a `health_status` event). Acting on it is the job of:

- **Compose**: `depends_on: condition: service_healthy` gates startup.
- **Docker Swarm**: replaces unhealthy tasks.
- **Kubernetes**: ignores Docker's `HEALTHCHECK` and uses its own liveness/readiness probes.
- Your monitoring, alerting on `docker events --filter event=health_status`.

## Try it

A Dockerfile uses `HEALTHCHECK CMD curl -f http://localhost:8080/ || exit 1` on
a `distroless` image, and the container is always `unhealthy` even though the
app works. Why?

<details>
<summary>Show answer</summary>

The check runs **inside** the container, and distroless images have no `curl`
(and no shell for `||`). The command fails every time. Use a tool that exists
in the image, ship a tiny health binary, or build the check into the app
(for example `CMD ["/app", "healthcheck"]`).

</details>

## Common mistakes

- **Expecting Docker to restart an unhealthy container.** It does not (outside Swarm).
- **Using a tool the image lacks** (`curl` on Alpine or distroless). Alpine has `wget` via busybox.
- **Checks that are too heavy** (full DB queries every 2 s) or **too strict**
  (no `start-period` for an app that boots in 30 s).
- **Healthcheck on `localhost` when the app binds another interface** only. Match the listen address.

## Remember

- Running = process alive. Healthy = the check command exits 0.
- States: `starting` → `healthy` ⇄ `unhealthy` (after `retries` failures).
- Set it in the Dockerfile (`HEALTHCHECK`), at run (`--health-cmd`) or in Compose (`healthcheck:`).
- Docker reports health; Compose/Swarm/monitoring act on it. Kubernetes uses its own probes.
- The check runs inside the container: use tools the image has.

**Self-check:**

1. What does `--start-period` protect against?
2. Does plain Docker restart a container that turns unhealthy?
3. Which command shows the output of the last health checks?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('01ce7af7-3e2a-5e71-9bfa-d5401ad8689a', '27527dc6-807c-51bf-beb9-a499519888d9', '1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', 'Resource Limits: Memory, CPU and PIDs', 'notes', 2, $md$## Why this matters

By default a container may use **all** of the host's memory and CPU. One memory
leak or runaway loop can freeze every other container on the machine. Limits
turn "the whole server died" into "one container restarted".

## Mental model: a hotel room's electricity fuse

Each room (container) gets a fuse. Plug in too much and **that room's** fuse
trips; the rest of the hotel keeps its lights on. These fuses are Linux
**cgroups** (Section 1): the kernel counts and caps what each container consumes.

Two kinds of limits behave very differently:

| Resource | What happens at the limit | Why |
|---|---|---|
| **Memory** | The kernel **kills** the process (OOM kill, exit code **137**) | Memory cannot be "slowed down" |
| **CPU** | The process is **throttled** (runs slower) | CPU time can be shared out |

## See it work

### Memory

```bash
docker run -d --name capped --memory 64m nginx:1.27-alpine
docker stats --no-stream capped
```

Expected output (values vary):

```
NAME     CPU %   MEM USAGE / LIMIT   MEM %
capped   0.00%   3.9MiB / 64MiB      6.09%
```

Watch an OOM kill happen:

```bash
docker run --name hog --memory 32m python:3.12-alpine \
  python3 -c "x = bytearray(100 * 1024 * 1024)"
docker inspect -f '{{.State.ExitCode}} {{.State.OOMKilled}}' hog
```

Expected output:

```
137 true
```

Memory flags:

- `--memory 512m`: hard limit.
- `--memory-swap 512m`: memory + swap total; equal to `--memory` means no swap.
- `--memory-reservation 256m`: a soft target the kernel enforces when the host is under pressure.

### CPU

```bash
docker run -d --name cpu-half --cpus 0.5 nginx:1.27-alpine
```

- `--cpus 1.5`: at most one and a half CPU cores' worth of time.
- `--cpu-shares 512`: relative weight (default 1024) that only matters when CPUs are busy.
- `--cpuset-cpus 0,1`: pin to specific cores.

### Process count

```bash
docker run --rm --pids-limit 100 alpine:3.20 sh -c 'echo limited'
```

`--pids-limit` stops fork bombs and thread leaks from exhausting the host's process table.

### Change limits on a running container

```bash
docker update --memory 128m --memory-swap 128m --cpus 1 capped
docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' capped
```

Output: `134217728 1000000000` (bytes, and billionths of a CPU).

### In Compose

```yaml
services:
  api:
    image: myorg/api:1.0
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          memory: 256M
    pids_limit: 200
```

`docker compose up` applies `deploy.resources.limits` to normal (non-Swarm) containers too.

### Runtimes must know their limit

Language runtimes size their heaps from "available memory". Modern JVMs (Java
10+), Node and Go read the cgroup limit, but you often still tune them:
`-XX:MaxRAMPercentage=75` for Java, `--max-old-space-size` for Node. Leave
headroom: the limit covers the whole process, not just the heap.

## Try it

A Java service restarts every few hours with exit code 137, and `OOMKilled` is
`true`. The limit is `--memory 1g` and the JVM uses `-Xmx1g`. What is wrong?

<details>
<summary>Show answer</summary>

The heap alone is allowed to use the entire 1 GB limit, but the JVM also needs
memory for metaspace, threads, buffers and the JIT. The total crosses 1 GB and
the kernel kills it. Lower the heap (`-XX:MaxRAMPercentage=75` or
`-Xmx700m`) or raise the limit.

</details>

## Common mistakes

- **No limits in production.** One leak takes the host down.
- **Reading exit 137 as "Docker bug".** Check `OOMKilled`; it is usually the memory limit.
- **Setting `--cpus` and expecting a crash.** CPU limits throttle; look for high
  latency, not restarts.
- **Heap = limit.** Leave room for non-heap memory.

## Remember

- No limits by default. Limits are cgroups.
- Memory over limit → OOM kill, exit **137**, `OOMKilled=true`.
- CPU over limit → throttled (slower), never killed.
- Flags: `--memory`, `--memory-swap`, `--cpus`, `--cpu-shares`, `--pids-limit`; `docker update` changes them live.
- `docker stats` shows usage against limits.

**Self-check:**

1. What happens when a container exceeds its memory limit? Its CPU limit?
2. Which `inspect` field confirms an OOM kill?
3. What does `--pids-limit` protect against?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1015fcd4-ce0a-5577-a3c1-a7320c82a81d', '27527dc6-807c-51bf-beb9-a499519888d9', '1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', 'Best Practices: The Production Checklist', 'notes', 3, $md$## Why this matters

You have now seen each piece separately. This lesson pulls them into one
checklist you can run against any image or `docker run` command, in a code
review or an interview. Every item points back to the lesson that explains it.

## Mental model: the twelve-factor container

A good container is **disposable cattle, not a pet**: you can kill it, start a
new one anywhere, and nothing is lost. Everything below serves that idea.

```
  config from env/secret files   logs to stdout/stderr
              \                    /
         +--------------------------------+
         |  one process, stateless,       |  <- killable at any time
         |  fast start, clean SIGTERM     |
         +--------------------------------+
              /                    \
  data in volumes / databases   same image in dev, CI, prod
```

## The checklist

The "Lesson" column reads *section.lesson*: 4.5 = Section 4, lesson 5.

### Image (build time)

| Do | Why | Lesson |
|---|---|---|
| Pin base image versions (or digests) | Reproducible builds | 3.2 |
| Use a slim/distroless final stage via multi-stage builds | Smaller, fewer CVEs | 4.5 |
| Order Dockerfile for cache: manifests → install → source | Fast rebuilds | 4.4 |
| `.dockerignore` (`.git`, `node_modules`, `.env`) | Smaller context, no leaked secrets | 4.1 |
| No secrets in `ARG`/`ENV`/layers; use `--secret` | Images get shared | 4.3, 4.6 |
| Non-root `USER` | Limit damage if breached | 4.3, 7.1 |
| Exec-form `CMD`/`ENTRYPOINT`, handle SIGTERM or use `--init` | Clean, fast stops | 4.2 |
| `HEALTHCHECK` (or orchestrator probes) | Detect "running but broken" | 7.2 |
| OCI labels (`org.opencontainers.image.source`, `version`) | Traceability | 4.3 |
| Scan in CI (`docker scout`, `trivy`) and rebuild regularly | New CVEs appear daily | 7.1 |
| Tag with a version (and git SHA); never deploy `latest` | Know what runs; easy rollback | 3.2 |

### Runtime

| Do | Why | Lesson |
|---|---|---|
| Memory, CPU and PID limits | One container cannot sink the host | 7.3 |
| `--restart unless-stopped` (or an orchestrator) | Recover from crashes | 2.2 |
| `--read-only` + `--tmpfs` where possible | Attacker cannot modify the filesystem | 7.1 |
| `--cap-drop ALL`, add back the minimum; `no-new-privileges` | Least privilege | 7.1 |
| Never `--privileged`, never mount `docker.sock` into apps | Both equal host root | 1.4, 7.1 |
| Data in named volumes or managed databases | Containers are disposable | 5.2 |
| User-defined networks; publish only public ports | Isolation | 5.1 |
| Logs to stdout/stderr, with a log driver and rotation | `docker logs` works; disks do not fill | 8.1 |
| One main concern per container | Independent scaling and restarts | this lesson |

## See it work: before and after

Before:

```dockerfile
FROM node:latest
COPY . .
RUN npm install
ENV API_KEY=sk_live_123
CMD npm start
```

Problems: moving `latest` tag, huge base, cache-busting order, dev dependencies
and source shipped, secret baked in, root user, shell-form CMD (signals).

After:

```dockerfile
FROM node:22.11-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:22.11-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
USER node
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

Run it:

```bash
docker run -d --name api \
  -p 3000:3000 \
  --env-file /etc/api/env \
  --memory 512m --cpus 1 --pids-limit 200 \
  --read-only --tmpfs /tmp \
  --cap-drop ALL --security-opt no-new-privileges:true \
  --restart unless-stopped \
  myorg/api:1.8.0
```

`API_KEY` now comes from a file on the server (better still, a mounted secret), not the image.

## Try it

Review this command and list at least four problems:

```bash
docker run -d --privileged -v /var/run/docker.sock:/var/run/docker.sock \
  -e DB_PASSWORD=hunter2 -p 5432:5432 myorg/app:latest
```

<details>
<summary>Show answer</summary>

1. `--privileged`: disables isolation.
2. Docker socket mounted: the container controls the host.
3. Password in `-e`: visible in `inspect`; use a secret file.
4. `-p 5432:5432`: database port exposed to the network.
5. `:latest`: unknown version, no reliable rollback.
6. No memory/CPU/PID limits, no restart policy, no read-only FS, probably root.

</details>

## Common mistakes

- **Treating containers as pets**: SSH-ing in (or `docker exec`) to patch things by hand.
  Rebuild the image instead; manual changes vanish on the next deploy.
- **Several services in one container** (app + DB + cron with a supervisor).
  Split them; let Compose or an orchestrator wire them together.
- **Copying a checklist without measuring.** Check image size (`docker images`),
  CVEs (scanner) and startup time before and after.

## Remember

- Containers are disposable: config in, logs out, data elsewhere.
- Build: pinned, small, cached, no secrets, non-root, exec form, healthcheck, scanned.
- Run: limits, restart policy, read-only, dropped caps, no privileged/socket, minimal ports.
- Version tags (and digests), never `latest`, in production.

**Self-check:**

1. Name three build-time and three run-time hardening steps.
2. Why should logs go to stdout/stderr?
3. Why is "one concern per container" a good default?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('84d3de2d-c60c-5f30-b36f-e59c7ee50f72', '27527dc6-807c-51bf-beb9-a499519888d9', '1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', 'Lab: Build and Run a Hardened Image', 'notes', 4, $md$## Why this matters

This lab combines the whole section into one image and one `docker run`: a
multi-stage build, a non-root user, a healthcheck, resource limits and a
read-only filesystem. It is the shape of a real production container, at toy size.

## Sandbox note

As in every lab here, containers use `--network host` and the build uses
`--network=host`. Everything else is exactly what you would type on a server.

## The Dockerfile

```dockerfile
# ---- build stage: has apk and a full toolset; thrown away ----
FROM alpine:3.20 AS build
RUN mkdir -p /out && echo "<h1>multi-stage ok</h1>" > /out/index.html

# ---- runtime stage: tiny busybox, only the built file ----
FROM busybox:1.36
COPY --from=build /out /www
# run unprivileged
USER 1000:1000
# >1024, so no root needed to bind
EXPOSE 8080
HEALTHCHECK --interval=5s --timeout=3s --start-period=2s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ || exit 1
# exec form, foreground
CMD ["httpd", "-f", "-p", "8080", "-h", "/www"]
```

## Task 1: build it

```bash
mkdir -p ~/work/prod && cd ~/work/prod
# write the Dockerfile above (cat > Dockerfile <<'EOF' ... EOF)
docker build --network=host -t webapp:1.0 .

docker images webapp                                   # a few MB
docker image inspect -f '{{.Config.User}}' webapp:1.0  # 1000:1000
docker history webapp:1.0                              # no apk/alpine layers on top of busybox
```

[[lab-task:1]]

## Task 2: run it hardened and limited

```bash
docker run -d --name webapp --network host \
  --memory 64m --cpus 0.5 \
  --read-only \
  webapp:1.0

docker ps --filter name=webapp     # STATUS: Up ... (health: starting), then (healthy)
docker stats --no-stream webapp    # MEM USAGE / LIMIT shows 64MiB
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8080
```

Expected output of the last command:

```
<h1>multi-stage ok</h1>
```

If `docker run` prints a warning like *"Your kernel does not support memory
limit capabilities ... Limitation discarded"*, the daemon you are talking to
(some rootless setups) has no cgroup control over memory or CPU, so it ignored
that limit. The check accepts that; on a normal Linux server the limits apply.

Extra credit (not graded): run a second copy with `--cap-drop ALL
--security-opt no-new-privileges:true` on another port and confirm it still serves.

[[lab-task:2]]

## Remember

- Multi-stage + non-root + healthcheck are image properties: check them with `docker image inspect`.
- Limits and read-only are run-time properties: check them in `docker inspect` under `HostConfig`.
- `(healthy)` in `docker ps` is the goal, not just `Up`.
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('61d0c40d-f9c0-5a10-943c-bd7da592647a', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '84d3de2d-c60c-5f30-b36f-e59c7ee50f72', 'module', 'Lab: Build and Run a Hardened Image', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 40, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'bf1f65b0-07a2-52d4-ac70-5ad372dc70fc' AND id NOT IN ('2e0e5610-6472-5c00-8641-ed7512a4c445', '13be64e1-d9d8-5742-bcca-c60bb33c631c');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'bf1f65b0-07a2-52d4-ac70-5ad372dc70fc';
DELETE FROM lab_tasks WHERE lab_id = '61d0c40d-f9c0-5a10-943c-bd7da592647a' AND id NOT IN ('c7fb77d7-f9c8-597a-b493-f734b7788a10', 'ca1928d6-9514-547e-a5ca-a13302a9de63');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '61d0c40d-f9c0-5a10-943c-bd7da592647a';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('c7fb77d7-f9c8-597a-b493-f734b7788a10', '61d0c40d-f9c0-5a10-943c-bd7da592647a', 1, 'Build a multi-stage, non-root image with a healthcheck', $md$Write the Dockerfile shown above to ~/work/prod/Dockerfile and build it as webapp:1.0. The image must come from a multi-stage build whose final stage is busybox (no apk), run as user 1000, and define a HEALTHCHECK.$md$, $script$docker image inspect webapp:1.0 >/dev/null 2>&1 \
  && test "$(docker image inspect -f '{{.Config.User}}' webapp:1.0)" = "1000:1000" \
  && test -n "$(docker image inspect -f '{{if .Config.Healthcheck}}yes{{end}}' webapp:1.0)" \
  && ! docker run --rm --network host --entrypoint sh webapp:1.0 -c 'test -e /sbin/apk' \
  && docker run --rm --network host --entrypoint cat webapp:1.0 /www/index.html | grep -q "multi-stage ok"
$script$, 'cd ~/work/prod and run docker build --network=host -t webapp:1.0 . — the first stage (FROM alpine:3.20 AS build) writes /out/index.html, and the final stage (FROM busybox:1.36) copies it with COPY --from=build /out /www, then sets USER 1000:1000 and a HEALTHCHECK.', 'Only the final stage ships. The alpine build stage (with apk) is thrown away; the busybox runtime gets just the one file it needs. USER makes the server run unprivileged, and HEALTHCHECK records how Docker should probe it, all baked into the image config you can read with docker image inspect.', 15, false, true),
('ca1928d6-9514-547e-a5ca-a13302a9de63', '61d0c40d-f9c0-5a10-943c-bd7da592647a', 2, 'Run it with resource limits until it reports healthy', $md$Run webapp:1.0 as a container named "webapp" (with --network host) limited to 64 MB of memory and half a CPU, read-only root filesystem, and wait until docker reports it healthy.$md$, $script$# A daemon without cgroup memory/CPU support (some rootless setups) discards
# limits with a warning, so only check the limits it can actually enforce.
test "$(docker inspect -f '{{.State.Health.Status}}' webapp 2>/dev/null)" = healthy \
  && test "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' webapp)" = true \
  && { [ "$(docker info -f '{{.MemoryLimit}}')" != true ] || test "$(docker inspect -f '{{.HostConfig.Memory}}' webapp)" = 67108864; } \
  && { [ "$(docker info -f '{{.CPUCfsQuota}}')" != true ] || test "$(docker inspect -f '{{.HostConfig.NanoCpus}}' webapp)" = 500000000; }
$script$, 'docker run -d --name webapp --network host --memory 64m --cpus 0.5 --read-only webapp:1.0, then watch docker ps until the STATUS column shows (healthy) — the healthcheck runs every 5 seconds.', '--memory and --cpus become cgroup limits (stored in HostConfig as bytes and billionths of a CPU), --read-only makes the root filesystem immutable, and the HEALTHCHECK from the image turns "running" into "healthy" once wget gets a page back.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('bf1f65b0-07a2-52d4-ac70-5ad372dc70fc', '61d0c40d-f9c0-5a10-943c-bd7da592647a', 1, $json$[{"id":"c7fb77d7-f9c8-597a-b493-f734b7788a10","lab_id":"61d0c40d-f9c0-5a10-943c-bd7da592647a","position":1,"title":"Build a multi-stage, non-root image with a healthcheck","description":"Write the Dockerfile shown above to ~/work/prod/Dockerfile and build it as webapp:1.0. The image must come from a multi-stage build whose final stage is busybox (no apk), run as user 1000, and define a HEALTHCHECK.","verification_script":"docker image inspect webapp:1.0 \u003e/dev/null 2\u003e\u00261 \\\n  \u0026\u0026 test \"$(docker image inspect -f '{{.Config.User}}' webapp:1.0)\" = \"1000:1000\" \\\n  \u0026\u0026 test -n \"$(docker image inspect -f '{{if .Config.Healthcheck}}yes{{end}}' webapp:1.0)\" \\\n  \u0026\u0026 ! docker run --rm --network host --entrypoint sh webapp:1.0 -c 'test -e /sbin/apk' \\\n  \u0026\u0026 docker run --rm --network host --entrypoint cat webapp:1.0 /www/index.html | grep -q \"multi-stage ok\"\n","hint_context":"cd ~/work/prod and run docker build --network=host -t webapp:1.0 . — the first stage (FROM alpine:3.20 AS build) writes /out/index.html, and the final stage (FROM busybox:1.36) copies it with COPY --from=build /out /www, then sets USER 1000:1000 and a HEALTHCHECK.","explanation_context":"Only the final stage ships. The alpine build stage (with apk) is thrown away; the busybox runtime gets just the one file it needs. USER makes the server run unprivileged, and HEALTHCHECK records how Docker should probe it, all baked into the image config you can read with docker image inspect.","points":15,"is_optional":false,"is_stateful":true},{"id":"ca1928d6-9514-547e-a5ca-a13302a9de63","lab_id":"61d0c40d-f9c0-5a10-943c-bd7da592647a","position":2,"title":"Run it with resource limits until it reports healthy","description":"Run webapp:1.0 as a container named \"webapp\" (with --network host) limited to 64 MB of memory and half a CPU, read-only root filesystem, and wait until docker reports it healthy.","verification_script":"# A daemon without cgroup memory/CPU support (some rootless setups) discards\n# limits with a warning, so only check the limits it can actually enforce.\ntest \"$(docker inspect -f '{{.State.Health.Status}}' webapp 2\u003e/dev/null)\" = healthy \\\n  \u0026\u0026 test \"$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' webapp)\" = true \\\n  \u0026\u0026 { [ \"$(docker info -f '{{.MemoryLimit}}')\" != true ] || test \"$(docker inspect -f '{{.HostConfig.Memory}}' webapp)\" = 67108864; } \\\n  \u0026\u0026 { [ \"$(docker info -f '{{.CPUCfsQuota}}')\" != true ] || test \"$(docker inspect -f '{{.HostConfig.NanoCpus}}' webapp)\" = 500000000; }\n","hint_context":"docker run -d --name webapp --network host --memory 64m --cpus 0.5 --read-only webapp:1.0, then watch docker ps until the STATUS column shows (healthy) — the healthcheck runs every 5 seconds.","explanation_context":"--memory and --cpus become cgroup limits (stored in HostConfig as bytes and billionths of a CPU), --read-only makes the root filesystem immutable, and the HEALTHCHECK from the image turns \"running\" into \"healthy\" once wget gets a page back.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('2e0e5610-6472-5c00-8641-ed7512a4c445', 'bf1f65b0-07a2-52d4-ac70-5ad372dc70fc', 'c7fb77d7-f9c8-597a-b493-f734b7788a10', 1, 'Build a multi-stage, non-root image with a healthcheck', $md$Write the Dockerfile shown above to ~/work/prod/Dockerfile and build it as webapp:1.0. The image must come from a multi-stage build whose final stage is busybox (no apk), run as user 1000, and define a HEALTHCHECK.$md$, $script$docker image inspect webapp:1.0 >/dev/null 2>&1 \
  && test "$(docker image inspect -f '{{.Config.User}}' webapp:1.0)" = "1000:1000" \
  && test -n "$(docker image inspect -f '{{if .Config.Healthcheck}}yes{{end}}' webapp:1.0)" \
  && ! docker run --rm --network host --entrypoint sh webapp:1.0 -c 'test -e /sbin/apk' \
  && docker run --rm --network host --entrypoint cat webapp:1.0 /www/index.html | grep -q "multi-stage ok"
$script$, 'cd ~/work/prod and run docker build --network=host -t webapp:1.0 . — the first stage (FROM alpine:3.20 AS build) writes /out/index.html, and the final stage (FROM busybox:1.36) copies it with COPY --from=build /out /www, then sets USER 1000:1000 and a HEALTHCHECK.', 'Only the final stage ships. The alpine build stage (with apk) is thrown away; the busybox runtime gets just the one file it needs. USER makes the server run unprivileged, and HEALTHCHECK records how Docker should probe it, all baked into the image config you can read with docker image inspect.', 15, false, true),
('13be64e1-d9d8-5742-bcca-c60bb33c631c', 'bf1f65b0-07a2-52d4-ac70-5ad372dc70fc', 'ca1928d6-9514-547e-a5ca-a13302a9de63', 2, 'Run it with resource limits until it reports healthy', $md$Run webapp:1.0 as a container named "webapp" (with --network host) limited to 64 MB of memory and half a CPU, read-only root filesystem, and wait until docker reports it healthy.$md$, $script$# A daemon without cgroup memory/CPU support (some rootless setups) discards
# limits with a warning, so only check the limits it can actually enforce.
test "$(docker inspect -f '{{.State.Health.Status}}' webapp 2>/dev/null)" = healthy \
  && test "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' webapp)" = true \
  && { [ "$(docker info -f '{{.MemoryLimit}}')" != true ] || test "$(docker inspect -f '{{.HostConfig.Memory}}' webapp)" = 67108864; } \
  && { [ "$(docker info -f '{{.CPUCfsQuota}}')" != true ] || test "$(docker inspect -f '{{.HostConfig.NanoCpus}}' webapp)" = 500000000; }
$script$, 'docker run -d --name webapp --network host --memory 64m --cpus 0.5 --read-only webapp:1.0, then watch docker ps until the STATUS column shows (healthy) — the healthcheck runs every 5 seconds.', '--memory and --cpus become cgroup limits (stored in HostConfig as bytes and billionths of a CPU), --read-only makes the root filesystem immutable, and the HEALTHCHECK from the image turns "running" into "healthy" once wget gets a page back.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'bf1f65b0-07a2-52d4-ac70-5ad372dc70fc', updated_at = now()
WHERE id = '61d0c40d-f9c0-5a10-943c-bd7da592647a' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f11d6e6d-878f-58f8-b787-3af7c613af72', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container needs to listen on port 80 and nothing else privileged. What is t...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('36d72068-30fb-5cd0-ae1f-5ecf92112e30', 'f11d6e6d-878f-58f8-b787-3af7c613af72', 1, $json${"prompt":"A container needs to listen on port 80 and nothing else privileged. What is the least-privilege capability setup?","multiple":false,"options":[{"id":"a","text":"--privileged","is_correct":false},{"id":"b","text":"--cap-drop ALL --cap-add NET_BIND_SERVICE","is_correct":true},{"id":"c","text":"--cap-add SYS_ADMIN","is_correct":false},{"id":"d","text":"The default capability set is already minimal","is_correct":false}],"explanation":"Dropping everything and adding back only NET_BIND_SERVICE (bind ports below 1024) is least privilege. --privileged disables isolation, SYS_ADMIN is close to root, and Docker's default set still contains capabilities most apps never need."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a53581ec-9831-5562-a12e-c67dd4b0aa99', '00000000-0000-0000-0000-000000000001', 'mcq', 'A monitoring tool asks you to mount /var/run/docker.sock into its container. ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('07cd15e1-f5ac-5cc8-80c5-1e96493f8561', 'a53581ec-9831-5562-a12e-c67dd4b0aa99', 1, $json${"prompt":"A monitoring tool asks you to mount /var/run/docker.sock into its container. What is the security impact?","multiple":false,"options":[{"id":"a","text":"None; the socket is read-only","is_correct":false},{"id":"b","text":"The container can control the Docker daemon, which is effectively root on the host","is_correct":true},{"id":"c","text":"It can only read logs","is_correct":false},{"id":"d","text":"It only affects containers in the same Compose project","is_correct":false}],"explanation":"The daemon does whatever the socket says, including starting privileged containers that mount the host filesystem. Mounting it read-only does not limit API calls, and the access is host-wide, not per project."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3af9fedb-2459-52d9-b393-c5cef6dad64a', '00000000-0000-0000-0000-000000000001', 'mcq', 'docker ps shows `Up 2 hours (unhealthy)` for a container started with plain d...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ddcff8b8-d222-5409-8524-ceaecf121d1e', '3af9fedb-2459-52d9-b393-c5cef6dad64a', 1, $json${"prompt":"docker ps shows `Up 2 hours (unhealthy)` for a container started with plain docker run. What does Docker do about it?","multiple":false,"options":[{"id":"a","text":"Restarts it automatically after three failures","is_correct":false},{"id":"b","text":"Nothing beyond reporting the status and emitting an event; something else must act on it","is_correct":true},{"id":"c","text":"Removes it","is_correct":false},{"id":"d","text":"Stops sending it traffic from -p ports","is_correct":false}],"explanation":"Plain Docker only reports health. Swarm replaces unhealthy tasks, Compose uses health for depends_on, and monitoring can alert on events. Docker does not restart, remove or reroute traffic for it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('57c5f1f2-3d96-59fe-be52-23e0b4bc541f', '00000000-0000-0000-0000-000000000001', 'mcq', 'A healthcheck `CMD curl -f http://localhost:8080/health` keeps failing on an ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b60bd58e-1786-5fc2-9383-08382f9074b2', '57c5f1f2-3d96-59fe-be52-23e0b4bc541f', 1, $json${"prompt":"A healthcheck `CMD curl -f http://localhost:8080/health` keeps failing on an Alpine-based image, although the app answers fine from outside. Most likely cause?","multiple":false,"options":[{"id":"a","text":"Healthchecks cannot use localhost","is_correct":false},{"id":"b","text":"curl is not installed in the image; the check runs inside the container","is_correct":true},{"id":"c","text":"The interval is too short","is_correct":false},{"id":"d","text":"Port 8080 must be published for healthchecks","is_correct":false}],"explanation":"Healthchecks execute inside the container, so they can only use tools present there; Alpine has busybox wget but not curl by default. localhost is correct inside the container, interval does not cause constant failure, and checks do not use published ports."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d946fdef-1f3f-5a60-8f81-f424773bbc24', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container with --memory 256m exits with code 137 and OOMKilled=true. A cont...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('52301f58-be03-541d-af28-61aa0c41e310', 'd946fdef-1f3f-5a60-8f81-f424773bbc24', 1, $json${"prompt":"A container with --memory 256m exits with code 137 and OOMKilled=true. A container with --cpus 0.5 is just slow. Why the difference?","multiple":false,"options":[{"id":"a","text":"Memory over the limit triggers the kernel's OOM killer; CPU over the limit is throttled","is_correct":true},{"id":"b","text":"Docker bug; both should be killed","is_correct":false},{"id":"c","text":"CPU limits are ignored by Docker","is_correct":false},{"id":"d","text":"Memory limits only log warnings","is_correct":false}],"explanation":"Memory cannot be slowed down, so the cgroup kills a process to stay under the limit. CPU time is shared out, so the process just gets less of it. Both limits are enforced by cgroups and work as designed."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f57d3d13-c39c-5b16-bad1-65ab2eb69d26', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which way of giving a database password to a production container is the safe...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('53d5e5f8-a0db-5594-85be-401e1a576a8b', 'f57d3d13-c39c-5b16-bad1-65ab2eb69d26', 1, $json${"prompt":"Which way of giving a database password to a production container is the safest of these?","multiple":false,"options":[{"id":"a","text":"ENV DB_PASSWORD=... in the Dockerfile","is_correct":false},{"id":"b","text":"docker run -e DB_PASSWORD=...","is_correct":false},{"id":"c","text":"A secret file mounted read-only (for example /run/secrets/db) that the app reads","is_correct":true},{"id":"d","text":"ARG DB_PASSWORD with --build-arg","is_correct":false}],"explanation":"A mounted secret file is not part of the image and not shown by docker inspect. ENV and ARG leak into the image or its history, and -e is visible in inspect output and to child processes."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('93316ae2-f17b-50c9-98f4-16c3ee6505bb', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `--read-only --tmpfs /tmp` give you?', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dcf079c3-55b0-586f-a94b-496837209eb3', '93316ae2-f17b-50c9-98f4-16c3ee6505bb', 1, $json${"prompt":"What does `--read-only --tmpfs /tmp` give you?","multiple":false,"options":[{"id":"a","text":"A root filesystem the process cannot modify, plus a small in-memory scratch area at /tmp","is_correct":true},{"id":"b","text":"A read-only image that cannot be pulled","is_correct":false},{"id":"c","text":"A container that cannot write logs to stdout","is_correct":false},{"id":"d","text":"Read-only volumes","is_correct":false}],"explanation":"--read-only makes the container's root filesystem immutable (an attacker cannot drop tools or modify code), and --tmpfs adds a writable in-memory path. It does not affect pulling, stdout logging, or volumes you mount explicitly."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('87d16115-7bee-5ad1-8084-946faa6a5a84', '00000000-0000-0000-0000-000000000001', 'mcq', '(Review: Dockerfiles) A team''s image runs as root, is based on node:latest, h...', 'advanced', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dbced038-0fe2-5ea1-bd63-6cb4982730cf', '87d16115-7bee-5ad1-8084-946faa6a5a84', 1, $json${"prompt":"(Review: Dockerfiles) A team's image runs as root, is based on node:latest, has `COPY . .` before `npm install`, and uses `CMD npm start`. Which single change fixes slow rebuilds?","multiple":false,"options":[{"id":"a","text":"Add USER node","is_correct":false},{"id":"b","text":"Pin node:22-alpine","is_correct":false},{"id":"c","text":"Copy package.json and package-lock.json and install before copying the rest","is_correct":true},{"id":"d","text":"Switch to CMD [\"npm\", \"start\"]","is_correct":false}],"explanation":"Rebuild speed is a cache-order problem: copying manifests first keeps the install layer cached. USER improves security, pinning improves reproducibility, and exec-form CMD improves signal handling; none of them affects rebuild time."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('dc6dd49c-ab55-5f69-a782-b51507ebad36', '00000000-0000-0000-0000-000000000001', 'Quiz: Production-Ready Containers', 'docker-production-quiz', 'Quiz covering Production-Ready Containers.', 'mcq', 'published', 'module', '63f4f1ed-0b4d-55f1-9470-87490e982302', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'dc6dd49c-ab55-5f69-a782-b51507ebad36' AND question_id NOT IN ('f11d6e6d-878f-58f8-b787-3af7c613af72', 'a53581ec-9831-5562-a12e-c67dd4b0aa99', '3af9fedb-2459-52d9-b393-c5cef6dad64a', '57c5f1f2-3d96-59fe-be52-23e0b4bc541f', 'd946fdef-1f3f-5a60-8f81-f424773bbc24', 'f57d3d13-c39c-5b16-bad1-65ab2eb69d26', '93316ae2-f17b-50c9-98f4-16c3ee6505bb', '87d16115-7bee-5ad1-8084-946faa6a5a84');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('36b6bd9d-37f9-5b92-8edd-5600218eaaaa', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', 'f11d6e6d-878f-58f8-b787-3af7c613af72', '36d72068-30fb-5cd0-ae1f-5ecf92112e30', 0, 2),
('60b3dbae-207e-5ef9-bc3b-92f49d986de7', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', 'a53581ec-9831-5562-a12e-c67dd4b0aa99', '07cd15e1-f5ac-5cc8-80c5-1e96493f8561', 1, 2),
('0705cdb1-506a-5b5b-a81c-127ec4483421', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', '3af9fedb-2459-52d9-b393-c5cef6dad64a', 'ddcff8b8-d222-5409-8524-ceaecf121d1e', 2, 2),
('cf733c1b-9e64-52f5-8581-26691b07ced1', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', '57c5f1f2-3d96-59fe-be52-23e0b4bc541f', 'b60bd58e-1786-5fc2-9383-08382f9074b2', 3, 2),
('e4e80bf0-b5cf-5096-8d07-14c41d390e12', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', 'd946fdef-1f3f-5a60-8f81-f424773bbc24', '52301f58-be03-541d-af28-61aa0c41e310', 4, 2),
('913f2a8b-e54e-5793-8b18-11b77471bb9b', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', 'f57d3d13-c39c-5b16-bad1-65ab2eb69d26', '53d5e5f8-a0db-5594-85be-401e1a576a8b', 5, 2),
('3351301c-363a-5dd8-9f94-cf9f36fd2587', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', '93316ae2-f17b-50c9-98f4-16c3ee6505bb', 'dcf079c3-55b0-586f-a94b-496837209eb3', 6, 2),
('53b3c568-bfb6-5c0e-8c41-81d14f4e5e58', 'dc6dd49c-ab55-5f69-a782-b51507ebad36', '87d16115-7bee-5ad1-8084-946faa6a5a84', 'dbced038-0fe2-5ea1-bd63-6cb4982730cf', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('63f4f1ed-0b4d-55f1-9470-87490e982302', '27527dc6-807c-51bf-beb9-a499519888d9', '1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', 'Quiz: Production-Ready Containers', 'assessment', 5, 12, 'dc6dd49c-ab55-5f69-a782-b51507ebad36')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Troubleshooting & Cleanup
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('e548c0f3-4414-5323-9baa-70ce7f49c47a', '27527dc6-807c-51bf-beb9-a499519888d9', 'Troubleshooting & Cleanup', 8, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ec12699d-cd7e-5cd3-88a4-e82cc7f304fc', '27527dc6-807c-51bf-beb9-a499519888d9', 'e548c0f3-4414-5323-9baa-70ce7f49c47a', 'Observing Containers: Logs, Events, Stats and Log Drivers', 'notes', 0, $md$## Why this matters

When something breaks at 3 a.m., you need to know **what happened** (logs),
**when** (events) and **how hard the machine is working** (stats). You met
`docker logs` in Section 2. This lesson adds the rest of the toolbox, plus the
one setting that stops logs from filling your disk.

## Mental model: a car dashboard

| Gauge | Docker command | Answers |
|---|---|---|
| Trip recorder | `docker logs` | What did the app say? |
| Black box / event log | `docker events` | What happened to containers (start, die, OOM, health)? |
| Speedometer and fuel | `docker stats` | CPU, memory, network, disk I/O right now |
| Passenger list | `docker top`, `docker ps` | Which processes / containers exist? |

## See it work

### Logs, with time filters

```bash
docker logs --since 10m --tail 100 -t api   # last 100 lines from the last 10 min, with timestamps
docker logs -f api 2>&1 | grep -i error    # follow and filter (stderr included)
```

### Events: the daemon's timeline

```bash
docker events --since 30m --filter container=api
```

Expected lines (shortened):

```
2026-10-16T10:01:12 container start 5c1f... (image=api:1.8.0, name=api)
2026-10-16T10:14:55 container oom 5c1f... (name=api)
2026-10-16T10:14:55 container die 5c1f... (exitCode=137, name=api)
2026-10-16T10:14:56 container restart 5c1f... (name=api)
```

This tells a story `docker logs` cannot: the container was **OOM-killed** and
restarted. Other useful filters: `--filter event=die`, `--filter event=health_status`,
`--filter type=image`. Without `--since`, `docker events` streams live until Ctrl+C.

### Stats: live resource use

```bash
docker stats                    # live table for all running containers (Ctrl+C to stop)
docker stats --no-stream        # one snapshot (good for scripts)
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

```bash
docker top api                  # processes inside the container
docker port api                 # published ports
docker ps -a                    # running AND stopped containers
```

```knowledge-check
{
  "questions": [
    {
      "id": "docker-monitoring-logs-q1",
      "type": "mcq",
      "prompt": "docker ps with no flags shows only running containers. Which command also shows stopped ones?",
      "options": [
        { "id": "a", "text": "docker ps -a" },
        { "id": "b", "text": "docker top" },
        { "id": "c", "text": "docker events" },
        { "id": "d", "text": "docker port" }
      ],
      "correct": "a",
      "explanation": "docker ps -a (\"all\") includes containers that have exited, not just currently-running ones. docker top shows processes inside a running container; docker events streams daemon activity; docker port shows a container's published ports."
    },
    {
      "id": "docker-monitoring-logs-q2",
      "type": "mcq",
      "prompt": "What's the difference between docker top and docker stats?",
      "options": [
        { "id": "a", "text": "They are aliases for the same command" },
        { "id": "b", "text": "docker top lists the container's running processes; docker stats shows live CPU/memory/network usage" },
        { "id": "c", "text": "docker top shows CPU usage; docker stats lists processes" },
        { "id": "d", "text": "docker stats only works on stopped containers" }
      ],
      "correct": "b",
      "explanation": "docker top answers \"what processes are running in this container\" (like ps inside it). docker stats answers \"how much CPU/memory/network is this container using right now\": a live resource dashboard, not a process list."
    }
  ]
}
```

### Log drivers and rotation

Where do `docker logs` lines live? The default **log driver** `json-file`
writes them to a file under `/var/lib/docker/containers/<id>/`, and by default
that file **grows forever**.

Set rotation per container:

```bash
docker run -d --log-opt max-size=10m --log-opt max-file=3 nginx:1.27-alpine
```

Or for every container, in `/etc/docker/daemon.json` (then restart Docker):

```json
{
  "log-driver": "local",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
```

The `local` driver is compact and rotates by default. Other drivers ship logs
elsewhere: `journald`, `syslog`, `fluentd`, `gelf`, `awslogs`, `gcplogs`. With
most remote drivers, `docker logs` still works through Docker's dual logging cache.

In Compose:

```yaml
services:
  api:
    logging:
      driver: local
      options: { max-size: "10m", max-file: "3" }
```

## Try it

A container restarted at 02:14 and its logs show nothing unusual before the
restart. Which command reveals why, and what would you look for?

<details>
<summary>Show answer</summary>

```bash
docker events --since "2026-10-16T02:00:00" --until "2026-10-16T02:30:00" --filter container=NAME
```

Look for an `oom` event, or `die` with `exitCode=137` (killed) vs another code,
or `health_status: unhealthy` followed by a restart from an orchestrator.
`docker inspect -f '{{.State.OOMKilled}}' NAME` confirms an OOM for the last exit.

</details>

## Common mistakes

- **No log rotation.** The json-file log grows until the disk is full and the host stops.
- **Apps logging to files inside the container.** `docker logs` is empty, and the
  writable layer grows. Log to stdout/stderr.
- **Using `docker stats` for history.** It shows only *now*. For trends, export
  metrics (cAdvisor, Prometheus, your cloud's monitoring).

## Remember

- `logs` = what the app said; `events` = what happened to the container; `stats` = resource use now.
- `docker events --filter container=X --since 1h` explains restarts and OOM kills.
- Default `json-file` logs grow forever: set `max-size`/`max-file`, or use the `local` driver.
- Log to stdout/stderr; ship logs with a log driver or collector.

**Self-check:**

1. Which command shows that a container was OOM-killed, besides `inspect`?
2. Where does the default log driver store logs, and what is its danger?
3. Name two log drivers other than `json-file`.
$md$, 8, $json$[{"id":"docker-monitoring-logs-q1","type":"mcq","correct":"a"},{"id":"docker-monitoring-logs-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8f8e5c37-f7f5-547a-9ed8-d07c46bbe1db', '27527dc6-807c-51bf-beb9-a499519888d9', 'e548c0f3-4414-5323-9baa-70ce7f49c47a', 'Troubleshooting Playbook: The Ten Classic Failures', 'notes', 1, $md$## Why this matters

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
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('14dacb5e-5f0c-5dec-bcf0-ed9bce9648ce', '27527dc6-807c-51bf-beb9-a499519888d9', 'e548c0f3-4414-5323-9baa-70ce7f49c47a', 'Disk Usage and Cleanup: system df and prune', 'notes', 2, $md$## Why this matters

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
$md$, 7, $json$[{"id":"docker-monitoring-prune-q1","type":"mcq","correct":"b"},{"id":"docker-monitoring-prune-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6e498b26-bbcc-5951-ae86-05554c2e34ac', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container restarted overnight and its logs show no error. Which command mos...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8cb21a3c-e4fc-51a4-9397-f273bddfaa04', '6e498b26-bbcc-5951-ae86-05554c2e34ac', 1, $json${"prompt":"A container restarted overnight and its logs show no error. Which command most directly tells you whether it was OOM-killed or stopped by someone?","multiple":false,"options":[{"id":"a","text":"docker events --since 12h --filter container=NAME","is_correct":true},{"id":"b","text":"docker stats NAME","is_correct":false},{"id":"c","text":"docker top NAME","is_correct":false},{"id":"d","text":"docker port NAME","is_correct":false}],"explanation":"Events record oom, die (with exit code), kill and restart with timestamps. stats shows only current usage, top shows current processes, and port shows mappings."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5f9ce9a3-61ff-581e-bf1a-9ad2618636b6', '00000000-0000-0000-0000-000000000001', 'mcq', 'A server''s disk filled up, and /var/lib/docker/containers holds a 40 GB *-jso...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e312aa5a-fc1e-5fbb-b0ee-fa3b09ead078', '5f9ce9a3-61ff-581e-bf1a-9ad2618636b6', 1, $json${"prompt":"A server's disk filled up, and /var/lib/docker/containers holds a 40 GB *-json.log file. What is the lasting fix?","multiple":false,"options":[{"id":"a","text":"Delete the file by hand every week","is_correct":false},{"id":"b","text":"Configure log rotation (max-size/max-file) or the local log driver","is_correct":true},{"id":"c","text":"Run docker system prune","is_correct":false},{"id":"d","text":"Use docker logs --tail","is_correct":false}],"explanation":"The default json-file driver grows without limit; rotation caps it. Manual deletion is fragile and unsafe under a running container, prune does not touch log files, and --tail only limits what you read."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cd79b83b-a866-58e0-9214-0037b1d88820', '00000000-0000-0000-0000-000000000001', 'mcq', 'Following the S-L-I-N triage, what should you do FIRST for a container in a r...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('75883715-4379-5228-8289-c359db7b8fb2', 'cd79b83b-a866-58e0-9214-0037b1d88820', 1, $json${"prompt":"Following the S-L-I-N triage, what should you do FIRST for a container in a restart loop?","multiple":false,"options":[{"id":"a","text":"docker exec into it","is_correct":false},{"id":"b","text":"Check state and exit code with docker ps -a / docker inspect, then read docker logs","is_correct":true},{"id":"c","text":"docker restart it","is_correct":false},{"id":"d","text":"Rebuild the image","is_correct":false}],"explanation":"State and logs come first and work even on a stopped container. exec races the restarts, restart destroys clues, and rebuilding before diagnosing is guesswork."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7cbb8afd-75ea-56ac-96b0-2467b69ca96b', '00000000-0000-0000-0000-000000000001', 'mcq', '`docker run myimage` fails with ''exec format error''. What is the most likely ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('651b5f15-5cea-5917-af85-b43873508cf7', '7cbb8afd-75ea-56ac-96b0-2467b69ca96b', 1, $json${"prompt":"`docker run myimage` fails with 'exec format error'. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"The image was built for a different CPU architecture","is_correct":true},{"id":"b","text":"The Dockerfile has a syntax error","is_correct":false},{"id":"c","text":"The container ran out of memory","is_correct":false},{"id":"d","text":"The port is already allocated","is_correct":false}],"explanation":"exec format error means the kernel cannot execute the binary format, typically arm64 vs amd64. A Dockerfile syntax error fails at build time, OOM gives exit 137, and port conflicts give 'port is already allocated'."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1bc85c81-4683-5148-958c-1890ea3849c7', '00000000-0000-0000-0000-000000000001', 'mcq', 'An app container with a bind mount logs ''permission denied'' writing to /data....', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('287249eb-fde3-5056-a7ae-b37015150f65', '1bc85c81-4683-5148-958c-1890ea3849c7', 1, $json${"prompt":"An app container with a bind mount logs 'permission denied' writing to /data. The container runs as UID 10001; on the host the folder is owned by root with mode 755. What fixes it?","multiple":false,"options":[{"id":"a","text":"Add EXPOSE 10001","is_correct":false},{"id":"b","text":"Give UID 10001 write access to the host folder (chown/chmod), or run the container with a UID that already has it","is_correct":true},{"id":"c","text":"Use docker restart","is_correct":false},{"id":"d","text":"Mount it with :ro","is_correct":false}],"explanation":"Bind mounts keep host permissions, checked against the numeric UID inside. EXPOSE is about ports, restart changes nothing, and :ro would make writes fail even more."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c4836046-f9f4-5c70-9a58-f0317ec391d8', '00000000-0000-0000-0000-000000000001', 'mcq', 'On a developer laptop with a Postgres named volume you want to keep, which co...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dd679ecf-edcf-5024-a8e0-8a31a85668e7', 'c4836046-f9f4-5c70-9a58-f0317ec391d8', 1, $json${"prompt":"On a developer laptop with a Postgres named volume you want to keep, which command reclaims the most space safely?","multiple":false,"options":[{"id":"a","text":"docker system prune -a --volumes","is_correct":false},{"id":"b","text":"docker system prune -a","is_correct":true},{"id":"c","text":"rm -rf /var/lib/docker","is_correct":false},{"id":"d","text":"docker compose down -v","is_correct":false}],"explanation":"system prune -a removes stopped containers, unused networks, all unused images and build cache, but no volumes. --volumes and down -v can delete volume data, and deleting /var/lib/docker by hand destroys everything and corrupts Docker's state."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2ba11283-2578-552a-9a7c-70d33bff5dda', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command shows how much disk images, containers, volumes and build cache...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2bfed9cf-c3a8-5a4b-a5d5-21dcbfeda3bd', '2ba11283-2578-552a-9a7c-70d33bff5dda', 1, $json${"prompt":"Which command shows how much disk images, containers, volumes and build cache use?","multiple":false,"options":[{"id":"a","text":"docker info","is_correct":false},{"id":"b","text":"docker system df","is_correct":true},{"id":"c","text":"docker stats","is_correct":false},{"id":"d","text":"docker images -a","is_correct":false}],"explanation":"docker system df summarises usage and reclaimable space per type. docker info shows daemon details, stats shows live CPU/memory, and docker images covers images only."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('af3a03e2-b3c0-5929-8273-4d406b458f99', '00000000-0000-0000-0000-000000000001', 'mcq', '(Review: Networking) A distroless container has no shell, and you need to che...', 'advanced', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('08748e48-8b62-55fc-a77e-ab98152a985d', 'af3a03e2-b3c0-5929-8273-4d406b458f99', 1, $json${"prompt":"(Review: Networking) A distroless container has no shell, and you need to check what it listens on. What works?","multiple":false,"options":[{"id":"a","text":"docker exec -it NAME sh","is_correct":false},{"id":"b","text":"Run a busybox container with --network container:NAME and check from there","is_correct":true},{"id":"c","text":"docker attach NAME","is_correct":false},{"id":"d","text":"Add a shell to the production image","is_correct":false}],"explanation":"--network container:NAME shares the target's network namespace, so busybox's tools see its sockets and localhost. exec needs a shell in the image, attach only connects to the main process, and adding a shell to production undoes the hardening."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('9772c67d-b566-5eb8-8deb-05e23b6410ac', '00000000-0000-0000-0000-000000000001', 'Quiz: Troubleshooting & Cleanup', 'docker-monitoring-cleanup-quiz', 'Quiz covering Troubleshooting & Cleanup.', 'mcq', 'published', 'module', '6575b202-478e-5623-8169-649a1e8f0c8f', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '9772c67d-b566-5eb8-8deb-05e23b6410ac' AND question_id NOT IN ('6e498b26-bbcc-5951-ae86-05554c2e34ac', '5f9ce9a3-61ff-581e-bf1a-9ad2618636b6', 'cd79b83b-a866-58e0-9214-0037b1d88820', '7cbb8afd-75ea-56ac-96b0-2467b69ca96b', '1bc85c81-4683-5148-958c-1890ea3849c7', 'c4836046-f9f4-5c70-9a58-f0317ec391d8', '2ba11283-2578-552a-9a7c-70d33bff5dda', 'af3a03e2-b3c0-5929-8273-4d406b458f99');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('0f04c7d7-0439-5ccf-b6da-eaedf9d37054', '9772c67d-b566-5eb8-8deb-05e23b6410ac', '6e498b26-bbcc-5951-ae86-05554c2e34ac', '8cb21a3c-e4fc-51a4-9397-f273bddfaa04', 0, 2),
('2f5f1b66-a665-5703-999a-12d3abf71bc9', '9772c67d-b566-5eb8-8deb-05e23b6410ac', '5f9ce9a3-61ff-581e-bf1a-9ad2618636b6', 'e312aa5a-fc1e-5fbb-b0ee-fa3b09ead078', 1, 2),
('bf7d780b-683f-5b3c-b35e-d4e8e798148b', '9772c67d-b566-5eb8-8deb-05e23b6410ac', 'cd79b83b-a866-58e0-9214-0037b1d88820', '75883715-4379-5228-8289-c359db7b8fb2', 2, 2),
('f396f766-c41e-50c3-8ea3-108f802609b7', '9772c67d-b566-5eb8-8deb-05e23b6410ac', '7cbb8afd-75ea-56ac-96b0-2467b69ca96b', '651b5f15-5cea-5917-af85-b43873508cf7', 3, 2),
('789157e3-a82c-5511-91ab-d3eefed965ae', '9772c67d-b566-5eb8-8deb-05e23b6410ac', '1bc85c81-4683-5148-958c-1890ea3849c7', '287249eb-fde3-5056-a7ae-b37015150f65', 4, 2),
('341934ba-4371-5f83-bbd3-456ced8b96af', '9772c67d-b566-5eb8-8deb-05e23b6410ac', 'c4836046-f9f4-5c70-9a58-f0317ec391d8', 'dd679ecf-edcf-5024-a8e0-8a31a85668e7', 5, 2),
('b7e4a8f5-d9db-5451-ba29-519d936e4872', '9772c67d-b566-5eb8-8deb-05e23b6410ac', '2ba11283-2578-552a-9a7c-70d33bff5dda', '2bfed9cf-c3a8-5a4b-a5d5-21dcbfeda3bd', 6, 2),
('4eb8d294-ea20-50dd-a4a5-1814f407376b', '9772c67d-b566-5eb8-8deb-05e23b6410ac', 'af3a03e2-b3c0-5929-8273-4d406b458f99', '08748e48-8b62-55fc-a77e-ab98152a985d', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('6575b202-478e-5623-8169-649a1e8f0c8f', '27527dc6-807c-51bf-beb9-a499519888d9', 'e548c0f3-4414-5323-9baa-70ce7f49c47a', 'Quiz: Troubleshooting & Cleanup', 'assessment', 3, 12, '9772c67d-b566-5eb8-8deb-05e23b6410ac')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Capstone
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('abd4b653-4e59-5e16-9ea5-6ecaff379ed9', '27527dc6-807c-51bf-beb9-a499519888d9', 'Capstone', 9, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6a98ace6-cec3-5801-978f-6a3a3c7fc18a', '27527dc6-807c-51bf-beb9-a499519888d9', 'abd4b653-4e59-5e16-9ea5-6ecaff379ed9', 'Capstone Lab: Two End-to-End Workflows', 'notes', 0, $md$## Why this matters

Real Docker work is never one command. It is a **chain**: write, build, run,
check, inspect. This capstone strings together commands from every section, so
you practise recognising the chain instead of memorising single flags.

## Mental model: the delivery loop

```
 write (Dockerfile / files)  ->  build  ->  run  ->  verify  ->  inspect / debug
          Section 4               4         2,5        2,8           2,8
```

Both examples use `--network host` and check results from a second
`--network host` container, as in every lab of this course (see the Running
Containers lab for why).

## Example 1: build, run and verify your own image

Recall Section 4: a `RUN` step bakes the page into the image; nginx's own `CMD`
starts the server.

```bash
mkdir -p ~/work && cd ~/work
cat > Dockerfile <<'EOF'
FROM nginx:1.27-alpine
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html
EXPOSE 80
EOF

# Build (sandbox: --network=host because of the RUN step)
docker build --network=host -t mysite .

# Run in the background
docker run -d --name mysite --network host mysite

# Verify from a second container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

Expected output of the last command:

```
<h1>Built from a Dockerfile</h1>
```

[[lab-task:1]]

## Example 2: a Python web server with a bind mount

Recall Section 5: a bind mount shows your host folder inside the container,
live. `-w` sets the working directory at run time, like `WORKDIR` at build time.

```bash
# Content to serve, on the "host"
mkdir -p ~/work/www
echo "Server is up" > ~/work/www/index.html

# Run python's built-in web server against that folder:
#   --name pythonweb                   readable name                (Section 2)
#   -v ~/work/www:/var/www/html        bind mount host -> container (Section 5)
#   -w /var/www/html                   working directory            (Section 4, WORKDIR)
#   --network host                     sandbox networking
#   python3 -m http.server 8000        the command (replaces the image's CMD)
docker run -d \
  --name pythonweb \
  -v ~/work/www:/var/www/html \
  -w /var/www/html \
  --network host \
  python:3.12-alpine \
  python3 -m http.server 8000

# Verify
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8000
```

Expected output: `Server is up`.

[[lab-task:2]]

**After the task is checked**, change the file and fetch again. The new text appears without restarting
anything, because the container reads your folder directly:

```bash
echo "Edited live" > ~/work/www/index.html
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8000
```

Inspect it with the Section 2 tools:

```bash
docker ps                                          # it is Up
docker logs pythonweb                              # one line per request
docker inspect -f '{{json .Mounts}}' pythonweb     # the bind mount
docker exec -it pythonweb sh                       # look inside; exit to leave
```

## Remember

- Every real workflow is a chain: write → build → run → verify → inspect.
- Bind mounts give live edits without rebuilds: ideal for development, not for shipping.
- Reading a long `docker run` line is easy once you can name each flag's section.
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('7b001873-fb9b-551b-9b8c-f5ac24ba4455', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '6a98ace6-cec3-5801-978f-6a3a3c7fc18a', 'module', 'Capstone Lab: Two End-to-End Workflows', NULL, 'terminal', 'mindforge/lab-docker:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 40, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '459ac5d9-419c-517c-b16c-d324209e5372' AND id NOT IN ('86000142-5046-5c80-a085-57bb105e6bc6', 'bf984e11-0f9c-5a06-b50e-4c43bad0b265');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '459ac5d9-419c-517c-b16c-d324209e5372';
DELETE FROM lab_tasks WHERE lab_id = '7b001873-fb9b-551b-9b8c-f5ac24ba4455' AND id NOT IN ('5faa99c0-5638-515b-8553-e324319146c9', '9fa495da-44d5-5033-b192-a727e1240544');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '7b001873-fb9b-551b-9b8c-f5ac24ba4455';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('5faa99c0-5638-515b-8553-e324319146c9', '7b001873-fb9b-551b-9b8c-f5ac24ba4455', 1, 'Example 1: build, run, and confirm your own image', $md$Write the Dockerfile shown above, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
$script$, 'This is the exact same sequence as the Dockerfile lab''s three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.', 'Every real Docker workflow is a chain like this one — write, build, run, verify — never a single isolated command. Recognizing the chain matters more than memorizing any one flag in it.', 15, false, false),
('9fa495da-44d5-5033-b192-a727e1240544', '7b001873-fb9b-551b-9b8c-f5ac24ba4455', 2, 'Example 2: a Python web server with a bind mount', $md$Create ~/work/www/index.html with some content, run python:3.12-alpine's http.server bind-mounting that directory, and confirm it serves your file.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:8000 2>/dev/null | grep -q "Server is up"
$script$, 'mkdir -p www && echo "Server is up" > www/index.html creates the content; docker run -d --name pythonweb -v $(pwd)/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000 serves it.', '-v host:container bind-mounts your directory straight into the container — the server process sees exactly the files you have on disk, live. -w sets the working directory http.server serves from, matching Dockerfile''s WORKDIR at container-start time instead of build time.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('459ac5d9-419c-517c-b16c-d324209e5372', '7b001873-fb9b-551b-9b8c-f5ac24ba4455', 1, $json$[{"id":"5faa99c0-5638-515b-8553-e324319146c9","lab_id":"7b001873-fb9b-551b-9b8c-f5ac24ba4455","position":1,"title":"Example 1: build, run, and confirm your own image","description":"Write the Dockerfile shown above, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2\u003e/dev/null | grep -q \"Built from a Dockerfile\"\n","hint_context":"This is the exact same sequence as the Dockerfile lab's three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.","explanation_context":"Every real Docker workflow is a chain like this one — write, build, run, verify — never a single isolated command. Recognizing the chain matters more than memorizing any one flag in it.","points":15,"is_optional":false,"is_stateful":false},{"id":"9fa495da-44d5-5033-b192-a727e1240544","lab_id":"7b001873-fb9b-551b-9b8c-f5ac24ba4455","position":2,"title":"Example 2: a Python web server with a bind mount","description":"Create ~/work/www/index.html with some content, run python:3.12-alpine's http.server bind-mounting that directory, and confirm it serves your file.","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:8000 2\u003e/dev/null | grep -q \"Server is up\"\n","hint_context":"mkdir -p www \u0026\u0026 echo \"Server is up\" \u003e www/index.html creates the content; docker run -d --name pythonweb -v $(pwd)/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000 serves it.","explanation_context":"-v host:container bind-mounts your directory straight into the container — the server process sees exactly the files you have on disk, live. -w sets the working directory http.server serves from, matching Dockerfile's WORKDIR at container-start time instead of build time.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('86000142-5046-5c80-a085-57bb105e6bc6', '459ac5d9-419c-517c-b16c-d324209e5372', '5faa99c0-5638-515b-8553-e324319146c9', 1, 'Example 1: build, run, and confirm your own image', $md$Write the Dockerfile shown above, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
$script$, 'This is the exact same sequence as the Dockerfile lab''s three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.', 'Every real Docker workflow is a chain like this one — write, build, run, verify — never a single isolated command. Recognizing the chain matters more than memorizing any one flag in it.', 15, false, false),
('bf984e11-0f9c-5a06-b50e-4c43bad0b265', '459ac5d9-419c-517c-b16c-d324209e5372', '9fa495da-44d5-5033-b192-a727e1240544', 2, 'Example 2: a Python web server with a bind mount', $md$Create ~/work/www/index.html with some content, run python:3.12-alpine's http.server bind-mounting that directory, and confirm it serves your file.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:8000 2>/dev/null | grep -q "Server is up"
$script$, 'mkdir -p www && echo "Server is up" > www/index.html creates the content; docker run -d --name pythonweb -v $(pwd)/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000 serves it.', '-v host:container bind-mounts your directory straight into the container — the server process sees exactly the files you have on disk, live. -w sets the working directory http.server serves from, matching Dockerfile''s WORKDIR at container-start time instead of build time.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '459ac5d9-419c-517c-b16c-d324209e5372', updated_at = now()
WHERE id = '7b001873-fb9b-551b-9b8c-f5ac24ba4455' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b862dd85-ba8a-531f-b382-5056d6030946', '27527dc6-807c-51bf-beb9-a499519888d9', 'abd4b653-4e59-5e16-9ea5-6ecaff379ed9', 'Course Review: Docker on One Page', 'notes', 1, $md$## How to use this page

Cover the right-hand column and try to say it out loud before you look. That
act of recalling (not re-reading) is what moves knowledge into long-term
memory. Come back to this page in a few days, then a week later.

## The ideas

| Prompt | Answer |
|---|---|
| Container in one sentence | An isolated Linux process: namespaces (what it sees) + cgroups (what it uses), sharing the host kernel |
| Image in one sentence | A read-only stack of content-addressed layers plus metadata |
| Container vs VM | Shares host kernel (fast, small, weaker isolation) vs own kernel |
| `docker run` = ? | `create` + `start`; lives as long as its main process |
| `stop` vs `kill` | SIGTERM, 10 s grace, SIGKILL vs SIGKILL now |
| Exit 137 / 143 / 127 | Killed (often OOM) / SIGTERM / command not found |
| Copy-on-write | Editing an image file copies it into the container's writable layer first |
| Tag vs digest | Movable pointer vs immutable content hash |
| `save` vs `export` | Image with layers and metadata vs a container's flattened filesystem |
| `RUN` vs `CMD` | Build time, once vs container start, every time |
| `ENTRYPOINT` + `CMD` | Program + default args; run args replace CMD |
| Exec form matters because | SIGTERM reaches your app, not a shell; PID 1 still needs a handler or `--init` |
| Build cache rule | Least-changed first: manifests → install → source |
| Multi-stage build | Build in a fat stage, `COPY --from` only artifacts into a slim final stage |
| BuildKit extras | Cache mounts, secret mounts, multi-platform builds, cache export |
| Default bridge vs user-defined | No DNS by name vs DNS by container name |
| `localhost` in a container | The container itself |
| Volume vs bind mount vs tmpfs | Docker-managed data vs your host path vs RAM |
| `-p` order | `HOST:CONTAINER` (outside:inside) |
| Compose readiness | `depends_on` + `condition: service_healthy` + `healthcheck` |
| `.env` vs `env_file:` | Fills YAML placeholders vs sets container variables |
| Healthy vs running | Check command exits 0 vs process alive; Docker reports, others act |
| Memory vs CPU limit | Over memory → OOM kill (137); over CPU → throttled |
| Least privilege | Non-root `USER`, `--cap-drop ALL`, no-new-privileges, `--read-only`, no `--privileged`, no socket mounts |
| Triage | S-L-I-N: State, Logs, Inspect, iNside |
| Cleanup | `docker system df`, then `prune`; `-a` images, `--volumes` volumes |

## The commands you will type every week

```bash
docker run -d --name api -p 8080:8000 -e KEY=val -v data:/data --restart unless-stopped img:1.0
docker ps -a ; docker logs -f api ; docker exec -it api sh ; docker inspect api
docker build -t img:1.0 . ; docker tag img:1.0 reg.example.com/team/img:1.0 ; docker push reg.example.com/team/img:1.0
docker compose up -d --build ; docker compose logs -f ; docker compose down
docker system df ; docker system prune
```

## What to learn next

- **Kubernetes**: runs these same images across many machines (Pods, Deployments,
  Services, probes instead of `HEALTHCHECK`).
- **CI/CD**: build, scan and push images automatically on every commit
  (GitHub Actions `docker/build-push-action`, GitLab CI).
- **Supply-chain security**: SBOMs (`docker buildx build --sbom=true`),
  provenance attestations, image signing (cosign).
- **Podman**: a daemonless, rootless-by-default Docker-compatible CLI.

## Remember

- Recall beats re-reading. Use the table above as flashcards.
- If you remember only one line per section: a container is a process; an image
  is layers; RUN is build time; volumes keep data; Compose is one file; least
  privilege plus limits plus healthchecks for production; S-L-I-N when it breaks.
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e53a6a2e-2cfa-5350-ad02-d7d81d5b3f5c', '00000000-0000-0000-0000-000000000001', 'mcq', 'You deploy a new image version by `docker rm -f app` and a new `docker run`. ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7fd14b1c-4304-5b14-992b-3e578f0ad9eb', 'e53a6a2e-2cfa-5350-ad02-d7d81d5b3f5c', 1, $json${"prompt":"You deploy a new image version by `docker rm -f app` and a new `docker run`. Uploaded user files disappear every deploy. What is the root cause and fix?","multiple":false,"options":[{"id":"a","text":"The registry deletes files; pin a digest","is_correct":false},{"id":"b","text":"Files were in the container's writable layer; store them in a named volume","is_correct":true},{"id":"c","text":"The restart policy wipes data; use on-failure","is_correct":false},{"id":"d","text":"The image is too large; use multi-stage builds","is_correct":false}],"explanation":"The writable layer is deleted with the container, while a volume persists across container replacements. Registries, restart policies and image size have nothing to do with runtime data."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6133fab9-0e5e-520d-8704-544500b11543', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Dockerfile has `COPY . .`, then `RUN npm ci`, then `CMD npm start`. Builds ...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5d376051-567b-572c-b713-5604577e47b1', '6133fab9-0e5e-520d-8704-544500b11543', 1, $json${"prompt":"A Dockerfile has `COPY . .`, then `RUN npm ci`, then `CMD npm start`. Builds are slow and `docker stop` takes 10 s. Which pair of changes fixes both?","multiple":false,"options":[{"id":"a","text":"Add USER node and EXPOSE 3000","is_correct":false},{"id":"b","text":"Copy package*.json and run npm ci before COPY . .; use exec form CMD [\"node\", \"server.js\"] with a SIGTERM handler (or --init)","is_correct":true},{"id":"c","text":"Use ADD instead of COPY and add --no-cache","is_correct":false},{"id":"d","text":"Use a bigger base image and a restart policy","is_correct":false}],"explanation":"Cache order fixes rebuild time; exec form plus signal handling fixes slow stops. USER/EXPOSE help security and docs, ADD/--no-cache make caching worse, and base size or restart policy do not affect either problem."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('059a53de-d131-55cb-9da5-8499954cd9b3', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container on a user-defined network cannot reach `redis:6379`, and `docker ...', 'advanced', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('df844fc9-803f-5cec-aee9-d781804a191e', '059a53de-d131-55cb-9da5-8499954cd9b3', 1, $json${"prompt":"A container on a user-defined network cannot reach `redis:6379`, and `docker network inspect` shows redis on a different network. What is the cleanest fix?","multiple":false,"options":[{"id":"a","text":"Publish redis with -p 6379:6379 and use the host IP","is_correct":false},{"id":"b","text":"docker network connect \u003capi-network\u003e redis (or put both services on one network)","is_correct":true},{"id":"c","text":"Use --network host for both","is_correct":false},{"id":"d","text":"Hard-code the redis container IP","is_correct":false}],"explanation":"Containers resolve and reach each other only on a shared network; connecting redis to the API's network solves it. Publishing exposes redis needlessly, host networking removes isolation, and container IPs change."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0d3066b3-258c-51c6-9358-0b9f94626bb1', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which statement about image tags and digests is true?', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f3ec651e-1bf4-5b5f-81d7-c2a8d40f58be', '0d3066b3-258c-51c6-9358-0b9f94626bb1', 1, $json${"prompt":"Which statement about image tags and digests is true?","multiple":false,"options":[{"id":"a","text":"latest always means the newest release","is_correct":false},{"id":"b","text":"A tag can be re-pointed to new content; a digest always refers to the same content","is_correct":true},{"id":"c","text":"Digests change when you re-tag an image","is_correct":false},{"id":"d","text":"Tags are immutable once pushed","is_correct":false}],"explanation":"Tags are movable labels (latest is just the default name); digests are content hashes and never change for the same bytes. Re-tagging does not change a digest, and most registries allow tags to be overwritten unless configured otherwise."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c7942491-b932-5f3f-8734-fbafab76416a', '00000000-0000-0000-0000-000000000001', 'mcq', 'In Compose, your api starts before Postgres accepts connections. Which config...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ba0abeb4-dee7-549f-b435-963034c68cbc', 'c7942491-b932-5f3f-8734-fbafab76416a', 1, $json${"prompt":"In Compose, your api starts before Postgres accepts connections. Which configuration makes Compose wait correctly?","multiple":false,"options":[{"id":"a","text":"depends_on: [db]","is_correct":false},{"id":"b","text":"A healthcheck on db and depends_on: db: condition: service_healthy","is_correct":true},{"id":"c","text":"restart: always on api only","is_correct":false},{"id":"d","text":"links: [db]","is_correct":false}],"explanation":"Only a health-gated condition waits for readiness; plain depends_on waits for container start. A restart policy retries after crashes instead of ordering startup, and links is a legacy option that does not wait either."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('979542f6-4afe-580c-95a4-a8ab374563ad', '00000000-0000-0000-0000-000000000001', 'mcq', 'A service shows `Exited (137)` and `OOMKilled: true` after a traffic spike. W...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('14350b16-4577-5d07-95e2-3ed3898509be', '979542f6-4afe-580c-95a4-a8ab374563ad', 1, $json${"prompt":"A service shows `Exited (137)` and `OOMKilled: true` after a traffic spike. What does this tell you?","multiple":false,"options":[{"id":"a","text":"Someone ran docker stop","is_correct":false},{"id":"b","text":"The process exceeded its cgroup memory limit and the kernel killed it","is_correct":true},{"id":"c","text":"The CPU limit was too low","is_correct":false},{"id":"d","text":"The healthcheck failed","is_correct":false}],"explanation":"137 is SIGKILL and OOMKilled=true pins it on the memory limit. docker stop normally ends in 143 or 0, CPU limits throttle rather than kill, and failed healthchecks do not kill containers under plain Docker."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('55d59018-a9a5-557d-bea9-06f0f1eb81e4', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which `docker run` option set is the most hardened for a stateless web app on...', 'advanced', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cbe376c0-f9f3-58f2-a92d-74114bdd95bc', '55d59018-a9a5-557d-bea9-06f0f1eb81e4', 1, $json${"prompt":"Which `docker run` option set is the most hardened for a stateless web app on port 8080?","multiple":false,"options":[{"id":"a","text":"--privileged -p 8080:8080","is_correct":false},{"id":"b","text":"-u 10001 --cap-drop ALL --security-opt no-new-privileges:true --read-only --tmpfs /tmp --memory 512m -p 8080:8080","is_correct":true},{"id":"c","text":"-v /var/run/docker.sock:/var/run/docker.sock -p 8080:8080","is_correct":false},{"id":"d","text":"--cap-add SYS_ADMIN --read-only -p 8080:8080","is_correct":false}],"explanation":"Non-root, dropped capabilities, no privilege escalation, an immutable root filesystem and a memory limit is defence in depth. --privileged and the Docker socket both hand over host root, and SYS_ADMIN is nearly as powerful as root."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('08b4343a-9b65-51e9-91d3-29c620c147fd', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need a private package token during `docker build`, and the token must no...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('78442f7e-87f3-5a6a-adeb-0242fbafe913', '08b4343a-9b65-51e9-91d3-29c620c147fd', 1, $json${"prompt":"You need a private package token during `docker build`, and the token must not be recoverable from the image. Which approach?","multiple":false,"options":[{"id":"a","text":"--build-arg TOKEN=... with ARG TOKEN","is_correct":false},{"id":"b","text":"COPY token.txt, use it, then RUN rm token.txt","is_correct":false},{"id":"c","text":"RUN --mount=type=secret,id=token ... with docker build --secret id=token,src=token.txt","is_correct":true},{"id":"d","text":"ENV TOKEN=... then unset it in the next RUN","is_correct":false}],"explanation":"A BuildKit secret mount is never written into a layer. Build args appear in history, a copied-then-deleted file stays in an earlier layer, and ENV is baked into the image config."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5d8a6655-321b-5f16-8c52-cbca1a6d4bf4', '00000000-0000-0000-0000-000000000001', 'mcq', 'Inside a container, the app listens on 127.0.0.1:5000. You started it with -p...', 'beginner', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2f8a78b5-9b8a-5717-9de4-a8242b0df08e', '5d8a6655-321b-5f16-8c52-cbca1a6d4bf4', 1, $json${"prompt":"Inside a container, the app listens on 127.0.0.1:5000. You started it with -p 5000:5000. Why can't your browser reach it?","multiple":false,"options":[{"id":"a","text":"Port 5000 is reserved","is_correct":false},{"id":"b","text":"127.0.0.1 inside the container is private to it; the app must listen on 0.0.0.0","is_correct":true},{"id":"c","text":"You need EXPOSE 5000","is_correct":false},{"id":"d","text":"-p only works with --network host","is_correct":false}],"explanation":"Published traffic arrives on the container's network interface, not its loopback. EXPOSE is documentation, port 5000 is not reserved, and -p works on bridge networks (it is ignored with host networking)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('97536376-8fd4-58c7-823e-5a8aa0b84aca', '00000000-0000-0000-0000-000000000001', 'mcq', 'A CI runner is out of disk. Which command reclaims unused images, stopped con...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2893510f-ddf6-53d1-8382-c13b8fbc81cb', '97536376-8fd4-58c7-823e-5a8aa0b84aca', 1, $json${"prompt":"A CI runner is out of disk. Which command reclaims unused images, stopped containers, networks and build cache in one go, without touching volumes?","multiple":false,"options":[{"id":"a","text":"docker system prune -a","is_correct":true},{"id":"b","text":"docker rmi $(docker images -q)","is_correct":false},{"id":"c","text":"docker volume prune","is_correct":false},{"id":"d","text":"docker compose down","is_correct":false}],"explanation":"system prune -a covers containers, networks, all unused images and build cache, and leaves volumes alone unless --volumes is added. Removing all images fails for in-use ones and skips cache, volume prune only removes volumes, and compose down only affects one project."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f3623592-e1b3-5c46-9ee9-31c0064c692e', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which pair correctly describes namespaces and cgroups?', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('18b8d3ce-f9cf-5b6c-be1f-2d4adeea2c5e', 'f3623592-e1b3-5c46-9ee9-31c0064c692e', 1, $json${"prompt":"Which pair correctly describes namespaces and cgroups?","multiple":false,"options":[{"id":"a","text":"Namespaces limit CPU and memory; cgroups hide processes","is_correct":false},{"id":"b","text":"Namespaces control what a process can see; cgroups control how much it can use","is_correct":true},{"id":"c","text":"Both are Docker-only features","is_correct":false},{"id":"d","text":"Namespaces give each container its own kernel","is_correct":false}],"explanation":"Namespaces isolate views (pids, network, mounts, hostname, users); cgroups meter and cap resources. They are Linux kernel features used by every container runtime, and no container has its own kernel."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e6105280-43cc-5193-ad91-9e92419b909b', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Go image is 850 MB. After switching to a multi-stage build with a distroles...', 'intermediate', 2, ARRAY['docker','containers','devops','cli','dockerfile','docker-compose'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7e6e7fb6-5cb5-5115-b588-3d56e3e286cf', 'e6105280-43cc-5193-ad91-9e92419b909b', 1, $json${"prompt":"A Go image is 850 MB. After switching to a multi-stage build with a distroless static final stage, it is 12 MB. Where did the 838 MB go?","multiple":false,"options":[{"id":"a","text":"Docker compressed the layers","is_correct":false},{"id":"b","text":"The toolchain, source and caches stayed in the discarded build stage; only the binary was copied","is_correct":true},{"id":"c","text":"The registry deduplicated it","is_correct":false},{"id":"d","text":"Multi-stage builds strip debug symbols automatically","is_correct":false}],"explanation":"Only the final stage becomes the image, and COPY --from takes just the named files. Compression and deduplication do not change the image's logical size, and nothing strips symbols automatically."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('86088900-df07-50ed-a5b8-b53fb1274d81', '00000000-0000-0000-0000-000000000001', 'Final Exam: Docker Essentials', 'docker-hands-on-examples-final-exam', 'Quiz covering Capstone.', 'mcq', 'published', 'module', '6a7712f6-818a-5436-ac43-f2442a2d7997', 25, 70, 5, 24, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '86088900-df07-50ed-a5b8-b53fb1274d81' AND question_id NOT IN ('e53a6a2e-2cfa-5350-ad02-d7d81d5b3f5c', '6133fab9-0e5e-520d-8704-544500b11543', '059a53de-d131-55cb-9da5-8499954cd9b3', '0d3066b3-258c-51c6-9358-0b9f94626bb1', 'c7942491-b932-5f3f-8734-fbafab76416a', '979542f6-4afe-580c-95a4-a8ab374563ad', '55d59018-a9a5-557d-bea9-06f0f1eb81e4', '08b4343a-9b65-51e9-91d3-29c620c147fd', '5d8a6655-321b-5f16-8c52-cbca1a6d4bf4', '97536376-8fd4-58c7-823e-5a8aa0b84aca', 'f3623592-e1b3-5c46-9ee9-31c0064c692e', 'e6105280-43cc-5193-ad91-9e92419b909b');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('00fa9ec3-0cc9-550d-95b1-a3cfc0f96b40', '86088900-df07-50ed-a5b8-b53fb1274d81', 'e53a6a2e-2cfa-5350-ad02-d7d81d5b3f5c', '7fd14b1c-4304-5b14-992b-3e578f0ad9eb', 0, 2),
('1b1804ec-d25f-5c23-9cd0-3ee452f9ced1', '86088900-df07-50ed-a5b8-b53fb1274d81', '6133fab9-0e5e-520d-8704-544500b11543', '5d376051-567b-572c-b713-5604577e47b1', 1, 2),
('c3350f3a-b903-5db3-96cc-876bb9b85ca8', '86088900-df07-50ed-a5b8-b53fb1274d81', '059a53de-d131-55cb-9da5-8499954cd9b3', 'df844fc9-803f-5cec-aee9-d781804a191e', 2, 2),
('07c1148f-4e11-5266-bb91-fd4ce86a12d5', '86088900-df07-50ed-a5b8-b53fb1274d81', '0d3066b3-258c-51c6-9358-0b9f94626bb1', 'f3ec651e-1bf4-5b5f-81d7-c2a8d40f58be', 3, 2),
('cabbe948-2e48-592c-875b-5727a67f36b7', '86088900-df07-50ed-a5b8-b53fb1274d81', 'c7942491-b932-5f3f-8734-fbafab76416a', 'ba0abeb4-dee7-549f-b435-963034c68cbc', 4, 2),
('28a6b626-4b74-599c-b452-04724f35e788', '86088900-df07-50ed-a5b8-b53fb1274d81', '979542f6-4afe-580c-95a4-a8ab374563ad', '14350b16-4577-5d07-95e2-3ed3898509be', 5, 2),
('1ad9cb0b-d391-5351-aa2a-017fde535cf8', '86088900-df07-50ed-a5b8-b53fb1274d81', '55d59018-a9a5-557d-bea9-06f0f1eb81e4', 'cbe376c0-f9f3-58f2-a92d-74114bdd95bc', 6, 2),
('b6c5a53b-4239-5d4a-b59b-6b20bce0851a', '86088900-df07-50ed-a5b8-b53fb1274d81', '08b4343a-9b65-51e9-91d3-29c620c147fd', '78442f7e-87f3-5a6a-adeb-0242fbafe913', 7, 2),
('f3e03858-0c08-5b27-8636-32d30b23211a', '86088900-df07-50ed-a5b8-b53fb1274d81', '5d8a6655-321b-5f16-8c52-cbca1a6d4bf4', '2f8a78b5-9b8a-5717-9de4-a8242b0df08e', 8, 2),
('013b750c-a0e4-5636-920b-c8a0bfe91047', '86088900-df07-50ed-a5b8-b53fb1274d81', '97536376-8fd4-58c7-823e-5a8aa0b84aca', '2893510f-ddf6-53d1-8382-c13b8fbc81cb', 9, 2),
('a1bdd6ba-8851-552f-b000-d68d620c3c5a', '86088900-df07-50ed-a5b8-b53fb1274d81', 'f3623592-e1b3-5c46-9ee9-31c0064c692e', '18b8d3ce-f9cf-5b6c-be1f-2d4adeea2c5e', 10, 2),
('8742f30b-5f13-5bf5-95ab-40b26f85487d', '86088900-df07-50ed-a5b8-b53fb1274d81', 'e6105280-43cc-5193-ad91-9e92419b909b', '7e6e7fb6-5cb5-5115-b588-3d56e3e286cf', 11, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('6a7712f6-818a-5436-ac43-f2442a2d7997', '27527dc6-807c-51bf-beb9-a499519888d9', 'abd4b653-4e59-5e16-9ea5-6ecaff379ed9', 'Final Exam: Docker Essentials', 'assessment', 2, 20, '86088900-df07-50ed-a5b8-b53fb1274d81')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('ecbeb3e7-aa38-504d-b2ef-db45e6f0a820', '00000000-0000-0000-0000-000000000014', '27527dc6-807c-51bf-beb9-a499519888d9', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = '27527dc6-807c-51bf-beb9-a499519888d9' AND id NOT IN ('dc39d161-9502-5abb-b9e0-18ac27659353', '2531d509-05f1-5c52-93d5-e38ad14e08ba', '30ffb6ba-46a7-53e9-bf63-7635c7939d8a', '8c756c3f-1a2d-5c2d-bd4c-d85c4f772575', '3116d636-ac04-5bc8-9b29-9ab048aafae2', 'a178e7db-37ff-5eaa-ae37-875087041171', '7efd9428-1ac7-5426-a93e-a8d1c997cbb9', '742cdd1c-acd4-5809-a6c3-493026af4687', '7c5d1a24-f9cb-5794-91a4-e34cf6c0fae6', '50cc2134-9259-58f1-b58c-e745804d8042', 'b9b25580-f1da-5867-91b9-0102884cf409', '472312dd-6846-5e0d-b561-1510db9d6037', '6fdd3661-f499-56ea-aa73-720b41025027', '7ce61692-fdb2-5280-b68e-30fd5dce6533', '697257e9-c37f-5e19-a1ed-f971bd9c3640', '8688da8c-d6a3-53d3-9307-8f12ab174b02', 'fce64ff8-0530-5470-bf41-a46815ca2e8a', '83aa82b8-4d05-5c58-b28f-8b9f20e1dd7a', 'e7c368fe-5d6f-5a54-8d3f-3a6540400ee5', '4d5f4a7e-858d-5844-b7c7-f3395b2f839c', '071c024b-3911-5ad2-ad69-b128b9e30631', '1a0b1a96-0b7a-5908-9df1-7251a89e96d8', '1ca73668-d795-59ca-a6ee-a23b57b3d520', 'e473f1c5-c300-5a6f-bdd3-84e5c2d8ff24', '3afb2453-2a2b-587a-8e42-d2ef98e457a0', 'e4397d58-c3b5-50f5-8fc7-4fb1f0dd3833', 'b040bf53-c4fd-55bd-b660-9e7db2dae45a', '074a526d-564e-5fc1-8433-21664c101fc9', '45110f93-674a-54e1-9bea-c54ec8fb73c4', '3426d34f-6f9f-50dd-a867-9f614ec612f4', '1efe97b4-e06c-57d2-9bea-2ad7fb2a127e', 'f2caeeff-6da0-5f10-a8b1-bb6e41e3e5c0', '3c9ad4fc-634e-576d-aecd-5f544c34301b', 'ccf2c203-70e2-536f-92f7-4cc6568329ca', '2b326c59-0832-5671-97d1-8cd071a8156d', '784678b7-85ef-5cc2-9575-fd8066409380', 'cd29543a-819b-5a09-b50d-cf9cbac6a86f', '0982ab00-00c6-5191-a94f-e5d1d8c464ec', '01ce7af7-3e2a-5e71-9bfa-d5401ad8689a', '1015fcd4-ce0a-5577-a3c1-a7320c82a81d', '84d3de2d-c60c-5f30-b36f-e59c7ee50f72', '63f4f1ed-0b4d-55f1-9470-87490e982302', 'ec12699d-cd7e-5cd3-88a4-e82cc7f304fc', '8f8e5c37-f7f5-547a-9ed8-d07c46bbe1db', '14dacb5e-5f0c-5dec-bcf0-ed9bce9648ce', '6575b202-478e-5623-8169-649a1e8f0c8f', '6a98ace6-cec3-5801-978f-6a3a3c7fc18a', 'b862dd85-ba8a-531f-b382-5056d6030946', '6a7712f6-818a-5436-ac43-f2442a2d7997');
DELETE FROM course_sections WHERE course_id = '27527dc6-807c-51bf-beb9-a499519888d9' AND id NOT IN ('35aeeb53-49c4-50de-a1ec-f1b34e695109', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'a78c1c7b-0f90-5144-98fd-18f96bedea51', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', '6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', '1ef055b7-cca8-517f-bf42-4e6b2c8ffd89', 'e548c0f3-4414-5323-9baa-70ce7f49c47a', 'abd4b653-4e59-5e16-9ea5-6ecaff379ed9');

