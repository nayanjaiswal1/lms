---
kind: lesson
id_key: docker/image-commands/lesson
course: docker
section: image-commands
section_title: Images & Layers
section_position: 3
title: "Lab: Build, Tag, Save and Load Images"
position: 3
estimated_minutes: 20
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 45
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: build-image
      title: Build an image from a Dockerfile
      points: 10
      description: Write the Dockerfile from the example above to ~/work/Dockerfile and build it as myimage:latest.
      verification_script: |
        docker image inspect myimage:latest >/dev/null 2>&1
      hint_context: docker build --network=host -t myimage:latest . builds using the Dockerfile in the current directory (--network=host is this sandbox's requirement for any build step that starts a container internally — see the note below the examples).
      explanation_context: docker build reads a Dockerfile and produces a new image, layer by layer. -t names (tags) the resulting image so you can reference it later.
      solution_script: |
        printf 'FROM alpine:3.20\nCMD ["echo", "hello from myimage"]\n' > /home/labuser/work/Dockerfile
        cd /home/labuser/work && docker build --network=host -t myimage:latest .
    - id_key: tag-image
      title: Tag an image with a second reference
      points: 10
      description: Create a second tag, myimage:v1, pointing at the same image as myimage:latest.
      verification_script: |
        docker image inspect myimage:v1 >/dev/null 2>&1
      hint_context: docker tag doesn't copy anything — it just adds another name pointing at the same image content.
      explanation_context: An image can have any number of tags pointing at the same underlying layers. docker tag myimage:latest myimage:v1 makes "v1" a second name for the exact same image.
      solution_script: docker tag myimage:latest myimage:v1
    - id_key: save-and-load
      title: Export an image to a tarball and reload it
      points: 10
      description: Save myimage:latest to ~/work/myimage.tar with "docker save", then load it back with "docker load".
      verification_script: |
        test -f /home/labuser/work/myimage.tar && docker image inspect myimage:latest >/dev/null 2>&1
      hint_context: docker save -o myimage.tar myimage:latest writes the tarball; docker load -i myimage.tar reads it back in.
      explanation_context: docker save/load round-trips an image through a plain .tar file — no registry needed. This is how you'd move an image to a machine with no network access at all.
      solution_script: |
        docker save -o /home/labuser/work/myimage.tar myimage:latest
        docker load -i /home/labuser/work/myimage.tar
    - id_key: remove-tag
      title: Remove one tag without deleting the image
      points: 10
      description: Remove the myimage:v1 tag with "docker rmi", while myimage:latest keeps working.
      verification_script: |
        ! docker image inspect myimage:v1 >/dev/null 2>&1 && docker image inspect myimage:latest >/dev/null 2>&1
      hint_context: docker rmi myimage:v1 removes only that tag — the underlying image stays as long as another tag (myimage:latest) still references it.
      explanation_context: docker rmi removes a tag reference, not necessarily the image data. The image's layers are only actually deleted once its last tag is removed (or you use docker image prune for dangling/untagged ones).
      solution_script: docker rmi myimage:v1
---

## Why this matters

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
