# Labs & Container Execution — Architecture, Security, Scalability & Cost Audit

_Audit date: 2026-10-08. Based on a read of the code (not docs): `backend/internal/labs`, `labkinds`, `labbuild`, `assessment/executor*.go`, `cmd/labproxy`, `jobs/handlers/labs.go`, `k8s/`, `docker-compose.prod.yml`, `render.yaml`, `lab-images/`._

Follow-up verification pass (same day) covered the frontend lab UI, `labauthor`/`labbuild`, every image `entrypoint.sh`/`services.d`, and a test run — see §8.

---

## 1. What runs in a container

Three ways untrusted code executes:

| Feature | Where it runs | Container per user? | Size (CPU / RAM) |
|---|---|---|---|
| Code lab (`lab_type=code`), `/api/labs/run` snippets, quiz coding questions | **Piston** (one shared, privileged service) | No — Piston jails each snippet | shared ~2 CPU / 2–4 GB |
| Terminal / guided / playground / sandbox labs (Linux, Python-web, Node-web, K8s, Docker) | 1 container (or Pod) per session | Yes | 1 CPU / 512 MB default |
| Nested Docker labs (`lab-docker`) | 1 container per session, elevated (sysbox or SYS_ADMIN caps) | Yes | 2 CPU / 1.5 GB / 10 GB disk |
| Debug labs (`lab-debug`: openvscode + Postgres + Redis + Django/FastAPI/React) | 1 container per session **+ a throwaway clean-room container per Check** | Yes, +1 per grade | 2 CPU / 2 GB each |
| Assessment sandbox questions (`executor_sandbox.go`) | Throwaway container per submission | Yes (short-lived) | 1 CPU / 512 MB |
| Lab authoring build/verify (`labbuild`) | Throwaway validation containers | Yes (short-lived) | per image |

### Lab images (`lab-images/`)
- **lab-python-web / lab-node-web** — Ubuntu/Node base, ttyd (web terminal on :7681), app-runner that boots the dev server shown in preview.
- **lab-k8s** — real kube-apiserver + etcd + controller-manager + scheduler, with **kwok** fake nodes. No kubelet, no real containers, so a full `kubectl` experience fits in 512 MB.
- **lab-docker** — `docker:27-dind-rootless`, a Docker daemon inside the container.
- **lab-debug** — heaviest: openvscode-server, Postgres 16, Redis, Node 22, Python 3.12, Django/FastAPI, grader at `/opt/mindforge/grade.sh`.

### Two runtimes, one interface (`labs/runtime.go` → `ContainerRuntime`)
- `LABS_RUNTIME=docker` (default) → `container.go` **shells out to the `docker` CLI** (`os/exec`). In prod compose it reaches the daemon via `tecnativa/docker-socket-proxy`.
- `LABS_RUNTIME=kubernetes` → `runtime_kubernetes.go` creates one Pod per session in namespace `mindforge-labs` via client-go.

Privilege is decided only by `LABS_IMAGE_PROFILES` (operator env) → `ImageProfile` (`profile.go`). Profiles today: standard (zero value), `nested-docker`, `debug-ide`.

---

## 2. Session flow end to end

```
Browser ──POST /api/labs/{id}/sessions──► Backend (Service.StartSession)
  1. load lab; must be published
  2. idempotency key (Redis, 10 min, namespaced org+user)
  3. org image allowlist; elevated images need an explicit allowlist entry
  4. circuit breaker: 3 provision failures / 10 min → lab blocked + admins emailed
  5. TX + pg_advisory_xact_lock(org):
       org concurrent cap (default 20), per-user distinct-lab cap (1 or plan quota),
       monthly lab_hours quota (individual plans)
  6. insert lab_sessions (status=provisioning, expires_at = min(lab, org) duration)
  7. go provisionContainer()   ← goroutine inside the API process
        ├─ claim warm container for this image → re-probe → write ttyd/IDE creds
        └─ else docker run / create Pod → write creds → poll /usr/local/bin/lab-ready
        → seed kind workspace bundle (debug) → run setup_script (root on Docker)
        → UPDATE status=running, container_host="<id>:7681"
        → Redis PUBLISH lab:events:<session> "ready"
Browser ◄── SSE /events (WaitForReadiness) ── "ready"

Browser ──POST /ws-token──► Backend: 5-min HS256 JWT, also stored in Redis (revocable)
Browser ══WS (subprotocol mf-lab,<token>)══► labproxy
   verify JWT + Redis liveness + DB row (owner, running)
   → dial ws://<container>:7681, Basic auth = HMAC(JWT_SECRET, sessionID)
   → relay; record terminal history to Redis; UPDATE last_active_at every 5 s
Preview: /preview/<token>/<port>/ → redirect p<port>-<session>.<preview-domain> → reverse proxy
```

