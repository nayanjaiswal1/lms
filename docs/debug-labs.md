# Debug Labs — "Real Debugging" on broken systems (design draft)

> **Status: design draft, not built**, except **Phase 1c-i/1c-ii (lab-authoring engine core, then renderer + build/verify pipeline + publish; 2026-09-30, see §10)**, **Phase 1b (student frontend, 2026-09-30, see §10)** and **Phase 1a (debug-lab runtime: migration 045, `labkinds` plugin seam, `lab-images/lab-debug`, clean-room grader, private bundles, student endpoints; 2026-09-30, see §10)**, **Part 3 "Add from library" (Phase A)** and **Part 1 §10 Phase 0 — both implemented 2026-09-29**: migration `044_course_library.sql`, `backend/internal/library`, the fork-lab-link fix, and the picker/library-page frontend described in L0-L6 below (Phase A); the ttyd HMAC auth fix, `ImageProfile.Elevated`, the preview-traffic heartbeat, and the generic lab hint endpoint + `HintDrawer` (Phase 0, see §10 below) are all in the working tree. Parts 1 (beyond Phase 0), 2, and B (the debug-lab builder) remain design draft. Open questions at the bottom need answers before Phase 1 starts.

A student gets a small, realistic, **broken** Django / FastAPI / React app inside a browser VS Code (openvscode-server) and debugs it like at work: read the ticket → reproduce → logs/tracebacks → breakpoints → root cause → fix → prove the fix → write a short incident note. Built as a new `lab_type = 'debug'` on top of the existing lab system (`docs/labs.md`), which already provides ~70% of what's needed: per-student Django/FastAPI/React sandboxes (`mindforge/lab-python-web:3.12`, `mindforge/lab-node-web:22`), a supervised dev server (`lab-images/shared/app-runner.sh`), an authenticated WebSocket-capable per-port preview proxy (`backend/cmd/labproxy/preview*.go`), batch Run/Submit grading (`service_sandbox.go` → `finalizeTaskPass`), pinned version snapshots, warm pools, idle-pause, metering, and canonical-markdown authoring (`kind: lab`). `content/courses/interview-prep-45/backend-fastapi/04-lab-async-aggregation.md` is already close to a debugging lab.

**Genuinely new:** (1) an IDE sandbox image (openvscode-server + Postgres + Redis + git), (2) a scenario bundle (repo with real git history streamed into the workspace + a hidden grader bundle), (3) a hardened grader (`grade.sh`: hidden tests + behavioral probes), (4) an AI-graded root-cause write-up task, (5) ~~the lab AI hint endpoint (documented as labs Phase 3 but never built — no hint handler in `backend/internal/labs/routes.go`)~~ **built as part of Phase 0, 2026-09-29** — see §10 below, (6) a `DebugWorkspace` frontend. **Django ships first.**

## Generic lab-kind architecture (supersedes the `debug_*` names in Parts 1-2)

The platform will have several composed lab types ("debug" now; "learn"/build-a-feature and others later), so composition is generic and **debug is the first plugin**, not a debug-only stack. Everywhere Parts 1-2 say `debug_blocks`, `debug_recipes`, ... read the generic names:

| Parts 1-2 name | Generic (migration 045) |
|---|---|
| `debug_blocks` / `debug_block_versions` | `lab_blocks` / `lab_block_versions` (`kind`, `stack` are TEXT validated by Go, not DB CHECKs; payload in `payload_key`/`payload_sha256`) |
| `debug_recipes` | `lab_recipes` (+ `lab_kind TEXT NOT NULL`, `target_placement JSONB`) |
| `debug_scenario_builds` | `lab_builds` (status CHECK kept: closed lifecycle) |
| `debug_scenario_variants` | `lab_build_variants` (generic columns + `payload JSONB` for kind fields; bundles are `*_bundle_key`/`*_bundle_sha256`, see below) |
| `debug_block_usages`, `debug_ai_drafts` | `lab_block_usages`, `lab_ai_drafts` |
| `lab_debug_scenarios` | `lab_catalog_meta (lab_id PK, stack, category, difficulty, skills)` for every lab type + `lab_definitions.build_id` linking a lab to its `lab_builds` row |
| task `grader='rootcause_review'`, `interaction_type='rootcause_review'` | `'writeup_review'` (generic "written reflection vs rubric") |
| `POST .../rootcause-review`, `GET /api/labs/debug/catalog` | `POST .../writeup-review`, `GET /api/labs/catalog?kind=&stack=&category=&difficulty=` |

For `lab_kind='debug'` the variant `payload` is `{root_cause_md, fix_diff, rubric, hint_ladder, baseline_commit}`.

**`lab_type` vs `lab_kind` (decision: two fields).** `lab_definitions.lab_type` is the closed runtime/workspace shape (DB CHECK: it selects image/profile and the frontend workspace, both genuinely closed and needing code for each new value). `lab_recipes.lab_kind` is the open authoring-plugin identity resolved by the Go registry (no DB CHECK: adding a kind needs no migration). They are 1:1 for `debug`, and the registry is keyed by `lab_type` at runtime because that is what every session already carries; a future kind sharing the debug IDE shape with different composition rules just registers under its own name.

**Plugin interface** (`backend/internal/labkinds/kind.go`), one interface, one registry (`registry.go`, `labkinds.Get/Register`), one implementation (`debug.go`, self-registered in `init()`):
`Name()`, `BlockKinds()`, `Tasks() []TaskTemplate`, `GradeModes()`, `VerifyMatrix() []VerifyRun`, `SessionPayload(*VariantView)`, `Debrief(*VariantView)`, `HintContext(*VariantView)`, `WriteupFilePath()`, `WriteupRubric(*VariantView)`. A future kind adds one file implementing `Kind` (plus a `lab_type` CHECK value if it needs a new workspace shape); `labs` itself does not change. The generic grader (`/opt/mindforge/grade.sh` + `grader/run_grade.py`) takes its modes from the grader bundle's `grader.json`, not from Go or bash constants.

**Bundles live in the private object store, not the DB.** Content-addressed keys `lab-bundles/<sha256>.tar.gz` in a **private** bucket (`storage.PrivateStore`, `MINIO_PRIVATE_BUCKET`), written before the DB row commits, immutable, sha256-verified on download, orphan-GC'd by `lab.bundle_gc`. `storage.MinioClient.EnsureBucket` makes its bucket world-readable (`s3:GetObject` for `Principal: *`), so bundles must never use that client; the private client never sets a policy and exposes no presigned URLs. This supersedes the "bundles live in the DB" paragraph in §8/B5.

## Pre-existing problems this feature must fix first

- ~~**Security hole, Docker runtime:** all lab containers share the `mindforge-labs` bridge and ttyd starts with no credential (`lab-images/shared/entrypoint.sh`: `exec ttyd -W -p 7681 bash`). The per-session container token described in `docs/labs.md` ("Proxy ↔ Container Channel Security") isn't implemented anywhere in `backend/internal/labs` or `backend/cmd/labproxy`. Student A can open a WebSocket to student B's container on :7681 and get a shell. An IDE port would be a second shell with the same hole. k8s is covered by `k8s/base/networkpolicy-labs.yaml`; Docker isn't.~~ **Fixed (Phase 0, 2026-09-29)** — see `docs/labs.md` "Proxy ↔ Container Channel Security".
- ~~`ImageProfile` treats any non-empty `Name` as elevated (`backend/internal/labs/profile.go`, incl. the k8s RuntimeClass requirement). A resource-only "bigger" profile needs an explicit `Elevated bool`.~~ **Fixed (Phase 0, 2026-09-29)** — `Elevated bool` added, `KubernetesContainerService.startPod` keys off it instead of `Name`.
- Exec passes scripts as argv (`container.go` `execAs`), ~128 KB max per arg, and `files:` are baked into `setup_script` as heredocs (`render_lab.go` `buildSetupScript`). A realistic repo with `.git` won't fit, so bundles must stream through the existing `ExecStdin`. **Still open — Phase 1 work, not part of Phase 0.**
- Preview requests re-validate a 5-minute token (`preview_host.go`); the app preview gets away with iframe reloads, an IDE can't. Needs a silent cookie refresh. **Still open — Phase 1 work, not part of Phase 0.**
- ~~Only the terminal relay updates `last_active_at` (`proxy.go:164`). A student working only in the IDE gets idle-paused after 15 min.~~ **Fixed (Phase 0, 2026-09-29)** — preview passthrough (HTTP + WS) now heartbeats too, via `ProxyHandler.heartbeatPreview`; see `docs/labs.md`. (The IDE port itself is still Phase 1 — this fix covers today's app preview, and the same `previewTarget` choke point the IDE's own preview-port traffic would route through once Phase 1 ships.)

## 1. Fit with the existing lab system

| Area | Reuse as-is | Extend | New |
|---|---|---|---|
| Session lifecycle (start / readiness SSE / reset / end / expire / idle-pause / metering) | `service.go`, jobs | — | — |
| Container runtime (Docker + k8s) | `ContainerRuntime` | `ImageProfile.Elevated`; new `debug-ide` profile (2 CPU / 2 GB / 5 GB) | — |
| Preview proxy | subdomain-per-port, WS pass-through | heartbeat on preview traffic; IDE connection-token cookie injection; silent cookie refresh | — |
| Grading | `SubmitAll` → `finalizeTaskPass`, scoring, completion, unlock | `VerifyTask` → `verifyDebugTask` branch; per-type timeout/cooldown | `/opt/mindforge/grade.sh`; grader bundle via stdin |
| Authoring | `kind: lab`, coursegen, deterministic IDs, publish/snapshot | `LabSpec.Debug`; `_scenario/` asset dir; bundle builder | `scripts/test-debug-labs.py` harness |
| AI | `internal/ai`, `lab_ai_interactions` cache | interaction type `rootcause_review` | hint endpoint (generic, all labs) |
| Frontend | readiness wait, timer, preview pane, checklist, sandbox tests panel | `lab-workspace-content.tsx` debug branch | `DebugWorkspace`, IDE frame, ticket panel, hint drawer, debrief, catalog |

## 2. Sandbox / IDE environment

**One image for all stacks — `mindforge/lab-debug:1`** (`lab-images/lab-debug/Dockerfile`), so one warm pool serves every scenario; scenario work happens at claim time.

- Ubuntu 24.04, Python 3.12, Node 22, `postgresql-16`, `redis-server`, `git`, `ttyd`, pinned **openvscode-server** (`--connection-token-file`).
- Python: Django 5 + DRF + django-debug-toolbar, FastAPI/uvicorn, SQLAlchemy 2 + asyncpg + psycopg, Alembic, pydantic 2 + pydantic-settings, httpx, celery, redis-py, **debugpy**, pytest + pytest-django + pytest-asyncio. Offline wheelhouse `/opt/wheels` for version-bump scenarios (e.g. pydantic 1.10).
- Node: baked Vite/React scaffold + vitest/jsdom/@testing-library in root-owned `/opt/scaffold`.
- VS Code extensions baked from Open VSX (Python, debugpy; js-debug is built in). Marketplace disabled at runtime (no egress).
- New image-local `app-runner` supervises every `.lab/services/*.sh` (postgres, redis, app, worker, stub services, IDE), logging to `/var/log/mindforge-lab/<svc>.log`. No docker-compose in the sandbox (nested Docker is operator-gated and off).
- Postgres as `labuser`, `fsync=off`, `shared_buffers=32MB`, `pg_stat_statements` on (grader counts queries).
- `debug-ide` profile: 2 CPU / 2048 MB / 5 GB, **not elevated**, mapped via `LABS_IMAGE_PROFILES=mindforge/lab-debug:1:debug-ide`. `max_duration` 90 min (org cap 120). Idle-pause stays 15 min but IDE WS traffic counts as activity.

**Isolation:** existing `--cap-drop ALL`, no-new-privileges, non-root `labuser`, isolated network, k8s NetworkPolicy. No egress (deps baked in; `lab_egress_rules` empty; SSRF denylist untouched). IDE port protected by `HMAC(LAB_JWT_SECRET, session_id)` written into the container at claim; labproxy recomputes it and injects `vscode-tkn`, so nothing is stored and the browser never sees it. **Phase 0 applies the same to ttyd.**

**Webview CDN:** VS Code webviews load from `*.vscode-cdn.net` (browser traffic, not sandbox). Set `webviewContentExternalBaseUrlTemplate` in `product.json` to self-host through labproxy.

**Embedding:** IDE is just another preview port (`ide_port: 3000`) → `/preview/{token}/3000/` → `p3000-<sid>` subdomain. Every 4 min a hidden iframe hits `/__mf/preview-auth?t=<fresh>&next=/__mf/ok` on the IDE origin to refresh the cookie without reloading VS Code. "Pop out IDE" button opens a new tab.

**Seeding:** `prepareLabEnvironment` debug branch streams `workspace_bundle` (tar.gz) → `tar -xzf - -C /home/labuser/work` via `ExecStdin` as labuser. `setup_script` then runs a readiness probe. `.lab/services/app.sh` migrates, seeds (`generate_series`, ~2 s for 500k rows), and starts the app **under debugpy**, autoreload off (`python -m debugpy --listen 5678 manage.py runserver --noreload`). Setup budget ≤ 30 s, enforced by the harness.

