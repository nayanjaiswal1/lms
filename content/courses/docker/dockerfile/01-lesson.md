---
kind: lesson
id_key: docker/dockerfile/lesson
course: docker
section: dockerfile
section_title: Dockerfile
section_position: 4
title: Writing a Dockerfile
position: 0
estimated_minutes: 25
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## What it is

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
