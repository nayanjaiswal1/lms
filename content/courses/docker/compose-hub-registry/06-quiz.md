---
kind: quiz
id_key: docker/compose-hub-registry/quiz
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: "Quiz: Compose & Registries"
position: 5
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
    prompt: "In a compose.yaml with services `web` and `db`, which hostname should web use to connect to the database?"
    options:
      - text: "localhost"
      - text: "db"
        correct: true
      - text: "The db container's IP from docker inspect"
      - text: "host.docker.internal"
    explanation: "Compose puts services on a project network where each service name resolves via Docker's DNS. localhost is web itself, IPs change on recreate, and host.docker.internal points at the host machine, not another container."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A teammate ran `docker compose down -v` to 'reset the containers' and the local database is now empty. Why?"
    options:
      - text: "down always deletes data"
      - text: "-v also removes the named volumes declared in the file"
        correct: true
      - text: "-v means verbose and is unrelated"
      - text: "Postgres wipes itself when stopped"
    explanation: "Plain down removes containers and networks but keeps volumes; -v deletes volumes too. It does not mean verbose, and Postgres keeps its data on restart when a volume is used."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "The API sometimes fails at startup with 'connection refused' to Postgres despite `depends_on: [db]`. What is the robust fix?"
    options:
      - text: "Add sleep 10 to the API's command"
      - text: "Add a healthcheck to db and use depends_on with condition: service_healthy (and retry in the app)"
        correct: true
      - text: "Use restart: always on db"
      - text: "Start db manually first"
    explanation: "depends_on alone waits only for container start, not readiness. A healthcheck-gated condition waits for Postgres to accept connections. Sleeps are guesses, restart policies do not order startup, and manual steps defeat the point of Compose."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "compose.yaml contains `image: myorg/api:${API_TAG:-dev}` and there is no API_TAG anywhere. Which tag is used?"
    options:
      - text: "latest"
      - text: "dev"
        correct: true
      - text: "Compose fails with an error"
      - text: "An empty tag"
    explanation: "${VAR:-default} falls back to the default when the variable is unset or empty. The ${VAR:?msg} form is the one that fails, and latest is only used when no tag is written at all."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What is the difference between the `.env` file and the `env_file:` key?"
    options:
      - text: "They are the same thing"
      - text: ".env fills ${VAR} placeholders in compose.yaml; env_file: passes variables into the container"
        correct: true
      - text: ".env is for production, env_file is for development"
      - text: "env_file fills placeholders; .env sets container variables"
    explanation: ".env is read by Compose for YAML interpolation; env_file lists KEY=value lines injected into the container's environment. They serve different layers and are not environment-specific."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which command pushes your local image `api:2.0` to GitHub Container Registry under org `acme`?"
    options:
      - text: "docker push api:2.0 --registry ghcr.io"
      - text: "docker tag api:2.0 ghcr.io/acme/api:2.0, then docker push ghcr.io/acme/api:2.0"
        correct: true
      - text: "docker push acme/api:2.0"
      - text: "docker save api:2.0 | docker push ghcr.io"
    explanation: "The registry is chosen by the image name, so you tag with the host prefix and push that name. There is no --registry flag, acme/api goes to Docker Hub, and push does not read tar streams."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your CI script logs in with `docker login -u bot -p $TOKEN`. What is the better practice?"
    options:
      - text: "echo \"$TOKEN\" | docker login -u bot --password-stdin"
        correct: true
      - text: "Hard-code the token in the Dockerfile"
      - text: "Use the account password instead of a token"
      - text: "Skip login and rely on anonymous pulls"
    explanation: "--password-stdin keeps the secret out of process lists and shell history. Tokens in Dockerfiles leak into images, account passwords are broader than tokens, and anonymous access cannot push and is rate-limited."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "(Review: Networking & Storage) Compose names your volume `shop_dbdata`. You move the project folder to `~/apps/shop-v2` and run `docker compose up -d`. The database is empty. Why?"
    options:
      - text: "Volumes are deleted when a folder moves"
      - text: "The project name comes from the folder name, so Compose created a new volume shop-v2_dbdata"
        correct: true
      - text: "Postgres needs a migration after moving"
      - text: "Named volumes only work with bind mounts"
    explanation: "Compose prefixes resources with the project name, which defaults to the folder name. The old volume still exists; set name: shop (or -p shop) to keep using it. Volumes are not tied to folder paths, and nothing needs migrating."
---
