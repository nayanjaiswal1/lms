-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-07-27T17:26:11Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Docker Essentials ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, estimated_hours)
VALUES ('27527dc6-807c-51bf-beb9-a499519888d9', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Docker Essentials', 'docker', 'A command-reference-driven Docker course covering the container architecture (client, daemon, registry), the full container and image lifecycle, Dockerfile authoring, networking, volumes, Docker Compose, Docker Hub, and monitoring/ cleanup commands — capped off with two worked, runnable examples (a WildFly app server and a simple Python web server) that string the commands together end to end.', '/course-covers/docker.svg', 'beginner', ARRAY['docker','containers','devops','cli'], 'published', true, 3.1)
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

## Basic commands

| Command | Description |
|---|---|
| `docker` | List all available Docker commands |
| `docker --help` | Help for Docker, or any subcommand with `--help` |
| `docker version` | Show the Docker client/server version |
| `docker info` | Display system-wide information (daemon, storage driver, containers, images) |
| `docker -d` | Start the Docker daemon directly (normally managed by your OS's service manager) |

The rest of this course walks through the command surface by area: containers,
images, Dockerfiles, networking/volumes, Compose/Hub, and monitoring/cleanup — then
ties it together with two runnable end-to-end examples.
$md$, 20, $json$[]$json$::jsonb)
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

```bash
# Run a container in interactive mode, get a shell
docker run -it rhel7/rhel bash

# Run a container in detached (background) mode, name it, publish a port
docker run --name mywildfly -d -p 8080:8080 jboss/wildfly

# Run a container in the background with a short flag
docker run -d <image_name>

# Publish container port(s) to the host: -p <host_port>:<container_port>
docker run -p 8080:8080 <image_name>

# Follow the logs of a running container
docker logs -f mywildfly

# List only active containers, then all containers (including stopped)
docker ps
docker ps -a
docker ps --all

# Stop a container, with a 1-second shutdown timeout
docker stop mywildfly
docker stop -t 1 mywildfly

# Remove a stopped container; force stop + remove; remove all containers
docker rm mywildfly
docker rm -f mywildfly
docker rm -f $(docker ps -aq)

# Remove all stopped containers
docker rm $(docker ps -q -f "status=exited")

# Open a shell inside a running container
docker exec -it mywildfly bash

# Inspect a running container
docker inspect mywildfly

# Live resource usage
docker container stats
```
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

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

```bash
# Build an image from the Dockerfile in the current directory
docker build -t myimage:latest .
docker build -t [username/]<image-name>[:tag] <dockerfile-path>

# Build without using Docker's layer cache
docker build -t <image_name> . --no-cache

# List local images
docker images

# Remove an image; remove all unused (dangling) images
docker rmi myimage:latest
docker image prune

# View the build history of an image
docker history jboss/wildfly

# Tag an image: create "myimage:v1" from "jboss/wildfly:latest"
docker tag jboss/wildfly myimage:v1
docker tag <image-name> <new-image-name>

# Export an image to a file, then re-import it elsewhere
docker save -o myimage.tar myimage:latest
docker load -i myimage.tar

# Authenticate, then push an image to a registry
docker login -u <username>
docker push <username>/<image-name>[:tag]

# Pull an image from Docker Hub; search Hub for one first
docker search <image-name>
docker pull <image-name>
```

## Images vs. containers, in one line

An **image** is the read-only template on disk (or in a registry); a **container** is
a live, writable instance of that template. `docker build` produces images, `docker
run` produces containers.
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

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

Custom WildFly image with an admin user, exposing the app and admin ports, and
binding the admin console to all interfaces:

```dockerfile
# Use the existing WildFly image
FROM jboss/wildfly

# Add an administrative user
RUN /opt/jboss/wildfly/bin/add-user.sh admin Admin#70365 --silent

# Expose the administrative port
EXPOSE 8080 9990

# Bind the WildFly management interface to all IP addresses
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", \
     "-bmanagement", "0.0.0.0"]
```

Build and run it:

```bash
# Build the image
docker build -t mywildfly .

# Run it, publishing both the app and admin ports
docker run -it -p 8080:8080 -p 9990:9990 mywildfly

# Log into the admin console at http://<docker-daemon-ip>:9990
# with admin / Admin#70635
```

`RUN` vs. `CMD`/`ENTRYPOINT` is the instruction to internalize: `RUN` executes at
**build** time and bakes its result into a layer; `CMD`/`ENTRYPOINT` define what runs
at **container start** time and don't affect the image's layers at all.
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

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
docker run --name mywildfly-net -d --net mynetwork \
  -p 8080:8080 jboss/wildfly
```

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
docker run --name mywildfly-volume -d \
  -v myfolder/:/opt/jboss/wildfly/standalone/deployments/ \
  -p 8080:8080 jboss/wildfly
```

`-v host_path:container_path` bind-mounts a path from the host. Omit the host path
(`-v /container/path`) or use a name (`-v myvolume:/container/path`) to use a
Docker-managed named volume instead — the difference matters for portability: a
bind mount depends on the host's filesystem layout, a named volume doesn't.
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Compose & Registries
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('5a6f4fb1-d93e-5010-bf79-1c44730b36cc', '27527dc6-807c-51bf-beb9-a499519888d9', 'Compose & Registries', 6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ccf2c203-70e2-536f-92f7-4cc6568329ca', '27527dc6-807c-51bf-beb9-a499519888d9', '5a6f4fb1-d93e-5010-bf79-1c44730b36cc', 'Docker Compose, Hub & Registries', 'notes', 0, $md$## Docker Compose

Compose defines and runs multi-container applications from a single YAML file
(`docker-compose.yml`), so you don't have to chain individual `docker run` commands.

| Command | Description |
|---|---|
| `docker-compose build` | Build the images referenced in the compose file |
| `docker-compose up` | Create and start all services defined in the compose file |
| `docker-compose start` | Start services that were already created by a previous `up` |
| `docker-compose run` | Run a one-off command inside one of the compose services |
| `docker-compose ps` | Show status of the compose stack's containers |
| `docker-compose ls` | List running compose projects |
| `docker-compose rm` | Remove the compose stack's containers |

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
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

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
$md$, 15, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Hands-On Examples
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('abd4b653-4e59-5e16-9ea5-6ecaff379ed9', '27527dc6-807c-51bf-beb9-a499519888d9', 'Hands-On Examples', 8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6a98ace6-cec3-5801-978f-6a3a3c7fc18a', '27527dc6-807c-51bf-beb9-a499519888d9', 'abd4b653-4e59-5e16-9ea5-6ecaff379ed9', 'Two Worked Examples', 'notes', 0, $md$Two end-to-end walkthroughs that chain together commands from every earlier
lesson: building, running, networking, mounting, and inspecting.

## Example 1 — custom WildFly app server

Build the custom image from the [Dockerfile lesson](../dockerfile/01-lesson.md), run
it, and reach the admin console:

```bash
# Build the image
docker build -t mywildfly .

# Run it, publishing the app port (8080) and admin port (9990)
docker run -it -p 8080:8080 -p 9990:9990 mywildfly

# Open http://<docker-daemon-ip>:9990 and log in with admin / Admin#70635
```

## Example 2 — a simple Python web server

Runs a bare Python `SimpleHTTPServer`, serving a bind-mounted directory from the
host, with the container's working directory set to that mount.

> On RHEL, SELinux needs the mounted directory relabeled first:
> `chcon -Rt svirt_sandbox_file_t $(pwd)`

```bash
# Create a directory and a page to serve
mkdir -p www/
echo "Server is up" > www/index.html

# Run the container as a daemon:
#   -p 8000:8000        map host port 8000 to container port 8000
#   --name=pythonweb     name the container
#   -v $(pwd)/www:/var/www/html   mount host ./www into the container
#   -w /var/www/html      set the working directory
#   rhel7/rhel /bin/python -m SimpleHTTPServer 8000   start the server
docker run -d \
  -p 8000:8000 \
  --name=pythonweb \
  -v $(pwd)/www:/var/www/html \
  -w /var/www/html \
  rhel7/rhel \
  /bin/python \
  -m SimpleHTTPServer 8000

# Check it's serving
curl <container-daemon-ip>:8000

# Confirm it's running, inspect it, and look inside
docker ps
docker inspect pythonweb | less
docker exec -it pythonweb bash
```

## What each flag ties back to

| Flag / command | Covered in |
|---|---|
| `-p host:container` | [Container Commands](../container-commands/01-lesson.md) |
| `-v host:container` (bind mount) | [Networks & Volumes](../networking-volumes/01-lesson.md) |
| `-w /path` (working directory) | Same as Dockerfile's `WORKDIR` — see [Dockerfile](../dockerfile/01-lesson.md) |
| `docker build -t`, `docker run` | [Building & Managing Images](../image-commands/01-lesson.md), [Container Lifecycle & Commands](../container-commands/01-lesson.md) |
| `docker ps`, `docker inspect`, `docker exec` | [Container Lifecycle & Commands](../container-commands/01-lesson.md) |

Both examples are just combinations of the individual commands from earlier
lessons — once each command is familiar in isolation, reading a real `docker run`
invocation with five flags stops being intimidating.
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('ecbeb3e7-aa38-504d-b2ef-db45e6f0a820', '00000000-0000-0000-0000-000000000014', '27527dc6-807c-51bf-beb9-a499519888d9', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

