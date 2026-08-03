-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-07-30T13:58:59Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Docker Essentials ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, estimated_hours)
VALUES ('27527dc6-807c-51bf-beb9-a499519888d9', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Docker Essentials', 'docker', 'A command-reference-driven Docker course covering the container architecture (client, daemon, registry), the full container and image lifecycle, Dockerfile authoring, networking, volumes, Docker Compose, Docker Hub, and monitoring/ cleanup commands — capped off with two worked, runnable examples (a WildFly app server and a simple Python web server) that string the commands together end to end.', '/course-covers/docker.svg', 'beginner', ARRAY['docker','containers','devops','cli'], 'published', true, 4.6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

-- Section: Fundamentals
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('35aeeb53-49c4-50de-a1ec-f1b34e695109', '27527dc6-807c-51bf-beb9-a499519888d9', 'Fundamentals', 1)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2531d509-05f1-5c52-93d5-e38ad14e08ba', '27527dc6-807c-51bf-beb9-a499519888d9', '35aeeb53-49c4-50de-a1ec-f1b34e695109', 'What Docker Is', 'notes', 0, $md$## Containers, images, registries

Docker packages an application, and everything it needs to run, into a **container
image**: a base operating system, libraries, files and folders, environment variables,
volume mount-points, and the application binaries itself.

- **Image** — a lightweight, standalone, executable template. Multiple containers can
  run from the same image, all sharing identical behavior. This is what makes an
  application scalable and distributable.
- **Container** — a runtime instance of an image. A container always runs the same way
  regardless of the underlying infrastructure, isolating the app from host differences
  (e.g. dev vs. staging).
- **Registry** — a remote store for images (Docker Hub is the default, at
  `https://hub.docker.com`). Images are pushed to and pulled from a registry to move
  them between machines.

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
      "explanation": "The image is the standalone, executable template. A container is what you get when that template is actually run — and any number of containers can be started from the same image, all sharing identical starting behavior."
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
      "explanation": "A registry (Docker Hub by default) is a remote store for named, tagged images — the mechanism for moving an image between machines via push/pull."
    }
  ]
}
```

## Container architecture

Three components make up the architecture, and you interact with all of them through
the single `docker` client binary:

```
Client                Runtime (Daemon)              Registry
------                -----------------              --------
docker build   --->   builds/runs containers  --->   image registry
docker pull    <---   and images                <---  (pull images down)
docker run     --->   from local images
```

The daemon manages containers and images locally; the client sends it commands
(`build`, `pull`, `run`, ...) either over a local socket or a remote API. The registry
is where named, tagged images live so they can be shared across machines.

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
    }
  ]
}
```

## Basic commands

