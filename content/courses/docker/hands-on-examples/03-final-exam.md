---
kind: quiz
id_key: docker/hands-on-examples/final-exam
course: docker
section: hands-on-examples
section_title: Capstone
section_position: 9
title: "Final Exam: Docker Essentials"
position: 2
estimated_minutes: 20
pass_percentage: 70
duration_minutes: 25
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You deploy a new image version by `docker rm -f app` and a new `docker run`. Uploaded user files disappear every deploy. What is the root cause and fix?"
    options:
      - text: "The registry deletes files; pin a digest"
      - text: "Files were in the container's writable layer; store them in a named volume"
        correct: true
      - text: "The restart policy wipes data; use on-failure"
      - text: "The image is too large; use multi-stage builds"
    explanation: "The writable layer is deleted with the container, while a volume persists across container replacements. Registries, restart policies and image size have nothing to do with runtime data."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A Dockerfile has `COPY . .`, then `RUN npm ci`, then `CMD npm start`. Builds are slow and `docker stop` takes 10 s. Which pair of changes fixes both?"
    options:
      - text: "Add USER node and EXPOSE 3000"
      - text: "Copy package*.json and run npm ci before COPY . .; use exec form CMD [\"node\", \"server.js\"] with a SIGTERM handler (or --init)"
        correct: true
      - text: "Use ADD instead of COPY and add --no-cache"
      - text: "Use a bigger base image and a restart policy"
    explanation: "Cache order fixes rebuild time; exec form plus signal handling fixes slow stops. USER/EXPOSE help security and docs, ADD/--no-cache make caching worse, and base size or restart policy do not affect either problem."
  - id_key: q3
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "A container on a user-defined network cannot reach `redis:6379`, and `docker network inspect` shows redis on a different network. What is the cleanest fix?"
    options:
      - text: "Publish redis with -p 6379:6379 and use the host IP"
      - text: "docker network connect <api-network> redis (or put both services on one network)"
        correct: true
      - text: "Use --network host for both"
      - text: "Hard-code the redis container IP"
    explanation: "Containers resolve and reach each other only on a shared network; connecting redis to the API's network solves it. Publishing exposes redis needlessly, host networking removes isolation, and container IPs change."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which statement about image tags and digests is true?"
    options:
      - text: "latest always means the newest release"
      - text: "A tag can be re-pointed to new content; a digest always refers to the same content"
        correct: true
      - text: "Digests change when you re-tag an image"
      - text: "Tags are immutable once pushed"
    explanation: "Tags are movable labels (latest is just the default name); digests are content hashes and never change for the same bytes. Re-tagging does not change a digest, and most registries allow tags to be overwritten unless configured otherwise."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In Compose, your api starts before Postgres accepts connections. Which configuration makes Compose wait correctly?"
    options:
      - text: "depends_on: [db]"
      - text: "A healthcheck on db and depends_on: db: condition: service_healthy"
        correct: true
      - text: "restart: always on api only"
      - text: "links: [db]"
    explanation: "Only a health-gated condition waits for readiness; plain depends_on waits for container start. A restart policy retries after crashes instead of ordering startup, and links is a legacy option that does not wait either."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A service shows `Exited (137)` and `OOMKilled: true` after a traffic spike. What does this tell you?"
    options:
      - text: "Someone ran docker stop"
      - text: "The process exceeded its cgroup memory limit and the kernel killed it"
        correct: true
      - text: "The CPU limit was too low"
      - text: "The healthcheck failed"
    explanation: "137 is SIGKILL and OOMKilled=true pins it on the memory limit. docker stop normally ends in 143 or 0, CPU limits throttle rather than kill, and failed healthchecks do not kill containers under plain Docker."
  - id_key: q7
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "Which `docker run` option set is the most hardened for a stateless web app on port 8080?"
    options:
      - text: "--privileged -p 8080:8080"
      - text: "-u 10001 --cap-drop ALL --security-opt no-new-privileges:true --read-only --tmpfs /tmp --memory 512m -p 8080:8080"
        correct: true
      - text: "-v /var/run/docker.sock:/var/run/docker.sock -p 8080:8080"
      - text: "--cap-add SYS_ADMIN --read-only -p 8080:8080"
    explanation: "Non-root, dropped capabilities, no privilege escalation, an immutable root filesystem and a memory limit is defence in depth. --privileged and the Docker socket both hand over host root, and SYS_ADMIN is nearly as powerful as root."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You need a private package token during `docker build`, and the token must not be recoverable from the image. Which approach?"
    options:
      - text: "--build-arg TOKEN=... with ARG TOKEN"
      - text: "COPY token.txt, use it, then RUN rm token.txt"
      - text: "RUN --mount=type=secret,id=token ... with docker build --secret id=token,src=token.txt"
        correct: true
      - text: "ENV TOKEN=... then unset it in the next RUN"
    explanation: "A BuildKit secret mount is never written into a layer. Build args appear in history, a copied-then-deleted file stays in an earlier layer, and ENV is baked into the image config."
  - id_key: q9
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Inside a container, the app listens on 127.0.0.1:5000. You started it with -p 5000:5000. Why can't your browser reach it?"
    options:
      - text: "Port 5000 is reserved"
      - text: "127.0.0.1 inside the container is private to it; the app must listen on 0.0.0.0"
        correct: true
      - text: "You need EXPOSE 5000"
      - text: "-p only works with --network host"
    explanation: "Published traffic arrives on the container's network interface, not its loopback. EXPOSE is documentation, port 5000 is not reserved, and -p works on bridge networks (it is ignored with host networking)."
  - id_key: q10
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A CI runner is out of disk. Which command reclaims unused images, stopped containers, networks and build cache in one go, without touching volumes?"
    options:
      - text: "docker system prune -a"
        correct: true
      - text: "docker rmi $(docker images -q)"
      - text: "docker volume prune"
      - text: "docker compose down"
    explanation: "system prune -a covers containers, networks, all unused images and build cache, and leaves volumes alone unless --volumes is added. Removing all images fails for in-use ones and skips cache, volume prune only removes volumes, and compose down only affects one project."
  - id_key: q11
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which pair correctly describes namespaces and cgroups?"
    options:
      - text: "Namespaces limit CPU and memory; cgroups hide processes"
      - text: "Namespaces control what a process can see; cgroups control how much it can use"
        correct: true
      - text: "Both are Docker-only features"
      - text: "Namespaces give each container its own kernel"
    explanation: "Namespaces isolate views (pids, network, mounts, hostname, users); cgroups meter and cap resources. They are Linux kernel features used by every container runtime, and no container has its own kernel."
  - id_key: q12
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A Go image is 850 MB. After switching to a multi-stage build with a distroless static final stage, it is 12 MB. Where did the 838 MB go?"
    options:
      - text: "Docker compressed the layers"
      - text: "The toolchain, source and caches stayed in the discarded build stage; only the binary was copied"
        correct: true
      - text: "The registry deduplicated it"
      - text: "Multi-stage builds strip debug symbols automatically"
    explanation: "Only the final stage becomes the image, and COPY --from takes just the named files. Compression and deduplication do not change the image's logical size, and nothing strips symbols automatically."
---
