---
kind: lesson
id_key: docker/fundamentals/architecture
course: docker
section: fundamentals
section_title: Big Picture & Fundamentals
section_position: 1
title: "Docker's Architecture: Client, Daemon, Runtime"
position: 3
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

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
