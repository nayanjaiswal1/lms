---
kind: quiz
id_key: docker/image-commands/quiz
course: docker
section: image-commands
section_title: Images & Layers
section_position: 3
title: "Quiz: Images & Layers"
position: 4
estimated_minutes: 12
pass_percentage: 70
duration_minutes: 12
source:
  - Docker Command Cheat Sheet.pdf
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A Dockerfile downloads a 2 GB file in one RUN step and deletes it in the next RUN step. Why is the image still about 2 GB larger?"
    options:
      - text: "Docker caches downloads in a hidden folder"
      - text: "The first RUN layer still contains the file; the later layer only hides it with a whiteout"
        correct: true
      - text: "rm does not work inside Docker builds"
      - text: "The deletion only applies when the container starts"
    explanation: "Layers are immutable and stacked. A later layer can only mask files from earlier layers, not remove their bytes. There is no hidden download cache, rm works fine, and image layers are fixed at build time. Fix: download, use and delete in one RUN, or use multi-stage builds."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Twenty containers run from the same 300 MB image. Roughly how much disk do the image layers use?"
    options:
      - text: "6 GB (20 x 300 MB)"
      - text: "About 300 MB, plus each container's small writable layer"
        correct: true
      - text: "Nothing; layers are streamed from the registry"
      - text: "300 MB per running container, 0 for stopped ones"
    explanation: "Read-only layers are shared by every container from that image; each container adds only its own thin writable layer. Layers are stored locally, not streamed, and stopped containers still keep their writable layers."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Inside a running container you edit /etc/app.conf, a file that came from the image. What does Docker do?"
    options:
      - text: "Edits the file in the image, affecting all containers"
      - text: "Copies the file into the container's writable layer and edits the copy"
        correct: true
      - text: "Refuses because image files are read-only"
      - text: "Creates a new image automatically"
    explanation: "This is copy-on-write: the file is copied up to the writable layer first. The image is never changed by a container, the write is allowed, and new images are only created by build or commit."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What does the image reference `redis` expand to?"
    options:
      - text: "redis:newest from the closest mirror"
      - text: "docker.io/library/redis:latest"
        correct: true
      - text: "localhost/redis:stable"
      - text: "hub.docker.com/redis:1"
    explanation: "Defaults are registry docker.io, namespace library (official images) and tag latest. There is no 'newest' or 'stable' default, and hub.docker.com is the website, not the registry host."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your team wants a deploy to run byte-for-byte the same image that passed CI, even if someone re-pushes the tag. What should the deploy reference?"
    options:
      - text: "myapp:latest"
      - text: "myapp:1.4"
      - text: "myapp@sha256:<digest from CI>"
        correct: true
      - text: "The image ID shown by docker images"
    explanation: "A digest is a content hash, so it cannot point to different bytes. Tags, including version tags and latest, are movable pointers. The local image ID is not a registry reference other machines can pull."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You run `docker tag app:1.0 app:stable` and then `docker rmi app:stable`. What happens to app:1.0?"
    options:
      - text: "It is deleted too because they share layers"
      - text: "Nothing; only the stable tag is removed"
        correct: true
      - text: "It becomes a dangling <none> image"
      - text: "docker rmi fails because the image has two tags"
    explanation: "docker tag only adds a pointer, and docker rmi removes that pointer. Layers are deleted only when the last reference is gone. A dangling image is one with no tags at all, which is not the case here."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You must move an image with its CMD and ENV intact to an air-gapped server. Which pair of commands?"
    options:
      - text: "docker export / docker import"
      - text: "docker save / docker load"
        correct: true
      - text: "docker commit / docker push"
      - text: "docker cp / docker run"
    explanation: "save/load keep layers, tags and metadata. export/import flatten a container's filesystem and drop CMD/ENV. push needs a reachable registry, and docker cp copies individual files, not images."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "(Review: Running Containers) A container built from your image exits with code 127 right after start. What is the most likely cause?"
    options:
      - text: "Out of memory"
      - text: "The command in CMD/ENTRYPOINT is not found in the image"
        correct: true
      - text: "Docker stop timed out"
      - text: "The port is already allocated"
    explanation: "127 is the shell's 'command not found'. OOM shows as 137, a stop timeout ends in 137 too, and a port conflict makes docker run fail before the container starts (exit 125 from the CLI)."
---
