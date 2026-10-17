---
kind: quiz
id_key: docker/container-commands/quiz
course: docker
section: container-commands
section_title: Running Containers
section_position: 2
title: "Quiz: Running Containers"
position: 6
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
    prompt: "You run `docker run -d ubuntu:24.04` and `docker ps` shows nothing. What happened?"
    options:
      - text: "The image failed to download"
      - text: "The default command (bash) had no terminal attached, exited immediately, and the container stopped"
        correct: true
      - text: "-d hides containers from docker ps"
      - text: "Detached containers only appear in docker images"
    explanation: "A container lives only as long as its main process. bash with no TTY or stdin exits at once. A failed download prints an error instead, -d does not hide containers, and docker images lists images, not containers. `docker ps -a` would show it as Exited (0)."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which command correctly runs a throwaway Alpine container that prints the date and deletes itself afterwards?"
    options:
      - text: "docker run alpine:3.20 --rm date"
      - text: "docker run --rm alpine:3.20 date"
        correct: true
      - text: "docker exec --rm alpine:3.20 date"
      - text: "docker start --rm alpine:3.20 date"
    explanation: "Docker options must come before the image name; anything after the image is the container's command, so option 1 passes --rm to the container. exec works on existing running containers and start works on existing containers; neither creates one from an image."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Every `docker stop` of your app takes exactly 10 seconds and ends with exit code 137. What is the most likely cause?"
    options:
      - text: "The app ignores SIGTERM, so Docker waits the grace period and then sends SIGKILL"
        correct: true
      - text: "The container ran out of memory"
      - text: "The restart policy is set to always"
      - text: "The image is too large"
    explanation: "10 seconds is the default stop grace period; 137 is 128+9 (SIGKILL). A clean SIGTERM exit would give 143 or 0 quickly. OOM would happen while running, not exactly at each stop. Restart policy and image size do not affect stop timing."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A container keeps exiting. You want to see the error message it printed before dying. What do you run?"
    options:
      - text: "docker exec -it NAME sh"
      - text: "docker logs NAME"
        correct: true
      - text: "docker attach NAME"
      - text: "docker top NAME"
    explanation: "docker logs shows stdout/stderr even for stopped containers. exec, attach and top all need a running container, so they fail on one that has exited."
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You want a browser on your laptop to reach nginx (listening on port 80 in the container) at http://localhost:8080. Which flag is right?"
    options:
      - text: "-p 80:8080"
      - text: "-p 8080:80"
        correct: true
      - text: "--expose 8080"
      - text: "-e PORT=8080"
    explanation: "The order is HOST:CONTAINER (outside:inside). -p 80:8080 forwards to container port 8080 where nothing listens. --expose only documents a port, and an env var does not change which port nginx listens on."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your Flask app inside a container works with `docker exec NAME curl localhost:5000`, but `-p 5000:5000` from the host gets 'connection reset'. Why?"
    options:
      - text: "Flask is listening on 127.0.0.1 inside the container, which is not reachable through port publishing"
        correct: true
      - text: "Port 5000 is reserved by Docker"
      - text: "You forgot EXPOSE 5000 in the Dockerfile"
      - text: "Containers cannot publish ports above 1024"
    explanation: "The container's localhost is private to the container. Published traffic arrives on the container's network interface, so the app must listen on 0.0.0.0. EXPOSE is documentation only, port 5000 is not reserved, and high ports publish fine."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want a database container to come back after crashes and after a server reboot, but stay down if an operator stops it on purpose. Which restart policy?"
    options:
      - text: "no"
      - text: "on-failure"
      - text: "always"
      - text: "unless-stopped"
        correct: true
    explanation: "unless-stopped restarts on crashes and on daemon start, but respects a manual stop. always comes back after a daemon restart even if stopped manually. on-failure ignores clean exits and the daemon-restart case for stopped containers. no never restarts."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "(Review: Fundamentals) Inside a container, `ps` shows only the container's processes, but `uname -r` matches the host. Which explanation is correct?"
    options:
      - text: "The pid namespace hides other processes; the kernel is shared with the host"
        correct: true
      - text: "cgroups hide other processes; the container ships its own kernel"
      - text: "The container is a VM with a copied kernel"
      - text: "Docker rewrites the uname output"
    explanation: "Namespaces control visibility (pid namespace), and containers share the host kernel, which is why uname matches. cgroups limit resource use, containers have no kernel of their own, and Docker does not fake uname."
---
