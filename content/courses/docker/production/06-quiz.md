---
kind: quiz
id_key: docker/production/quiz
course: docker
section: production
section_title: Production-Ready Containers
section_position: 7
title: "Quiz: Production-Ready Containers"
position: 5
estimated_minutes: 12
pass_percentage: 70
duration_minutes: 12
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A container needs to listen on port 80 and nothing else privileged. What is the least-privilege capability setup?"
    options:
      - text: "--privileged"
      - text: "--cap-drop ALL --cap-add NET_BIND_SERVICE"
        correct: true
      - text: "--cap-add SYS_ADMIN"
      - text: "The default capability set is already minimal"
    explanation: "Dropping everything and adding back only NET_BIND_SERVICE (bind ports below 1024) is least privilege. --privileged disables isolation, SYS_ADMIN is close to root, and Docker's default set still contains capabilities most apps never need."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A monitoring tool asks you to mount /var/run/docker.sock into its container. What is the security impact?"
    options:
      - text: "None; the socket is read-only"
      - text: "The container can control the Docker daemon, which is effectively root on the host"
        correct: true
      - text: "It can only read logs"
      - text: "It only affects containers in the same Compose project"
    explanation: "The daemon does whatever the socket says, including starting privileged containers that mount the host filesystem. Mounting it read-only does not limit API calls, and the access is host-wide, not per project."
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "docker ps shows `Up 2 hours (unhealthy)` for a container started with plain docker run. What does Docker do about it?"
    options:
      - text: "Restarts it automatically after three failures"
      - text: "Nothing beyond reporting the status and emitting an event; something else must act on it"
        correct: true
      - text: "Removes it"
      - text: "Stops sending it traffic from -p ports"
    explanation: "Plain Docker only reports health. Swarm replaces unhealthy tasks, Compose uses health for depends_on, and monitoring can alert on events. Docker does not restart, remove or reroute traffic for it."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A healthcheck `CMD curl -f http://localhost:8080/health` keeps failing on an Alpine-based image, although the app answers fine from outside. Most likely cause?"
    options:
      - text: "Healthchecks cannot use localhost"
      - text: "curl is not installed in the image; the check runs inside the container"
        correct: true
      - text: "The interval is too short"
      - text: "Port 8080 must be published for healthchecks"
    explanation: "Healthchecks execute inside the container, so they can only use tools present there; Alpine has busybox wget but not curl by default. localhost is correct inside the container, interval does not cause constant failure, and checks do not use published ports."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A container with --memory 256m exits with code 137 and OOMKilled=true. A container with --cpus 0.5 is just slow. Why the difference?"
    options:
      - text: "Memory over the limit triggers the kernel's OOM killer; CPU over the limit is throttled"
        correct: true
      - text: "Docker bug; both should be killed"
      - text: "CPU limits are ignored by Docker"
      - text: "Memory limits only log warnings"
    explanation: "Memory cannot be slowed down, so the cgroup kills a process to stay under the limit. CPU time is shared out, so the process just gets less of it. Both limits are enforced by cgroups and work as designed."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which way of giving a database password to a production container is the safest of these?"
    options:
      - text: "ENV DB_PASSWORD=... in the Dockerfile"
      - text: "docker run -e DB_PASSWORD=..."
      - text: "A secret file mounted read-only (for example /run/secrets/db) that the app reads"
        correct: true
      - text: "ARG DB_PASSWORD with --build-arg"
    explanation: "A mounted secret file is not part of the image and not shown by docker inspect. ENV and ARG leak into the image or its history, and -e is visible in inspect output and to child processes."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What does `--read-only --tmpfs /tmp` give you?"
    options:
      - text: "A root filesystem the process cannot modify, plus a small in-memory scratch area at /tmp"
        correct: true
      - text: "A read-only image that cannot be pulled"
      - text: "A container that cannot write logs to stdout"
      - text: "Read-only volumes"
    explanation: "--read-only makes the container's root filesystem immutable (an attacker cannot drop tools or modify code), and --tmpfs adds a writable in-memory path. It does not affect pulling, stdout logging, or volumes you mount explicitly."
  - id_key: q8
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "(Review: Dockerfiles) A team's image runs as root, is based on node:latest, has `COPY . .` before `npm install`, and uses `CMD npm start`. Which single change fixes slow rebuilds?"
    options:
      - text: "Add USER node"
      - text: "Pin node:22-alpine"
      - text: "Copy package.json and package-lock.json and install before copying the rest"
        correct: true
      - text: "Switch to CMD [\"npm\", \"start\"]"
    explanation: "Rebuild speed is a cache-order problem: copying manifests first keeps the install layer cached. USER improves security, pinning improves reproducibility, and exec-form CMD improves signal handling; none of them affects rebuild time."
---