### Lifecycle jobs (in-process cron, `jobs/handlers/labs.go`)
- `lab.expire_sessions` (every minute):
  - 15 min idle → Docker: `docker pause`; K8s: **killed** (no pause primitive).
  - Paused 120 min → snapshot (`git diff` of student work) + kill.
  - `expires_at` passed → kill.
  - Stuck provisioning > 180 + 60 s → reap.
- `lab.cleanup` (every 10 min) — orphan containers with no live session row.
- `lab.warm_pool` — Little's Law per image, `N = λ × W × 2`, scale-to-zero when nobody active, global cap 20.

### Debug lab "Check"
Editable files tarred out → fresh clean-room container → pristine bundle + student overlay → `grade.sh` per mode → kill. Per-process semaphore of 4 (`cleanRoomSem`), 30 s per-session cooldown. Authoring verify uses a Redis-backed global per-org semaphore instead.

---

## 3. Why each piece exists

| Choice | Reason |
|---|---|
| Piston for code labs | No container per run; milliseconds and near-zero cost vs booting a container |
| ttyd in every image | Tiny C binary serving a terminal over WebSocket; no custom in-container agent |
| labproxy as separate service | Long-lived terminal WebSockets survive API redeploys (90 s drain) and scale independently |
| HMAC per-session ttyd password | Containers share a network; without it any student could open another's ttyd |
| Warm pool keyed by image, not lab | Image boot is the expensive part (K8s ~20 s) and identical for all labs on that image; lab setup runs at claim time, so one pool serves every lab |
| Image-owned readiness probe (`/usr/local/bin/lab-ready`) | "Ready" is an image fact; replaced copy-pasted readiness loops in ~20 setup scripts |
| Pause on idle | Stops CPU use, keeps the student's work |
| Clean-room grading | Student controls their container and could tamper with tests/grader |
| kwok in lab-k8s | Real API behaviour, fake nodes; full kubectl lab in 512 MB |
| sysbox / RuntimeClass for nested Docker | Docker-in-Docker without `--privileged` |
| `ImageProfile` from env only | Lab content can never decide privilege |

---

## 4. Security findings (ranked)

### Critical

**C1. Docker socket proxy is still host root.** `docker-compose.prod.yml` sets `CONTAINERS=1, POST=1, EXEC=1`. Socket-proxy filters URL paths, not request bodies, so code execution in the backend → `docker run --privileged -v /:/host` → host owned — and that host also runs Postgres/Redis/MinIO.
_Fix:_ separate lab host; replace the socket with a small **lab-agent** exposing a typed API (`Start(image ∈ allowlist)`, `Exec`, `Kill`, fixed flags, mTLS). It can reuse `DockerContainerService` nearly unchanged.

**C2. K8s lab Pods have no egress NetworkPolicy** (`k8s/base/networkpolicy-labs.yaml` says so). A student Pod can reach:
- cloud metadata `169.254.169.254` → node IAM credentials on EKS/GKE;
- `postgres.mindforge:5432`, `redis.mindforge:6379` — the `mindforge` namespace has no NetworkPolicy, only passwords protect them;
- the whole internet (mining, spam, attacks from your IP).
_Fix:_ default-deny egress; deny `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`; allow public internet only for labs that need it.

