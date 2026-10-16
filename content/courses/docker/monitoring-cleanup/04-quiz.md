---
kind: quiz
id_key: docker/monitoring-cleanup/quiz
course: docker
section: monitoring-cleanup
section_title: Troubleshooting & Cleanup
section_position: 8
title: "Quiz: Troubleshooting & Cleanup"
position: 3
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
    prompt: "A container restarted overnight and its logs show no error. Which command most directly tells you whether it was OOM-killed or stopped by someone?"
    options:
      - text: "docker events --since 12h --filter container=NAME"
        correct: true
      - text: "docker stats NAME"
      - text: "docker top NAME"
      - text: "docker port NAME"
    explanation: "Events record oom, die (with exit code), kill and restart with timestamps. stats shows only current usage, top shows current processes, and port shows mappings."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A server's disk filled up, and /var/lib/docker/containers holds a 40 GB *-json.log file. What is the lasting fix?"
    options:
      - text: "Delete the file by hand every week"
      - text: "Configure log rotation (max-size/max-file) or the local log driver"
        correct: true
      - text: "Run docker system prune"
      - text: "Use docker logs --tail"
    explanation: "The default json-file driver grows without limit; rotation caps it. Manual deletion is fragile and unsafe under a running container, prune does not touch log files, and --tail only limits what you read."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Following the S-L-I-N triage, what should you do FIRST for a container in a restart loop?"
    options:
      - text: "docker exec into it"
      - text: "Check state and exit code with docker ps -a / docker inspect, then read docker logs"
        correct: true
      - text: "docker restart it"
      - text: "Rebuild the image"
    explanation: "State and logs come first and work even on a stopped container. exec races the restarts, restart destroys clues, and rebuilding before diagnosing is guesswork."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`docker run myimage` fails with 'exec format error'. What is the most likely cause?"
    options:
      - text: "The image was built for a different CPU architecture"
        correct: true
      - text: "The Dockerfile has a syntax error"
      - text: "The container ran out of memory"
      - text: "The port is already allocated"
    explanation: "exec format error means the kernel cannot execute the binary format, typically arm64 vs amd64. A Dockerfile syntax error fails at build time, OOM gives exit 137, and port conflicts give 'port is already allocated'."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "An app container with a bind mount logs 'permission denied' writing to /data. The container runs as UID 10001; on the host the folder is owned by root with mode 755. What fixes it?"
    options:
      - text: "Add EXPOSE 10001"
      - text: "Give UID 10001 write access to the host folder (chown/chmod), or run the container with a UID that already has it"
        correct: true
      - text: "Use docker restart"
      - text: "Mount it with :ro"
    explanation: "Bind mounts keep host permissions, checked against the numeric UID inside. EXPOSE is about ports, restart changes nothing, and :ro would make writes fail even more."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "On a developer laptop with a Postgres named volume you want to keep, which command reclaims the most space safely?"
    options:
      - text: "docker system prune -a --volumes"
      - text: "docker system prune -a"
        correct: true
      - text: "rm -rf /var/lib/docker"
      - text: "docker compose down -v"
    explanation: "system prune -a removes stopped containers, unused networks, all unused images and build cache, but no volumes. --volumes and down -v can delete volume data, and deleting /var/lib/docker by hand destroys everything and corrupts Docker's state."
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which command shows how much disk images, containers, volumes and build cache use?"
    options:
      - text: "docker info"
      - text: "docker system df"
        correct: true
      - text: "docker stats"
      - text: "docker images -a"
    explanation: "docker system df summarises usage and reclaimable space per type. docker info shows daemon details, stats shows live CPU/memory, and docker images covers images only."
  - id_key: q8
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "(Review: Networking) A distroless container has no shell, and you need to check what it listens on. What works?"
    options:
      - text: "docker exec -it NAME sh"
      - text: "Run a busybox container with --network container:NAME and check from there"
        correct: true
      - text: "docker attach NAME"
      - text: "Add a shell to the production image"
    explanation: "--network container:NAME shares the target's network namespace, so busybox's tools see its sockets and localhost. exec needs a shell in the image, attach only connects to the main process, and adding a shell to production undoes the hardening."
---
