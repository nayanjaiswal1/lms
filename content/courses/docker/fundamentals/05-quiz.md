---
kind: quiz
id_key: docker/fundamentals/quiz
course: docker
section: fundamentals
section_title: Big Picture & Fundamentals
section_position: 1
title: "Quiz: Big Picture & Fundamentals"
position: 4
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 10
source:
  - Docker Command Cheat Sheet.pdf
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A colleague's app runs fine on their laptop but crashes on the server because the server has an older OpenSSL. How does Docker prevent this class of problem?"
    options:
      - text: "Docker upgrades the server's OpenSSL automatically when you run a container"
      - text: "The image ships the app together with its own libraries, so the server's installed packages no longer matter"
        correct: true
      - text: "Docker runs the app inside a full virtual machine with its own kernel"
      - text: "Docker compiles the app into a static binary"
    explanation: "An image bundles the app's userland dependencies (libraries, runtimes, config). Docker never touches host packages, so option 1 is wrong. Containers do not bring their own kernel (that is a VM), so option 3 is wrong. Docker does not compile anything, so option 4 is wrong."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You start three containers from the image shop:2.1. One of them deletes /app/config.yml. What happens to the other two and to the image?"
    options:
      - text: "All three containers and the image lose the file"
      - text: "The image loses the file, so the next container started will not have it"
      - text: "Only that one container loses the file; the image and the other containers are unchanged"
        correct: true
      - text: "Docker refuses the delete because images are read-only"
    explanation: "Each container gets its own writable layer on top of the read-only image. The delete is recorded only in that container's layer. The image is never modified by a running container, and the delete is allowed because it happens in the writable layer, not the image."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Inside a container, `ps` shows only two processes and the first one is PID 1. Which Linux kernel feature causes this?"
    options:
      - text: "cgroups"
      - text: "The pid namespace"
        correct: true
      - text: "The overlay2 storage driver"
      - text: "The hypervisor"
    explanation: "Namespaces control what a process can see; the pid namespace gives the container its own process tree. cgroups limit what it can consume (CPU, memory), not what it sees. overlay2 handles files, and there is no hypervisor in plain containers."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A container with no flags slowly leaks memory until the whole host becomes unresponsive. What was missing?"
    options:
      - text: "A user namespace"
      - text: "A cgroup memory limit (for example --memory 512m)"
        correct: true
      - text: "A registry login"
      - text: "The --rm flag"
    explanation: "By default containers have no memory limit, so a leak can eat host memory. Memory limits are enforced by cgroups. A user namespace changes user mapping, not resource use. --rm only deletes the container after it exits."
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "`docker ps` prints \"Cannot connect to the Docker daemon at unix:///var/run/docker.sock\". What is the most likely cause?"
    options:
      - text: "The image you want does not exist on Docker Hub"
      - text: "The dockerd service is not running (or your client points at the wrong host)"
        correct: true
      - text: "The container crashed"
      - text: "Your Dockerfile has a syntax error"
    explanation: "The client could not reach the daemon's socket at all, so no command can work. Missing images, crashed containers and Dockerfile errors all produce different errors that come back from a reachable daemon."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why do security teams treat membership of the `docker` group as equivalent to root?"
    options:
      - text: "Because the docker group can edit /etc/passwd directly"
      - text: "Because anyone who can talk to the Docker socket can start a container that mounts the host filesystem as root"
        correct: true
      - text: "Because docker group members can read all container logs"
      - text: "It is not; the docker group is unprivileged"
    explanation: "The daemon runs as root (in standard mode) and does whatever the socket tells it, including bind-mounting / into a privileged container. Reading logs is a minor risk compared to this, and the group has no direct /etc/passwd access."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which statement about containers and VMs is correct?"
    options:
      - text: "Containers and VMs both run their own kernel"
      - text: "A container can run a Windows kernel on a Linux host"
      - text: "Containers share the host kernel, so they start faster but isolate less strongly than VMs"
        correct: true
      - text: "Containers cannot run inside VMs"
    explanation: "Only VMs have their own kernel; that is why containers start in milliseconds and why their isolation is weaker. A container cannot swap kernels, and in the cloud containers usually do run inside VMs."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In the chain docker CLI -> dockerd -> containerd -> runc, which component actually creates the namespaces and cgroups and then exits?"
    options:
      - text: "docker CLI"
      - text: "dockerd"
      - text: "containerd"
      - text: "runc"
        correct: true
    explanation: "runc is the low-level OCI runtime that sets up the isolation and starts the process. The CLI only sends API calls, dockerd manages Docker objects, and containerd supervises lifecycles and images."
---