**C3. `mindforge-labs` namespace is Pod Security `privileged`** (because Piston lives there), and the backend ServiceAccount can `create pods` there → compromised backend creates a privileged Pod → node root.
_Fix:_ move Piston to its own namespace; set `mindforge-labs` to `restricted`/`baseline`; add `runAsNonRoot: true` to the lab Pod spec (not set today).

**C4. labproxy holds the platform `JWT_SECRET` and full DB credentials while sitting on the lab network.** `JWT_SECRET` is the same secret `auth/jwt.go` uses for user login tokens. labproxy compromise → forge an admin JWT for any user.
_Fix:_ separate `LAB_TOKEN_SECRET` for ws-tokens + ttyd/IDE HMAC; labproxy DB role limited to `SELECT` on `lab_sessions`/`lab_definitions`/`lab_build_variants` and `UPDATE lab_sessions.last_active_at`.

### High

**H1. Docker networking defaults are open.** `LABS_NETWORK_PER_SESSION` and `LABS_NETWORK_INTERNAL` default to `false` and prod compose doesn't set them → every student container on one shared bridge with full internet egress, able to reach other students' **preview ports** (dev servers have no auth; only ttyd does).
_Fix:_ `LABS_NETWORK_PER_SESSION=true` now (config only); add host egress filtering.

**H2. No disk quota on the Docker runtime.** `ContainerDiskGB=3` / `DebugIDEContainerDiskGB=5` are documented, not enforced. One `dd if=/dev/zero` fills the host disk and takes down every session (and Postgres if co-located).
_Fix:_ lab host on XFS with pquota + `--storage-opt size=3G`, or a dedicated `/var/lib/docker` partition.

**H3. Piston unpinned and privileged.** `image: ghcr.io/engineer-man/piston` (compose and `k8s/base/piston.yaml`) has no tag/digest — any upstream push lands in prod with privileged rights.
_Fix:_ pin by digest.

**H4. setup_script runs as root on Docker** (`ExecSetup --user root`). Any org's instructor can run root inside the container. Caps are dropped so it isn't host root, but it's another reason the lab host must not be the app host. K8s runs setup as the image user — the runtimes diverge here.

### Medium
- ws-token appears in the preview URL path (`/preview/<token>/...`) → can leak via access logs/Referer. Short-lived (5 min) and revocable; strip from logs.
- `/api/labs/run` (Piston) only requires login + 2 s cooldown; no plan/entitlement gate → unlimited free code execution. Add a daily quota.
- `connLimiter` (5 terminals/user) and `cleanRoomSem` (4) are per-process; with 2 replicas they become 10 and 8. Fine as node protection, not as global limits.

---

## 5. Scalability findings

1. **The API process is the orchestrator.**
   - Provisioning runs as goroutines in the API; a restart loses them (reaper cleans up after ~4 min).
   - Every file read/write/list, ports, Verify and resources call **forks a `docker` CLI process** that then calls the proxy. Saves are manual, but port polling (every 5 s per open page, §8 M1) alone is ~100 forks/s at 500 sessions.
   - _Fix:_ Docker Go SDK, or better, the lab-agent from C1.
2. **Docker runtime is single-host.** No placement across 2+ hosts — hard ceiling of ~100 standard or ~25 debug sessions per 64 GB box (§6). `container_host` already stores the host, so multi-host mostly needs "pick least-loaded agent".
3. **Heartbeat writes to Postgres.** labproxy does `UPDATE lab_sessions SET last_active_at=now()` every 5 s per open terminal → 1,000 terminals = 200 writes/s. On Neon it also prevents compute auto-suspend (cost 24/7).
   _Fix:_ Redis `SET` with TTL read by the expire job, or batch-flush to DB every 60 s.
4. **Debug labs double peak resources.** Each Check boots a second 2 CPU / 2 GB container for 30–90 s; 25 students clicking Check → 25 extra containers.
   _Fix:_ small warm pool of clean-room graders (pool code already supports any image) + the Redis semaphore `labbuild` already uses.
