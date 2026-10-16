---
kind: lesson
id_key: docker/compose-hub-registry/lab-healthy-stack
course: docker
section: compose-hub-registry
section_title: Compose & Registries
section_position: 6
title: "Lab: A Health-Gated Two-Service Stack"
position: 4
estimated_minutes: 20
source:
  - Docker Command Cheat Sheet.pdf
lab:
  lab_type: terminal
  environment: mindforge/lab-docker:27
  max_duration: 35
  max_resets: 3
  is_required: false
  setup_script: |
    for i in $(seq 1 70); do docker info >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1
  tasks:
    - id_key: stack-healthy
      title: Start a stack where web waits for a healthy api
      points: 15
      is_stateful: true
      description: In ~/work/stack, write the compose.yaml shown above (an "api" service with a healthcheck, and a "web" service that depends on api with condition service_healthy), then run "docker compose up -d". Both containers must be running and api must report healthy.
      verification_script: |
        test "$(docker inspect -f '{{.State.Health.Status}}' stack-api-1 2>/dev/null)" = healthy && test "$(docker inspect -f '{{.State.Running}}' stack-web-1 2>/dev/null)" = true
      hint_context: The project name comes from the folder name, so the folder must be ~/work/stack for the containers to be named stack-api-1 and stack-web-1. Run docker compose up -d from inside that folder, then docker compose ps to watch api go from "starting" to "healthy".
      explanation_context: A plain depends_on only waits for the api container to start. condition service_healthy makes Compose wait until api's healthcheck passes, so web never starts against an api that is not ready yet. That is the fix for "random" startup races between services.
      solution_script: |
        mkdir -p /home/labuser/work/stack && cd /home/labuser/work/stack
        cat > compose.yaml <<'EOF'
        services:
          api:
            image: python:3.12-alpine
            network_mode: host
            command: ["python3", "-m", "http.server", "8001"]
            environment:
              APP_ENV: ${APP_ENV:-dev}
            healthcheck:
              test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8001/"]
              interval: 3s
              timeout: 2s
              retries: 5
          web:
            image: nginx:1.27-alpine
            network_mode: host
            depends_on:
              api:
                condition: service_healthy
        EOF
        docker compose up -d
    - id_key: env-interpolation
      title: Switch the api to staging with a .env file
      points: 10
      description: Without editing compose.yaml, create ~/work/stack/.env containing APP_ENV=staging and run "docker compose up -d" again, so that the api container's APP_ENV variable is "staging".
      verification_script: |
        test "$(docker exec stack-api-1 printenv APP_ENV 2>/dev/null)" = staging
      hint_context: Compose reads .env from the project folder and substitutes ${APP_ENV:-dev} in the YAML. docker compose config shows the resolved value; docker compose up -d then recreates only the service whose configuration changed.
      explanation_context: The .env file feeds ${...} placeholders in compose.yaml; the default after :- is used only when the variable is unset or empty. Because the api's resolved environment changed, up -d recreated the api container and left everything else alone.
      solution_script: |
        cd /home/labuser/work/stack
        echo "APP_ENV=staging" > .env
        docker compose up -d
---

## Why this matters

Lesson 2 showed that `depends_on` alone does not wait for a service to be
**ready**, and that `.env` files parameterise the YAML. This lab makes you see
both happen: Compose holds back `web` until `api` is healthy, then a one-line
`.env` file changes `api`'s configuration without editing the YAML.

## Sandbox note

As in the other labs, services use `network_mode: host` instead of `ports:`.
`api` listens on port 8001 and `web` (nginx) on port 80 of the sandbox network.

## The stack

```yaml
services:
  api:
    image: python:3.12-alpine
    network_mode: host
    command: ["python3", "-m", "http.server", "8001"]   # a tiny web server
    environment:
      APP_ENV: ${APP_ENV:-dev}       # from .env, default "dev"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8001/"]
      interval: 3s
      timeout: 2s
      retries: 5
  web:
    image: nginx:1.27-alpine
    network_mode: host
    depends_on:
      api:
        condition: service_healthy   # wait for api's healthcheck to pass
```

## Task 1: start it and watch the gate

The folder name matters: it becomes the project name, so containers are named
`stack-api-1` and `stack-web-1`.

```bash
mkdir -p ~/work/stack && cd ~/work/stack
# write compose.yaml (paste the file above, e.g. with cat > compose.yaml <<'EOF' ... EOF)
docker compose up -d
```

Expected output (shortened). Notice `Waiting` then `Healthy` before web starts:

```
 Container stack-api-1  Started
 Container stack-api-1  Waiting
 Container stack-api-1  Healthy
 Container stack-web-1  Started
```

```bash
docker compose ps --format "{{.Service}} {{.State}} {{.Health}}"
```

Expected:

```
api running healthy
web running
```

[[lab-task:1]]

## Task 2: change configuration with `.env`

```bash
cd ~/work/stack
docker compose exec api printenv APP_ENV     # dev (the default)
echo "APP_ENV=staging" > .env
docker compose config | grep APP_ENV         # APP_ENV: staging  (resolved YAML)
docker compose up -d                         # recreates only api
docker compose exec api printenv APP_ENV     # staging
```

[[lab-task:2]]

## Remember

- `condition: service_healthy` + a `healthcheck` = start order that waits for readiness.
- `.env` fills `${VAR:-default}` in the YAML; `docker compose config` shows the result.
- `docker compose up -d` again recreates only what changed.

**Self-check:**

1. What would happen to `web` if `api`'s healthcheck never passed?
2. Which command shows the YAML after variable substitution?
