---
kind: quiz
id_key: docker/dockerfile/quiz
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "Quiz: Writing Dockerfiles"
position: 8
estimated_minutes: 15
pass_percentage: 70
duration_minutes: 15
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A Dockerfile ends with `RUN python app.py`. The build hangs forever. Why?"
    options:
      - text: "RUN executes at build time, so the server starts during the build and never exits"
        correct: true
      - text: "Python is not allowed in RUN"
      - text: "RUN needs exec form"
      - text: "The image is missing EXPOSE"
    explanation: "RUN runs during the build and waits for the command to finish; a server never finishes. The app should start with CMD at container start. RUN works with any program in either form, and EXPOSE is only documentation."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Every small code change makes `pip install` rerun for 3 minutes. The Dockerfile has `COPY . .` followed by `RUN pip install -r requirements.txt`. What is the fix?"
    options:
      - text: "Add --no-cache to docker build"
      - text: "Copy requirements.txt and install before copying the rest of the code"
        correct: true
      - text: "Use ADD instead of COPY"
      - text: "Combine both lines into one RUN"
    explanation: "A cache miss on COPY . . (any file changed) invalidates every later step. Copying only the manifest first keeps the install layer cached until requirements change. --no-cache makes it worse, ADD has the same cache behaviour, and COPY cannot be merged into RUN."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "An image has `ENTRYPOINT [\"python\", \"cli.py\"]` and `CMD [\"--help\"]`. What runs for `docker run img report --month 5`?"
    options:
      - text: "report --month 5"
      - text: "python cli.py --help report --month 5"
      - text: "python cli.py report --month 5"
        correct: true
      - text: "python cli.py --help"
    explanation: "Arguments after the image name replace CMD and are appended to ENTRYPOINT. They do not replace ENTRYPOINT (that needs --entrypoint) and they are not added to CMD."
  - id_key: q4
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "A container uses `CMD node server.js` (shell form). `docker stop` always takes 10 seconds and the app never runs its shutdown handler. Which change fixes it?"
    options:
      - text: "Increase the stop timeout with -t 30"
      - text: "Switch to exec form CMD [\"node\", \"server.js\"] so node receives SIGTERM, and make sure node handles SIGTERM (or run with --init)"
        correct: true
      - text: "Add EXPOSE so Docker can reach the process"
      - text: "Use RUN instead of CMD"
    explanation: "With shell form, sh is PID 1 and may not forward SIGTERM. Exec form makes node the target; as PID 1 it must handle SIGTERM itself or run under an init like tini (--init). A longer timeout only delays the SIGKILL, EXPOSE is unrelated, and RUN is build time."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which statement about ARG and ENV is correct?"
    options:
      - text: "ARG values are visible in running containers; ENV values are not"
      - text: "ENV values are available in running containers; ARG values exist only during the build, but can still leak into image history"
        correct: true
      - text: "Both are safe places for secrets because images are private"
      - text: "ARG cannot be used before FROM"
    explanation: "ENV is baked into the image config; ARG is build-time only, yet values used in RUN steps show up in docker history. Neither is safe for secrets. ARG before FROM is allowed and is how you parameterise the base image."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A Go service image is 900 MB because it contains the Go toolchain. What is the standard fix?"
    options:
      - text: "Run `go clean` at the end of the Dockerfile"
      - text: "A multi-stage build: compile in a golang stage, then COPY --from that stage only the binary into a small runtime image"
        correct: true
      - text: "Use docker export and import to flatten it"
      - text: "Compress the image with gzip before pushing"
    explanation: "Multi-stage builds leave the toolchain in a discarded stage. go clean in a later layer cannot shrink earlier layers, flattening still includes the toolchain files, and registries already compress layers."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You need an npm token to install private packages during a build, without the token ending up in the image. What do you use?"
    options:
      - text: "ARG NPM_TOKEN and --build-arg"
      - text: "ENV NPM_TOKEN in the Dockerfile, removed with unset later"
      - text: "RUN --mount=type=secret plus docker build --secret"
        correct: true
      - text: "COPY .npmrc and delete it in the next RUN"
    explanation: "A secret mount exists only during that RUN step and is never written to a layer. ARG values appear in history, ENV is baked into the config, and a file copied then deleted still lives in the earlier layer."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your team builds on Apple Silicon laptops and deploys to amd64 servers, where containers fail with 'exec format error'. What fixes it?"
    options:
      - text: "docker buildx build --platform linux/amd64 (or linux/amd64,linux/arm64 for a multi-platform image)"
        correct: true
      - text: "Use the --no-cache flag"
      - text: "Switch the base image to alpine"
      - text: "Set CGO_ENABLED=0 in every Dockerfile"
    explanation: "exec format error means the binary's CPU architecture does not match the host. Building for the target platform fixes it. Cache, base distro and CGO settings do not change the target architecture."
  - id_key: q9
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "(Review: Images & Layers) Why put `apt-get update`, `apt-get install` and `rm -rf /var/lib/apt/lists/*` in a single RUN?"
    options:
      - text: "Docker allows only one RUN per Dockerfile"
      - text: "So the package index is never stale from cache and the deleted lists never get stored in a layer"
        correct: true
      - text: "Because apt-get only works in shell form"
      - text: "To make the build output shorter"
    explanation: "Separate layers would cache an old index and keep the deleted files in an earlier layer. Dockerfiles can have many RUN lines, and the form or output length is not the reason."
---