5. **K8s can't pause → idle sessions killed at 15 min** (Docker keeps them paused 2 h). Different UX per runtime.
6. **K8s requests = limits** (Guaranteed QoS) → no overcommit; a 1 CPU / 512 MB lab reserves a full CPU while the student reads instructions. 3–5x waste from sizing alone.
7. Minor: K8s `List()` lists every Pod in the namespace with no label selector; `waitForRunning` polls GET every 500 ms (a watch is cheaper). Fine below a few thousand Pods.

### Current prod reality (confirm)
`render.yaml` runs the backend on **Render free** with no `LABS_RUNTIME`, no Docker daemon and no `PISTON_URL`. By that file, container labs and code runs **cannot work in current prod**: start fails; run returns "executor unavailable". Render free also sleeps after idle, so in-process cron (`lab.expire_sessions`) doesn't run while asleep — containers would never be reaped even if they could start.

---

## 6. Resources & cost

### Capacity per host (64 GB RAM, 8c/16t, 8 GB reserved for OS + Docker + labproxy)

| Lab type | Limit per session | Concurrent per box (RAM-bound) |
|---|---|---|
| Linux / Python-web / Node-web | 1 CPU / 512 MB | ~100 (CPU overcommitted; students mostly idle) |
| lab-k8s (apiserver + etcd) | 1 CPU / 512 MB | ~60 (boot is CPU-heavy) |
| Nested Docker | 2 CPU / 1.5 GB | ~30, needs dedicated box |
| Debug (+ Check spikes) | 2 CPU / 2 GB | ~22–25 |

**Cost is driven by peak concurrent sessions, not total users.** At ~10% of active students in a lab simultaneously, one box serves ~1,000 active students on standard labs or ~250 on debug labs.

### Price comparison (2026)

| Option | Approx. monthly | Per standard lab-hour |
|---|---|---|
| **Hetzner dedicated (AX class) / Server Auction, 64 GB** | ~€50–90 (≈ ₹5–9k); bare metal rose only ~15–21% in 2026 | ≈ ₹0.1 or less at decent utilisation |
| Hetzner Cloud CCX/CPX | up 113–204% since June 2026 — avoid for labs | much higher |
| Hetzner Cloud CAX (ARM) | rose ~33% | cheap, but images are amd64-only (`TARGETARCH=amd64`) |
| Managed K8s (EKS/GKE) | ~$73/mo control plane + on-demand nodes (~$250–300 per 32 GB node) | 3–5x bare metal |
| E2B / Daytona | ~$0.050/vCPU-hr + $0.016/GB-hr | 1 CPU + 0.5 GB ≈ $0.058/hr ≈ ₹5/hr; debug ≈ $0.13/hr |
| Fly Machines | per-second; stopped machines pay rootfs only ($0.15/GB-month) | in between |

**Verdict:** for long, mostly-idle interactive sessions with heavy images, bare-metal Docker is ~30–50x cheaper than per-second sandbox providers. Managed K8s only pays off beyond ~5 hosts, and even then k3s on Hetzner bare metal beats EKS/GKE. Verify current AX prices on Hetzner's own page before budgeting — third-party sources disagree.

---

## 7. Cost-reduction & hardening plan

