---
kind: lesson
id_key: docker/fundamentals/lesson
course: docker
section: fundamentals
section_title: Big Picture & Fundamentals
section_position: 1
title: Images, Containers and Registries
position: 1
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## Why this matters

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