**Workspace contents:** `TICKET.md` (brief), `INCIDENT.md` (postmortem template: Symptom / Reproduction / Root cause / Fix / Prevention), `.vscode/launch.json` (attach to app on debugpy :5678, debug pytest, debug vitest), `.vscode/tasks.json` (restart app, tail logs, run tests, reset DB), `logs/` → `/var/log/mindforge-lab`, real git history (`git log` / `git bisect` work).

**React:** student's own browser DevTools on the preview iframe (source maps, React DevTools) + vitest under VS Code's JS Debug Terminal.

## 3. Authoring & storage

Canonical markdown `kind: lab`, `lab_type: debug`; assets in a sibling `_scenario/` (coursegen's WalkDir skips `_`-prefixed dirs).

```
content/courses/production-debugging/django/dj-perf-01-order-list/
  lab.md                      # kind: lab, lab_type: debug; body = student-visible ticket
  _scenario/
    app/                      # good baseline repo (runnable locally by authors)
    commits/*.patch           # git format-patch, replayed with git am → real history; one commit injects the fault
    fix.patch                 # reference fix (hidden: CI, post-completion debrief, hint-leak filter)
    cheats/*.patch            # known bad "fixes" that MUST fail grading
    grader/tests/{symptom,regression}/   # hidden pytest/vitest
    grader/probes/*.py        # behavioral probes vs the live server (take --seed)
    grader/fixtures/          # grader-owned seed data
```

`debug:` frontmatter (`canonical/types.go` → `LabSpec.Debug`): `stack` (django|fastapi|react|fullstack), `category`, `difficulty`, `skills[]`, `app_ports`, `ide_port`, `protected: [globs]`, `root_cause` (md), `rubric: {key_points[], misconceptions[]}`, `hints: [l1,l2,l3]`, `baseline_commit_subject`.

Coursegen builds a **deterministic** tar.gz (fixed mtimes, sorted entries, pinned `GIT_*_DATE`) so reseeds stay idempotent, records the baseline commit hash and protected-file sha256 manifest, and enforces size caps (workspace ≤ 2 MB, grader ≤ 512 KB).

**Standard tasks per debug lab** (tasks already carry points → partial credit):

| # | Task | Required | Grader |
|---|---|---|---|
| 1 | Symptom resolved | yes | `grade.sh symptom` |
| 2 | No regressions | yes | `grade.sh regression` |
| 3 | Regression test proves the fix | optional (points) | `grade.sh student-test` |
| 4 | Root-cause write-up (`INCIDENT.md`) | optional (points) | AI rubric |

Completion + section unlock need 1 and 2. Task 4 gives diagnosis credit even if the fix isn't finished.

## 4. Verification

**Primary signal:** behavioral probes against the student's **live, restarted** dev server using **randomized per-Check data**. Hidden in-process tests are secondary (unit-level, query counts). Protected-file integrity is a precondition.

`verifyDebugTask` streams the pinned `grader_bundle` via `ExecStdin` to root-owned `/opt/mindforge/grade.sh <mode> --seed <server-random>`, run as labuser:

1. **Integrity:** sha256 of `protected` files vs manifest; reject `sitecustomize.py`, `usercustomize.py`, `*.pth` in the workspace and a replaced `node_modules` symlink.
2. **Restart** the app via the supervisor and wait for readiness (no stale process).
3. **Fresh DB** `grade_<seed>`: workspace migrations + grader fixtures with seeded random values (student edits to dev DB/seed are irrelevant).
4. **In-process tests:** `python -I -m pytest --noconftest -p no:cacheprovider --rootdir=$TMP`; React via vitest from `/opt/scaffold` with a grader config outside the workspace.
5. **Probe kinds** (used as codes in the catalog):
   - **P** HTTP behavior
   - **Q** query count via `pg_stat_statements` / `EXPLAIN` without Seq Scan
   - **C** N concurrent requests + invariant check
   - **M** migrate from clean DB *and* from a seeded "prod snapshot" pre-state, plus `makemigrations --check` / `alembic check`
   - **L** latency/lock (e.g. `/health` p95 while a slow call runs; writer max latency during a migration)
   - **H** header/contract (CORS preflight, Set-Cookie attributes, JSON schema)
   - **T** hidden test
6. **Output:** JSON with check names and **author-written** failure messages only (no test source, no expected values). Temp files removed by trap. Budget 90 s (`DebugGradeTimeoutSeconds`), 30 s cooldown per session, existing bounded exec semaphore.

**`student-test` mode:** `git worktree add` the baseline commit (content-addressed, can't be forged), copy in the student's added/changed tests; they **must fail** on the broken baseline **and pass** on the student's workspace.

| Cheat | Defense |
|---|---|
| Delete/edit the failing visible test | Grading tests are hidden, streamed only at Check; visible tests are `protected` |
| Special-case the repro input | Randomized seed data per Check + held-out tests |
| try/except or empty 200 | Probes assert correct data; regression suite asserts full behavior |
| Delete the feature / revert the bad commit | Fault commit also ships a feature the regression suite checks; plain revert fails |
| Detect test env (`"pytest" in sys.modules`) | Probes hit the supervised server, not under pytest |
| Tamper with runner (conftest, sitecustomize, node_modules) | `-I`, `--noconftest`, root-owned runners, startup-hook rejection |
| Edit fixtures / dev DB | Grader builds its own DB from its own fixtures |
| Timeouts / sleep hacks | Latency upper bounds + correctness checks |
| Spam Check | Cooldown + existing `attempts` counter |

**Clean-room grader (implemented, replaces the old "residual risk" paragraph).** A Check no longer runs anything in the student's container. `labs.GradeInCleanRoom` starts a separate short-lived `mindforge-validate-grade-*` sandbox from the same image, seeds it with the pristine workspace bundle, overlays only the student's editable regular files (copied out with the trusted `ExecCapture`: `.git`, dependency dirs, symlinks and `protected` manifest paths are never copied), streams the grader bundle to `grade.sh`, and destroys the sandbox. Hidden tests and fixtures never exist in the student's container, so watching `/tmp` during a Check reveals nothing, and tampering with runners, `pg_stat_statements` or Postgres in their own container cannot influence grading. What remains of the old anti-tamper list is cheap defense in depth inside the clean room (`python -I`, `--noconftest`, startup-hook and protected-manifest checks). Remaining risks: a student can still craft editable files that misbehave inside the grader sandbox (bounded by the 90 s timeout, the sandbox's own limits and the per-session cooldown), and clean-room start latency (cold start, no warm-pool reuse yet) counts against the Check.

**CI proof per scenario** (`scripts/test-debug-labs.py`, modeled on `test-k8s-labs.py`): broken repo → task 1 fails, task 2 passes; with `fix.patch` → all pass; every `cheats/*.patch` fails; setup ≤ 30 s. A scenario that hasn't passed the harness is unverified.

## 5. Debugging experience (v1 scope)

**In v1:** ticket entry point (reporter, severity, user complaint, Sentry-style trace or slow-query log excerpt, "what support tried", optional red herring); running app with seed data (production-sized where it matters); preview pane; logs in the IDE; debugpy attach (Python) / vitest debug + DevTools (React); real git history for `git bisect`; `INCIDENT.md` template; stub downstream services with a fault-control endpoint (latency, 500s, contract version); post-completion debrief (root cause, reference fix vs student diff, prevention).

**Out of v1:** real Sentry/APM UI, Playwright/real-browser grading, multi-container compose, collaborative debugging, Pylance.

## 6. AI assistance

Builds the generic hint endpoint labs Phase 3 never shipped: `POST /api/labs/sessions/{id}/tasks/{taskId}/hint` — 3 levels, `hints_used` incremented atomically, `cache_key = sha256(session_id+task_id+level)`, `INSERT … ON CONFLICT DO NOTHING`, Redis circuit breaker → AI called once per level per session.

- **Level 1:** authored, static (free, can't leak).
- **Levels 2–3:** AI, contextual. Prompt = ticket + ground-truth `root_cause` + authored ladder + student's `git diff` vs baseline (≤ 8 KB) + app log tail + last grader output. Socratic system prompt: one question, one place to look, never code.
- **Leak filter:** if output contains any normalized line added by `fix.patch`, regenerate once, then fall back to the authored hint.
- **Failure diagnosis at attempt 3:** reuses the existing design.
- **Write-up review** (`interaction_type='rootcause_review'`): reads `INCIDENT.md` via the existing file-read path, scores against rubric key points via a structured tool schema validated by a Go struct; cache key `sha256(session+"rootcause"+sha256(content))`; ≤ 3 per session. Feedback names covered points, never reveals missing ones. Student text delimited as untrusted data (prompt injection; low stakes — optional points).

## 7. Scenario catalog

Difficulty E / M / H (stored beginner / intermediate / advanced). Every scenario also runs the regression suite (R) and has the write-up (W); not repeated below. "Checked by" codes are from §4.

### Django (DJ)

**Migrations / schema**

| ID | D | Ticket / symptom | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-MIG-1 | E | Deploy fails: "Conflicting migrations detected; multiple leaf nodes" | Two branches both added `0007_*` | Migration graph, `--merge` | M |
| DJ-MIG-2 | M | Works locally, prod `DataError: value too long` | `max_length`/choices changed, migration never committed | `makemigrations --check` in CI | M |
| DJ-MIG-3 | M | Data migration crashes only on prod: `null value in column "slug"` | Backfill assumes non-null unique titles; prod has NULLs and dupes | Expand–backfill–constrain | M |
| DJ-MIG-4 | M | During rolling deploy, old workers 500 `column "username" does not exist` | One-step rename breaks still-running v1 | Expand/contract, `db_column` | M+P (old + new worker) |
| DJ-MIG-5 | H | Checkout timeouts every deploy | `AddIndex` on 500k rows holds a lock | `AddIndexConcurrently`, `atomic=False` | L+M |
| DJ-MIG-6 | M | Rollback runbook fails with `IrreversibleError` | `RunPython` without `reverse_code` | Reversible migrations | M (migrate back) |
| DJ-MIG-7 | H | Fresh installs fail "relation already exists"; existing DBs fine | Squashed migration `replaces` wrong | Migration state vs DB state | M (fresh + existing) |

**Data model / ORM**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-DATA-1 | E | "Invoices vanished after deleting a customer" | `on_delete=CASCADE` | Relationship semantics | T |
| DJ-DATA-2 | E | "My orders" shows orders assigned to me, not placed by me | Two FKs to User, wrong `related_name` | Reading the model graph | T |
| DJ-DATA-3 | M | Duplicate subscriptions | No `UniqueConstraint`, double-submit | Constraints over app checks, dedup migration | C+M |
| DJ-DATA-4 | M | Totals off by one cent | `FloatField` money | Decimal, quantize/rounding | T (random amounts) |
| DJ-DATA-5 | M | Late-night orders land on the next day's report | Naive datetimes / `TruncDate` without tz | `USE_TZ`, aware datetimes | T (seeded times) |
| DJ-DATA-6 | M | Comment count drifts | Counter in `save()`, `queryset.delete()` bypasses it | Denormalization, bulk ops skip signals | T+P |
| DJ-DATA-7 | M | Deleted products in category pages | Soft-delete manager bypassed by related manager | Managers, `_base_manager` | T |
| DJ-DATA-8 | H | Admin 500 `ValueError` on legacy orders | Code dropped choice `cancelled`, DB still has it (or DB CHECK rejects new `refunded`) | Enum drift DB vs code | M+T |

**Performance / queries**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-PERF-1 | E | Order list takes 8 s | N+1 in template (customer, items) | debug-toolbar, `select_related`/`prefetch_related` | Q (constant queries vs rows) |
| DJ-PERF-2 | M | API list slow only for big accounts | N+1 in DRF `SerializerMethodField` | Serializer query tracing | Q |
| DJ-PERF-3 | M | Endpoint times out / OOMs as data grows | Unpaginated list | Pagination contracts | P |
| DJ-PERF-4 | M | Dashboard fires 3× expected queries | `if qs:` + `qs.count()` + iterate; `len(qs)` | Queryset evaluation & caching | Q |
| DJ-PERF-5 | M | New "filter by status" page slow | Missing composite index | `EXPLAIN ANALYZE` | Q (no Seq Scan) + M |
| DJ-PERF-6 | H | Revenue report inflated and slow | Cartesian join from two multi-valued annotates | Subquery / `distinct=True` | T+Q |
| DJ-PERF-7 | H | Admin changelist hangs | `COUNT(*)` on huge table + FK N+1 in `list_display` | Admin tuning | Q |

**Async / sync & concurrency**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-CONC-1 | M | New async view 500s `SynchronousOnlyOperation` | Sync ORM in async view | `sync_to_async` / async ORM | P |
| DJ-CONC-2 | M | Stock goes negative under load | Lost update (read-modify-write) | `select_for_update`, `F()` | C |
| DJ-CONC-3 | M | Sporadic `IntegrityError` 500s on signup burst | `get_or_create` race | Constraint + retry | C |
| DJ-CONC-4 | M | Users occasionally see someone else's name | Request data in module global under threads | Thread safety | C |
| DJ-CONC-5 | M | Customers get emails twice | Celery retry of non-idempotent task | Idempotency keys | T (run twice → one effect) |
| DJ-CONC-6 | H | Worker intermittently `DoesNotExist` | Task enqueued before commit | `transaction.on_commit` | T+C |
| DJ-CONC-7 | H | `deadlock detected` on transfers | Opposite lock order | Lock ordering | C |
| DJ-CONC-8 | H | `too many clients` after traffic spike | Connection lifetime / threads misconfigured | Pool sizing, `CONN_MAX_AGE` | P (under load) |

**Service communication & caching**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-SVC-1 | E | Checkout hangs 30 s when payments is down | No timeout on `requests` | Timeouts, failure modes | P (stub fault) |
| DJ-SVC-2 | M | Customers double-charged | Retry on POST without idempotency key | Idempotent retries | P+C (stub counts charges) |
| DJ-SVC-3 | M | Everything "out of stock" | Upstream renamed `qty`→`quantity`, code defaults to 0 | Contract drift, fail loudly | T+P |
| DJ-SVC-4 | M | Stripe-style webhooks rejected | HMAC over re-serialized JSON, not raw body | Raw body, `compare_digest` | P (signed payloads) |
| DJ-SVC-5 | M | Profile edits take 15 min to show | Wrong cache key invalidated | Cache invalidation | P |
| DJ-SVC-6 | H | Users see each other's dashboard | `cache_page` on per-user view, no Vary | Cache keys & privacy | P (two users) |
| DJ-SVC-7 | H | DB CPU spikes every hour | Cache stampede on expiry | Locking / early refresh | C (recompute count) |

**Config / deployment**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-CFG-1 | E | CSS missing in prod only | `DEBUG=False`, static not collected/served | Dev vs prod parity | P (prod-mode process) |
| DJ-CFG-2 | E | "Data disappears after restart" in staging | Missing `DATABASE_URL` silently falls back to SQLite | Fail-fast config | P |
| DJ-CFG-3 | M | One page 500s: "Missing staticfiles manifest entry" | Template references an unmanifested file | Manifest storage | P |
| DJ-CFG-4 | M | After dependency bump: `AttributeError: localize` | pytz removed / zoneinfo | Reading changelogs, offline wheelhouse | T |
| DJ-CFG-5 | M | `request.user` anonymous on some routes | Middleware order | Middleware pipeline | P |

**Auth / security**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-SEC-1 | E | Pen-test: any invoice readable by ID | Queryset not scoped (IDOR) | Object-level authz | P (two users) |
| DJ-SEC-2 | M | "CSRF Origin checking failed" only behind HTTPS proxy | `CSRF_TRUSTED_ORIGINS` / `SECURE_PROXY_SSL_HEADER` | Proxies & headers | P |
| DJ-SEC-3 | M | Search with an apostrophe 500s | f-string in `raw()` → SQL injection | Parameterized SQL | P (payloads) + T |
| DJ-SEC-4 | M | PATCH lets users edit others' records | Permission on list, not object | DRF permissions | P |
| DJ-SEC-5 | H | Session survives re-login as another user | Custom login doesn't rotate session | Session fixation | T |

**Error handling / observability**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| DJ-ERR-1 | E | Import says "success", imports nothing | Bare `except: pass` | Reading logs, surfacing errors | T |
| DJ-ERR-2 | M | Orphan orders without payments | Missing `transaction.atomic` | Atomicity | T (fault injection) |
| DJ-ERR-3 | M | Log blames the wrong order ID | Late-binding closure in log call | Distrusting logs | T |
| DJ-ERR-4 | H | Duplicate audit rows and emails | `post_save` handler re-saves the instance | Signals, recursion | T |

### FastAPI (FA)

**Migrations (Alembic)**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-MIG-1 | E | `alembic upgrade head`: "Multiple head revisions" | Divergent heads after merge | Merge revisions | M |
| FA-MIG-2 | M | Deploy fails on non-empty table | NOT NULL column without `server_default` | Prod-snapshot thinking | M |
| FA-MIG-3 | M | `invalid input value for enum` | Python enum grew, PG enum not altered (autogenerate blind spot) | Autogenerate limits | M+T |
| FA-MIG-4 | H | Autogenerate wants to drop tables | `env.py` `target_metadata` misses model imports | Alembic wiring | M (`alembic check`) |
| FA-MIG-5 | H | Column rename lost all data | Autogenerate emitted drop+add | Review generated SQL | M (data preserved) |

**Data model (SQLAlchemy / Pydantic)**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-DATA-1 | E | After upgrade every response 500 `ResponseValidationError` | Pydantic v2: `orm_mode`→`from_attributes` | Migration guides | T |
| FA-DATA-2 | M | PATCH wipes fields users didn't send | Missing `exclude_unset` | Partial-update semantics | T |
| FA-DATA-3 | M | 422 on fields that used to be optional | v2 `Optional[X]` without default is required | Pydantic v2 semantics | T |
| FA-DATA-4 | M | Tags leak between requests | Mutated module-level default | Mutable defaults | T+C |
| FA-DATA-5 | M | `can't compare offset-naive and offset-aware` | `utcnow()` vs aware DB values | Datetime hygiene | T |
| FA-DATA-6 | H | Reassigning items deletes children | `delete-orphan` cascade misunderstanding | ORM cascades | T |

**Performance**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-PERF-1 | E | `/orders` slow | Lazy-load N+1 while serializing | `selectinload` | Q |
| FA-PERF-2 | M | 500 `MissingGreenlet` on one endpoint | Lazy relationship access under AsyncSession | Async ORM loading | P |
| FA-PERF-3 | M | Memory spikes on export | Loads full table, slices in Python | Pagination / streaming | P+Q |
| FA-PERF-4 | M | Latency creeps up, "too many open files" | New `httpx.AsyncClient` per request | Client lifecycle (lifespan) | L |
| FA-PERF-5 | M | Search slow | Missing index / leading-wildcard `ILIKE` | EXPLAIN, trigram index | Q |

**Async / sync & concurrency**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-ASYNC-1 | E | Whole API freezes while a report runs | `time.sleep` / `requests` in `async def` | Event-loop blocking | L |
| FA-ASYNC-2 | M | p99 spikes on password endpoints | CPU-bound bcrypt in `async def` | `run_in_threadpool` | L |
| FA-ASYNC-3 | M | Requests queue behind a slow upstream | Sync `def` endpoints exhaust the threadpool | Threadpool limits | L |
| FA-ASYNC-4 | M | "QueuePool limit reached" after errors | `yield` dependency doesn't close session on exception | Dependency lifecycle | P (errors then health) |
| FA-ASYNC-5 | M | Welcome emails silently never sent | `BackgroundTasks` exception swallowed | Observability of background work | T |
| FA-ASYNC-6 | M | Some jobs just vanish | Un-referenced `create_task` gets GC'd | Task references | T |
| FA-ASYNC-7 | H | Wallet balance wrong under load | Read-modify-write across `await` | DB locking in async | C |
| FA-ASYNC-8 | H | Prod: "attached to a different loop" | Engine/session created at import in another loop | Loop ownership, lifespan | P |

**Service communication**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-SVC-1 | E | Orders hang forever when inventory is slow | `timeout=None` | Timeouts | P (stub) |
| FA-SVC-2 | M | Duplicate orders downstream | tenacity retry on POST, no idempotency key | Idempotency | C+P |
| FA-SVC-3 | M | Sync job processes only 100 items | Upstream moved to cursor pagination | Contract drift | T+P |
| FA-SVC-4 | M | Staging orders hit a nonexistent host | Base URL read at import from defaults | Settings loading | P |
| FA-SVC-5 | H | Queue stops draining | Poison message crashes consumer, retried forever | DLQ, ack semantics | P |
| FA-SVC-6 | H | Webhook rejected intermittently | HMAC over `request.json()`, `==` compare | Raw body, `compare_digest` | P |
| FA-SVC-7 | M | Feature-flag changes never take effect | `lru_cache` on settings/DB read | Cache lifetime | P |

**Config / deployment**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-CFG-1 | E | App won't start after upgrade | `BaseSettings` moved to pydantic-settings / `env_prefix` change | Tracebacks at import | T (starts) |
| FA-CFG-2 | M | `/docs` broken behind `/api` prefix | Missing `root_path` | Reverse proxies | P |
| FA-CFG-3 | M | POST loses body behind proxy | Trailing-slash 307 via http→https | Redirect semantics | P |
| FA-CFG-4 | M | Rate limit inconsistent with 4 workers | In-process state | Multi-worker state | C |

**Auth / security**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-SEC-1 | E | Any order readable by ID | IDOR | Ownership checks | P |
| FA-SEC-2 | M | New route is public | Auth dependency on a router the route isn't mounted under | Dependency scoping | P (all routes) |
| FA-SEC-3 | M | Tokens "expired" on some servers / never expire | Naive time, no leeway / `verify_exp` off | JWT clock skew | T |
| FA-SEC-4 | M | Search 500s on quotes | f-string in `text()` | Bound params | P |

**Errors**

| ID | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|
| FA-ERR-1 | E | Monitoring shows 0 errors, users see failures | Handler returns 200 with error body | Status-code contracts | H |
| FA-ERR-2 | M | Half-created records | Commit between two inserts | Transactions | T |
| FA-ERR-3 | M | 500s with no traceback in logs | Custom middleware catches and hides the exception | Logging pipeline | P + log check |

### React (RE)

| ID | Cat | D | Ticket | Root cause | Skill | Checked by |
|---|---|---|---|---|---|---|
| RE-HOOK-1 | Hooks | E | Timer stuck at 1 | Stale closure in `setInterval` | Closures, functional updates | T (fake timers) |
| RE-HOOK-2 | Hooks | M | Changing filters doesn't refresh results | Missing effect dependency | Effect deps | T |
| RE-HOOK-3 | Hooks | M | Tab freezes, API hammered | Object dep recreated each render → effect loop | Referential identity | T (fetch count) |
| RE-HOOK-4 | Hooks | M | Form submits the previous value | Stale `useCallback` into memoized child | Memo boundaries | T |
| RE-ASYNC-1 | Races | M | Typeahead shows results for an older query | Out-of-order responses | AbortController / request ids | T (controlled resolve order) |
| RE-ASYNC-2 | Races | M | Wrong page data flashes after navigation | Request not aborted on unmount | Effect cleanup | T |
| RE-ASYNC-3 | Races | M | "Liked" stays after server failure | Optimistic update not rolled back | Optimistic UI | T |
| RE-ASYNC-4 | Races | H | Duplicate records created in dev | Non-idempotent POST in effect + StrictMode | Effects vs events | T (POST count) |
| RE-STATE-1 | State | E | Deleting a row shifts typed text to the wrong row | Index as key | Reconciliation | T |
| RE-STATE-2 | State | M | Editing a user shows the previous user | Props copied into state | Derived state / key reset | T |
| RE-STATE-3 | State | M | List doesn't update after add | In-place mutation | Immutability | T |
| RE-STATE-4 | State | M | Input warning, field desyncs | Controlled ↔ uncontrolled (`undefined`) | Form state | T |
| RE-PERF-1 | Perf | M | Typing laggy on settings page | Context value recreated → whole tree re-renders | Profiler, memoized value | T (Profiler render counts) |
| RE-PERF-2 | Perf | M | 10k-row table janky | Expensive render work, no memo/virtualization | Profiling | T (op counts) |
| RE-PERF-3 | Perf | H | Memory grows with each navigation | Uncleaned subscription/listener | Leak hunting | T (listener count) |
| RE-SSR-1 | SSR | M | "Hydration failed" warning, flicker | `Date.now()` / locale in render | SSR determinism | T (`onRecoverableError`) |
| RE-CFG-1 | Config | E | Requests go to `undefined/api` | `process.env` vs `import.meta.env.VITE_` | Build-time env | T+P |
| RE-CFG-2 | Config | M | Staging UI talks to prod API | Base URL baked at build | Build vs runtime config | P |
| RE-API-1 | Contract | M | "map is not a function" after backend deploy | Array → `{results,next}` | Contract drift | T |
| RE-API-2 | Contract | M | Dates off by one for US users | UTC string parsed as local | Timezones in UI | T (TZ env) |
| RE-API-3 | Contract | M | UI says "saved" on server 500 | `fetch` doesn't reject on HTTP errors | Error paths | T |
| RE-ERR-1 | Errors | M | White screen despite ErrorBoundary | Boundaries don't catch async/event errors | Error handling | T |

### Cross-stack (XS: React + Django/FastAPI in one sandbox)

Vite on :5173 proxies `/api` to :8000; Postgres and stubs run as extra supervised processes; the browser sees one origin. CORS/cookie bugs are reproduced with a provided `repro.sh` (curl with `Origin`) and verified with H probes. Real cross-origin browser repro is deferred (needs the proxy to exempt the API port from preview-cookie auth).

| ID | D | Ticket | Root cause | Checked by |
|---|---|---|---|---|
| XS-1 | M | Login works in Postman, fails in browser | `allow_origins=*` with credentials | H+T |
| XS-2 | M | Session lost after redirect | Cookie `SameSite`/`Secure`/domain | H |
| XS-3 | M | Totals show NaN | `total_cents` → `total` float drift | T+P |
| XS-4 | M | First page of items missing / duplicated | 0-based offset vs 1-based page | T+P |
| XS-5 | H | SPA POST 403 | CSRF cookie HttpOnly / wrong header name | P |
| XS-6 | H | Dates wrong across the boundary | Backend emits naive datetimes | T |
| XS-7 | H | Two tabs overwrite each other silently | No version/ETag on either side | C+T |

### Organization in the product

- **Tags** (`lab_debug_scenarios`): `stack`, `category` (migrations, data-model, performance, concurrency, service-comm, config, security, errors, react-hooks, …), `difficulty`, `skills[]`.
- **Learning path** (recommended order, not gated): L1 "Read the error" (config, tracebacks, E-level) → L2 "Reproduce and step through" (debugger, tests) → L3 "Data and performance" (queries, migrations) → L4 "Concurrency and distributed" (races, retries, queues).
- **Placement:** new course `production-debugging`, `section_group` per stack, sections per category; three flagships linked from interview-prep-45's Django/FastAPI/Frontend sections via a pointer lesson.
- **Randomization tiers:**
  1. v1: per-Check randomized grader data (server seed). Kills hard-coding, no schema change.
  2. v2: per-session cosmetic parameters (entity names, IDs, which endpoint shows the symptom), templated in the bundle.
  3. v2: structural variants (2–3 alternative faults for the same symptom, e.g. N+1 in serializer vs template), picked by `hash(session_id)`, stored as `lab_sessions.variant_key`.
  The write-up in the student's own words further blunts answer-sharing.

## 8. Data model & API

**Migration `044_debug_labs.sql` (+ down):**
- `lab_definitions_lab_type_check` gains `'debug'`; Go constant `LabTypeDebug` in `models.go` (keeps the Go-set-equals-CHECK test).
- `lab_tasks` and `lab_task_version_items` gain `grader TEXT NOT NULL DEFAULT 'script' CHECK (grader IN ('script','rootcause_review'))`.
- `lab_ai_interactions_interaction_type_check` gains `'rootcause_review'`.

```sql
CREATE TABLE lab_debug_scenarios (
  task_version_id    UUID PRIMARY KEY REFERENCES lab_task_versions(id) ON DELETE CASCADE, -- pinned with the snapshot
  lab_id             UUID NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  stack              TEXT NOT NULL CHECK (stack IN ('django','fastapi','react','fullstack')),
  category           TEXT NOT NULL,             -- CHECK list mirrored by Go constants
  difficulty         TEXT NOT NULL CHECK (difficulty IN ('beginner','intermediate','advanced','expert')),
  skills             TEXT[] NOT NULL DEFAULT '{}',
  brief_md           TEXT NOT NULL,             -- student-visible ticket
  root_cause_md      TEXT NOT NULL,             -- hidden until completed
  rubric             JSONB NOT NULL,
  hint_ladder        JSONB NOT NULL,
  fix_diff           TEXT NOT NULL,             -- hidden; debrief + hint-leak filter
  baseline_commit    TEXT NOT NULL,
  protected_manifest JSONB NOT NULL,            -- {path: sha256}
  ide_port           INT NOT NULL DEFAULT 3000,
  app_ports          INT[] NOT NULL,
  workspace_bundle   BYTEA NOT NULL,            -- tar.gz incl .git (≤ 2 MB, enforced by coursegen)
  grader_bundle      BYTEA NOT NULL             -- never leaves the backend except via ExecStdin
);
CREATE INDEX ON lab_debug_scenarios (lab_id);
CREATE INDEX ON lab_debug_scenarios (stack, category, difficulty);
```

Bundles live in the DB rather than MinIO so publish/pin stays transactional with no new moving part. `render_lab.go` emits the row in the same generated script as the version snapshot.

**Endpoints** (existing student router: `RequireAuth` + `RequireCSRF`, IDOR checked per handler):
- Reused: `POST /api/labs/{labId}/sessions`, readiness/events, `ws-token` (also the preview/IDE token), `POST /sessions/{id}/submit` (the **Check** button; debug branch inside `SubmitAll`), `reset`, `end`.
- `GET /api/labs/sessions/{id}` gains a `debug` block (brief, `ide_port`, `app_ports`) — never root cause, fix, rubric or bundles.
- New `POST /api/labs/sessions/{id}/tasks/{taskId}/hint` — generic, 3 levels, Redis rate limit.
- New `POST /api/labs/sessions/{id}/rootcause-review` — reads `INCIDENT.md`, cached, ≤ 3/session.
- New `GET /api/labs/sessions/{id}/debrief` — only when `status='completed'`; root cause, reference fix, student diff vs baseline.
- New `GET /api/labs/debug/catalog?stack=&category=&difficulty=` — org-scoped, published only, student-safe fields + caller's best status.
- labproxy: `GET /__mf/preview-auth` reused for silent refresh; preview passthrough updates debounced `last_active_at`; IDE-port requests get the HMAC `vscode-tkn` cookie.
- Instructor/admin: "Preview as student" starts an `is_test` session (flag exists in `repo.go`), gated by the course-editing RBAC permission (`authz.RequirePermission`). Authoring stays in the markdown pipeline (no instructor lab CRUD routes today).

## 9. Frontend

**Student** (`/labs/sessions/[sessionId]`, branch in `components/labs/lab-workspace-content.tsx` on `lab_type==='debug'`) → new `components/labs/debug-workspace.tsx`:
- **Left rail:** `debug-ticket-panel.tsx` (brief via existing markdown renderer; Jira/Sentry look, trace block, severity); checklist (reuse `lab-task-checklist.tsx` / `sandbox-tests-panel.tsx` for per-check results); **Check** (submit, with cooldown); **Hints** (new generic `hint-drawer.tsx` + `hooks/use-lab-hints.ts`); **Submit write-up**.
- **Main:** tabs **IDE** (`lab-ide-frame.tsx`: iframe, 4-min silent cookie refresh via `hooks/use-lab-preview.ts` extended for the IDE port, pop-out) and **App** (existing `lab-preview-pane.tsx`). `lab-timer.tsx` in the header.
- **Result** (`labs/sessions/[sessionId]/result`): `debug-debrief.tsx` — score by task, write-up feedback, root cause, reference fix next to the student's diff.
- **Catalog:** `app/(app)/labs/debug/page.tsx` with stack/category/difficulty filters, learning-path grouping, status badge. `lib/labs/lab-type-ui.ts` gets a `debug` entry.

**Instructor:** "Preview as student" on the lab module (test session); scenario metadata view (tags, pass rate from `lab_analytics`). Authoring UI out of scope.

## 10. Phased build order

**Phase 0 — prerequisites (security + generic AI) — implemented 2026-09-29.**
1. ✅ ttyd auth via HMAC connection token checked by labproxy (closes the cross-container shell on Docker). `HMAC-SHA256(LABPROXY_JWT_SECRET, session_id)` — `backend/internal/labs/credential.go` (`DeriveContainerCredential`, `writeTTYDCredential`), written at claim/start time via `Service.acquireSandbox` (covers both the warm-pool claim path and cold `Start`, plus `resetContainerSession`'s replacement container), read by every lab image's entrypoint before it starts ttyd (`lab-images/shared/entrypoint.sh`, `lab-images/lab-docker/entrypoint.sh` + `entrypoint-sysbox.sh`, `lab-images/lab-k8s/entrypoint.sh`), recomputed and presented as ttyd Basic Auth by `cmd/labproxy/proxy.go`'s `deriveContainerCredential` on every upstream connect. Nothing new stored in the DB; the browser never sees it. See `docs/labs.md` "Proxy ↔ Container Channel Security" for the full writeup. The same `DeriveContainerCredential` helper is what Phase 1's IDE port reuses.
2. ✅ `ImageProfile.Elevated` split from `Name` — `backend/internal/labs/profile.go`; `KubernetesContainerService.startPod`'s RuntimeClass requirement now keys off `Elevated`, not a non-empty `Name`, so the future `debug-ide` resource-only profile won't be forced through it. See `docs/labs.md`'s "Nested Docker labs" section.
3. ✅ Preview-traffic heartbeat — `ProxyHandler.heartbeatPreview` (`cmd/labproxy/proxy.go`), called from `previewTarget` (`preview.go`) so both HTTP passthrough and the WS upgrade heartbeat, debounced to the terminal relay's own 5s cadence via Redis `SetNX`. See `docs/labs.md`'s labproxy responsibilities list.
4. ✅ Generic lab hint endpoint + HintDrawer (labs Phase 3) — `POST /api/labs/sessions/:sessionId/tasks/:taskId/hint` (`backend/internal/labs/hint.go`), `components/labs/hint-drawer.tsx` + `hooks/use-lab-hint.ts`, wired into `LabTaskChecklist`/`LabConsoleWorkspace` via `LabWorkspaceContent`. 3 levels, atomic `hints_used`, `cache_key` dedup, Redis-backed AI circuit breaker. **Deviation:** the hint prompt does not yet include terminal/grader output — the PTY ring buffer that would source it doesn't exist yet (see `docs/labs.md`'s Hint System section for the full deviation note); it uses the task's authored content + attempt count only. No `lab_tasks`/`lab_ai_interactions` schema change was needed — migration 045 was not created.

**Phase 1a — debug-lab runtime, backend + image — implemented 2026-09-30.** Migration `045_debug_labs.sql` (generic `lab_*` schema above, `lab_type='debug'`, `grader`, `lab_sessions.variant_key`, `lab_definitions.build_id`, `lab_catalog_meta`); `labkinds` registry + `debug` kind; variant pick at `StartSession`; bundle seeding via `ExecStdin`; `GradeInCleanRoom` + `ContainerRuntime.ExecCapture`/`StartValidation`; private bundle store + `lab.bundle_gc`; IDE credential + labproxy token injection + `/__mf/ok` silent refresh; terminal-history ring buffer and hint upgrades (idempotency key, kind context, leak filter); `debug-ide` profile; `GET session` kind block, `debrief`, `writeup-review`, `catalog`, library `debug` kind + stack/category/difficulty filters; `lab-images/lab-debug` (Dockerfile, supervisor, `grade.sh`, probe library P/Q/C/M/L/H/T). Verified: `go build`/`go vet`, `bash -n`, `py_compile`; no image build or DB test could be run here (no Docker). Not in 1a: frontend debug workspace (1b), builder/renderer/coursegen/scenario content (1c), failure-diagnosis prompt wiring.

**Phase 1c-i — lab-authoring engine core — implemented 2026-09-30.** No new tests (per instruction until all phases land); verified with `go build ./... && go vet ./...` plus a throwaway harness over a sample block tree. Names are the generic ones from the architecture section (`labauthor.*` permissions, `/api/.../lab-authoring/...` paths, `content/lab-blocks/`). The renderer, build/verify jobs, builds/preview/publish endpoints are Phase 1c-ii (below); the builder UI is later.
- **Packages.** `backend/internal/labblock` (import-cycle-free leaf: `block.yaml` manifest types incl. the debug sections, `Issue`, `Recipe`/`ResolvedBlock`, semver + ranges), `backend/internal/labauthor` (the kind-agnostic engine: `manifest.go` manifest validation, `params.go` JSON-Schema validation with `randomize`, `validate.go` `Validate`/`Analyze`, `tokens.go` capability algebra, `variants.go` variant enumeration + `RecipeHash`, `literal.go` literal escapers, `sync.go` block pack + SQL, `repo.go`/`service.go`/`draft.go`/`handler.go`/`routes.go` API), `labkinds/debug_compose.go` (debug rules). `labkinds.Kind` gained `ValidateRecipe(*labblock.Recipe, labblock.ParamValidator) []labblock.Issue` and `DeriveDifficulty(*labblock.Recipe) string`. JSON Schema lib: `github.com/santhosh-tekuri/jsonschema/v6` (draft 2020-12, pure Go, no CGO).
- **Validator split.** Engine (all kinds): block kind allowed for the lab kind, yank, org scope, params vs schema + `randomize`, pools (>=2 members, same kind/category, difficulty within 1), rule 1 stack/app range, rule 2 capability satisfaction (`data:rows>=N` predicates), rule 5 conflicts, rule 7 budgets (25 s / 2 MB / 512 KB). Every fault-pool combination is validated separately. Debug kind: cardinality (exactly 1 app, >=1 fault, `custom` combines only with ticket/hints/rubric), rule 3 slot exclusivity (chained faults and `migration` slots exempt), rule 4 chains (target in recipe, mode, acyclic, <=3 faults), rule 6 check + carrier coverage, the value-slot literal rules, rule 8 derived difficulty. Issue shape `{code, block, message, severity: error|warning|info}`; `Analysis` adds `valid`, `recipe_hash`, `derived_difficulty`, `difficulty`, `variant_count`, `variant_total`, `budget`.
- **Trust boundary.** String params must declare `x-mf-use: text` (markdown only, maxLength <= 2000) or `literal:<python_str|js_string|json>` (maxLength <= 200); a param may only be interpolated (`{{params.x}}`) into a `value` slot whose declared `literal` fits its type; `labauthor.RenderLiteral`/`PythonRepr`/`JSString`/`JSONLiteral` are the only sanctioned way to emit it (the renderer in 1c-ii must use them). Org text blocks are ticket/hints/rubric/preset only, inline `template_md`, with no params/requires/provides/budget.
- **Block sync.** `cd backend && go run ./cmd/coursegen blocks sync [--in ../content/lab-blocks] [--out db/fixtures/lab-blocks.generated.sql] [--dry-run] [--no-upload]`. Validates every `block.yaml`, content-hashes each directory (sorted paths, CRLF-normalised), uploads deterministic tar.gz payloads (`lab-bundles/<sha>.tar.gz`, `storage.PutBundle`, needs the `MINIO_*` env) and writes an idempotent SQL fixture. Apply with `scripts/db-seed-courses.sh` (it runs every `db/fixtures/*.generated.sql`; the local container DB is stale, see the shared-DB note, so apply against the real `DATABASE_URL` deliberately). The fixture upserts `lab_blocks` (UUIDv5 ids, `org_id NULL`), raises an exception if a version already exists with a different content hash ("bump the version"), and inserts a version row only when new.
- **API** (`RequireAuth + RequireCSRF`, org scoped in queries): the B5 table above under `/api/instructor/lab-authoring` (blocks list/detail/create/update/delete, recipes CRUD, `validate`, `ticket-draft`) and `POST /api/admin/lab-authoring/blocks/{versionId}/yank` (`super_admin`). Recipe GET returns `{recipe, blocks, updates}` (newer non-yanked versions of pinned blocks). Error `code`s: `recipe_invalid` (422, issues in `data`), `block_yanked`, `block_version_immutable`, `block_not_found`, `block_key_taken`, `block_in_use`, `block_not_editable`, `recipe_revision_conflict`, `recipe_in_use`, `rate_limited`, `ai_unavailable`. Ticket drafts: cached in `lab_ai_drafts` by `sha256(recipe_hash+persona)`; a cache miss is rate limited per user (`LABAUTHOR_DRAFT_RATE_MAX`, `LABAUTHOR_DRAFT_RATE_WINDOW`, default 10/hour). Builds/preview/publish endpoints are 1c-ii.

**Phase 1c-ii — renderer, build/verify pipeline, publish — implemented 2026-09-30.** No new tests (per instruction until all phases land); verified with `go build ./... && go vet ./...`, `compile()` of every Python module, and a throwaway end-to-end harness (block tree -> Go validator -> `RenderSpec` -> the real `mf-build` with ruff + git -> extracted workspace/grader/overlays). No Docker image build or DB run was possible here, so migration 048, the publish SQL and the sandbox flow are unexecuted.
- **Packages.** `backend/internal/labbuild` (`service.go` wiring, `render.go` `lab.recipe_build`, `verify.go` `lab.recipe_verify`, `capture.go`, `publish.go` publish + preview, `api.go`, `jobs.go` handlers + platform sync + GC, `repo.go`, `handler.go`, `tarutil.go`); `labkinds/debug_render.go` (the debug renderer input) plus additions to `debug_compose.go`; `lab-images/lab-debug/mf-build/` (the Python renderer, module-split); migration `048_lab_builds_per_recipe.sql`; `canonical/recipe.go` + `generator/render_recipe_lab.go` (platform recipes). `labkinds.Kind` gained `VerifyMatrix(VerifyInput)` (replaces the static list), `VerifyInput(payload)`, `Image()`, `SetupScript()` and `RenderSpec(RenderInput)`.
- **Renderer contract (`/opt/mindforge/mf-build`, root-owned; `python3 -I /opt/mindforge/mf-build --out /tmp/mf-out`).**
  - *Input (stdin):* one tar(.gz): `spec.json` = `{"schema":1,"variants":[<render spec>...]}` plus `blocks/<dir>/<payload files>`. The render spec is built by `DebugKind.RenderSpec` and carries the app (slot catalog, history, noise, features, protected globs, setup commands, ports), the ordered faults (`inject`/`fix`/`carrier`/`cheats`, each `{dir, slots[{slot, value|file}], files[{path, from}]}`), the checks (probe kind, student-facing name with an `Issue N:` prefix when there are several faults, message, effective params, role), data/stub/env blocks, and the final ticket text (`{{captured.*}}` left as placeholders), root cause, hint ladder and rubric. **Slot values are already final source text**, rendered by `labauthor.RenderLiteral`, so there is exactly one escaping implementation and the renderer never interprets a parameter.
  - *Output:* stdout is one JSON line `{"ok":true,"variants":[...]}` or `{"ok":false,"error":...}` (exit 1). Per variant, under `--out/<key>/`: `workspace.tar.gz` (the working tree **with `.git`**, ready to extract into `/home/labuser/work`), `grader.tar.gz` (`grader.json` + hidden `regression_tests/`), `verify.tar.gz` (`overlays/fix-<n>.tgz` = the reference fix of the first n issues in chain order, `overlays/cheat-<i>-<j>.tgz`), `meta.json` (`payload` {root_cause_md, fix_diff, rubric, hint_ladder, baseline_commit, pre_fault_commit, issue_info}, `protected_manifest`, `app_ports`, `brief_md`, `captures`, `cheats` with diffs, `sizes`).
  - *Rendering rules:* history is built by materializing raw source plus the active override layers at every commit, so a later feature commit can never undo an active fault: scaffold -> features (the fault commit(s) land between the last 2-4 features, or `position: early|end`) -> noise; dates come from the seed, personas from the app/fault, every commit builds and is ruff-formatted (prettier for JS when present). `mf:` markers are stripped and any survivor is a hard error. Migration slots insert the next Django (`NNNN_slug.py`, `{{mf.prev}}`/`{{mf.number}}`) or Alembic (`<rev>_slug.py`, `{{mf.revision}}`/`{{mf.prev}}`) migration. `TICKET.md`, `INCIDENT.md`, `.vscode/`, `.mf/` (setup script, data generators, stubs) and generated `.lab/services/*` are written but excluded from git. `baseline_commit` is the final commit, i.e. the broken state students receive, which is what the student-test and hint diff logic already use. Tar.gz output is deterministic (sorted, zero owners, fixed mtime). Image pins: `ruff==0.8.4`, `prettier@3.4.2`.
- **What the debug blocks must author to fit (for 1d).**
  - *app block:* `src/**` (the scaffold commit; must include `.lab/services/app.sh`, the supervised app, whose output goes to `/var/log/mindforge-lab/app.log`); `history/<name>/**` and `noise/<name>/**` overlay dirs referenced by `history[].paths` / `noise[].paths`; `regression_tests/core/**` (always) and `regression_tests/<feature>/**` (tests are tagged by feature = directory; a feature's tests are included iff it is a history feature or a fault carrier). Manifest `app:` fields: `language`, `slots` (region: comment markers `# mf:slot NAME` ... `# mf:endslot`, also `//`, `<!-- -->`, `/* */`; value: inline `@@mf:value NAME=default@@`, needs `literal`; file: `default` = the path; migration: `dir` + `scheme: django|alembic`), `features`, `history`, `noise`, `ports`, `protected` (fnmatch globs; `.mf/*` and `.lab/services/*` are always protected), `setup` (shell commands run with `DATABASE_URL` and `MF_WORKDIR` set, for the student's dev DB at session start via the generated `.mf/setup.sh` and inside every grader mode), `readiness_path`, `test_globs`.
  - *fault block:* `inject`/`fix`/`carrier`/each cheat are `{slots[{slot, value|file}], files[{path, from}]}` (`from` = a path inside the block payload; a `migration` slot override takes `file` only). The **fix must add a reference test** (a `fix.files` path matching the app's test globs; validated, and it is what proves `student-test`). `carrier: {feature, ...overrides}` names a feature in `app.features` that has a `regression_tests/<feature>/` dir. Also `commit.message` (+ `persona` `Name <email>`, `position`), `checks[{ref, role symptom|regression, params}]` (a param may be exactly `"{{params.x}}"` to take the fault's typed param), `symptom.vars` (ticket `{{symptom.x}}`), `root_cause` (Markdown, required, `{{params.x}}` allowed), `hints` (3), `rubric`, `chain`. `{{params.x}}` may only appear in **value-slot** overrides, typed by the slot's `literal`.
  - *check block:* `probe` (P/Q/C/M/L/H/T of the image's probe library) + `failure_message`; the block's `params` schema is the probe's parameters (`entry` is reserved and unused).
  - *data block:* `data.generator` is a Python file in the payload, run as `python3 <gen> <params.json>` with `MF_SEED` set (the grader seed at grade time, the variant seed for the dev DB); it must write to `$DATABASE_URL`.
  - *stub / env / custom:* a stub's payload `service.sh` becomes `.lab/services/<stub.process>.sh` (the rest goes under `.mf/stubs/<key>/`). An env block's `overlay` files are added in the fault commit, `pins` install from the wheelhouse in `setup`, and `supervisor` `NAME=value` entries plus `missing_var` are written to `.lab/env` (source it from `app.sh`). `custom` blocks are rejected by the build for now.
- **Job flow and status transitions.**
  - *Request:* `POST .../recipes/{id}/builds` validates (422 `recipe_invalid`), reuses a verified build with the same hash (200 `reused`), returns an in-flight build, else enforces 10 builds/instructor/day (`LAB_BUILDS_PER_USER_DAY`, Redis, 429 `build_rate_limited`), inserts `lab_builds(queued)` with the frozen `spec_snapshot` and enqueues `lab.recipe_build` (idempotency key `lab.recipe_build:<build_id>`).
  - *`lab.recipe_build`* (`queued -> rendering -> verifying`): re-resolves the frozen spec and re-runs `Analyze` (org scoping again; the hash must match); enumerates variants; downloads and sha-verifies block payloads; builds the input tar; starts one `mindforge-validate-build-*` sandbox on `Kind.Image()`, streams the input to `mf-build`, collects each variant with `ExecCapture` (16 MB cap); enforces the 2 MB / 512 KB bundle budgets; `PutBundle`s the workspace/grader/verify bundles; one transaction writes `lab_build_variants` + `lab_block_usages` and moves the build to `verifying`; enqueues `lab.recipe_verify`.
  - *`lab.recipe_verify`* (`verifying -> verified | failed`): for each variant runs `Kind.VerifyMatrix(Kind.VerifyInput(payload))` through `labs.GradeModesInCleanRoom`, the fix/cheat overlay being the editable tar (runs in parallel, bounded per org by `LAB_VERIFY_PARALLEL_PER_ORG`, default 4): broken (unmasked symptoms fail on a real probe, regression passes, setup <= 30 s, real output captured), each chain step, full fix x 3 seeds, student-test on the fix, each cheat (must fail a required task). The broken run's after-grade hook captures `{{captured.trace|log|slow_queries}}` from the app/postgres logs; they are substituted into `brief_md` and `TICKET.md` (workspace bundle re-uploaded). The structured per-run report (expectations, failures, per-seed check results, author messages, stderr tail, setup seconds) is written to `lab_builds.report` live and finally with the terminal status; platform recipes then auto-publish.
  - *Safety:* both jobs are retry-safe (status-guarded `Advance`, content-addressed uploads, idempotent inserts); a job that dies is failed by an `OnDead` hook; validation time is metered as `validation_seconds` (no session). Content errors fail the build and succeed the job; infrastructure errors retry.
- **Endpoints** (`/api/instructor/lab-authoring`, org scoped): `POST /recipes/{id}/builds` (202 `{build_id}`), `GET /builds/{id}` (status, report, variant keys), `POST /builds/{id}/preview-session {variant_key?}` (an `is_test` session through `labs.StartSession` on a hidden per-recipe preview lab; `labs.WithVariantOverride` picks the variant), `POST /builds/{id}/publish {course_id, section_id, position, is_required}` (guard `labauthor.compose` + `courses.publish`; falls back to the recipe's `target_placement` for a not-yet-published recipe). Publish is **one transaction**: build verified and its hash equal to the recipe's current hash (else 409 `build_stale`); create/update the lab (`lab_type`, image and `setup_script` from the kind, `build_id`); sync `lab_tasks` from `Kind.Tasks()`; cut a new `lab_task_versions` row tied to the build (`lab_task_versions.build_id`; publishing the same build twice is a no-op); upsert `lab_catalog_meta`; set `lab_recipes.lab_id`; place it with `library.Service.AttachTx`, the single insert path (`Attach` now wraps it). Sessions keep their pinned task version **and that version's build**, so republishing never re-points an in-flight session. Error codes: `build_not_found`, `build_in_flight`, `build_not_verified`, `build_stale`, `build_rate_limited`, `invalid_placement`, `variant_unknown`, `build_queue_failed`.
- **Platform recipes.** A `kind: lab` document may carry `recipe: recipe.yaml` (`lab_kind`, `app_range`, `seed`, `blocks: [{block: key@version, pool, params}]`; omit `lab_type`/`environment`/`tasks`/`setup_script`). `coursegen generate` emits the lab unpublished plus a `lab_recipes` row (`is_platform`, UUIDv5 block-version ids from `canonical.LabBlockVersionID`, revision bumps only when the spec changes). **Run order on seed/deploy:** `coursegen blocks sync`, `coursegen generate`, apply both fixtures (`scripts/db-seed-courses.sh` runs every `*.generated.sql`), then the scheduled job `lab.platform_recipes_sync` (every 15 min) builds each platform recipe whose current hash has no build (auto-publish on verify) and publishes a verified build the lab is not on. Failed and in-flight builds are left alone (change the recipe or its blocks to retry), so a broken recipe cannot rebuild in a loop.
- **GC.** `lab.build_gc` (daily) deletes failed, and superseded verified, builds older than 30 days that no lab or task version references (variants/usages cascade); `lab.bundle_gc` then reclaims their bundles (it now also treats `payload.verify_bundle_key` as referenced).
- **Migration 048.** Verified builds are unique per (recipe, hash) instead of per hash (cross-org reuse would leak build rows); one in-flight build per (recipe, hash); `lab_task_versions.build_id`; `lab_recipes.is_platform`; GC indexes. **Config:** `LAB_BUILDS_PER_USER_DAY` (10), `LAB_VERIFY_PARALLEL_PER_ORG` (4).

**Phase 1b — student frontend for kind-based labs (debug first) — implemented 2026-09-30.** No new tests (per instruction until all phases land); verified with `tsc --noEmit` + `eslint --max-warnings=0`.
- **Kind-UI registry (mirrors backend `labkinds`).** `components/labs/kinds/workspace-registry.ts` (`LAB_KIND_WORKSPACES`: `lab_type` → client workspace), `components/labs/kinds/debrief-registry.ts` (`LAB_KIND_DEBRIEFS`: `lab_type` → server-rendered result-page section), `lib/labs/kinds/catalog.ts` (`LAB_KIND_CATALOG`: filter options + learning-path groups), `lib/labs.ts` (`LabKindBlocks`: the per-kind block in `GET /sessions/{id}`). `lab-workspace-content.tsx` is now a thin dispatcher; the old body moved unchanged to `standard-lab-workspace.tsx`. Kind labs embedded in course notes render `kind-embed-notice.tsx` (open full screen).
- **Adding a kind on the frontend:** (1) add its block type to `LabKindBlocks`; (2) add `<Kind>Workspace` under `components/labs/kinds/<kind>/` and register it; (3) optional debrief section + registry entry; (4) optional catalog config; (5) an icon/label in `lib/labs/lab-type-ui.ts`. Nothing else changes.
- **Debug kind** (`components/labs/kinds/debug/`): `debug-workspace` (orchestrator, remounts on reset), `debug-ticket-panel` (+ `lib/labs/kinds/debug-ticket.ts` extracts optional `Severity:`/`Reporter:` lines), `debug-check-bar` (Check + 30 s cooldown + grader-busy state), `debug-failure-list` (parsed `FAIL name: message` lines, `lib/labs/kinds/debug-results.ts`), `debug-writeup-panel` (`.ai-surface` review), `debug-main` (IDE / App tabs, both kept mounted), `debug-ide-frame`, `debug-debrief` + `debug-diff-view` (unified +/- diff, reference fix beside student diff, no new dependency), `lab-markdown`.
- **Hooks / libs:** `use-debug-check`, `use-writeup-review`, `use-lab-ide` + `lib/labs/ide-token-store.ts` (a `useSyncExternalStore` token store: mints on subscribe and every 4 min, no effects), `use-countdown`, `lib/labs/preview-url.ts` (shared with `use-lab-preview`). Silent IDE cookie refresh loads `<proxy>/preview/<fresh token>/<ide_port>/__mf/ok` in a hidden iframe (labproxy redirects it through `/__mf/preview-auth?...&next=/__mf/ok`, 204) — no new env var needed.
- **Catalog:** `app/(app)/labs/catalog/` (`page.tsx`, `catalog-filters.tsx` nuqs URL state, `catalog-card.tsx`, `loading.tsx`, `error.tsx`), `ROUTES.LABS_CATALOG`, nav entry "Debug Labs" in the Learn hub, categories mapped to L1-L4 in `lib/labs/kinds/debug.ts`. `LabStartButton` now takes `Pick<Lab, "id"|"title"|"lab_type">`.
- **Small shared changes:** `ActionResult.status` (HTTP status on failures; lets callers branch on 429/503), `LabTaskChecklist` gained `showTaskCheck` / `renderTaskDetail`, `LabEnvironment` zeroes the header score on reset.
- **Contract gaps found in 1b, fixed in the follow-up (2026-09-30):** (a) completion policy `CompleteOnFinish` for debug: required-pass credits the module but the session stays active until **Finish** (`POST /end`) or the deadline, so the write-up is always possible (frontend `debug-finish-bar`, enabled when the required tasks pass); (b) the latest write-up review is persisted (`lab_sessions.writeup_review`, migration 046) and returned by the debrief, rendered on the result page; the student diff is captured into `lab_sessions.student_diff` by `labs.SandboxCloser` on every close path (Finish, deadline check, reaper); (c) labs 429s carry `Retry-After` from the key TTL and `apiAction` exposes `retryAfter` (the hard-coded 30 s mirror is gone; no countdown is shown after a *successful* Check, only when the server actually refuses); (d) task views expose `grader`, the hint endpoint 422s for `writeup_review` tasks, and the write-up task is identified by grader instead of re-reading the session. `standard-lab-workspace.tsx` was split (`standard-lab-desktop-layout.tsx`, `standard-lab-workspace-types.ts`).

**Phase 1 — Django end to end (v1).** Django first because it exercises the hardest infrastructure (in-sandbox Postgres, migrations, `pg_stat_statements` query counting, debugpy attach, hidden pytest), which de-risks FastAPI; the course also has the densest Django material.
1. `lab-images/lab-debug` image, `debug-ide` profile, `grade.sh`, supervisor.
2. Migration 044, models/repo, `verifyDebugTask`, bundle streaming in `prepareLabEnvironment`, catalog, debrief, rootcause-review.
3. Coursegen: `LabSpec.Debug`, `_scenario/` skip, deterministic bundler, size caps; `scripts/test-debug-labs.py`.
4. Frontend: DebugWorkspace, IDE frame, ticket panel, debrief, catalog.
5. Content: 3 flagships through the harness — DJ-PERF-1 (E), DJ-DATA-5 (M), DJ-CONC-2 (H) — then fill to ~10 across categories.

**Phase 2 — FastAPI.** Mostly content on the same image, plus Alembic/async probes (L-type latency harness). ~10 scenarios.

**Phase 3 — React.** Vitest grader config, Profiler render-count + listener-count harness, hydration harness. ~10 scenarios.

**Phase 4.** Cross-stack (XS), randomization tiers 2–3 (`variant_key`), clean-room grader if abuse appears, per-category analytics.

**Out of v1:** Playwright/real-browser grading, docker-compose/nested Docker, structural variants, cross-origin browser repro, web authoring UI, AI-generated scenarios, real Sentry/APM UI.

**Risks:** cost (2 CPU / 2 GB per session = 4× current 512 MB labs); openvscode-server in an iframe (same-site cookies fine, but webview CDN and Safari quirks need testing); authoring cost ~0.5–1 day per scenario (app, history, fix, cheats, grader); grader flakiness in timing probes (prefer counts over wall-clock, wide margins); Open VSX extension availability.

## Open questions

1. **Hosting cost:** is 2 CPU / 2 GB per concurrent debug session acceptable, and what per-org concurrency cap? (Sets `lab_org_config` defaults.)
2. **Placement:** new `production-debugging` course (recommended) with flagships linked from interview-prep-45, or everything inside interview-prep-45?
3. **Single vs multi-fault:** single root cause (+ red herring) for E/M, chained two-fault bugs only at H?
4. **Grading strictness:** write-up as bonus points (recommended) or required? Hint penalty via existing `hint_penalty_pct` (suggested 10%)?
5. **Solution reveal:** debrief only after completion (recommended), or also "give up and show solution" ending the session with a reduced score?
6. **Primary production runtime — Docker or k8s?** Decides how urgent the Phase 0 ttyd/IDE auth fix is (needed on Docker regardless).
7. **AI budget:** AI review of each write-up (≤ 3 per session, cached) acceptable?

---

# Part 2 — Scenario Builder (building blocks)

> Extends Part 1 and makes the builder the main authoring path from Phase 1. Supersedes Part 1's hand-authored `_scenario/` dirs (kept only as a `custom` block), the bundle columns on `lab_debug_scenarios` in Part 1 §8, and the phase order in Part 1 §10.

## B0. Summary

Every block is a small versioned package. **Code blocks** (app, fault, stub, check, data generator, env, custom) are written by platform staff in the repo under `content/lab-blocks/` and synced to the DB. **Text blocks** (ticket, hints, rubric, parameter presets) can also be created in the UI by org instructors. A composed scenario is a **recipe**: block references pinned to exact versions, plus parameters. A server-side job builds it in a lab sandbox and runs the verification matrix automatically. Only a verified build can be published into a course section, and publishing cuts a normal `lab_task_versions` snapshot. A block update never changes a live lab: the recipe shows "update available", and taking it means rebuild → re-verify → republish. Faults attach through **named slots** declared in the base app's source, never line-based patches, and the builder strips slot markers so students never see them.

Existing pieces reused:
- the jobs system (`backend/internal/jobs`, `Enqueue` with `IdempotencyKey`/`TimeoutMS`, handlers in `jobs/handlers/`)
- the `mindforge-validate-*` sandbox prefix (already cleaned by `LabCleanupHandler`)
- RBAC `authz.RequirePermission` and `middleware.RequirePlatformRole(pool, PlatformRoleSuperAdmin)`
- coursegen's UUIDv5 + idempotent-upsert sync pattern

## B1. Block types

Each block is a directory with `block.yaml` plus files:

```yaml
kind: fault                 # app | fault | data | stub | env | check | ticket | hints | rubric | custom
id: dj.perf.n-plus-one-list # stable, namespaced by stack
version: 1.2.0              # semver; stored identity = sha256 of the directory
stack: django               # django | fastapi | react | fullstack | any
title, summary, category, difficulty, skills[]
params:                     # JSON Schema; a param may declare `randomize: {choices|range}`
requires: [slot:orders.list.queryset, cap:postgres, data:rows>=5000]
provides: [...]
conflicts: [...]
```

Composition is a **capability algebra**. Blocks provide and require tokens of five kinds, and the slot rules apply on top:
- `slot:`
- `cap:` (e.g. `cap:celery`, `cap:tz-reports`)
- `data:<predicate>`
- `svc:`
- `env:`

| Kind | Contributes | Key fields | Author |
|---|---|---|---|
| **app** | A realistic small app with known-good tests: `dj-shop` (catalog, cart, orders, payments client, Celery, admin), `fa-orders` (async SQLAlchemy, Alembic, httpx, background tasks), `re-dashboard` (Vite/React, fetching, forms, context), `fs-shop` (re-dashboard + dj-shop) | `src/` with slot markers; `slots:` catalog (name, type, default, description); `history:` feature commits; `noise:` trivial commits; hidden `regression_tests/`; `visible_tests/`; `services:`; `ports`; `protected` globs | Platform |
| **fault** | One catalog entry, e.g. `dj.perf.n-plus-one-list`, `dj.data.naive-datetime`, `dj.conc.lost-update`, `xs.cors-credentials` | `inject:` (slot overrides, files, migrations); `fix:`; `cheats:` (overrides that must fail); `carrier:` (a real feature shipped in the same commit, so `git revert` fails regression); `commit:` (message template, persona, position); `checks:` (symptom/regression check refs + params); `symptom:` (ticket vars, expected log/trace signature); default `hints`/`rubric`; `chain:` | Platform |
| **data** | `seed.small`, `seed.prod-scale` (500k rows via `generate_series`), `seed.dirty` (NULLs, duplicates, legacy enum values), `seed.tz-spread` | One seeded generator used for both the dev seed and the grader fixtures; params for scale and dirtiness; `est_seed_seconds` | Platform (orgs save presets) |
| **stub** | `stub.payments`, `stub.inventory`, `stub.webhook-sender`, `stub.queue` | Process + fault API `POST /__fault {latency_ms, error_rate, contract_version}` | Platform |
| **env** | `env.prod-mode` (DEBUG off, static manifest, gunicorn), `env.missing-var:<NAME>`, `env.pin:<pkg>==<ver>` (wheelhouse only) | Settings overlay, supervisor flags, requirement pins | Platform |
| **check** | Probe kinds P/Q/C/M/L/H/T: `check.query-count`, `check.concurrent-invariant`, `check.latency-while`, `check.migrate-from-snapshot`, `check.http-contract`, `check.pytest-node` | Root-owned probe in `grader/lib/probes/*.py` + param schema (e.g. `{endpoint, rows:[10,500], max_queries:"const(≤5)"}`) + author-facing failure message | Platform |
| **ticket** | The student brief | Markdown template with `{{symptom.*}}`, `{{params.*}}`, `{{captured.trace}}` (filled from the build run); `red_herrings[]`; severity; reporter persona | Anyone composing |
| **hints / rubric** | 3-level hint ladder; key points + misconceptions | Defaults from the fault; the block overrides or extends them | Anyone composing |
| **custom** | Escape hatch: a full hand-made scenario (the old `_scenario/` layout) for things slots can't express (e.g. squashed-migration drift) | Only combines with ticket/hints/rubric | Platform |

## B2. Composition rules

**Slots** replace line-based patches:

```python
def order_list(request):
    # mf:slot orders.list.queryset
    orders = Order.objects.select_related("customer").prefetch_related("items__product")
    # mf:endslot
```

Slot types:
- `region`: replace a block, re-indented to the marker.
- `value`: replace a scalar, e.g. `USE_TZ = {{slot}}`.
- `file`: add or replace a whole file.
- `migration`: an ordered insertion point. The builder assigns the next number and rewrites `dependencies` / Alembic `down_revision`; this is what makes migration faults composable.

JS/TS uses `// mf:slot`. The builder strips every marker and **fails if any `mf:` remains**. Output is formatted afterwards (ruff/black, prettier) so slot regions look native. App CI renders the app with all slot defaults and runs its tests. Faults, fixes and cheats are all just slot overrides, so cheats compose automatically.

**Validation** is `internal/debuglabs/compose.Validate(recipe) []Issue`. It runs in Go on manifests only, in milliseconds, on every wizard step:
1. Stack match (block stack = app stack or `any`) and app semver range (`app: dj-shop@^1`).
2. Every `requires` is satisfied by the union of `provides`.
3. Slot exclusivity: one fault per slot, except explicit chains.
4. Chains: fault B declares `chain: {after: A, mode: masks|compounds}`.
   - `masks`: B's symptom only appears once A is fixed (e.g. the app won't start because of config; after that fix, the N+1 is visible).
   - `compounds`: both symptoms are visible at once.
   - Chains are acyclic, with at most 3 faults per recipe in v1.
5. Declared `conflicts` are rejected.
6. Check coverage: at least 1 symptom check per fault, and the app's regression suite covers each fault's `carrier` feature (tests are tagged by feature).
7. Budgets: estimated setup ≤ 25 s; workspace ≤ 2 MB; grader ≤ 512 KB.
8. Derived difficulty = the hardest fault, +1 for a `masks` chain, +1 for 2 or more red herrings. The author can override it.

**Multi-fault tasks:** a `masks` chain A→B generates Task 1a "A resolved" and Task 1b "B resolved" (both required), Task 2 regression, and Tasks 3–4 as before.

**Git history** is deterministic, with dates from the recipe seed and author personas from the app:
1. Scaffold commit.
2. The app's `history` feature commits.
3. The **fault commit**: the slot changes plus the `carrier` feature, with a realistic message like "orders: add customer tier badge to order list". By default it goes between the last 2–4 features. Chained faults get separate commits.
4. 1–3 noise commits.

`baseline_commit` is the commit before the first fault. Every commit builds, so `git bisect` works.

## B3. Build & verify pipeline

Jobs live in `jobs/handlers/debuglabs.go`, with `IdempotencyKey = recipe_hash`.

**`debug.scenario_build`**
1. **Resolve:** pin every block reference to a `debug_block_versions.id`, then compute `recipe_hash = sha256(canonical spec)`. If a verified build with the same hash already exists, reuse it and stop.
2. **Validate:** run `compose.Validate`.
3. **Enumerate variants:** the cartesian product of the variant axes (B6), capped at 8, each with a `variant_key`.
4. **Render:** start one sandbox `mindforge-validate-build-<id>` on `mindforge/lab-debug` and stream in the block payloads plus the resolved spec via `ExecStdin`. The image's `/opt/mindforge/mf-build` renders each variant: workspace (stripped markers, git history, `.vscode`, `TICKET.md`), grader bundle, `fix.diff`, and one diff per cheat. Rendering in the sandbox uses the exact git/python/node versions students get.
5. **Collect** via a new trusted-only `ContainerRuntime.ExecCapture(ctx, id, script, maxBytes)`, used by builder jobs only and capped at 16 MB. Today's `MaxExecOutputBytes` (256 KB) is too small.

**`debug.scenario_verify`** runs per variant. Each run is a fresh sandbox seeded exactly like a student session (`prepareLabEnvironment` debug branch), so verification exercises the real student path. Runs go in parallel up to the org validation cap of 5.

| Run | Expectation |
|---|---|
| broken | every symptom task fails; regression passes; measured setup ≤ 30 s |
| per chain step (fix A only, …) | the next fault's symptom fails, earlier ones pass |
| full fix | all tasks pass across 3 grader seeds (catches flaky probes) |
| each cheat | at least 1 required task fails |
| fix + `student-test` with the fault's reference test | fails on baseline, passes on the fix |

The broken run also **captures the real traceback, slow-query log or log excerpt** (per the fault's `symptom.capture`) into `captured.*`, which the ticket uses. Tickets show real output.

The build status moves `queued → rendering → verifying → verified | failed`, with a per-run report (task results, author messages, grader stdout/stderr, setup seconds) that the author polls live. **Publishing requires `status='verified'` for exactly the recipe hash being published.** This is enforced in the publish transaction, not just the UI.

**Cost control:**
- builds are deduplicated by `recipe_hash`
- Redis limit of 10 builds per instructor per day
- runs are metered as `validation_seconds` in `lab_usage_events`

## B4. Builder UI

**A wizard, not a canvas**, since the choices are linear and compatibility-filtered. It lives at `frontend/app/(app)/instructor/debug-labs/`:
- `page.tsx`: my recipes, build status, "update available".
- `new/` and `[recipeId]/`: a stepper (`components/debuglabs/builder/*`) with a live validation panel pinned on the right and a derived-difficulty badge.
  1. **Stack.**
  2. **Base app:** its features, slots and a screenshot.
  3. **Faults:** compatibility-filtered. Incompatible ones are greyed out with the reason ("needs cap:celery"). Adding a second fault offers chain mode.
  4. **Data:** suggested blocks first (from the faults' `requires`); scale and dirtiness params.
  5. **Stubs & env:** added automatically when required; optional extras.
  6. **Ticket:** rendered from the fault's symptom template. "Draft with AI" rewrites it in a persona voice, cached in `debug_ai_drafts` by `sha256(recipe_hash+persona)`. Red herrings are optional. `{{captured.trace}}` shows as a placeholder until the first build.
  7. **Checks:** defaults from the faults, with editable params. Symptom and regression checks can be tuned but not removed; extra checks can be added.
  8. **Hints & rubric:** merged defaults, editable.
  9. **Randomization:** toggle variant axes; shows "N variants will be built and verified".
  10. **Build & verify:** live run matrix, expandable logs, and the finished ticket with the real trace.
  11. **Preview as student:** an `is_test` session on a chosen variant.
  12. **Publish:** course, section, position, required/optional, max duration.
- `blocks/`: library browser. Filter by kind, stack and category; shows version history, changelog, which recipes and published labs use each block, and yanked status.

**Creating new blocks:**
- **Code blocks are repo-only:** a PR under `content/lab-blocks/` → CI `scripts/test-debug-blocks.py` (renders every app and runs every fault against its declared apps through the full matrix) → `coursegen blocks sync` on deploy.
- **Text blocks** are created in the UI by anyone with `labauthor.manage_blocks`, scoped to their org.

The reason for the split: code blocks run inside the sandboxes that grade students, so they need review, not a web form.

## B5. Storage — merged into migration 044 (neither part has shipped)

```sql
CREATE TABLE debug_blocks (
  id          UUID PRIMARY KEY,           -- UUIDv5(block id) for platform, random for org text blocks
  org_id      UUID REFERENCES orgs(id),   -- NULL = platform-shipped
  block_key   TEXT NOT NULL,
  kind        TEXT NOT NULL CHECK (kind IN ('app','fault','data','stub','env','check','ticket','hints','rubric','custom')),
  stack       TEXT NOT NULL CHECK (stack IN ('django','fastapi','react','fullstack','any')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (org_id, block_key)
);
CREATE TABLE debug_block_versions (        -- immutable
  id            UUID PRIMARY KEY,
  block_id      UUID NOT NULL REFERENCES debug_blocks(id),
  version       TEXT NOT NULL,
  content_hash  TEXT NOT NULL,
  manifest      JSONB NOT NULL,
  payload       BYTEA,                    -- tar.gz; NULL for text-only blocks
  changelog     TEXT,
  yanked_at     TIMESTAMPTZ, yanked_reason TEXT,
  created_by    UUID REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (block_id, version), UNIQUE (block_id, content_hash)
);
CREATE TABLE debug_recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES orgs(id), owner_id UUID NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  spec JSONB NOT NULL,                     -- [{block_version_id, params, role}], variant axes, overrides
  revision INT NOT NULL DEFAULT 1,
  lab_id UUID REFERENCES lab_definitions(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE debug_scenario_builds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES debug_recipes(id) ON DELETE CASCADE,
  recipe_hash TEXT NOT NULL, spec_snapshot JSONB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued','rendering','verifying','verified','failed')),
  job_id UUID, report JSONB, derived_difficulty TEXT,
  created_by UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(), finished_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX ON debug_scenario_builds (recipe_hash) WHERE status = 'verified';
CREATE TABLE debug_scenario_variants (      -- immutable; what sessions run
  build_id UUID NOT NULL REFERENCES debug_scenario_builds(id) ON DELETE CASCADE,
  variant_key TEXT NOT NULL,
  workspace_bundle BYTEA NOT NULL, grader_bundle BYTEA NOT NULL,
  brief_md TEXT NOT NULL, root_cause_md TEXT NOT NULL, fix_diff TEXT NOT NULL,
  rubric JSONB NOT NULL, hint_ladder JSONB NOT NULL, protected_manifest JSONB NOT NULL,
  baseline_commit TEXT NOT NULL, app_ports INT[] NOT NULL, ide_port INT NOT NULL DEFAULT 3000,
  PRIMARY KEY (build_id, variant_key)
);
CREATE TABLE debug_block_usages (
  build_id UUID REFERENCES debug_scenario_builds(id) ON DELETE CASCADE,
  block_version_id UUID REFERENCES debug_block_versions(id),
  PRIMARY KEY (build_id, block_version_id)
);
CREATE TABLE debug_ai_drafts (cache_key TEXT PRIMARY KEY, org_id UUID NOT NULL, kind TEXT NOT NULL,
  prompt TEXT NOT NULL, response TEXT NOT NULL, tokens_used INT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
-- lab_debug_scenarios (Part 1) becomes: (task_version_id PK, lab_id, build_id FK NOT NULL, stack, category, difficulty, skills)
ALTER TABLE lab_sessions ADD COLUMN variant_key TEXT;   -- chosen at session start, pinned
```

**Versioning guarantees:**
- Block versions are immutable.
- A recipe pins `block_version_id`s.
- A build freezes `spec_snapshot`.
- Publishing ties `lab_task_versions` to `build_id`.
- A session pins `task_version_id` and `variant_key`.

A new block version only shows "update available: 1.2.0 → 1.3.0 (changelog)". Taking it means new revision → build → verify → republish → new task version; in-flight sessions keep theirs. `yanked_at` blocks new builds with that version and lists the affected published labs, but never touches live labs automatically.

**Platform course content:** a lab `.md` gets `debug: {recipe: recipe.yaml}`, referencing `block_key@version`. Coursegen emits the lab rows **unpublished** plus a `debug_recipes` row, and enqueues `debug.scenario_build`. On `verified`, the same publish code path runs automatically. CI runs the same matrix.

**API** (`RequireAuth + RequireCSRF`, org scoping in queries):

| Method | Path | Guard |
|---|---|---|
| GET | `/api/instructor/lab-authoring/blocks?kind=&stack=&category=`, `/blocks/{id}` | `labauthor.compose` |
| POST/PUT/DELETE | `/api/instructor/lab-authoring/blocks` (text kinds, org-scoped) | `labauthor.manage_blocks` |
| CRUD | `/api/instructor/lab-authoring/recipes[/{id}]` | `labauthor.compose` (owner or same org) |
| POST | `/recipes/{id}/validate` (sync, no side effects) | `labauthor.compose` |
| POST | `/recipes/{id}/ticket-draft` (AI, cached) | `labauthor.compose` + LLM rate limit |
| POST | `/recipes/{id}/builds` → 202 `{build_id}`; GET `/builds/{id}` | `labauthor.compose` |
| POST | `/builds/{id}/preview-session` (is_test, variant) | `labauthor.compose` |
| POST | `/builds/{id}/publish` `{course_id, section_id, position, is_required}`: one transaction creating `course_modules(type='lab')` + `lab_definitions(lab_type='debug')` + tasks + `lab_task_versions` + `lab_debug_scenarios` | `courses.publish` + verified check |
| POST | `/api/admin/lab-authoring/blocks/{versionId}/yank` | `RequirePlatformRole(super_admin)` |

## B6. Randomization

Recipes declare **variant axes**:
- **Parameter axes:** params with `randomize` set — entity names, which endpoint carries the N+1, amount ranges, which env var is missing.
- **Fault pools:** "pick 1 of [`dj.perf.n-plus-one-list`, `dj.perf.n-plus-one-serializer`]". Pool members must pass the same validation, share a category, and have difficulty within ±1.

Part 1's tier 1 (random grader data on every Check) stays always on; tiers 2 and 3 become recipe axes. The build **materializes and verifies every variant** (at most 8), so nothing unverified reaches a session. At session start, `variant_key = variants[hash(user_id, lab_id) % N]`. That is stable per student, so retries, hints and the debrief stay consistent, while classmates get different variants. Hints and rubric are per variant.

## B7. Permissions

- **New codes** (module `labs`):
  - `labauthor.compose` → system `instructor` role.
  - `labauthor.manage_blocks` → `instructor` + org `admin`.
  - Publishing reuses `courses.publish`.
- **Code blocks** only arrive via repo PR + sync. The only runtime admin action is yank (`RequirePlatformRole(super_admin)`).
- **Org scoping:**
  - Platform blocks (`org_id NULL`) are visible to all orgs.
  - Org text blocks are visible only within their org.
  - Recipes, builds and published labs are org-owned.
  - A recipe can't reference another org's block; this is enforced in `Validate` and again in the build job.
- **Trust boundary:** org content is markdown and params only, rendered as text and never executed. Params are validated against the block's JSON Schema. String params that land in code go through a `value` slot with language-aware literal escaping (Python `repr`, JSON). No org input is pasted raw into source.

## B8. Revised phase plan (replaces Part 1 §10)

**Phase 0 — prerequisites (unchanged, implemented 2026-09-29 — see Part 1 §10):** ttyd/IDE HMAC auth; `ImageProfile.Elevated`; preview-traffic heartbeat; generic hint endpoint.

**Phase 1 — runtime + builder core, Django only**
1. Part 1 runtime: `lab-debug` image, `grade.sh`, `debug` lab type, bundle seeding, DebugWorkspace, debrief.
2. Block format; the `mf-build` renderer (slots, migration insertion, history, marker stripping); grader probe library P/Q/C/M/L/H/T; `coursegen blocks sync`; `scripts/test-debug-blocks.py`.
3. Migration 044 (merged schema); `internal/debuglabs/{compose,builder,repo,handler}`; jobs `debug.scenario_build` / `debug.scenario_verify`; `ExecCapture`.
4. Blocks:
   - app `dj-shop`
   - about 10 Django faults: DJ-PERF-1, PERF-4, DATA-1, DATA-4, DATA-5, CONC-2, CONC-3, MIG-1, MIG-3, SVC-1, CFG-1
   - data `seed.small` / `seed.prod-scale` / `seed.dirty`
   - stub `stub.payments`
   - env `env.prod-mode`
5. Builder UI v1: single fault plus an optional red herring; parameter axes only; template ticket (no AI); build & verify; preview; publish; read-only block library.
6. The 3 flagship labs as repo recipes, through the same pipeline.

**Phase 2 — builder depth:** multi-fault chains, fault pools, AI ticket drafting, org text blocks, update-available and yank flows.

**Phase 3 — FastAPI:** `fa-orders`, about 10 faults, the Alembic migration slot type, the latency harness.

**Phase 4 — React:** `re-dashboard`, JSX/TS slots, vitest/Profiler/listener harnesses, about 10 faults.

**Phase 5 — fullstack:** `fs-shop` and the XS faults; the `custom` block kind for anything that doesn't fit.

**Out of v1:** canvas UI, org-authored code blocks, AST codemods, cross-org sharing or a marketplace, automatic rebuild on block update.

## B9. Risks

- **Base apps are the critical path.** Slots must be designed for every fault up front, and adding a slot means a new app version that every recipe must rebuild onto. Design `dj-shop`'s slot catalog against the whole Django catalog before writing faults.
- **Scenarios may feel templated.** Mitigations: feature and noise commits, real captured traces, persona tickets, variants. Watch completion rates and "felt real" feedback.
- **Verification cost.** 8 variants × 5 cheats × a 2-fault chain is about 70 sandbox runs at 60–90 s each. Mitigations: hash dedupe, 5-parallel cap, variant cap of 8, daily build limit.
- **Flaky probes** would block publishing. The fix is verified over 3 seeds, and probes prefer counts over wall-clock time.
- **Slot leakage** could reveal where the bug is. Mitigations: marker stripping, a hard failure on any leftover `mf:`, and post-render formatting.
- **DB size:** about 20 MB per 8-variant build in bytea. Garbage-collect unpublished failed or superseded builds after 30 days; move to MinIO later if needed.

## Builder open questions

1. **Who composes:** every instructor by default, or platform staff first while the block library matures?
2. **Org-authored code blocks:** never, later with super_admin review, or in v1? (Recommended: never for v1.)
3. **Variant assignment:** stable per student (recommended), or a new variant on every retry?
4. **Build budget:** are about 70 sandbox runs for the largest recipe OK? What daily build cap per org or instructor?
5. **Check tuning:** may instructors only tighten thresholds, or tune freely within the block's allowed ranges?
6. **Platform repo labs** build before publish, so a fresh seed shows debug labs only after the build jobs finish (minutes). Is that acceptable, or should CI-built artifacts be committed or stored?
7. **Migrations:** merge Part 1's 044 and the builder schema into one migration (recommended, since neither has shipped)?

---

# Part 3 — "Add from library" into a course

Every item (existing lab, published debug lab, quiz, notes lesson) is pickable from a library and droppable into any course section at a chosen position.

## Part 3 implementation notes (2026-09-29)

L0-L5 below are implemented essentially as written, with these deviations:

- **Filters:** `GET /api/library` implements `type`/`q`/`cursor`/`limit` only. `stack`/`category`/`difficulty` aren't backed by any column on `lab_definitions`/`assessments`/`course_modules` today (no migration in L2 adds one), so they're not query params yet rather than being silently accepted and ignored — add them alongside whatever adds those columns (the Part 2 scenario-catalog work).
- **Quiz cross-org visibility:** L3 step 3 says a quiz may be "same org, or platform-public and published"; `assessments` has no platform-visibility column, so Phase A implements same-org-only (matching `library_visibility` exists on `lab_definitions` alone). Extend `assessments` the same way if cross-org quiz sharing is wanted.
- **Lab image-allowlist re-check:** Attach does not duplicate `StartSession`'s `lab_org_config`/`allowed_images` check at placement time (`ponytail:` comment in `service.go`) — an instructor can place a lab whose image isn't allowed for their org, and a student gets `ErrImageNotAllowed` at launch, same as any other image-restricted lab today. Add the earlier check only if instructors need that feedback at placement time instead.
- **Position:** the course-builder integration always appends ("Add from library" reuses the existing "Add module" menu next to the section's module list, not a new per-slot "+"); `Attach`'s `position` param still accepts an explicit index for a future per-slot UI or the builder's publish-then-attach path with no backend change needed.
- **Notes preview `content_body`:** returned as the raw stored string (may be markdown or the JSON `ContentBlock[]` shape course-wizard.tsx writes) — the picker renders it as-is; a nicer preview can reuse `frontend/lib/courses/markdown.ts`/the block renderer later.

## L0. Existing bugs this fixes first

1. **Forking a course breaks its lab modules** (verified).
   - `copySectionsAndModules` (`backend/internal/courses/repo.go` ~L1236) inserts new module rows with new ids.
   - Labs are looked up by `WHERE module_id=$1 AND org_id=$2` (`GetLabByModuleID`, `backend/internal/labs/repo.go:48`), so a forked lab module finds no lab. `docs/courses.md` claims forked labs stay linked; they don't.
   - A `module_id`-keyed lookup also can't place one lab in more than one module.
   - The fix is a `course_modules.lab_id` link, the same pattern `assessment_id` already uses.
2. **Import cycle:** `labs` already imports `courses`, so the lab-module insert can't live in `courses`. It goes in a new package `backend/internal/library` that imports courses, labs, assessment and debuglabs.

## L1. Reference or copy, per item

| Item | Mode | Why |
|---|---|---|
| Existing lab | Reference (`course_modules.lab_id`) | Sessions already pin `task_version_id`, so a republished lab reaches every placement safely; in-flight sessions keep their version. Same idea as course bundles. |
| Debug build | Reference to the `lab_definitions` row created when the recipe is published | Rebuild + republish cuts a new task version that reaches every placement; rebuilds are explicit, never automatic. |
| Quiz / assessment | Reference (`assessment_id`, as today) | Already the module link model; fork shares it too. Attempts are per assessment (open question 2). |
| Notes lesson | Copy (new row with `content_body` copied + `copied_from_module_id`) | Content lives in the row, and highlights, reflections and knowledge-check gates are keyed by module id; a live reference would need a new indirection everywhere. |
| Video / PDF | Copy sharing `storage_key` | Same as fork. |

"Detach and edit a copy" for org-owned labs is left out; it isn't needed yet.

## L2. Data model (fold into 044 if shipped together)

```sql
ALTER TABLE course_modules
  ADD COLUMN lab_id UUID REFERENCES lab_definitions(id) ON DELETE RESTRICT,
  ADD COLUMN lab_is_required BOOLEAN NOT NULL DEFAULT false,   -- gating is per placement, not per lab
  ADD COLUMN copied_from_module_id UUID REFERENCES course_modules(id) ON DELETE SET NULL;
UPDATE course_modules m SET lab_id = l.id, lab_is_required = l.is_required
  FROM lab_definitions l WHERE l.module_id = m.id AND m.type = 'lab';     -- backfill
-- relink already-forked lab modules via forked_from course + matching section/module position; report any left unmatched
ALTER TABLE course_modules ADD CONSTRAINT lab_module_has_lab
  CHECK ((type = 'lab') = (lab_id IS NOT NULL)) NOT VALID;   -- VALIDATE once the backfill report is clean
ALTER TABLE lab_definitions ADD COLUMN library_visibility TEXT NOT NULL DEFAULT 'org'
  CHECK (library_visibility IN ('private','org','platform'));
ALTER TABLE lab_sessions ADD COLUMN module_id UUID REFERENCES course_modules(id);  -- which placement launched it
CREATE INDEX ON course_modules (lab_id) WHERE lab_id IS NOT NULL;
```

Changes in `labs`:
- `GetLabByModuleID` resolves through `course_modules.lab_id`. Access requires the module's course org to equal the caller's org, and the lab to be either in the same org or `library_visibility='platform'`.
- Completion and unlock use `lab_sessions.module_id` + `lab_is_required`, so one lab placed in two courses completes the right module.
- `lab_definitions.module_id` / `is_required` become legacy fields and are no longer read on these paths.
- The course fork copies `lab_id` and `lab_is_required`, which fixes bug 1.

## L3. One shared insert path

`library.Service.Attach(ctx, actor, AttachReq{SectionID, Position, Kind, ItemID, Title?, IsRequired})` runs as one transaction:
1. Lock the section: `SELECT … FROM course_sections s JOIN courses c … WHERE s.id=$1 AND c.org_id=$actorOrg FOR UPDATE`.
2. Check the actor can edit the course (the same rule `CreateModule` applies today).
3. Check the item for its kind:
   - **Lab:** published, visible to the org, and its image allowed by `lab_org_config.allowed_images`.
   - **Debug build:** its lab is published from a `verified` build.
   - **Assessment:** same org, or platform-public and published.
   - **Notes:** the source module is readable by the actor.
4. Shift positions `>= Position` (the `UNIQUE (section_id, position)` constraint is deferrable).
5. Insert through a new `courses.Repo.InsertModuleTx(ctx, tx, …)`, reusing `CreateModule`'s column list.
6. Write the audit log and commit.

The builder's `/builds/{id}/publish` creates or updates the lab, cuts the task version, writes `lab_debug_scenarios`, then calls `Attach` with the same `tx`, so publishing into a section and picking from the library are one code path. `CreateModule` keeps rejecting `lab`; the only ways a lab module is inserted are `library.Attach` and coursegen fixtures (which also emit `lab_id`).

## L4. Endpoints (`backend/internal/library/routes.go`)

All routes use RequireAuth + RequireCSRF + `RequireOrgRole(owner, admin, instructor)`, the same guard as the module routes.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/library?type=lab,debug,quiz,notes&stack=&category=&difficulty=&q=&cursor=` | Searchable, paginated union of org items + platform-public published items. A query over `lab_definitions` (+ `lab_debug_scenarios` tags), `assessments` and notes modules; no new table. |
| GET | `/api/library/{kind}/{id}/preview` | Lab/debug: student-safe projection (`studentTaskView`) + tags; quiz: questions; notes: rendered body |
| POST | `/api/library/{kind}/{id}/try` | Try a lab or debug build as a student (`is_test` session, existing caps) |
| POST | `/api/sections/{sectionID}/library-items` | `Attach`; returns the new module |

## L5. Frontend

- `components/courses/course-builder.tsx`: the section menu gets **"Add from library"** and **"Create debug lab here"**, both carrying the insertion position from the "+" slot between modules.
- New `components/library/library-picker-dialog.tsx`: filters (type, stack, category, difficulty, search), cards with badges (Reference / Copy, Verified, difficulty), a preview pane, "Try it", "Add" → `POST …/library-items` → builder refresh.
- New `app/(app)/library/page.tsx`: the same list and preview as a standalone page, with "Add to course…" (pick course, section, position).
- `components/courses/module-editor.tsx`: a referenced lab or quiz shows "Linked: updates reach this course when the source is republished", a link to the source, and a per-placement **Required** toggle. Notes copies show "Copied from X".
- **"Create debug lab here"** opens `/instructor/debug-labs/new?course=…&section=…&position=…`. The recipe stores `target_placement` (JSONB on `debug_recipes`), the Publish step comes pre-filled, and publishing runs `Attach` in the same transaction; a failed build places nothing. The user lands back in the course editor with the new module highlighted.

## L6. Phase placement

This is the earliest user-visible win, and it fixes the fork bug, so it ships as **Phase A, before or alongside Phase 0**:
1. Migration: `lab_id`, `lab_is_required`, `lab_sessions.module_id`, `library_visibility`, `copied_from_module_id`, plus the backfill report.
2. `labs` resolves through `lab_id`; completion uses `module_id`; fork copies `lab_id`.
3. `library` package: `Attach` and the list/preview/try endpoints for **labs, quizzes and notes**.
4. Picker dialog, library page, module-editor link state.

When the builder ships in Phase 1, "debug build" becomes another library kind and `/builds/{id}/publish` reuses `Attach`. "Create debug lab here" ships with builder UI v1.

## Library open questions

1. **Cross-org platform content:** may any org place platform-shipped labs and debug labs in its own courses (`library_visibility='platform'`)? Sessions would count against the placing org's lab caps and usage.
2. **Shared quiz attempts:** if one quiz is placed in two courses, should an attempt in one count in the other (reference, today's behavior), or should quizzes be copied per course?
3. **Notes lessons as copies:** OK to add them as copies with a "source updated" badge and no automatic sync? Live-linked lessons need a bigger refactor.
4. **Required per placement:** should "required to unlock the next section" be set per placement (recommended), so the same lab can be required in one course and optional in another?