**Phase 0 — config / small code (this week)**
1. `LABS_NETWORK_PER_SESSION=true`; pin Piston by digest (H1, H3).
2. Heartbeats → Redis (scalability #3; lets Neon auto-suspend).
3. `IdleReapMinutes` 120 → ~30. Paused containers hold RAM; the `git diff` snapshot already preserves work. Frees ~2–4x RAM at peak.
4. Plan quota on `/api/labs/run`.

**Phase 1 — one dedicated lab host (~₹5–9k/month)**
5. App stays on Vercel + Render (paid tier so cron doesn't sleep) + Neon. Lab host runs lab-agent, labproxy, Piston and containers (fixes C1, C4; Piston off the app host).
6. XFS + pquota so disk quotas are enforced (H2).
7. Pre-pull every lab image on the host — pull time is the worst cold start.

**Phase 2 — when one box is full**
8. Add hosts; backend picks the agent with most free RAM. Stay off K8s until ~5 hosts.
9. If moving to K8s: requests ≈ 25% of limits, egress policy (C2), Piston out of the namespace (C3).

**Debug labs (most expensive type)**
10. Warm pool of clean-room graders, globally capped.
11. Optional trade-off: Postgres + Redis + VS Code + app in one 2 GB container makes debug labs ~4x other labs. A shared Postgres with a database per session saves ~300–400 MB each but weakens isolation — decide deliberately.

### Remediation status (C1, H1, H2, H4)

- **C1 lab agent.** `backend/cmd/labagent` owns the Docker socket on the lab host; the backend uses `labs.AgentClient` (selected when `LABS_AGENT_URL` is set) over mTLS. The agent API is typed (start / kill / exec / exec-capture / running / pause / unpause / list), accepts only images in `LABAGENT_ALLOWED_IMAGES`, rejects unknown JSON fields, derives every Docker flag itself via `DockerContainerService`, and refuses exec/kill on containers that are not `mindforge-lab-`/`warm-`/`validate-` sandboxes. `docker-compose.prod.yml` no longer has a socket proxy or lab networks; `docker-compose.labhost.yml` runs the agent and labproxy (labproxy must be co-located with the lab bridges). Residual: the lab host now holds labproxy's least-privilege DB/Redis credentials; keep that Postgres role minimal and the host firewalled to the app host only.
- **H1 isolation.** `LABS_NETWORK_PER_SESSION` defaults to true. `scripts/labhost-egress.sh` installs DOCKER-USER/INPUT rules dropping lab-bridge traffic to RFC1918, CGNAT, 169.254.0.0/16 (metadata), other lab bridges and the host itself. `LABS_NETWORK_INTERNAL` (no egress at all) exists but is not per-lab selectable, so it stays off by default.
- **H2 disk quota.** Containers get `--storage-opt size=<DiskGB>G` (3 GB standard, 5 debug-ide, 10 nested) when `LABS_STORAGE_QUOTA_ENABLED` is on. Requirement: Docker `overlay2` on a dedicated XFS filesystem for `/var/lib/docker` mounted with `pquota` (`/etc/fstab`: `... /var/lib/docker xfs defaults,pquota 0 0`; the filesystem must be freshly formatted or remounted with the option, then restart Docker). The agent probes this once at startup by creating a throwaway container with `--storage-opt size=1G` and exits with an error if Docker rejects it; it never silently runs unlimited.
- **H4 setup user.** Docker `ExecSetup` no longer passes `--user root`; setup runs as the image user, same as Kubernetes. All lab images end in `USER labuser`.

---

## 8. Verification pass — frontend, authoring pipeline, images, tests

### New findings

**H5. Test sessions bypass every cap.** `StartSession(isTest=true)` skips the org concurrency cap, the per-user distinct-lab cap, the monthly `lab_hours` quota and the provision circuit breaker. Two entry points pass `isTest=true`:
- `POST /api/library/{kind}/{id}/try` (`library/service.go`), guarded only by `RequireOrgRole(owner, admin, instructor)`;
- `POST .../builds/{id}/preview-session` (`labbuild/publish.go`), guarded by the compose permission.

The only remaining limit is one active session per (user, lab). So an instructor can run one session for every platform-visible lab at once — a debug lab is 2 CPU / 2 GB each. Org creation is self-serve (`POST /api/orgs` → onboarding → `Activate`, owner role, no payment gate found), so this is likely reachable by any signed-up user.
_Fix:_ count test sessions against their own small cap (e.g. 2 per user, 5 per org) inside the same advisory-locked transaction.

**M1. Port polling drives `docker exec` load.** `hooks/use-lab-ports.ts` polls `GET /ports` every 5 s per open lab page; each poll is a `docker exec` (fork of the CLI). 500 open sessions ≈ 100 exec forks/s from polling alone. File saves are manual (`use-lab-files.ts` `save()`), not autosave — so editor traffic is lighter than §5 assumed.
_Fix:_ poll every 15–30 s, or have the image write listening ports to a file that the existing terminal channel or a cheap exec reads only when the preview pane is open.

**M2. Image supply chain is mostly unverified.** Only the Node tarball in `lab-debug` is sha256-checked. Downloaded without checksums: ttyd (`lab-node-web`), kubectl / kube-apiserver / controller-manager / scheduler / etcd / kwok / helm and the kwok stage YAMLs from `raw.githubusercontent.com` (`lab-k8s`), openvscode-server (`lab-debug`). All base images are pinned by tag, not digest.
_Fix:_ add `sha256sum -c` per download and pin base images by digest.

**M3. `labkinds` and `labbuild` have no test files.** These hold the grader trust boundary (`debug_compose.go` value-slot rules, clean-room bundle handling) and the build/verify pipeline.

**Unverified risk:** `lab-k8s` runs etcd + kube-apiserver + controller-manager + scheduler + kwok under the default 512 MB unless `LABS_IMAGE_PROFILES` maps it to a bigger profile (no compose file does). Possible OOM under real use; needs a measured run.

### Confirmed good (checked, no action)
- Every image waits for `~/.mf-ttyd-cred` before starting ttyd; `lab-debug`'s IDE waits for `~/.mf-ide-cred` and uses `--connection-token-file`. No unauthenticated shell/IDE window, including warm containers.
- Debug image: grader under `/opt/mindforge` is root-owned and `go-w`; Postgres (`trust` auth) and Redis bind 127.0.0.1 only. The student container receives only the workspace bundle (`seedKindWorkspace` loads with `withGrader=false`); hidden tests reach only the clean-room container.
- `lab-k8s` apiserver binds 127.0.0.1 with `AlwaysAllow` — reachable only inside the sandbox.
- Terminal ws-token travels in the WebSocket subprotocol, not the URL (`use-lab-terminal.ts`). Only the preview path carries it in the URL (already noted).
- Auth cookies (`access_token`, `refresh_token`, `csrf_token`) have no `Domain` attribute, so preview subdomains never receive them; labproxy also strips `Domain=` from preview `Set-Cookie`.
- Authoring: the build image comes from the lab kind (`kind.Image()`), never from author input; renders run inside validation sandboxes; builds are capped at 10/user/day and verify runs by a Redis-backed global per-org semaphore.
- Preview iframe uses `sandbox="allow-scripts allow-same-origin allow-forms"`; safe because it is served from a separate per-session origin.
- App dev servers inside images bind 0.0.0.0 without auth — confirms **H1** (any container on the shared bridge can reach them).

### Test run (2026-10-08, Windows, Docker daemon not running)
- `go test ./cmd/labproxy/` — pass.
- `go test ./internal/labs/` — all 44 non-DB tests pass. 3 DB-backed tests (`TestSessionBuildID_RepublishDoesNotRepointInFlightSession`, `TestGetLabByModuleID_*`) fail only because testcontainers cannot reach Docker.
- No container was started, so image boot times, real RAM per image and the lab-k8s 512 MB question remain unmeasured.

---

## Sources
- [Northflank — Hetzner price increases 2026](https://northflank.com/blog/hetzner-cloud-server-price-increases)
- [wz-it — Hetzner June 2026 increase](https://wz-it.com/en/blog/hetzner-price-increase-june-2026-cpx-ccx-alternatives/)
- [webhosting.today — Hetzner CCX/CPX increases](https://webhosting.today/2026/06/18/hetzners-price-increases-reached-209-the-30-headline-applied-to-a-different-tier/)
- [Netcup blog — Hetzner third hike](https://netcupvoucher.com/blog/hetzner-third-price-hike-june-2026)
- [SaaSCity — buy hardware vs cloud](https://saascity.io/blog/hetzner-price-hikes-2026-buy-hardware-vs-cloud)
- [Morph — E2B pricing](https://www.morphllm.com/e2b-pricing)
- [Fly.io — AI sandbox pricing compared](https://fly.io/learn/ai-sandbox-pricing/)
- [Costbench — Daytona pricing](https://costbench.com/software/ai-code-execution/daytona/)
- [Fly.io billing docs](https://fly.io/docs/about/billing/)
