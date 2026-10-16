---
kind: quiz
id_key: docker/networking-volumes/quiz
course: docker
section: networking-volumes
section_title: Networking & Storage
section_position: 5
title: "Quiz: Networking & Storage"
position: 3
estimated_minutes: 12
pass_percentage: 70
duration_minutes: 12
source:
  - Docker Command Cheat Sheet.pdf
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Two containers started with plain `docker run` (no --network) cannot reach each other by name. Why?"
    options:
      - text: "Containers can never talk to each other"
      - text: "They are on the default bridge network, which has no DNS by container name"
        correct: true
      - text: "They need -p to publish ports to each other"
      - text: "Names only work with --network host"
    explanation: "Only user-defined networks get Docker's embedded DNS for container names. Containers can talk over IP even on the default bridge, published ports are for traffic from outside Docker, and host networking is unrelated to name resolution."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Inside the `api` container, the connection string is `postgres://localhost:5432`. The database runs in a separate container named `db` on the same user-defined network. What is wrong?"
    options:
      - text: "localhost inside api refers to api itself; use db:5432"
        correct: true
      - text: "Port 5432 must be published with -p"
      - text: "Postgres cannot run in a container"
      - text: "The network needs the host driver"
    explanation: "Each container has its own network namespace, so localhost is the container itself. Same-network containers talk on container ports directly by name; no -p or host driver needed."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want the API reachable from the internet and the database reachable only by the API. Which setup is right?"
    options:
      - text: "Publish both with -p and use a firewall"
      - text: "Put both on one user-defined network; publish only the API's port"
        correct: true
      - text: "Run both with --network host"
      - text: "Run the database with --network none"
    explanation: "Containers on the same network reach each other without publishing, so only the API needs -p. Publishing the DB widens exposure, host networking removes isolation, and --network none would cut the DB off from the API too."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You upgrade Postgres with `docker rm -f db` and a new `docker run`. All data is gone. What should the original run have included?"
    options:
      - text: "--restart always"
      - text: "A named volume, e.g. -v pgdata:/var/lib/postgresql/data"
        correct: true
      - text: "--memory 2g"
      - text: "-p 5432:5432"
    explanation: "Data in the writable layer is deleted with the container; a named volume lives independently. Restart policies, memory limits and port publishing do not persist data."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`docker run -v data:/app/data myimg` was meant to mount ./data from your project. What actually happened?"
    options:
      - text: "It mounted ./data as expected"
      - text: "It created (or reused) a named volume called data, because the source is not an absolute path"
        correct: true
      - text: "It failed with a syntax error"
      - text: "It copied ./data into the image"
    explanation: "With -v, a source without a leading / is treated as a volume name. Use \"$(pwd)/data\" for a bind mount. It is not an error, and nothing is copied into the image."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which storage type should hold short-lived secrets that must never be written to disk?"
    options:
      - text: "A named volume"
      - text: "A bind mount"
      - text: "tmpfs"
        correct: true
      - text: "The container's writable layer"
    explanation: "tmpfs lives in memory and disappears when the container stops. Volumes, bind mounts and the writable layer all write to disk."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A developer's `docker run -v /home/dev/proj/src:/app/src` typo-ed the path, and the app started with an empty /app/src. Which option would have failed loudly instead?"
    options:
      - text: "--mount type=bind,src=...,dst=/app/src"
        correct: true
      - text: "-v with :ro"
      - text: "VOLUME /app/src in the Dockerfile"
      - text: "--tmpfs /app/src"
    explanation: "With -v, a missing host path is silently created as an empty directory; --mount type=bind refuses a missing source. :ro only makes it read-only, VOLUME creates an anonymous volume, and tmpfs is memory."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "(Review: Dockerfiles) A Dockerfile has `VOLUME /var/lib/app`. Containers are created and removed many times a day. What builds up over time?"
    options:
      - text: "Dangling images"
      - text: "Anonymous volumes, unless containers are removed with -v or run with --rm"
        correct: true
      - text: "Extra image layers"
      - text: "Unused networks"
    explanation: "VOLUME makes Docker create an anonymous volume for each new container, and plain docker rm leaves it behind. It does not create images, layers or networks."
---