| Command | Description |
|---|---|
| `docker` | List all available Docker commands |
| `docker --help` | Help for Docker, or any subcommand with `--help` |
| `docker version` | Show the Docker client/server version |
| `docker info` | Display system-wide information (daemon, storage driver, containers, images) |
| `docker -d` | Start the Docker daemon directly (normally managed by your OS's service manager) |

```knowledge-check
{
  "questions": [
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
      "explanation": "docker version only reports the client/server version numbers. docker info is the one that shows system-wide daemon state — storage driver, container counts, image counts, and more."
    }
  ]
}
```

The rest of this course walks through the command surface by area: containers,
images, Dockerfiles, networking/volumes, Compose/Hub, and monitoring/cleanup — then
ties it together with two runnable end-to-end examples.
$md$, 20, $json$[{"id":"docker-fundamentals-concepts-q1","type":"mcq","correct":"c"},{"id":"docker-fundamentals-concepts-q2","type":"mcq","correct":"b"},{"id":"docker-fundamentals-architecture-q1","type":"mcq","correct":"b"},{"id":"docker-fundamentals-commands-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Container Commands
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('aafccd23-0abe-53b5-a951-5b01f113868c', '27527dc6-807c-51bf-beb9-a499519888d9', 'Container Commands', 2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('50cc2134-9259-58f1-b58c-e745804d8042', '27527dc6-807c-51bf-beb9-a499519888d9', 'aafccd23-0abe-53b5-a951-5b01f113868c', 'Container Lifecycle & Commands', 'notes', 0, $md$## Syntax

```
docker [CMD] [OPTS] [CONTAINER]
```

## Lifecycle at a glance

`create` → `start` → (`pause`/`unpause`, `stop`/`restart`) → `rm`. `run` is `create` +
`start` in one step. `kill` force-stops and can be combined with removal.

| Command | Description |
|---|---|
| `docker create` | Create a new container (does not start it) |
| `docker run` | Create **and** start a container from an image |
| `docker start` | Start one or more stopped containers |
| `docker stop` | Stop a container (sends `SIGTERM`, then `SIGKILL` after a grace period) |
| `docker restart` | Restart a container |
| `docker pause` / `docker unpause` | Freeze / unfreeze all processes in a container |
| `docker kill` | Kill a running container immediately with `SIGKILL` (or a specified signal) |
| `docker wait` | Block until one or more containers stop, then print their exit codes |
| `docker rm` | Remove a container — must be stopped first, or use `-f` to force |
| `docker update` | Update the resource configuration of one or more containers |

## Inspecting & interacting

| Command | Description |
|---|---|
| `docker ps` | List running containers (`docker ps -a` for running **and** stopped) |
| `docker attach` | Attach your terminal to a running container's main process |
| `docker exec` | Run a new command inside an already-running container |
| `docker logs` | Fetch a container's logs (`-f` to follow, like `tail -f`) |
| `docker inspect` | Full container/image metadata as JSON |
| `docker top` | Show the running processes inside a container |
| `docker stats` | Live CPU, memory, and network I/O usage |
| `docker port` | Show a container's published ports |
| `docker diff` | Inspect changed files/dirs on a container's filesystem vs. its image |
| `docker rename` | Rename a container |
| `docker cp` | Copy files/folders between a container and the local filesystem |
| `docker commit` | Create a new image from a container's current state |
| `docker export` | Export a container's filesystem as a `.tar` archive |

## Examples

### Starting containers

```bash
# Run a container in interactive mode, get a shell
docker run -it alpine:3.20 sh

# Run a container in detached (background) mode and name it
docker run --name myserver -d --network host nginx:1.27-alpine

# Run a container in the background with a short flag
docker run -d <image_name>

# Normally you'd publish a container port to the host with -p <host_port>:<container_port> —
# this lab's sandbox runs its own Docker daemon inside a nested network, so -p publishing
# doesn't reach the terminal you're typing in. --network host sidesteps that: the container
# shares the sandbox's own network directly, no publishing needed. The "Inspecting" section
# below shows the pattern for actually reaching a --network host container's port.
docker run --network host <image_name>
```

[[lab-task:1]]

### Stopping & removing

```bash
# Stop a container, with a 1-second shutdown timeout
docker stop myserver
docker stop -t 1 myserver

# Remove a stopped container; force stop + remove; remove all containers
docker rm myserver
docker rm -f myserver
docker rm -f $(docker ps -aq)

# Remove all stopped containers
docker rm $(docker ps -q -f "status=exited")
```

[[lab-task:2]]

### Interacting with a running container

```bash
# List only active containers, then all containers (including stopped)
docker ps
docker ps -a
docker ps --all

# Open a shell inside a running container
docker exec -it myserver sh

# Follow the logs of a running container
docker logs -f myserver
```

[[lab-task:3]]

### Inspecting

```bash
# Inspect a running container
docker inspect myserver

# Live resource usage
docker container stats

# Confirm myserver is actually serving, using a second throwaway --network host
# container to reach it via 127.0.0.1 (both share the same network stack)
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

[[lab-task:4]]
$md$, 45, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('f9f516ae-38a5-5f99-ac05-eecb4b3457a4', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '50cc2134-9259-58f1-b58c-e745804d8042', 'module', 'Container Lifecycle & Commands', NULL, 'terminal', 'mindforge/lab-docker-sysbox:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 45, 3, 0, false, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('305e159f-d3f1-5664-ba80-90a794042cac', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 1, 'Run a detached, named container', $md$Start an nginx:1.27-alpine container named "myserver", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).$md$, $script$docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx
$script$, 'docker run has a flag for detached mode and one for naming — check the "Starting containers" examples above.', 'docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.', 10, false, false),
('6ca687da-2d6c-5a4f-8d12-ef1bab717ef7', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 2, 'Stop and remove a container', $md$Start a second container named "tempbox" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in "docker ps -a".$md$, $script$! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox
$script$, 'docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.', 'docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container''s filesystem and metadata. docker rm -f does both in one step.', 10, false, false),
('6ad892e5-1554-57fb-bb9d-af5074f5ba3b', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 3, 'Exec into a container and check its logs', $md$Using "docker exec", create a file /tmp/hello.txt inside myserver containing the word "hello". Then view myserver's logs.$md$, $script$docker exec myserver test -f /tmp/hello.txt && docker exec myserver grep -q hello /tmp/hello.txt
$script$, 'docker exec myserver sh -c "echo hello > /tmp/hello.txt" runs a command inside the already-running container.', 'docker exec runs a new process inside a container that''s already running — unlike docker run, which always starts a fresh container. docker logs shows what the container''s main process has printed to stdout/stderr.', 10, false, false),
('b7c3a69d-fde0-5f4d-96d8-887c936aa0f5', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 4, 'Inspect the container and confirm it''s serving', $md$Use "docker inspect myserver" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox''s terminal can''t directly curl a container''s port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.', 'docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other''s ports directly via 127.0.0.1 — the pattern this sandbox uses to check "is it really serving," in place of curl-ing the terminal''s own localhost.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('76a8d19f-7cf6-5751-91aa-ec3139d3db58', 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4', 1, $json$[{"id":"305e159f-d3f1-5664-ba80-90a794042cac","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":1,"title":"Run a detached, named container","description":"Start an nginx:1.27-alpine container named \"myserver\", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).","verification_script":"docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx\n","hint_context":"docker run has a flag for detached mode and one for naming — check the \"Starting containers\" examples above.","explanation_context":"docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.","points":10,"is_optional":false,"is_stateful":false},{"id":"6ca687da-2d6c-5a4f-8d12-ef1bab717ef7","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":2,"title":"Stop and remove a container","description":"Start a second container named \"tempbox\" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in \"docker ps -a\".","verification_script":"! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox\n","hint_context":"docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.","explanation_context":"docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container's filesystem and metadata. docker rm -f does both in one step.","points":10,"is_optional":false,"is_stateful":false},{"id":"6ad892e5-1554-57fb-bb9d-af5074f5ba3b","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":3,"title":"Exec into a container and check its logs","description":"Using \"docker exec\", create a file /tmp/hello.txt inside myserver containing the word \"hello\". Then view myserver's logs.","verification_script":"docker exec myserver test -f /tmp/hello.txt \u0026\u0026 docker exec myserver grep -q hello /tmp/hello.txt\n","hint_context":"docker exec myserver sh -c \"echo hello \u003e /tmp/hello.txt\" runs a command inside the already-running container.","explanation_context":"docker exec runs a new process inside a container that's already running — unlike docker run, which always starts a fresh container. docker logs shows what the container's main process has printed to stdout/stderr.","points":10,"is_optional":false,"is_stateful":false},{"id":"b7c3a69d-fde0-5f4d-96d8-887c936aa0f5","lab_id":"f9f516ae-38a5-5f99-ac05-eecb4b3457a4","position":4,"title":"Inspect the container and confirm it's serving","description":"Use \"docker inspect myserver\" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2\u003e/dev/null | grep -qi \"Welcome to nginx\"\n","hint_context":"docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox's terminal can't directly curl a container's port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.","explanation_context":"docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other's ports directly via 127.0.0.1 — the pattern this sandbox uses to check \"is it really serving,\" in place of curl-ing the terminal's own localhost.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f0a35b0f-eb6c-50b1-9248-77f2e1fad366', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', '305e159f-d3f1-5664-ba80-90a794042cac', 1, 'Run a detached, named container', $md$Start an nginx:1.27-alpine container named "myserver", detached, using --network host (this sandbox's Docker runs inside its own nested network — see the note below the examples).$md$, $script$docker ps --filter name=myserver --filter status=running --format '{{.Image}}' | grep -q nginx
$script$, 'docker run has a flag for detached mode and one for naming — check the "Starting containers" examples above.', 'docker run --name myserver -d --network host nginx:1.27-alpine combines create+start (-d for detached) with --name to name it.', 10, false, false),
('43b5ab0c-428d-55ad-a0d6-f141bda94a7d', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', '6ca687da-2d6c-5a4f-8d12-ef1bab717ef7', 2, 'Stop and remove a container', $md$Start a second container named "tempbox" from alpine:3.20 that sleeps, then stop it and remove it so it no longer appears in "docker ps -a".$md$, $script$! docker ps -a --filter name=tempbox --format '{{.Names}}' | grep -q tempbox
$script$, 'docker run -d --network host --name tempbox alpine:3.20 sleep 3600 creates it; docker stop and docker rm (or docker rm -f) remove it.', 'docker stop sends SIGTERM (then SIGKILL after a grace period); docker rm then deletes the stopped container''s filesystem and metadata. docker rm -f does both in one step.', 10, false, false),
('25f58c35-b87e-5f76-8686-b3f04c350978', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', '6ad892e5-1554-57fb-bb9d-af5074f5ba3b', 3, 'Exec into a container and check its logs', $md$Using "docker exec", create a file /tmp/hello.txt inside myserver containing the word "hello". Then view myserver's logs.$md$, $script$docker exec myserver test -f /tmp/hello.txt && docker exec myserver grep -q hello /tmp/hello.txt
$script$, 'docker exec myserver sh -c "echo hello > /tmp/hello.txt" runs a command inside the already-running container.', 'docker exec runs a new process inside a container that''s already running — unlike docker run, which always starts a fresh container. docker logs shows what the container''s main process has printed to stdout/stderr.', 10, false, false),
('0b946792-cb44-56dd-a527-b0bbe1d99ff2', '76a8d19f-7cf6-5751-91aa-ec3139d3db58', 'b7c3a69d-fde0-5f4d-96d8-887c936aa0f5', 4, 'Inspect the container and confirm it''s serving', $md$Use "docker inspect myserver" to look at its state, then confirm it's really serving by running a second, throwaway container (also --network host) that fetches its default page.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker inspect myserver dumps full JSON metadata (state, IP, mounts, ...). This sandbox''s terminal can''t directly curl a container''s port (its Docker runs inside its own nested network) — running a second --network host container to fetch from it sidesteps that.', 'docker inspect is your window into everything Docker knows about a container. Two --network host containers share the same network stack as each other, so one can reach the other''s ports directly via 127.0.0.1 — the pattern this sandbox uses to check "is it really serving," in place of curl-ing the terminal''s own localhost.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '76a8d19f-7cf6-5751-91aa-ec3139d3db58', updated_at = now()
WHERE id = 'f9f516ae-38a5-5f99-ac05-eecb4b3457a4' AND published_version_id IS NULL;

-- Section: Image Commands
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('a78c1c7b-0f90-5144-98fd-18f96bedea51', '27527dc6-807c-51bf-beb9-a499519888d9', 'Image Commands', 3)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8688da8c-d6a3-53d3-9307-8f12ab174b02', '27527dc6-807c-51bf-beb9-a499519888d9', 'a78c1c7b-0f90-5144-98fd-18f96bedea51', 'Building & Managing Images', 'notes', 0, $md$## Syntax

```
docker [CMD] [OPTS] [IMAGE]
```

## Command reference

| Command | Description |
|---|---|
| `docker build` | Build an image from a Dockerfile |
| `docker images` | List local images |
| `docker rmi` | Remove one or more images |
| `docker image prune` | Remove all dangling (untagged, unreferenced) images |
| `docker tag` | Add a tag to an image, or create a renamed reference to it |
| `docker history` | Show the layer-by-layer build history of an image |
| `docker inspect` | Full image metadata as JSON |
| `docker save` / `docker load` | Export an image to a `.tar` file / import it back |
| `docker import` | Create an image from a filesystem tarball |
| `docker pull` / `docker push` | Download from / upload to a registry |
| `docker search` | Search a configured registry for images |
| `docker login` / `docker logout` | Authenticate to a registry (default `https://index.docker.io/v1/`) |

## Examples

### Building & tagging

```bash
# A minimal Dockerfile to build from — write this to ./Dockerfile
FROM alpine:3.20
CMD ["echo", "hello from myimage"]
```

```bash
# Build an image from the Dockerfile in the current directory
docker build -t myimage:latest .
docker build -t [username/]<image-name>[:tag] <dockerfile-path>

# Build without using Docker's layer cache
docker build -t <image_name> . --no-cache
```

> This lab sandbox's Docker runs inside its own nested network — any RUN instruction
> in a Dockerfile starts an internal build-time container, and that needs
> `--network=host` here to work at all (`docker build --network=host -t ...`), the
> same way running any container does. A Dockerfile with no RUN steps builds fine
> either way; add the flag as a habit once your Dockerfile has one.

```bash
# List local images
docker images

# View the build history of an image
docker history myimage:latest

# Tag an image: create a second reference to the same image
docker tag myimage:latest myimage:v1
docker tag <image-name> <new-image-name>
```

[[lab-task:1]]

[[lab-task:2]]

### Save, load & clean up

```bash
# Export an image to a file, then re-import it elsewhere
docker save -o myimage.tar myimage:latest
docker load -i myimage.tar

# Remove a specific tag; remove all unused (dangling) images
docker rmi myimage:v1
docker image prune
```

[[lab-task:3]]

[[lab-task:4]]

### Registries (Docker Hub, in real usage)

```bash
# Authenticate, then push an image to a registry
docker login -u <username>
docker push <username>/<image-name>[:tag]

# Pull an image from Docker Hub; search Hub for one first
docker search <image-name>
docker pull <image-name>
```

These three (`login`/`push`/`search`) target Docker Hub in real usage — the
[Compose, Hub & Registry](../compose-hub-registry/01-lesson.md) lesson runs the same
push/pull flow against an offline registry so you can practice it hands-on.

## Images vs. containers, in one line

An **image** is the read-only template on disk (or in a registry); a **container** is
a live, writable instance of that template. `docker build` produces images, `docker
run` produces containers.
$md$, 45, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('176a62d7-cf17-5b81-8d01-33a4ee89f337', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '8688da8c-d6a3-53d3-9307-8f12ab174b02', 'module', 'Building & Managing Images', NULL, 'terminal', 'mindforge/lab-docker-sysbox:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 45, 3, 0, false, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

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
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

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

-- Section: Dockerfile
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('18aaecad-38b6-53ef-86ff-4ed976c8bbad', '27527dc6-807c-51bf-beb9-a499519888d9', 'Dockerfile', 4)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e473f1c5-c300-5a6f-bdd3-84e5c2d8ff24', '27527dc6-807c-51bf-beb9-a499519888d9', '18aaecad-38b6-53ef-86ff-4ed976c8bbad', 'Writing a Dockerfile', 'notes', 0, $md$## What it is

A Dockerfile is the set of instructions `docker build` compiles into an image — the
same way a compiler turns source code into a binary. It always starts from a base
image (`FROM`), followed by whatever setup instructions the app needs.

```bash
docker build -t [username/]<image-name>[:tag] <dockerfile-path>
```

## Instruction reference

| Instruction | Description |
|---|---|
| `FROM` | Sets the base image for everything that follows |
| `MAINTAINER` | Sets the author field on the generated image (legacy — prefer a `LABEL`) |
| `RUN` | Executes a command in a new layer on top of the current image and commits the result |
| `CMD` | The default command to run when the container starts. Allowed once — if repeated, the last one wins |
| `LABEL` | Adds metadata (key/value) to an image |
| `EXPOSE` | Documents which network ports the container listens on at runtime |
| `ENV` | Sets an environment variable |
| `ADD` | Copies files, directories, or remote URLs into the image filesystem (also unpacks local tarballs) |
| `COPY` | Copies files/directories into the image filesystem (no URL fetching, no auto-unpacking) |
| `ENTRYPOINT` | Configures the container to run as an executable |
| `VOLUME` | Creates a mount point marked as holding externally-mounted data |
| `USER` | Sets the username/UID subsequent instructions and the container run as |
| `WORKDIR` | Sets the working directory for `RUN`, `CMD`, `ENTRYPOINT`, `COPY`, and `ADD` |
| `ARG` | Declares a build-time variable, settable via `--build-arg` |
| `ONBUILD` | Registers an instruction to run later, when this image is used as a base for another build |
| `STOPSIGNAL` | Sets the system call signal sent to the container to make it exit |

## Example Dockerfile

A custom nginx image that serves a static page and exposes port 80:

```dockerfile
# Use the existing nginx image as a base
FROM nginx:1.27-alpine

# Bake a custom page into the image at build time
RUN echo "<h1>Built from a Dockerfile</h1>" > /usr/share/nginx/html/index.html

# Document which port the container listens on
EXPOSE 80

# nginx:1.27-alpine's own base image already sets the CMD that starts nginx
# in the foreground — no need to override it here.
```

Build and run it:

```bash
# Build the image. --network=host is needed here because the RUN instruction
# above starts an internal build-time container, and this sandbox's Docker
# runs inside its own nested network — same reason running any container
# here needs --network host (see the Container Commands lesson).
docker build --network=host -t mysite .

# Run it — --network host (not -p) is how a container here becomes reachable at all
docker run -d --name mysite --network host mysite

# Confirm it's serving your custom page, from a second --network host
# container (both share the same network stack, so this can reach it via
# 127.0.0.1 even though the terminal itself can't)
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

`RUN` vs. `CMD`/`ENTRYPOINT` is the instruction to internalize: `RUN` executes at
**build** time and bakes its result into a layer; `CMD`/`ENTRYPOINT` define what runs
at **container start** time and don't affect the image's layers at all.

[[lab-task:1]]

[[lab-task:2]]

[[lab-task:3]]
$md$, 40, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('066ee5fe-29dd-5dce-b852-52ee85e60bca', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', 'e473f1c5-c300-5a6f-bdd3-84e5c2d8ff24', 'module', 'Writing a Dockerfile', NULL, 'terminal', 'mindforge/lab-docker-sysbox:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 40, 3, 0, false, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4c0968e9-2015-59d5-8cec-5441943f6eb7', '066ee5fe-29dd-5dce-b852-52ee85e60bca', 1, 'Write the Dockerfile', $md$Write the example Dockerfile above to ~/work/Dockerfile — FROM nginx:1.27-alpine, a RUN that writes a custom index.html, and EXPOSE 80.$md$, $script$test -f /home/labuser/work/Dockerfile && grep -q "FROM nginx" /home/labuser/work/Dockerfile
$script$, 'Use a heredoc or your terminal''s editor to write the file — cat > Dockerfile <<''EOF'' ... EOF is the quickest way from a plain shell.', 'FROM sets the base image every later instruction builds on top of. RUN executes once at build time and bakes its result into a new layer — that''s how the custom index.html ends up baked into the image itself, not written at container-start time.', 10, false, false),
('a8f224be-119c-545b-9485-3fa2b02f2742', '066ee5fe-29dd-5dce-b852-52ee85e60bca', 2, 'Build the image', $md$Build the Dockerfile in ~/work as mysite:latest.$md$, $script$docker image inspect mysite:latest >/dev/null 2>&1
$script$, 'docker build --network=host -t mysite:latest . builds using the Dockerfile in the current directory — cd into ~/work first. --network=host is needed because this Dockerfile''s RUN instruction starts an internal build-time container, same as running any container in this sandbox.', 'docker build reads your Dockerfile top to bottom, executing each instruction as a new layer — RUN specifically does this inside its own temporary container. The result is a new, immutable image tagged mysite:latest.', 10, false, false),
('5e297ce4-f570-5a40-8de6-0c73f35c9c7f', '066ee5fe-29dd-5dce-b852-52ee85e60bca', 3, 'Run it and confirm it serves your page', $md$Run mysite:latest detached with --network host, then confirm it's serving your custom page using a second --network host container.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
$script$, 'docker run -d --name mysite --network host mysite:latest starts it; docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80 reaches it from a second host-networked container.', 'This sandbox''s Docker runs inside its own nested network, so the terminal itself can''t curl a container''s port directly — two --network host containers share the same network stack as each other, so one can reach the other via 127.0.0.1. That''s the pattern this whole course uses in place of the usual "just curl localhost" you''d do on a normal machine.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

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

-- Section: Networking & Volumes
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', '27527dc6-807c-51bf-beb9-a499519888d9', 'Networking & Volumes', 5)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('45110f93-674a-54e1-9bea-c54ec8fb73c4', '27527dc6-807c-51bf-beb9-a499519888d9', '6d7e7b79-30a3-5600-ad5d-d6899edcc0e6', 'Networks & Volumes', 'notes', 0, $md$## Networking

By default every container gets a network interface on Docker's default bridge
network. Custom networks give containers a private, name-resolvable network to
communicate over.

```
docker network [CMD] [OPTS]
```

| Command | Description |
|---|---|
| `docker network create` | Create a new network with the given name |
| `docker network ls` | List all networks |
| `docker network inspect` | Show detailed configuration for a network |
| `docker network connect` | Attach a running container to a network |
| `docker network disconnect` | Detach a container from a network |
| `docker network rm` | Delete one or more networks |

```bash
# Create a network, then run a container attached to it
docker network create mynetwork
docker run --name myserver-net -d --net mynetwork nginx:1.27-alpine
```

> This lab sandbox's Docker daemon runs inside its own nested network — creating a
> container that attaches to a *new* bridge network (like `mynetwork` above) doesn't
> work reliably in this environment, so the hands-on task below checks that you can
> create and inspect a network correctly, rather than two containers actually
> resolving each other by name. Everywhere else in this course that needs a
> container reachable at all, `--network host` is the pattern that works here — see
> the [Container Commands](../container-commands/01-lesson.md) lesson.

[[lab-task:1]]

## Volumes

Volumes persist container data outside the container's writable layer, and let
multiple containers share the same data.

```
docker volume [CMD] [OPTS]
```

| Command | Description |
|---|---|
| `docker volume create` | Create a named volume |
| `docker volume inspect` | Show low-level info about a volume |
| `docker volume ls` | List volumes |
| `docker volume rm` | Remove a volume |

```bash
# Bind-mount a local folder into a container at a specific path
docker run --name myserver-bind -d \
  -v myfolder/:/usr/share/nginx/html/ \
  --network host nginx:1.27-alpine

# Create and use a named (Docker-managed) volume instead
docker volume create mydata
docker run --name myserver-vol -d \
  -v mydata:/usr/share/nginx/html \
  --network host nginx:1.27-alpine
```

`-v host_path:container_path` bind-mounts a path from the host. Omit the host path
(`-v /container/path`) or use a name (`-v myvolume:/container/path`) to use a
Docker-managed named volume instead — the difference matters for portability: a
bind mount depends on the host's filesystem layout, a named volume doesn't.

[[lab-task:2]]
$md$, 35, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('85ace03d-4a36-536d-bd8b-63043a0c295f', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '45110f93-674a-54e1-9bea-c54ec8fb73c4', 'module', 'Networks & Volumes', NULL, 'terminal', 'mindforge/lab-docker-sysbox:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 35, 3, 0, false, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('b6d9e652-34f8-5504-a612-f05935a53ad9', '85ace03d-4a36-536d-bd8b-63043a0c295f', 1, 'Create and inspect a custom network', $md$Create a bridge network named "mynetwork" and confirm it exists with the right driver.$md$, $script$docker network inspect mynetwork --format '{{.Driver}}' 2>/dev/null | grep -q bridge
$script$, 'docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.', 'docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.', 10, false, false),
('88be1661-d9d3-5e7a-8d89-895cdbcb027a', '85ace03d-4a36-536d-bd8b-63043a0c295f', 2, 'Prove a named volume survives its container', $md$Create a named volume "mydata", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.$md$, $script$docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2>/dev/null | grep -q "still here"
$script$, 'docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo ''still here'' > /data/proof.txt" writes the file (--network host is needed for any container to start at all in this sandbox — see the Container Commands lesson); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what''s persisting the data.', 'A named volume''s data lives independently of any one container — that''s the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('6b132d62-f23c-5236-beb5-2f0c742f9acb', '85ace03d-4a36-536d-bd8b-63043a0c295f', 1, $json$[{"id":"b6d9e652-34f8-5504-a612-f05935a53ad9","lab_id":"85ace03d-4a36-536d-bd8b-63043a0c295f","position":1,"title":"Create and inspect a custom network","description":"Create a bridge network named \"mynetwork\" and confirm it exists with the right driver.","verification_script":"docker network inspect mynetwork --format '{{.Driver}}' 2\u003e/dev/null | grep -q bridge\n","hint_context":"docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.","explanation_context":"docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.","points":10,"is_optional":false,"is_stateful":false},{"id":"88be1661-d9d3-5e7a-8d89-895cdbcb027a","lab_id":"85ace03d-4a36-536d-bd8b-63043a0c295f","position":2,"title":"Prove a named volume survives its container","description":"Create a named volume \"mydata\", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.","verification_script":"docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2\u003e/dev/null | grep -q \"still here\"\n","hint_context":"docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c \"echo 'still here' \u003e /data/proof.txt\" writes the file (--network host is needed for any container to start at all in this sandbox — see the Container Commands lesson); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what's persisting the data.","explanation_context":"A named volume's data lives independently of any one container — that's the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('c16eb049-e584-57e0-b222-b3f25a216aaa', '6b132d62-f23c-5236-beb5-2f0c742f9acb', 'b6d9e652-34f8-5504-a612-f05935a53ad9', 1, 'Create and inspect a custom network', $md$Create a bridge network named "mynetwork" and confirm it exists with the right driver.$md$, $script$docker network inspect mynetwork --format '{{.Driver}}' 2>/dev/null | grep -q bridge
$script$, 'docker network create mynetwork makes it; docker network inspect mynetwork shows its full config as JSON.', 'docker network create sets up an isolated bridge network and its config (subnet, gateway, driver) — a pure control-plane operation, distinct from attaching any actual container to it.', 10, false, false),
('39c9670e-3898-54e7-a913-01581a5d0db3', '6b132d62-f23c-5236-beb5-2f0c742f9acb', '88be1661-d9d3-5e7a-8d89-895cdbcb027a', 2, 'Prove a named volume survives its container', $md$Create a named volume "mydata", write a file into it via one container, remove that container, then read the file back via a second container using the same volume.$md$, $script$docker run --rm --network host -v mydata:/data busybox:1.36 cat /data/proof.txt 2>/dev/null | grep -q "still here"
$script$, 'docker volume create mydata; then docker run --rm --network host -v mydata:/data busybox:1.36 sh -c "echo ''still here'' > /data/proof.txt" writes the file (--network host is needed for any container to start at all in this sandbox — see the Container Commands lesson); removing that container (--rm does this automatically) and running a fresh one with the same -v mydata:/data proves the volume, not the container, is what''s persisting the data.', 'A named volume''s data lives independently of any one container — that''s the whole point. This task proves it by writing from one (now-gone) container and reading from a completely different one, both just mounting the same named volume.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '6b132d62-f23c-5236-beb5-2f0c742f9acb', updated_at = now()
WHERE id = '85ace03d-4a36-536d-bd8b-63043a0c295f' AND published_version_id IS NULL;

-- Section: Compose & Registries
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('5a6f4fb1-d93e-5010-bf79-1c44730b36cc', '27527dc6-807c-51bf-beb9-a499519888d9', 'Compose & Registries', 6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ccf2c203-70e2-536f-92f7-4cc6568329ca', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Docker Compose, Hub & Registries', 'notes', 0, $md$## Docker Compose

Compose defines and runs multi-container applications from a single YAML file
(`compose.yaml`), so you don't have to chain individual `docker run` commands.
`docker-compose` (a separate binary) was Compose v1 — `docker compose` (a subcommand
of the `docker` CLI itself, no hyphen) is v2 and what every modern install ships.

| Command | Description |
|---|---|
| `docker compose build` | Build the images referenced in the compose file |
| `docker compose up` | Create and start all services defined in the compose file |
| `docker compose start` | Start services that were already created by a previous `up` |
| `docker compose run` | Run a one-off command inside one of the compose services |
| `docker compose ps` | Show status of the compose stack's containers |
| `docker compose ls` | List running compose projects |
| `docker compose down` | Stop and remove the compose stack's containers |

```yaml
# compose.yaml
services:
  web:
    image: nginx:1.27-alpine
    # This lab sandbox's Docker runs inside its own nested network (see the
    # Container Commands lesson) — network_mode: host is Compose's equivalent
    # of --network host, needed here for the same reason.
    network_mode: host
    volumes:
      - webdata:/usr/share/nginx/html

volumes:
  webdata:
```

```bash
docker compose up -d
docker compose ps
docker compose down
```

[[lab-task:1]]

## Docker Hub

Docker Hub (`https://hub.docker.com`) is Docker's hosted registry for finding and
sharing images with a team.

| Command | Description |
|---|---|
| `docker login -u <username>` | Log in to a registry (defaults to Docker Hub) |
| `docker logout` | Log out of a registry |
| `docker search <image_name>` | Search Hub for an image |
| `docker pull <image_name>` | Pull an image from Hub |
| `docker push <username>/<image_name>` | Publish an image to Hub |
| `docker tag <image>[:tag][username/] <new-name>[:new-tag]` | Retag an image for a specific registry/namespace before pushing |

```bash
# Log in, then publish an image under your namespace
docker login -u myuser
docker tag myimage:latest myuser/myimage:latest
docker push myuser/myimage:latest
```

Registries other than Docker Hub (a private registry, GHCR, ECR, etc.) work the same
way — `docker login <registry-host>` first, then tag images with that host as the
prefix (`<registry-host>/<username>/<image>:<tag>`) before pushing.

## Practicing against a real registry, offline

This sandbox has no internet access, so `docker login`/`push`/`pull` against Docker
Hub itself isn't something you can practice hands-on here — but the sandbox runs its
own private registry (the same `registry:2` image Docker Hub itself is built on) on
`localhost:5000`, with no login required. The push/pull mechanics are identical to
Hub; only the hostname differs.

```bash
# Tag an existing image for the local registry, then push it
docker tag alpine:3.20 localhost:5000/myimage:latest
docker push localhost:5000/myimage:latest

# Remove your local copy, then pull it back from the registry to prove the round trip
docker rmi localhost:5000/myimage:latest
docker pull localhost:5000/myimage:latest
```

Unlike a container's published port, `docker push`/`pull`/`build` all reach
`localhost:5000` fine directly from this terminal — those commands are carried out by
the Docker daemon itself (which shares a network with the registry), not by the
terminal's own network stack, so they aren't affected by the nested-network
constraint that `-p` publishing and raw `curl` hit elsewhere in this course.

[[lab-task:2]]
$md$, 35, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('871b5216-5e02-59e0-bdd1-db78f4e78d63', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', 'ccf2c203-70e2-536f-92f7-4cc6568329ca', 'module', 'Docker Compose, Hub & Registries', NULL, 'terminal', 'mindforge/lab-docker-sysbox:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 35, 3, 0, false, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('9371c5d9-e32e-5d21-aee8-74ea3009b389', '871b5216-5e02-59e0-bdd1-db78f4e78d63', 1, 'Bring up a service with Docker Compose', $md$Write the compose.yaml from the example above to ~/work/compose.yaml and bring it up with "docker compose up -d".$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.', 'Compose''s whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.', 10, false, false),
('9d1d5416-abd8-5399-9492-76b27a6003eb', '871b5216-5e02-59e0-bdd1-db78f4e78d63', 2, 'Push and pull through the offline registry', $md$Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.$md$, $script$docker image inspect localhost:5000/myimage:latest >/dev/null 2>&1
$script$, 'docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.', 'The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('c0055992-dbf7-5f9d-a52c-e5512d9c629e', '871b5216-5e02-59e0-bdd1-db78f4e78d63', 1, $json$[{"id":"9371c5d9-e32e-5d21-aee8-74ea3009b389","lab_id":"871b5216-5e02-59e0-bdd1-db78f4e78d63","position":1,"title":"Bring up a service with Docker Compose","description":"Write the compose.yaml from the example above to ~/work/compose.yaml and bring it up with \"docker compose up -d\".","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2\u003e/dev/null | grep -qi \"Welcome to nginx\"\n","hint_context":"docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.","explanation_context":"Compose's whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.","points":10,"is_optional":false,"is_stateful":false},{"id":"9d1d5416-abd8-5399-9492-76b27a6003eb","lab_id":"871b5216-5e02-59e0-bdd1-db78f4e78d63","position":2,"title":"Push and pull through the offline registry","description":"Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.","verification_script":"docker image inspect localhost:5000/myimage:latest \u003e/dev/null 2\u003e\u00261\n","hint_context":"docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.","explanation_context":"The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('00ab659d-a194-5e3e-9b97-70880674298b', 'c0055992-dbf7-5f9d-a52c-e5512d9c629e', '9371c5d9-e32e-5d21-aee8-74ea3009b389', 1, 'Bring up a service with Docker Compose', $md$Write the compose.yaml from the example above to ~/work/compose.yaml and bring it up with "docker compose up -d".$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -qi "Welcome to nginx"
$script$, 'docker compose up -d reads compose.yaml in the current directory and starts every service it defines, detached.', 'Compose''s whole value is turning a multi-flag docker run command (or several) into one declarative file — docker compose up reads it and creates/starts every service in one command instead of you chaining docker run calls by hand.', 10, false, false),
('179f4db8-2f1a-552f-a755-0d6be480b185', 'c0055992-dbf7-5f9d-a52c-e5512d9c629e', '9d1d5416-abd8-5399-9492-76b27a6003eb', 2, 'Push and pull through the offline registry', $md$Tag alpine:3.20 as localhost:5000/myimage:latest, push it, remove your local copy, then pull it back.$md$, $script$docker image inspect localhost:5000/myimage:latest >/dev/null 2>&1
$script$, 'docker tag alpine:3.20 localhost:5000/myimage:latest; docker push localhost:5000/myimage:latest; docker rmi localhost:5000/myimage:latest; docker pull localhost:5000/myimage:latest.', 'The push/pull mechanics against this offline registry are identical to Docker Hub — only the hostname differs, and no login is required. Removing your local copy before pulling it back proves the image really round-tripped through the registry, not just stayed cached locally.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'c0055992-dbf7-5f9d-a52c-e5512d9c629e', updated_at = now()
WHERE id = '871b5216-5e02-59e0-bdd1-db78f4e78d63' AND published_version_id IS NULL;

-- Section: Monitoring & Cleanup
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('e548c0f3-4414-5323-9baa-70ce7f49c47a', '27527dc6-807c-51bf-beb9-a499519888d9', 'Monitoring & Cleanup', 7)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ec12699d-cd7e-5cd3-88a4-e82cc7f304fc', '27527dc6-807c-51bf-beb9-a499519888d9', 'e548c0f3-4414-5323-9baa-70ce7f49c47a', 'Logs, Monitoring & Cleanup', 'notes', 0, $md$## Logs & monitoring

| Command | Description |
|---|---|
| `docker ps -a` | Show running **and** stopped containers |
| `docker logs` | Show a container's logs (`-f` to follow) |
| `docker events` | Stream real-time events from the daemon (container start/stop/die, image pull, ...) |
| `docker top` | Show running processes inside a container |
| `docker stats` | Live CPU, memory, and network I/O usage per container |
| `docker port` | Show a container's published ports |

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
      "explanation": "docker top answers \"what processes are running in this container\" (like ps inside it). docker stats answers \"how much CPU/memory/network is this container using right now\" — a live resource dashboard, not a process list."
    }
  ]
}
```

## Cleanup / prune commands

Docker accumulates disk usage fast — stopped containers, dangling images, unused
volumes and networks. Prune commands reclaim that space in one shot:

| Command | Description |
|---|---|
| `docker system prune` | Remove all resources (stopped containers, dangling images, unused networks, build cache) not associated with a running container |
| `docker image prune` | Remove dangling (untagged) images |
| `docker container prune` | Remove all stopped containers |
| `docker volume prune` | Remove all volumes not used by at least one container |
| `docker network prune` | Remove all networks not used by at least one container |

```bash
# Reclaim everything unused in one command
docker system prune

# Narrower cleanups
docker container prune
docker image prune
docker volume prune
docker network prune
```

`docker system prune` skips anything a running container still references — it's
safe to run routinely without checking `docker ps` first. Add `-a` to also remove
images not referenced by *any* container (running or not), and `--volumes` to include
unused volumes in the same pass.

```knowledge-check
{
  "questions": [
    {
      "id": "docker-monitoring-prune-q1",
      "type": "mcq",
      "prompt": "Is it safe to run plain docker system prune without first checking docker ps?",
      "options": [
        { "id": "a", "text": "No — it can delete a running container" },
        { "id": "b", "text": "Yes — it only removes resources not associated with a running container" },
        { "id": "c", "text": "Only if --volumes is omitted" },
        { "id": "d", "text": "Only on a freshly restarted daemon" }
      ],
      "correct": "b",
      "explanation": "docker system prune skips anything a running container still references. Whatever it removes was already stopped/dangling/unused, so it's safe to run routinely."
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
$md$, 15, $json$[{"id":"docker-monitoring-logs-q1","type":"mcq","correct":"a"},{"id":"docker-monitoring-logs-q2","type":"mcq","correct":"b"},{"id":"docker-monitoring-prune-q1","type":"mcq","correct":"b"},{"id":"docker-monitoring-prune-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Hands-On Examples
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('abd4b653-4e59-5e16-9ea5-6ecaff379ed9', '27527dc6-807c-51bf-beb9-a499519888d9', 'Hands-On Examples', 8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6a98ace6-cec3-5801-978f-6a3a3c7fc18a', '27527dc6-807c-51bf-beb9-a499519888d9', 'abd4b653-4e59-5e16-9ea5-6ecaff379ed9', 'Two Worked Examples', 'notes', 0, $md$Two end-to-end walkthroughs that chain together commands from every earlier
lesson: building, running, mounting, and inspecting. Both use `--network host`
throughout, same as every hands-on example in this course — see the
[Container Commands](../container-commands/01-lesson.md) lesson for why.

## Example 1 — the custom image from the Dockerfile lesson

Build the image from the [Dockerfile lesson](../dockerfile/01-lesson.md), run it, and
confirm it's serving:

```bash
# Build the image (--network=host: this Dockerfile has a RUN instruction)
docker build --network=host -t mysite .

# Run it
docker run -d --name mysite --network host mysite

# Confirm it's serving, from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:80
```

[[lab-task:1]]

## Example 2 — a simple Python web server with a bind mount

Runs a bare Python `http.server`, serving a bind-mounted directory from the host,
with the container's working directory set to that mount.

```bash
# Create a directory and a page to serve
mkdir -p www/
echo "Server is up" > www/index.html

# Run the container as a daemon:
#   --name=pythonweb              name the container
#   -v $(pwd)/www:/var/www/html   mount host ./www into the container
#   -w /var/www/html              set the working directory
#   --network host                reach it directly (see the note above)
#   python:3.12-alpine ... http.server 8000   start the server
docker run -d \
  --name=pythonweb \
  -v $(pwd)/www:/var/www/html \
  -w /var/www/html \
  --network host \
  python:3.12-alpine \
  python3 -m http.server 8000

# Check it's serving, from a second --network host container
docker run --rm --network host busybox:1.36 wget -qO- http://127.0.0.1:8000

# Confirm it's running, inspect it, and look inside
docker ps
docker inspect pythonweb | less
docker exec -it pythonweb sh
```

## What each flag ties back to

| Flag / command | Covered in |
|---|---|
| `--network host` | [Container Commands](../container-commands/01-lesson.md) |
| `-v host:container` (bind mount) | [Networks & Volumes](../networking-volumes/01-lesson.md) |
| `-w /path` (working directory) | Same as Dockerfile's `WORKDIR` — see [Dockerfile](../dockerfile/01-lesson.md) |
| `docker build -t`, `docker run` | [Building & Managing Images](../image-commands/01-lesson.md), [Container Lifecycle & Commands](../container-commands/01-lesson.md) |
| `docker ps`, `docker inspect`, `docker exec` | [Container Lifecycle & Commands](../container-commands/01-lesson.md) |

[[lab-task:2]]

Both examples are just combinations of the individual commands from earlier
lessons — once each command is familiar in isolation, reading a real `docker run`
invocation with several flags stops being intimidating.
$md$, 40, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('7b001873-fb9b-551b-9b8c-f5ac24ba4455', '00000000-0000-0000-0000-000000000001', '27527dc6-807c-51bf-beb9-a499519888d9', '6a98ace6-cec3-5801-978f-6a3a3c7fc18a', 'module', 'Two Worked Examples', NULL, 'terminal', 'mindforge/lab-docker-sysbox:27', 0, $script$for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
$script$, NULL, 40, 3, 0, false, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('5faa99c0-5638-515b-8553-e324319146c9', '7b001873-fb9b-551b-9b8c-f5ac24ba4455', 1, 'Example 1: build, run, and confirm the Dockerfile lesson''s image', $md$Write the Dockerfile from the Dockerfile lesson, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
$script$, 'This is the exact same sequence as the Dockerfile lesson''s three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.', 'Every real Docker workflow is a chain like this one — write, build, run, verify — never a single isolated command. Recognizing the chain matters more than memorizing any one flag in it.', 15, false, false),
('9fa495da-44d5-5033-b192-a727e1240544', '7b001873-fb9b-551b-9b8c-f5ac24ba4455', 2, 'Example 2: a Python web server with a bind mount', $md$Create ~/work/www/index.html with some content, run python:3.12-alpine's http.server bind-mounting that directory, and confirm it serves your file.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:8000 2>/dev/null | grep -q "Server is up"
$script$, 'mkdir -p www && echo "Server is up" > www/index.html creates the content; docker run -d --name pythonweb -v $(pwd)/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000 serves it.', '-v host:container bind-mounts your directory straight into the container — the server process sees exactly the files you have on disk, live. -w sets the working directory http.server serves from, matching Dockerfile''s WORKDIR at container-start time instead of build time.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('459ac5d9-419c-517c-b16c-d324209e5372', '7b001873-fb9b-551b-9b8c-f5ac24ba4455', 1, $json$[{"id":"5faa99c0-5638-515b-8553-e324319146c9","lab_id":"7b001873-fb9b-551b-9b8c-f5ac24ba4455","position":1,"title":"Example 1: build, run, and confirm the Dockerfile lesson's image","description":"Write the Dockerfile from the Dockerfile lesson, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2\u003e/dev/null | grep -q \"Built from a Dockerfile\"\n","hint_context":"This is the exact same sequence as the Dockerfile lesson's three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.","explanation_context":"Every real Docker workflow is a chain like this one — write, build, run, verify — never a single isolated command. Recognizing the chain matters more than memorizing any one flag in it.","points":15,"is_optional":false,"is_stateful":false},{"id":"9fa495da-44d5-5033-b192-a727e1240544","lab_id":"7b001873-fb9b-551b-9b8c-f5ac24ba4455","position":2,"title":"Example 2: a Python web server with a bind mount","description":"Create ~/work/www/index.html with some content, run python:3.12-alpine's http.server bind-mounting that directory, and confirm it serves your file.","verification_script":"docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:8000 2\u003e/dev/null | grep -q \"Server is up\"\n","hint_context":"mkdir -p www \u0026\u0026 echo \"Server is up\" \u003e www/index.html creates the content; docker run -d --name pythonweb -v $(pwd)/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000 serves it.","explanation_context":"-v host:container bind-mounts your directory straight into the container — the server process sees exactly the files you have on disk, live. -w sets the working directory http.server serves from, matching Dockerfile's WORKDIR at container-start time instead of build time.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('86000142-5046-5c80-a085-57bb105e6bc6', '459ac5d9-419c-517c-b16c-d324209e5372', '5faa99c0-5638-515b-8553-e324319146c9', 1, 'Example 1: build, run, and confirm the Dockerfile lesson''s image', $md$Write the Dockerfile from the Dockerfile lesson, build it as mysite, run it, and confirm it serves your custom page — chaining build, run, and confirm together end to end.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:80 2>/dev/null | grep -q "Built from a Dockerfile"
$script$, 'This is the exact same sequence as the Dockerfile lesson''s three tasks, done back to back — write the Dockerfile, docker build --network=host -t mysite ., docker run -d --name mysite --network host mysite, then verify with a second --network host container.', 'Every real Docker workflow is a chain like this one — write, build, run, verify — never a single isolated command. Recognizing the chain matters more than memorizing any one flag in it.', 15, false, false),
('bf984e11-0f9c-5a06-b50e-4c43bad0b265', '459ac5d9-419c-517c-b16c-d324209e5372', '9fa495da-44d5-5033-b192-a727e1240544', 2, 'Example 2: a Python web server with a bind mount', $md$Create ~/work/www/index.html with some content, run python:3.12-alpine's http.server bind-mounting that directory, and confirm it serves your file.$md$, $script$docker run --rm --network host busybox:1.36 wget -qO- --timeout=3 http://127.0.0.1:8000 2>/dev/null | grep -q "Server is up"
$script$, 'mkdir -p www && echo "Server is up" > www/index.html creates the content; docker run -d --name pythonweb -v $(pwd)/www:/var/www/html -w /var/www/html --network host python:3.12-alpine python3 -m http.server 8000 serves it.', '-v host:container bind-mounts your directory straight into the container — the server process sees exactly the files you have on disk, live. -w sets the working directory http.server serves from, matching Dockerfile''s WORKDIR at container-start time instead of build time.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '459ac5d9-419c-517c-b16c-d324209e5372', updated_at = now()
WHERE id = '7b001873-fb9b-551b-9b8c-f5ac24ba4455' AND published_version_id IS NULL;

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('ecbeb3e7-aa38-504d-b2ef-db45e6f0a820', '00000000-0000-0000-0000-000000000014', '27527dc6-807c-51bf-beb9-a499519888d9', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

