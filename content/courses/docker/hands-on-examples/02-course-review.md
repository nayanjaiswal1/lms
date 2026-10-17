---
kind: lesson
id_key: docker/hands-on-examples/course-review
course: docker
section: hands-on-examples
section_title: Capstone
section_position: 9
title: "Course Review: Docker on One Page"
position: 1
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
  - 4855175-docker-cheatsheet-r4v2.pdf (Docker CLI Cheat Sheet)
---

## How to use this page

Cover the right-hand column and try to say it out loud before you look. That
act of recalling (not re-reading) is what moves knowledge into long-term
memory. Come back to this page in a few days, then a week later.

## The ideas

| Prompt | Answer |
|---|---|
| Container in one sentence | An isolated Linux process: namespaces (what it sees) + cgroups (what it uses), sharing the host kernel |
| Image in one sentence | A read-only stack of content-addressed layers plus metadata |
| Container vs VM | Shares host kernel (fast, small, weaker isolation) vs own kernel |
| `docker run` = ? | `create` + `start`; lives as long as its main process |
| `stop` vs `kill` | SIGTERM, 10 s grace, SIGKILL vs SIGKILL now |
| Exit 137 / 143 / 127 | Killed (often OOM) / SIGTERM / command not found |
| Copy-on-write | Editing an image file copies it into the container's writable layer first |
| Tag vs digest | Movable pointer vs immutable content hash |
| `save` vs `export` | Image with layers and metadata vs a container's flattened filesystem |
| `RUN` vs `CMD` | Build time, once vs container start, every time |
| `ENTRYPOINT` + `CMD` | Program + default args; run args replace CMD |
| Exec form matters because | SIGTERM reaches your app, not a shell; PID 1 still needs a handler or `--init` |
| Build cache rule | Least-changed first: manifests → install → source |
| Multi-stage build | Build in a fat stage, `COPY --from` only artifacts into a slim final stage |
| BuildKit extras | Cache mounts, secret mounts, multi-platform builds, cache export |
| Default bridge vs user-defined | No DNS by name vs DNS by container name |
| `localhost` in a container | The container itself |
| Volume vs bind mount vs tmpfs | Docker-managed data vs your host path vs RAM |
| `-p` order | `HOST:CONTAINER` (outside:inside) |
| Compose readiness | `depends_on` + `condition: service_healthy` + `healthcheck` |
| `.env` vs `env_file:` | Fills YAML placeholders vs sets container variables |
| Healthy vs running | Check command exits 0 vs process alive; Docker reports, others act |
| Memory vs CPU limit | Over memory → OOM kill (137); over CPU → throttled |
| Least privilege | Non-root `USER`, `--cap-drop ALL`, no-new-privileges, `--read-only`, no `--privileged`, no socket mounts |
| Triage | S-L-I-N: State, Logs, Inspect, iNside |
| Cleanup | `docker system df`, then `prune`; `-a` images, `--volumes` volumes |

## The commands you will type every week

```bash
docker run -d --name api -p 8080:8000 -e KEY=val -v data:/data --restart unless-stopped img:1.0
docker ps -a ; docker logs -f api ; docker exec -it api sh ; docker inspect api
docker build -t img:1.0 . ; docker tag img:1.0 reg.example.com/team/img:1.0 ; docker push reg.example.com/team/img:1.0
docker compose up -d --build ; docker compose logs -f ; docker compose down
docker system df ; docker system prune
```

## What to learn next

- **Kubernetes**: runs these same images across many machines (Pods, Deployments,
  Services, probes instead of `HEALTHCHECK`).
- **CI/CD**: build, scan and push images automatically on every commit
  (GitHub Actions `docker/build-push-action`, GitLab CI).
- **Supply-chain security**: SBOMs (`docker buildx build --sbom=true`),
  provenance attestations, image signing (cosign).
- **Podman**: a daemonless, rootless-by-default Docker-compatible CLI.

## Remember

- Recall beats re-reading. Use the table above as flashcards.
- If you remember only one line per section: a container is a process; an image
  is layers; RUN is build time; volumes keep data; Compose is one file; least
  privilege plus limits plus healthchecks for production; S-L-I-N when it breaks.
