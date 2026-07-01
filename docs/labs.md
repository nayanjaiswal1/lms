# Labs

Interactive, sandboxed lab environments attached to course modules. Students get a real terminal or code environment, complete verifiable tasks, and receive AI-driven hints and explanations. KodeKloud-style, self-hosted.

---

## Position in Learning Flow

Labs slot after the module quiz and before the next section:

```
Read lesson → Solve coding problem → Take quiz → Complete lab → Next section
```

Labs are optional per module — instructor decides whether a module has one. When `is_required = true`, the next section unlocks only once the student has a **completed** session for the lab — meaning *every non-optional task passed*, not just one. Passing some-but-not-all tasks records partial score but does not unlock. (See Progress & Scoring for the exact rule.)

---

## Lab Types

| Type | Description | Execution |
|---|---|---|
| `terminal` | Browser terminal → isolated Linux container | Docker + ttyd |
| `code` | In-browser editor + sandboxed runner | Piston (already wired) |
| `playground` | No tasks, free exploration, TTL only | Docker + ttyd |
| `guided` | Step-by-step tasks with inline AI hints | Docker + ttyd |

`terminal` and `guided` use the same container infrastructure. `code` reuses the existing Piston executor. `playground` is a `terminal` with no `lab_tasks` rows.

**`code`-type labs diverge from the container model — make this explicit so handlers branch on `lab_type`:**
- No Docker container, no `cmd/labproxy`, no WebSocket/PTY, no `ttyd`, no idle-pause/reset/egress.
- A `lab_sessions` row is still created (for scoring, progress, analytics) but `container_id`/
  `container_host` stay NULL and `status` goes straight `provisioning → running` with no readiness wait.
- Verification runs the student's submitted code through Piston (the existing sandboxed runner),
  not `docker exec`. `verification_script` for a `code` task is interpreted as the test harness/
  expected-output spec the Piston runner uses, not bash-in-container.
- Concurrency caps, hint/explanation AI, snapshot pinning, scoring, and usage metering
  (`ai_tokens` only — no `container_seconds`) all still apply. Container-specific edge cases
  (OOM, disk, ttyd, WS) do not.

---

## Architecture

```
Browser (xterm.js)
      │  WebSocket
      ▼
Lab Proxy Service (Go, :8081)   ←→   ttyd inside container (PTY over WS)
      │
      ▼
Main API (Go, :8080)
      │
      ├── PostgreSQL (session state, task completions, AI cache)
      ├── Redis (rate-limit windows, AI circuit-breaker state, WS-proxy pub/sub) — shared, never in-process
      ├── Docker Engine (container lifecycle)
      └── Claude API (hints, explanations, diagnosis, generation)
```

Redis holds all cross-replica state: verify/hint/session-start rate-limit windows, the AI
circuit-breaker open/closed flag, and the lab-proxy node↔session registry. None of this lives
in process memory — it must stay correct across multiple API and proxy replicas.

### Lab Proxy Service

Separate Go binary (`cmd/labproxy`). Responsibilities:
- Accepts WS connections from browser with a short-lived `session_token`
- Validates token against `lab_sessions` table before upgrading
- If the session is `paused`, calls the API to `docker unpause` and flip to `running` before upgrading
- Proxies bytes between browser WS and the container's ttyd WS
- Reports `last_active_at` heartbeat to DB on each WS message (debounced to ≤1 write/5s per session)
- Kills connection and marks session `expired` when TTL is hit

The proxy never runs user code directly. It relays to the container only.

**WS token lifecycle.** `session_token` is a 5-minute JWT, but sessions live up to 120 minutes.
The token only needs to be valid at the moment of WS upgrade — once upgraded, the connection
persists regardless of token expiry. For reconnects after the token has expired, the client
fetches a fresh one from `POST /api/labs/sessions/:sessionId/ws-token` (authenticated with the
user's main JWT, returns a new 5-minute `session_token`). The proxy never reads the user's main
JWT — only the scoped `session_token`.

### Container Runtime

- One Docker container per active `lab_session`
- Container name: `mindforge-lab-{session_id}-{reset_count}` — the `reset_count` suffix prevents a name
  collision during a staged reset, when the new container must exist before the old is removed.
  All runtime operations (exec, pause, stats, kill) address the container by the stored
  `lab_sessions.container_id`, never by name; the name exists only for the prefix-based
  `cleanup_dead_containers` sweep (`mindforge-lab-*`).
- Base images pre-built per lab type (stored in private registry):
  - `mindforge/lab-linux:24.04` — Ubuntu, common CLI tools
  - `mindforge/lab-k8s:1.31` — kubectl, minikube
  - `mindforge/lab-docker:27` — Docker-in-Docker (privileged)
  - `mindforge/lab-terraform:1.9` — Terraform, cloud CLIs
  - `mindforge/lab-python:3.12` — Python with common packages
- Resource limits enforced at container creation: 1 CPU, 512 MB RAM, 3 GB disk
- Network: isolated bridge network, no internet by default
  - Labs that need `apt install` use a whitelisted egress proxy
- `setup_script` runs once via `docker exec --user root` after container starts (so it can install
  packages / start services); the interactive shell and all verification scripts run as the
  unprivileged `labuser`. The two user contexts are deliberate — setup provisions, verify cannot tamper.
- ttyd runs as the non-root `labuser` inside the container

### Task Verification

Verification is always server-side. Flow:

```
Student clicks "Check" in UI
      ↓
POST /api/labs/sessions/:id/tasks/:taskId/verify
      ↓
Backend: docker exec --user labuser {container_id} bash -c "timeout 10 <verification_script>"
         (addresses the container by stored container_id, not name — survives staged resets)
      ↓
exit 0  → task marked passed, score updated, explanation AI call queued,
          then completion check: if every non-optional task in the session's
          pinned version is now passed → session.status = 'completed',
          completed_at = now(), course progress updated (see Progress & Scoring)
exit ≠0 → attempts++; stderr returned as hint context; failure diagnosis triggered at attempt 3
```

Verification scripts are bash. They check real container state (file presence, service status, command output). Never trust client claims.

**Atomicity.** Every verify mutates `lab_task_completions` (attempts/status) and possibly
`lab_sessions` (score, status) — these run in a single DB transaction. `attempts` and `hints_used`
are incremented with `UPDATE ... SET attempts = attempts + 1 RETURNING attempts` (atomic,
race-free), never read-modify-write in app code. The completion check uses `SELECT ... FOR UPDATE`
on the session row so two concurrent verifies can't both flip it to `completed`.

**Verify on a paused container.** If the session is `paused`, the verify handler unpauses the
container (and flips status to `running`) before `docker exec`, otherwise the exec hangs. This is
the same unpause path the proxy uses on reconnect — shared helper, not duplicated.

**The session always runs the pinned snapshot.** `docker exec` runs the `verification_script`
from `lab_task_versions.tasks` (pinned at session start), never the live `lab_tasks` row. An
instructor editing or republishing the lab cannot change a running session's behavior.

---

## Database Schema

```sql
-- Lab template — instructor creates once, attached to a course module (or standalone).
CREATE TABLE lab_definitions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           UUID        NOT NULL REFERENCES orgs(id),
  course_id        UUID        REFERENCES courses(id),       -- NULL for standalone labs
  module_id        UUID        REFERENCES course_modules(id),-- NULL for standalone / course-level labs
  scope            TEXT        NOT NULL DEFAULT 'module'
                     CHECK (scope IN ('module','course','standalone')),  -- standalone = practice lab, not gated to progress
  title            TEXT        NOT NULL,
  description      TEXT,
  lab_type         TEXT        NOT NULL CHECK (lab_type IN ('terminal','code','playground','guided')),
  environment      TEXT        NOT NULL,         -- Docker image (pinned by digest in prod) or 'piston:{language}'
  setup_script     TEXT,                         -- runs once on container start (as root)
  max_duration     INT         NOT NULL DEFAULT 60,   -- minutes
  max_resets       INT         NOT NULL DEFAULT 3,
  hint_penalty_pct INT         NOT NULL DEFAULT 0 CHECK (hint_penalty_pct BETWEEN 0 AND 100), -- % of a task's points docked per hint used
  is_required      BOOLEAN     NOT NULL DEFAULT false,
  is_published     BOOLEAN     NOT NULL DEFAULT false,
  published_version_id UUID,   -- the version new sessions pin; NULL until first publish (FK added after lab_task_versions exists)
  created_by       UUID        NOT NULL REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- A required lab MUST belong to a module (nothing to gate otherwise):
  CONSTRAINT required_lab_has_module CHECK (NOT is_required OR module_id IS NOT NULL),
  CONSTRAINT scope_module_consistency CHECK (
    (scope = 'standalone' AND module_id IS NULL) OR
    (scope = 'course'     AND course_id IS NOT NULL) OR
    (scope = 'module'     AND module_id IS NOT NULL)
  )
);

-- Ordered tasks within a lab. These rows are the *live editable* copy used by
-- the instructor builder. Running sessions never read this table directly — they
-- read an immutable snapshot in lab_task_versions (see below).
CREATE TABLE lab_tasks (
  id                    UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id                UUID  NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  position              INT   NOT NULL,
  title                 TEXT  NOT NULL,
  description           TEXT  NOT NULL,          -- markdown shown to student
  verification_script   TEXT  NOT NULL,          -- bash, runs inside container
  hint_context          TEXT,                    -- extra context fed to AI for hints
  explanation_context   TEXT,                    -- extra context fed to AI post-pass
  points                INT   NOT NULL DEFAULT 10,
  is_optional           BOOLEAN NOT NULL DEFAULT false,
  is_stateful           BOOLEAN NOT NULL DEFAULT false,  -- verify depends on state from earlier tasks
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lab_id, position)
);

-- Immutable snapshot of a lab's full task set, cut every time the lab is published.
-- A session pins exactly one version at start, so an instructor editing/republishing
-- a lab never changes the tasks, scripts, or scoring of any in-flight session.
CREATE TABLE lab_task_versions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id        UUID        NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  version       INT         NOT NULL,            -- monotonically increasing per lab
  tasks         JSONB       NOT NULL,            -- frozen array of full task rows (incl. scripts)
  published_by  UUID        NOT NULL REFERENCES users(id),
  published_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lab_id, version)
);

-- Resolve the circular reference now that both tables exist.
ALTER TABLE lab_definitions
  ADD CONSTRAINT lab_definitions_published_version_fk
  FOREIGN KEY (published_version_id) REFERENCES lab_task_versions(id);

-- One session per user attempt; maps 1:1 to a container lifecycle
CREATE TABLE lab_sessions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id           UUID        NOT NULL REFERENCES lab_definitions(id),
  task_version_id  UUID        NOT NULL REFERENCES lab_task_versions(id),  -- pinned snapshot
  user_id          UUID        NOT NULL REFERENCES users(id),
  org_id           UUID        NOT NULL REFERENCES orgs(id),
  container_id     TEXT,                          -- Docker container ID
  container_host   TEXT,                          -- internal host:port for proxy
  status           TEXT        NOT NULL DEFAULT 'provisioning'
                     CHECK (status IN ('provisioning','running','paused','completed','expired','failed','terminated_abuse')),
  reset_count      INT         NOT NULL DEFAULT 0,
  score            INT         NOT NULL DEFAULT 0,
  is_test          BOOLEAN     NOT NULL DEFAULT false,  -- instructor test sessions
  started_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ NOT NULL,          -- HARD wall-clock deadline: started_at + min(lab.max_duration, org.max_session_duration)
  paused_seconds   INT         NOT NULL DEFAULT 0,    -- cumulative idle-paused time (cost metric only; does NOT extend expires_at)
  completed_at     TIMESTAMPTZ,
  last_active_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Status semantics: reset is an *action* (reset_count++, re-provision), not a status —
-- a reset session stays 'running'. Terminal states: completed | expired | failed | terminated_abuse.
-- expires_at is a FIXED wall-clock deadline set at start and never moved. Idle-pause is purely a
-- compute-cost optimization (it stops CPU billing) — it does NOT extend the student's deadline, so
-- a paused session still expires exactly at expires_at. paused_seconds is recorded for cost
-- accounting only. (This avoids the bug where a session paused near expiry would either die early
-- or, if the clock were extended, live unboundedly past the org hard cap.)
-- At most one non-terminal (provisioning|running|paused) session per (user_id, lab_id):
CREATE UNIQUE INDEX lab_sessions_one_active
  ON lab_sessions (user_id, lab_id)
  WHERE status IN ('provisioning','running','paused');

-- Per-task completion state within a session
CREATE TABLE lab_task_completions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID        NOT NULL REFERENCES lab_sessions(id) ON DELETE CASCADE,
  task_id       UUID        NOT NULL,  -- task id from the session's pinned snapshot (lab_task_versions.tasks).
                                       -- Deliberately NO FK to live lab_tasks: the snapshot is the source of
                                       -- truth, and a live task may be edited/deleted while this row persists.
  status        TEXT        NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','passed','skipped')),
  attempts      INT         NOT NULL DEFAULT 0,
  hints_used    INT         NOT NULL DEFAULT 0,
  completed_at  TIMESTAMPTZ,
  UNIQUE (session_id, task_id)
);

-- AI interaction log — hints and explanations are cached forever (called once)
CREATE TABLE lab_ai_interactions (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id        UUID        NOT NULL REFERENCES lab_sessions(id) ON DELETE CASCADE,
  task_id           UUID,       -- snapshot task id (no FK to live lab_tasks; same reasoning as lab_task_completions)
  interaction_type  TEXT        NOT NULL CHECK (interaction_type IN ('hint','explain','diagnose','generate')),
  hint_level        INT,                         -- 1=nudge, 2=specific, 3=near-answer
  cache_key         TEXT,                        -- sha256(session_id + task_id + hint_level) for dedup
  prompt            TEXT        NOT NULL,
  response          TEXT        NOT NULL,
  tokens_used       INT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Org-level lab capacity config (enforced at session start).
-- A row is NOT guaranteed to exist for every org. When absent, the backend falls back to
-- platform defaults (defined as constants in config, not magic numbers): the column DEFAULTs
-- below are those same platform defaults, applied via COALESCE at read time.
CREATE TABLE lab_org_config (
  org_id                    UUID  PRIMARY KEY REFERENCES orgs(id),
  max_concurrent_sessions   INT   NOT NULL DEFAULT 20,
  max_session_duration      INT   NOT NULL DEFAULT 120,  -- minutes, hard cap
  allowed_images            TEXT[],              -- NULL = platform default images only (NOT all images)
  egress_proxy_enabled      BOOLEAN NOT NULL DEFAULT false,
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per-lab egress allowlist. Only consulted when egress_proxy_enabled is true for the org.
-- The egress proxy permits a container to reach ONLY these destinations; everything else is
-- denied. This is the allowlist counterpart to the global SSRF *deny*list in docs/infrastructure.md —
-- both are enforced: a host in the denylist is rejected even if an instructor allowlists it.
CREATE TABLE lab_egress_rules (
  id          UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id      UUID  NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  host        TEXT  NOT NULL,           -- FQDN or CIDR, e.g. 'archive.ubuntu.com', 'registry.npmjs.org'
  port        INT,                      -- NULL = any port
  protocol    TEXT  NOT NULL DEFAULT 'https' CHECK (protocol IN ('http','https','tcp')),
  reason      TEXT,                     -- instructor note: why this host is needed
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lab_id, host, port)
);

-- Usage ledger for cost attribution and abuse forensics. One row per metered event.
-- Append-only; never updated. A future billing system consumes this; for now it powers
-- per-org cost dashboards and the "this org is burning compute" alerts. (Katacoda lesson:
-- never run unlimited free compute blind — measure every session-second and AI token.)
CREATE TABLE lab_usage_events (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        UUID        NOT NULL REFERENCES orgs(id),
  session_id    UUID        REFERENCES lab_sessions(id) ON DELETE SET NULL,
  event_type    TEXT        NOT NULL CHECK (event_type IN ('container_seconds','ai_tokens','validation_seconds')),
  quantity      BIGINT      NOT NULL,   -- seconds, or tokens, depending on event_type
  image         TEXT,                   -- for container_seconds: which image (cost varies by image)
  recorded_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Daily-rolled analytics per lab (populated by lab_analytics_rollup job).
-- Pre-aggregated so the instructor analytics endpoint never scans raw session tables.
CREATE TABLE lab_analytics (
  lab_id              UUID        NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  day                 DATE        NOT NULL,
  sessions_started    INT         NOT NULL DEFAULT 0,
  sessions_completed  INT         NOT NULL DEFAULT 0,
  avg_duration_sec    INT         NOT NULL DEFAULT 0,
  avg_score           NUMERIC(6,2) NOT NULL DEFAULT 0,
  total_hints_used    INT         NOT NULL DEFAULT 0,
  per_task_pass_rate  JSONB       NOT NULL DEFAULT '{}',  -- { task_id: pass_rate_0_to_1 }
  computed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (lab_id, day)
);

-- Indexes
CREATE INDEX ON lab_definitions (course_id, module_id) WHERE is_published; -- section-unlock + "labs in module" lookup
CREATE INDEX ON lab_sessions (user_id, lab_id, status);  -- "has this user a completed session for this lab?" (unlock check)
CREATE INDEX ON lab_sessions (status, expires_at);       -- expiry/idle cleanup jobs (covers running AND paused)
CREATE INDEX ON lab_sessions (org_id, status);           -- concurrency check
CREATE INDEX ON lab_task_completions (session_id);
CREATE INDEX ON lab_egress_rules (lab_id);
CREATE INDEX ON lab_usage_events (org_id, recorded_at);  -- per-org cost rollups over a time window
-- cache_key is UNIQUE, not just indexed: the "AI called once" rule is enforced at the DB,
-- so two concurrent hint requests can't both insert. The handler does INSERT ... ON CONFLICT
-- (cache_key) DO NOTHING then reads the winning row — no app-level locking needed.
CREATE UNIQUE INDEX ON lab_ai_interactions (cache_key) WHERE cache_key IS NOT NULL;
```

---

## API Endpoints

### Student

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/labs/:labId` | Lab overview, **student-safe projection only**: title, type, duration, and per-task `{position, title, description, points, is_optional}`. **Never** returns `verification_script`, `hint_context`, `explanation_context`, or `solution_script` — exposing the verification script reveals the expected end-state (the answer). Those fields are instructor-only. |
| `POST` | `/api/labs/:labId/sessions` | Start session (idempotent via `Idempotency-Key`). Returns `202` + session in `provisioning` — **no WS token yet** (container not ready). Client waits for `running` via the events/poll path below. |
| `GET` | `/api/labs/sessions/:sessionId` | Session state + per-task completion status (same student-safe task projection — no scripts). Poll target for readiness. |
| `GET` | `/api/labs/sessions/:sessionId/events` | SSE stream: emits a single `ready` or `failed` event when provisioning resolves |
| `POST` | `/api/labs/sessions/:sessionId/ws-token` | Mint a fresh 5-min `session_token` for (re)connecting; only valid once `status='running'`; auth'd with the user's main JWT |
| `GET` | `/api/labs/sessions/:sessionId/ws` | WebSocket upgrade (lab proxy handles; validates `session_token`) |
| `POST` | `/api/labs/sessions/:sessionId/tasks/:taskId/verify` | Run verification script |
| `POST` | `/api/labs/sessions/:sessionId/verify-all` | Run every task's verification in order (cumulative for stateful labs) |
| `POST` | `/api/labs/sessions/:sessionId/tasks/:taskId/hint` | AI hint (level 1→2→3) |
| `POST` | `/api/labs/sessions/:sessionId/tasks/:taskId/skip` | Skip optional task |
| `POST` | `/api/labs/sessions/:sessionId/reset` | Reset container (staged: new container healthy before old is killed; costs 1 reset_count) |
| `POST` | `/api/labs/sessions/:sessionId/end` | End session early. Kills the container AND sets a terminal status in one transaction: `completed` if all non-optional tasks passed, else `expired` (partial score kept). Never leaves the session `running` — otherwise the one-active index and expiry job would leak it. |

### Instructor

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/instructor/labs` | Create lab definition |
| `PUT` | `/api/instructor/labs/:labId` | Update lab metadata |
| `POST` | `/api/instructor/labs/:labId/publish` | Publish lab. Validates: image exists (`docker manifest inspect`); ≥1 task **except `playground`** (task-free by design); and if `is_required`, at least one **non-optional** task must exist (else completion would be vacuously true and unlock for free — so a `playground` can never be `is_required`). Then **cuts a new `lab_task_versions` snapshot** (frozen tasks; empty array for playground) and sets `is_published=true` + `published_version_id`. New sessions pin the latest version; in-flight sessions keep their old pinned version. Re-publishing cuts a new version — never mutates an existing one. |
| `POST` | `/api/instructor/labs/:labId/tasks` | Add task |
| `PUT` | `/api/instructor/labs/:labId/tasks/:taskId` | Edit task |
| `DELETE` | `/api/instructor/labs/:labId/tasks/:taskId` | Remove task |
| `POST` | `/api/instructor/labs/:labId/reorder` | Reorder tasks (body: `[{task_id, position}]`) |
| `POST` | `/api/instructor/labs/:labId/generate` | **One-shot** AI task-list draft for an *existing* lab (quick "fill this lab with tasks" shortcut). Distinct from the conversational creation flow below — no session, no revision loop, no validation. Returns a draft the instructor pastes/edits. For full authoring use `/labs/creation`. |
| `GET`/`PUT` | `/api/instructor/labs/:labId/egress` | View / set the lab's `lab_egress_rules` allowlist (only effective when org egress proxy is enabled) |
| `POST` | `/api/instructor/labs/:labId/test-session` | Start instructor test session (is_test=true) |
| `GET` | `/api/instructor/labs/:labId/analytics` | Completion rates, avg time, common failure tasks |
| `GET` | `/api/admin/labs/usage` | Org-admin: per-org lab compute + AI-token usage from `lab_usage_events` over a window |

---

## AI Integration

All AI responses are cached forever. First call stores in `lab_ai_interactions`. Subsequent identical requests (`cache_key` match) return the stored row. No re-generation.

### Hint System (3 levels)

```
cache_key = sha256(session_id + task_id + hint_level)

Level 1 (first hint): Conceptual nudge — what approach to take
Level 2 (second hint): More specific — what command category or file to look at
Level 3 (third hint): Near-answer — the exact syntax with one gap for student to fill

Max 3 hints per task per session. Level 4+ returns level 3 cached response.
```

The cache key is scoped to `session_id`, not `user_id`. Hints are generated from the session's
live terminal history, so a hint produced in one attempt must not be replayed in a later attempt
of the same lab (the container state is different). Caching is still "called once" — once per
(session, task, level) — satisfying the AI-cached-forever rule without leaking stale context across
attempts.

Prompt context includes:
- Task title + description
- Last 50 lines of terminal history (see **Terminal history source** below — NOT `docker logs`)
- Current attempt count
- Hint level

> **Terminal history source.** ttyd serves an interactive **PTY**; its I/O does not appear in
> `docker logs` (which only captures the container's PID-1 stdout/stderr). The lab proxy is the
> only component that sees PTY traffic, so it maintains a bounded per-session **ring buffer**
> (last ~200 lines, capped in bytes) of terminal output, kept in Redis keyed by `session_id`.
> AI features read the buffer via an internal proxy/Redis call. For `code`-type labs (no PTY),
> the "history" is instead the student's last submitted source + Piston run output.

### Post-Completion Explanation (auto-triggered on task pass)

Queued as a background job after verification passes. Stored in `lab_ai_interactions` with `type='explain'`. Shown in the task panel when student clicks "Why did this work?".

Context: task description + what the student ran (slice of the PTY ring buffer from task start to pass time — see Terminal history source above; `docker logs` is not used).

### Failure Diagnosis (auto-triggered from attempt 3)

Triggered when a verify call fails with `attempts >= 3` **and** no diagnosis has been generated yet
for this (session, task) — guarded by the `lab_ai_interactions` cache so it fires once, not on
every failure past 3 (an exact `attempts = 3` check would silently never fire if attempts jumped
past 3 due to a prior diagnosis failure or a concurrent verify). Returns inline in the verify
response under the `diagnosis` field.

Context: verification script source + verification stderr + last 30 lines from the PTY ring buffer.

### Instructor Lab Generation (one-shot)

```
POST /api/instructor/labs/:labId/generate
Body: { "topic": "Kubernetes pod scheduling with taints and tolerations", "task_count": 5 }

Returns: [{ title, description, verification_script, hint_context, position }]
```

Output is a draft. Instructor reviews, edits scripts, then saves. AI output is never auto-committed to `lab_tasks`.

**Relationship to the conversational creation flow.** This endpoint is the lightweight path:
one Claude call, no conversation state, no self-validating containers, no version history. It is for
an instructor who already created a lab shell and wants tasks scaffolded quickly. The full
**AI Lab Creation Flow** (`/api/instructor/labs/creation/...`, below) is the rich path: stateful
conversation, cheap-plan-before-expensive-draft, delta revisions, script self-validation, rollback.
Both share the same `submit_draft` tool schema and the same post-generation static-analysis pass
(package-existence check, `bash -n`, `shellcheck`) so generated scripts get identical safety
treatment regardless of path. Neither auto-commits.

---

## Frontend Components

| Component | File path | Description |
|---|---|---|
| `LabLauncher` | `components/labs/lab-launcher.tsx` | Button + overview modal in module page; "Start Lab" CTA |
| `LabEnvironment` | `components/labs/lab-environment.tsx` | Full-screen layout wrapper |
| `LabTaskPanel` | `components/labs/lab-task-panel.tsx` | Left pane: task checklist + current task description |
| `LabTerminal` | `components/labs/lab-terminal.tsx` | Right pane: xterm.js terminal connected to WS |
| `LabTimer` | `components/labs/lab-timer.tsx` | Countdown from expires_at; red at 10 min remaining |
| `HintDrawer` | `components/labs/hint-drawer.tsx` | Slides in from right; shows AI hint; previous hints scrollable |
| `LabResetModal` | `components/labs/lab-reset-modal.tsx` | Confirm reset; shows resets remaining |
| `LabCompletionScreen` | `components/labs/lab-completion-screen.tsx` | Score, time, tasks passed/skipped, AI summary |
| `InstructorLabBuilder` | `components/instructor/lab-builder.tsx` | Drag-to-reorder tasks, script editor, AI generate, test session |

Terminal uses `xterm.js` + `@xterm/addon-fit` + `@xterm/addon-web-links`. Loaded via `next/dynamic` (client only, no SSR).

---

## Background Jobs

| Job | Schedule | Action |
|---|---|---|
| `expire_lab_sessions` | Every 60s | Find `status IN ('running','paused')` where `expires_at < now()` → if `container_id IS NOT NULL`, kill (or unpause-then-kill) the container; mark `expired`; record any passed-task score to course progress. Must include `paused`, or idle-paused sessions never expire and leak containers. `code` sessions (no container) are just marked `expired`. |
| `idle_pause_sessions` | Every 5 min | Find `status='running'`, `container_id IS NOT NULL` sessions with `last_active_at < now() - 15min` and no active WS in the proxy's Redis connection registry → `docker pause`; status → `paused`; record pause start |
| `resume_on_connect` | On WS connect / verify | If session is `paused`, `docker unpause`, add the just-ended pause duration to `paused_seconds` (cost metric — `expires_at` is NOT moved), status → `running`, before serving the request |
| `cleanup_dead_containers` | Every 10 min | Find containers named `mindforge-lab-*` with no matching `provisioning/running/paused` session → `docker rm -f`. Includes `provisioning` so a container mid-startup is never reaped as an orphan; only reaps containers whose session reached a terminal state or never existed. A 2-min grace on container age guards the provisioning window. |
| `test_session_cleanup` | Hourly | Delete `is_test=true` sessions older than 2 hours; kill their containers |
| `monitor_container_resources` | Every 60s | Over all non-terminal sessions **with `container_id IS NOT NULL`** (incl. playground; excludes container-less `code` labs): `docker stats` for CPU, `docker exec df` for disk. >90% CPU for >5 min with no WS activity → kill + `terminated_abuse`. Disk ≥95% → flag session, surface "disk full" on next interaction. Covers labs that never call verify. |
| `lab_analytics_rollup` | Daily 02:00 | Aggregate pass rates, avg time, hint usage per lab into `lab_analytics` table (UPSERT on `(lab_id, day)`) |
| `meter_usage` | On session/validation teardown + every 60s for live sessions | Append `container_seconds` (and `validation_seconds`) to `lab_usage_events`; AI token events are written inline when each AI call returns. Drives cost dashboards + over-budget alerts. |
| `purge_ai_interactions` | Daily 04:00 | Redact `prompt`/`response` on `lab_ai_interactions` older than 90 days (terminal history is PII); keep tokens/cache_key/timestamps for analytics. |

---

## Edge Cases

### Session Lifecycle

| Case | Handling |
|---|---|
| **TTL expires mid-task** | `expire_lab_sessions` job kills container, marks `expired`. Completed tasks are kept. No resume after expiry — user starts a new session from scratch. |
| **Browser tab closed / disconnect** | Container keeps running until `expires_at`. WS reconnect re-attaches via session_id + fresh WS token. `last_active_at` gap triggers idle pause at 15 min. |
| **User opens lab in two tabs** | Second WS connection is accepted (proxy allows multiple readers). Both tabs share the same PTY. This is fine — KodeKloud allows it too. |
| **User navigates away and returns** | `GET /sessions/:id` returns current state. If `running`, show "Resume Lab" button. If `expired`, show "Start New Attempt". |
| **Session stuck in `provisioning`** | Container start timeout is 30s. If container doesn't reach `running` in 30s, mark session `failed`, surface error to user, allow retry. |

### Container / Environment

| Case | Handling |
|---|---|
| **User corrupts the environment** | Reset button: kill container, provision new one with same image + setup_script. Deducts from `reset_count`. Completed tasks persist. At `max_resets`, reset button is disabled — user must end session. |
| **Reset wipes state a passed stateful task depended on** | A reset rebuilds the container from `setup_script` only — any state a student created (a running container, a file, a configured service) is gone, even though the `passed` row for the task that created it persists. Later `is_stateful` tasks can then fail because their prerequisite is missing. Handling: on reset, the verify endpoint re-evaluates downstream stateful tasks lazily — when the student next verifies a stateful task whose upstream state is absent, the UI shows "This task depends on earlier setup that the reset cleared; re-run the earlier steps." Passed scores are never revoked, but the student must rebuild state to progress. Labs with heavy cross-task state should mark those tasks `is_stateful: true` so the builder warns the instructor that reset is destructive for them. |
| **Verification script hangs** | Wrapped with `timeout 10 bash -c "..."`. Returns "Verification timed out — check if the process is still running" as the error. |
| **Container OOM killed** | Docker restart policy is `no`. Session detects dead container on next verify/WS call → auto-mark `failed` with "Environment crashed — please reset". |
| **Disk quota exceeded** | Docker `--storage-opt size=3G`. Container pauses on limit. Verify returns "Disk full — reset or delete files". |
| **setup_script fails** | Captured stdout/stderr logged to session. Session marked `failed`. Error shown to student: "Lab environment failed to initialize". Instructor sees full stderr in test sessions. |
| **Container image not found** | Validated at lab publish time (`docker manifest inspect`). Publish blocked if image pull fails. Students never hit this at runtime. |
| **Docker daemon unreachable** | Provision call returns 503. Student sees "Lab service unavailable". No session created. Retryable. |

### Verification

| Case | Handling |
|---|---|
| **Student clicks verify before doing anything** | Script runs, fails fast (exit ≠ 0). `attempts++`. Normal failure path. |
| **Student clicks verify repeatedly (spam)** | Rate limit: 1 verify per task per 3 seconds (Redis sliding window). 429 returned otherwise. |
| **Double-click races on verify button** | Button disabled immediately on first click, re-enabled on response. Server-side: if task already `passed`, verify returns cached pass immediately (idempotent). |
| **Verification script has a bug** | Instructor catches this in test sessions. If a student hits a broken script, they can skip the task (if optional) or contact instructor. Analytics will show 0% pass rate, flagging it. |
| **Malicious verification script** | Instructors are org-admins (trusted). Verification runs inside the user container — no host mount, no privileged mode. Worst case: student's own container is affected. |

### AI

| Case | Handling |
|---|---|
| **Hint request spam** | Max 3 hints per task per session (enforced in DB: `hints_used` column). Beyond level 3, return level 3 cached response. No new AI calls. |
| **Same prompt, different sessions** | `cache_key = sha256(session_id + task_id + hint_level)` — per-session cache. The same user retrying a lab in a new session gets fresh hints generated against that session's terminal state; a stale hint from a prior attempt is never replayed. |
| **Claude API down** | Hint/explain endpoints return 503 with `"AI service unavailable"`. Verify still works — verification is independent of AI. |
| **Explanation job fails** | Queued as a background job. On failure, retried 3 times with exponential backoff. If all retries fail, explanation simply won't appear in the UI. Non-blocking. |
| **AI generates bad verification script** | Generate endpoint returns a draft only. Instructor must review and save explicitly. No auto-commit. Instructor test session validates scripts before publishing. |

### Multi-tenancy / Concurrency

| Case | Handling |
|---|---|
| **Org exceeds concurrent session limit** | `POST /sessions` enforces the cap atomically, not check-then-insert (which races: two simultaneous starts both pass a naive count). The handler takes a Postgres advisory lock keyed on `org_id` (`pg_advisory_xact_lock(hashtext(org_id))`), counts non-terminal sessions for the org inside the same transaction, inserts the new session, then releases on commit. Two concurrent starts serialize; the second sees the first's row and gets 429 "Lab capacity reached, try again shortly." The org cap falls back to the platform default when no `lab_org_config` row exists (COALESCE). |
| **User exceeds per-user concurrency** | The partial unique index `lab_sessions_one_active (user_id, lab_id) WHERE status IN ('provisioning','running','paused')` makes a duplicate active session for the same lab a DB-level constraint violation, not an app-level check. The 2-concurrent-sessions-across-all-labs cap is enforced inside the same advisory-locked transaction as the org cap. |
| **Two users start same lab at same time** | Each gets their own container and session. No shared state. Fully isolated. |
| **Same user POSTs /sessions again while one is active** | Whether via a repeated `Idempotency-Key` or a fresh one, the handler must return the existing active session (200 with that session), not surface the raw `lab_sessions_one_active` unique-violation as a 500. The handler catches the conflict and resolves to the current active session. |
| **`verify` / `verify-all` spam** | Per-task verify is 1/3s (Redis). `verify-all` has its own limit (1 per 10s per session) since one call fans out to every task's `docker exec`; otherwise it's a cheap way to spawn many execs. |
| **Instructor edits lab while student is in session** | `lab_tasks` is the live editable copy; sessions never read it. Each session pins `task_version_id` → an immutable `lab_task_versions` snapshot cut at publish time. An instructor editing tasks and re-publishing cuts a *new* version; in-flight sessions keep their pinned version for their whole lifetime — same scripts, same scoring, same task order. There is no live-read path that could change a running session. |
| **Lab deleted while sessions are active** | Soft-delete only (`is_published = false`). Active sessions run to completion. Hard-delete blocked if any `status IN ('running','paused')` sessions exist. |

### Progress & Scoring

| Case | Handling |
|---|---|
| **Student ends session without completing all tasks** | Partial score (sum of passed tasks' points, after any hint penalty) is always recorded to progress. But a *required* lab only counts toward **section unlock** when the session is `completed` (all non-optional tasks passed) — partial passes never unlock. Optional labs never gate unlock regardless. |
| **Required lab blocks section unlock** | "Required tasks" = tasks with `is_optional=false`. A session reaches `status='completed'` (set by the verify handler's completion check, not a job) when every non-optional task in its pinned version is passed. Section unlock requires: for **every** lab in the module with `is_required=true`, the user has at least one `completed` session. Multiple required labs in one module → all must be completed. |
| **Who transitions a session to `completed`** | The verify handler. After marking a task passed, inside the same transaction it checks (under `SELECT ... FOR UPDATE`) whether all non-optional tasks in the pinned version are now passed; if so it sets `status='completed'`, `completed_at`, and writes course progress. `POST /sessions/:id/end` also lands a terminal status (`completed` if all non-optional passed, else `expired`) so no path leaves a session stuck in `running`. No background job ever sets `completed` — only verify and end do. |
| **Session expired before all tasks done** | Expired sessions still count earned score. Course progress updated with partial score. Required lab remains unblocked (student must start new session and pass remaining required tasks). |
| **Instructor test sessions** | `is_test=true` sessions never update course progress, never count toward analytics, container removed within 2 hours. |

### Terminal & WebSocket (xterm.js Production Issues)

| Case | Handling |
|---|---|
| **PTY WebSocket closes silently** | The WS `onclose` event is not always fired on network drop or container restart. Implement a heartbeat ping/pong every 15s. If 2 consecutive pings are missed, treat as disconnected and trigger reconnect. |
| **Terminal becomes unresponsive (blinking cursor, no input)** | Reported on KodeKloud and in xterm.js issues. Caused by a stale PTY state after WS reconnection. On reconnect, send a `\r` (carriage return) to the PTY to reset the prompt state. If still unresponsive after 3s, offer "Refresh terminal" button that tears down and recreates the xterm.js instance without ending the session. |
| **Blacked-out / corrupt cell artifacts** | xterm.js rendering bug on resize. Fix: debounce terminal resize events by 150ms using `@xterm/addon-fit`. Never call `fit()` during a WS write. |
| **Raw control JSON appearing in terminal output** | Control frames (resize commands, metadata) are prefixed with a `0x00` byte. The proxy must filter these before writing to xterm. Filter: if `data[0] === 0x00`, parse as control; else write to terminal. |
| **Double-send to WebSocket** | Known xterm.js issue — `onData` fires twice for some paste events. Deduplicate on the proxy side: discard if identical payload received within 10ms on same session. |
| **WS reconnect exponential backoff** | On disconnect: retry after 1s, 2s, 4s, 8s, then give up and show "Connection lost — reconnect" button. Don't retry indefinitely (burns connections on a dead container). |
| **Terminal resize after reconnect wrong size** | xterm.js loses track of terminal dimensions after reconnect. On every WS reconnect, immediately send a resize control frame with the current `cols` × `rows` from `addon-fit`. |
| **Copy-paste large text into terminal** | Large pastes (~10KB+) can flood the PTY input buffer and hang the terminal. Chunk large pastes into 512-byte segments with 50ms delay between chunks via the proxy. |

### Container Security (Hardening Beyond Defaults)

| Case | Handling |
|---|---|
| **Container escape via runC / kernel exploit** | Never run lab containers directly on the host Docker daemon with default settings. Apply: `--security-opt seccomp=<profile>`, `--security-opt apparmor=docker-default`, `--cap-drop ALL`, `--cap-add` only the specific capabilities each lab image actually needs. For highest-risk labs (Docker-in-Docker), use Kata Containers or Firecracker microVMs instead of standard Docker. |
| **Docker socket mounted into container** | The Docker socket (`/var/run/docker.sock`) must never be mounted into any lab container. This gives the container full host Docker API access — game over. Blocked at container creation time; any image that specifies a socket mount in its entrypoint is rejected. |
| **Oversized HTTP requests bypass auth plugins** | CVE-2026-34040 class: attackers send oversized requests to the Docker API to bypass authorization. Mitigate: run the Docker daemon behind a reverse proxy with request body size limits (max 1MB for API calls), and use `--authorization-plugin` with an allowlist of permitted operations. |
| **Privilege escalation via SUID binaries** | Lab images must not contain SUID binaries beyond what the base OS ships. Custom images go through an automated scan (`trivy` or `grype`) before being allowed in `lab_org_config.allowed_images`. Any image with unexpected SUID binaries is rejected. |
| **Capabilities creep** | Each container starts with `--cap-drop ALL`. Lab images declare their required capabilities in a manifest (e.g., `lab-docker` needs `SYS_ADMIN` for DinD). Backend adds only the declared caps. Anything not declared is never granted. |
| **Namespace collision between containers** | All lab containers are on isolated bridge networks with randomly-assigned subnets. No two active sessions share a network. User/PID namespaces are isolated per container (`--userns-remap`). |
| **Container metadata service access** | On cloud-hosted deployments (AWS/GCP), the instance metadata service (169.254.169.254) must be blocked via iptables rules on the host, not just the container network. Containers could otherwise steal instance credentials. Added to the host bootstrap script. |

### AI Hallucination & Structured Output Failures

| Case | Handling |
|---|---|
| **AI invents non-existent packages in setup_script** | Research shows 19.7% of LLM-recommended packages are fabricated. After generation, statically scan `setup_script` and all verification scripts for `apt install`, `pip install`, `npm install` calls. For each package name, query the respective registry API to confirm existence before validation runs. Flag unresolved packages as `hallucinated_dependency`. |
| **Verification script is schema-valid but semantically wrong** | Claude's `tool_use` strict parameter does not guarantee semantic correctness — only shape. A script can exit 0 for any input if the logic is wrong. This is exactly what validation (step 5) catches. Do not skip validation on "simple" labs. |
| **Claude's tool_use doesn't enforce strict schema** | Claude makes best effort but does not guarantee argument schema compliance for tool definitions. Every tool response must be validated against the schema with a Go struct unmarshalling pass before use. On unmarshal failure: retry the AI call once with the error appended to the prompt ("Previous response failed schema validation: <error>. Retry."). On second failure: return 422 to the frontend with the raw response for instructor inspection. |
| **Markdown code fences wrapping JSON output** | Even with tool_use, Claude occasionally wraps JSON in ` ```json ``` ` fences. Strip fence markers before unmarshalling. Trim leading/trailing whitespace and ` ```json ` / ` ``` ` patterns. |
| **Trailing commas / single quotes in generated scripts** | Static bash linting: run `bash -n <script>` as part of the post-generation static analysis pass. Scripts that fail `bash -n` are sent back to the AI for correction before showing to instructor. |
| **AI hallucinates a working path that doesn't exist in the image** | Verification script references `/usr/local/bin/somecli` that isn't in the image. Caught during validation (command not found → exit non-zero). Self-correction prompt includes the exact stderr: "Command not found: /usr/local/bin/somecli. Verify this binary exists in mindforge/lab-linux:24.04 or use an alternative." |
| **AI generates verification logic that is always-true** | Static analysis detects single-statement scripts that can only exit 0 (e.g., `echo "done"`). Pattern: parse the AST with `shellcheck --format=json`; flag scripts with no conditional exit. Flagged scripts are auto-rejected and sent back to AI before showing to instructor. |
| **AI generates security vulnerabilities in scripts** | Research: 29–45% of LLM-generated code contains security vulnerabilities. Run `shellcheck` on all generated scripts. Flag: command injection patterns (`eval`, unquoted variables in exec contexts), world-writable file creation, `chmod 777`. Flagged patterns are highlighted inline in the Monaco editor for instructor review. |
| **Schema-valid but semantically hallucinated content** | e.g., AI returns a verification script that tests the wrong thing (checks nginx is running instead of checking the correct port). This is not detectable by static analysis or schema validation. Caught only by: (a) validation against the AI's own solution_script, (b) instructor's test session, (c) post-publish analytics (abnormally high or low pass rates). |
| **AI partial_revision corrupts task positions** | If a revision response omits the `position` field for a task, merging the delta would create a position collision. Validate delta before merging: all returned positions must exist in the current draft. Missing positions are rejected; AI is retried with the current draft state. |
| **Context window overflow on large creation sessions** | Long revision chains (20+ rounds) may push the message history past Claude's context window. Strategy: after 10 rounds of revision, summarize earlier conversation turns into a single "History summary" system message using a separate Claude call (haiku, cheap). Full recent messages (last 5) remain verbatim. |

### Resource Abuse & Cost Control

| Case | Handling |
|---|---|
| **Container farming** (spinning up containers without doing lab work) | Rate limit `POST /sessions`: max 5 session starts per user per hour. Max 2 concurrent active sessions per user across all labs. Org-level cap enforced separately via `lab_org_config.max_concurrent_sessions`. |
| **Cryptocurrency mining inside containers** | CPU throttling enforced at Docker level (`--cpus 1.0`). Background job monitors per-container CPU usage every 60s via `docker stats`. Any container sustaining >90% CPU for >5 minutes without any WS activity is flagged and killed. Session marked `terminated_abuse`. |
| **Runaway AI retry storms** (exponential backoff misimplemented) | All AI calls use a circuit breaker whose state lives in **Redis**, not process memory — at 2+ API replicas an in-process breaker would be inconsistent (one replica open, another still hammering Claude). After 3 consecutive Claude failures within 60s the shared circuit opens for 2 minutes; all AI endpoints across all replicas return 503 during the open state. Prevents cascading spend when the API is degraded. |
| **Instructor runs validation in a loop** (repeated validate clicks) | Validate endpoint is idempotent per draft version: if `current_draft` hasn't changed since last validation, return cached `validation_results` immediately. No new containers spun up. |
| **Student leaves container idle for entire TTL** | Idle detection: if `last_active_at < now() - 15min` and no open WS connection, `docker pause`. This stops CPU billing without destroying state. Container is unpaused on next WS connect. At `expires_at`, container is killed regardless. |
| **Playground / no-task labs escape verify-triggered monitoring** | Disk and abuse checks are described as "triggered by verify calls," but `playground` labs have no tasks and never call verify. So those checks must not hang off the verify path alone. The `docker stats` CPU job (every 60s) and a dedicated `monitor_container_resources` job (disk via `docker exec df`, every 5 min, over ALL non-terminal sessions regardless of type) cover playgrounds. Verify-time checks are an optimization, not the only path. |
| **Cost spike from many concurrent validation runs** | Validation containers are resource-limited (0.5 CPU, 256 MB RAM, 1 GB disk) since they run scripts briefly and are discarded. Org-level cap: max 5 simultaneous validation containers per org (queue others). |
| **Token cost runaway on creation sessions** | `total_tokens_used` tracked per session. Soft limit 100k: warning shown. Hard limit 200k: AI calls blocked. Instructor must approve current draft or start a new session. This prevents a single bad revision loop from consuming the org's entire AI budget. |
| **Abuse via AI generation endpoint** (mass lab generation) | `POST /creation` rate-limited to 3 new creation sessions per instructor per day. AI message endpoint rate-limited to 30 messages per creation session per hour. |

---

## Security

- **Container isolation**: Each container gets its own network namespace. No inter-container routing. Bridge network has no host access.
- **No privileged mode** (except `lab-docker` image which requires it for Docker-in-Docker — restricted to authorized org plans).
- **WS auth**: Lab proxy validates `session_token` (short-lived JWT, 5-minute TTL, issued at `POST /sessions` and `POST /sessions/:id/ws-token`) before upgrading. Token is not the user's main JWT. Claims are bound to `{ session_id, user_id }`, so a token minted for one session cannot be replayed against another, and a token cannot be used by a different user.
- **Verification runs as non-root**: `docker exec --user labuser` — verification script cannot write to system paths. `setup_script` is the only thing that runs as root, and only once at provision.
- **SSRF denylist**: Containers on isolated network by default. Egress proxy (for labs that need internet) enforces the global SSRF denylist from `docs/infrastructure.md`.
- **Image allowlist**: `lab_org_config.allowed_images` restricts which Docker images an org can use. NULL = platform defaults only.
- **Rate limits**: Verify: 1/3s per task. Hints: 3 total per task. Session start: 5/hour per user (prevents container farming).
- **Object-level authorization (IDOR)**: every `/sessions/:id/*` endpoint (verify, hint, skip, reset, end, ws-token, GET) verifies `session.user_id == caller` before acting — a valid JWT for user A must never operate on user B's session. Every `/instructor/labs/:labId/*` endpoint verifies the lab's `org_id == caller.org_id` and the caller holds the instructor role (`RequireRole`). Org scoping is checked in the query (`WHERE org_id = $caller_org`), not just middleware.
- **`solution_script` is never exposed**: it exists only inside `lab_creation_sessions.current_draft` / `lab_draft_versions` for validation. It is stripped on `approve` — never written to `lab_tasks`, never copied into `lab_task_versions`, never present in any student- or proxy-facing payload. Leaking it would hand students every answer.

### App-Layer Hardening (Scalability · Maintainability · DB · Leaks)

| Concern | Decision |
|---|---|
| **`docker exec` exhausts API workers** | Verify/validation are synchronous and can block up to 10s. Each runs through a bounded semaphore (worker pool) per node — not unbounded goroutines — so a verify storm can't starve HTTP handlers. Over the limit → 429 with retry-after, never an unbounded queue. |
| **Reset is destructive if provision fails** | Reset is staged: provision the new container and confirm it reaches `running` BEFORE killing the old one and incrementing `reset_count`. If the new container fails, the old one stays and the session is unchanged (error surfaced). No window where a `running` session has no container. |
| **Pre-warm pool & validation container orphans** | Pool containers use the `mindforge-pool-*` prefix and validation containers `mindforge-validate-*`. `cleanup_dead_containers` reconciles all three prefixes (`lab`/`pool`/`validate`) against live state so a crashed node never leaks pooled or validation containers. |
| **Hard-deleting a task referenced by a live session** | `DELETE /tasks/:taskId` is blocked if the task's `id` appears in any pinned `lab_task_versions` belonging to a non-terminal session. Edits go to a new version; the snapshot the session runs is never mutated or removed under it. |
| **Status enums drift between DB and Go** | All status/enum string sets (session status, creation status, message_type, interaction_type) have a single source of truth in Go constants; the CHECK constraints mirror them. A migration test asserts the Go set equals the DB CHECK set so they can't silently diverge. |
| **Advisory-lock hotspot on session start** | The per-`org_id` advisory lock held during the concurrency check is sub-millisecond (one COUNT + one INSERT). It serializes only same-org starts, not the whole platform. If a single mega-org ever contends, shard the lock key by `org_id + (user_id % N)`. |
| **Heartbeat write amplification** | The proxy debounces `last_active_at` to ≤1 write / 5s / session, so 5,000 active terminals don't translate to thousands of row updates per second. Idle detection tolerates the 5s granularity. |
| **`is_test` sessions and caps** | Instructor test sessions are excluded from the org/user concurrency caps (instructors shouldn't be blocked by student load) but are themselves capped at 2 concurrent per instructor and force-cleaned at 2h, so they can't be used to farm containers. |

---

## AI Lab Creation Flow

A complete conversational system for instructors to create labs using AI. The instructor describes what they want — the AI designs, generates, validates, and revises the entire lab through a back-and-forth conversation. The instructor reviews and approves; nothing is auto-committed.

---

### Philosophy

- AI is the author, instructor is the editor. AI writes the first draft; humans approve it.
- Cheap pass before expensive pass. AI generates a task outline (no scripts) first. Instructor corrects intent misalignment before the expensive full generation.
- Nothing auto-saves. Every AI output is a draft until the instructor explicitly approves.
- Self-healing scripts. AI validates its own verification scripts in disposable containers and self-corrects before showing results to the instructor.
- Full history. Every draft version is snapshotted. Instructor can roll back to any prior state.

---

### Creation State Machine

```
intent ──► planning ──► generating ──► reviewing ──► validating ──► completed
                                           │                │
                                           ▼                ▼
                                        revising        self-correct (up to 3x)
                                           │                │
                                           └──► generating  └──► needs_manual_review (flagged, not blocked)

Any state ──► abandoned  (instructor leaves; preserved 7 days for resume)
```

| State | What's happening | Who acts next |
|---|---|---|
| `intent` | AI is gathering topic, type, difficulty, task count, duration | Instructor |
| `planning` | AI shows task outline (titles only, no scripts); instructor reviews | Instructor |
| `generating` | AI is writing full tasks, scripts, hints (streaming) | AI |
| `reviewing` | Full draft shown; instructor accepts, edits, or requests revisions | Instructor |
| `revising` | Instructor sent a change; AI is updating only the affected tasks (delta) | AI |
| `validating` | Verification scripts are being tested in disposable containers | System |
| `completed` | Instructor approved; tasks saved to `lab_tasks`; creation session closed | — |
| `abandoned` | Inactive > 24h or instructor manually abandoned; preserved 7 days for resume | — |

---

### Conversation Model

Every instructor message goes through a single endpoint. The AI responds with a typed response that drives the state machine:

```
POST /api/instructor/labs/creation/:creationId/message
Body: { "content": "Make task 3 harder and add a task about overlay networks" }

AI response types (each maps 1:1 to a tool in the Tool Schema below):
  chat             → plain conversational message (clarifying question, explanation)   [no tool — plain text]
  intent_complete  → AI has gathered all intent fields; ready to plan                  [submit_intent]
  plan             → numbered task outline (titles + 1-line descriptions only)         [submit_plan]
  draft            → full lab spec JSON (all tasks with scripts, hints, explanations)  [submit_draft]
  partial_revision → delta of changed tasks only; merged into current draft            [submit_partial_revision]
  validation_start → AI signals it's ready to trigger script validation                [request_validation]
  ready_to_save    → AI signals draft is complete and validated; prompts approval      [signal_ready_to_save]
  flag_issue       → AI flags an impossible task / bad environment constraint          [flag_issue]
```

System-generated (not AI) message types also stored in the thread: `validation_result` (written by
the validation engine after a run) and `error` (written on an AI/transport failure). These two never
come from a tool — the backend appends them.

Context sent to Claude on every call:
1. System prompt (role, constraints, environment context, current intent)
2. Full message history for this creation session (conversation thread)
3. Current draft JSON (if one exists)
4. Validation results (if validation has run)

---

### Step-by-Step Flow

#### Step 1 — Intent Gathering (`intent`)

Instructor clicks "Create Lab with AI". AI asks for:

| Field | How gathered |
|---|---|
| `topic` | Instructor's opening message |
| `lab_type` | terminal / code / guided / playground |
| `environment` | Inferred from topic (Docker → `lab-docker:27`) or instructor specifies |
| `difficulty` | beginner / intermediate / advanced |
| `task_count` | 3–10 (AI suggests based on topic scope) |
| `duration_minutes` | 15 / 30 / 45 / 60 / 90 |
| `focus_areas` | Specific concepts to cover (e.g., "bridge networks, host mode, not overlay") |
| `custom_setup` | Any pre-configuration needed (packages, files, running services) |

If the instructor's first message contains enough information (e.g., "Create a 5-task intermediate Docker networking lab covering bridge and host networks, 45 minutes"), the AI skips the Q&A and goes straight to planning. No forced wizard steps.

An `IntentFormCard` can appear inline in the chat if the AI needs structured input (e.g., dropdown for `environment`) rather than parsing free text.

#### Step 2 — Planning (`planning`)

AI generates a numbered task outline — **titles and one-line descriptions only, no scripts**. Shown as a scannable list, not a wall of text.

Example:
```
1. Inspect the default Docker networks
   List all networks and identify their drivers.

2. Create a custom bridge network
   Create a bridge network named "app-net" with a custom subnet.

3. Connect two containers on the same bridge
   Launch nginx and curl containers; verify curl can reach nginx by name.

4. Expose a container port to the host
   Publish port 80 to host port 8080; verify from host.

5. Observe host network mode
   Run a container with --network host; compare available ports.
```

Instructor can respond with:
- "Looks good" → move to generating
- "Swap tasks 2 and 3"
- "Remove task 5, add one about none network mode"
- "Make it harder — assume intermediate Docker knowledge"
- "Start over, I want to focus on overlay networks instead"

This step is cheap (no scripts). It catches intent misalignment before the expensive generation.

#### Step 3 — Full Generation (`generating`)

AI generates the complete lab spec JSON. This is the expensive call (4k–10k tokens for a 5–10 task lab). Streamed to the UI so the instructor sees tasks appear one by one.

Output structure:
```json
{
  "title": "Docker Network Fundamentals",
  "description": "...",
  "lab_type": "terminal",
  "environment": "mindforge/lab-docker:27",
  "setup_script": "docker network prune -f || true",
  "max_duration": 45,
  "max_resets": 3,
  "tasks": [
    {
      "position": 1,
      "title": "Inspect the default Docker networks",
      "description": "List all Docker networks on this host...",
      "verification_script": "docker network ls --format '{{.Driver}}' | grep -q bridge && docker network ls --format '{{.Driver}}' | grep -q host",
      "solution_script": "docker network ls",
      "hint_context": "The docker network command has a subcommand for listing resources",
      "explanation_context": "Docker ships with three default networks: bridge, host, and none...",
      "points": 10,
      "is_optional": false,
      "is_stateful": false
    }
  ]
}
```

Note `solution_script` — the AI writes what the student would run to pass the task. Used only for validation, never shown to students.

`is_stateful: true` means this task's verification depends on state set by previous tasks (e.g., a container that was started in task 2). Used to determine whether to validate tasks independently or cumulatively.

#### Step 4 — Review & Revision Loop (`reviewing` ↔ `revising`)

Full draft is shown in `DraftPreviewPanel`. Each task card displays:
- Title + description (rendered markdown)
- Verification script (Monaco, syntax highlighted, editable inline)
- Hint context + explanation context (collapsible)
- Per-task actions: Edit · Regenerate this task · Delete

Instructor can either edit manually (inline Monaco) or send a natural language revision instruction. Natural language revision targets only the mentioned tasks — AI generates a delta, not a full redraft:

```
"Make task 3's verification script more strict — also check the container name, not just that something is running"
→ AI returns partial_revision: { tasks_changed: [3], updated_tasks: [...] }
→ Current draft is updated at position 3 only
→ New draft version snapshot created
```

The revision loop can repeat as many times as needed. Each round trips to Claude once.

#### Step 5 — Script Validation (`validating`)

Triggered automatically before final approval (can also be triggered manually mid-review). Runs task by task:

**For stateless tasks** (`is_stateful: false`) — each task validated independently:
```
1. Spin up test container (same image + setup_script)
2. Run solution_script inside container
3. Run verification_script inside container
4. Exit 0 → PASS; else FAIL
5. Tear down container
```

**For stateful tasks** (`is_stateful: true`) — validated cumulatively in one container:
```
Container starts with setup_script
  → solution_script[1] → verify[1] → PASS/FAIL
  → solution_script[2] → verify[2] → PASS/FAIL
  → solution_script[3] → verify[3] → PASS/FAIL
  → tear down
```

**Self-correction loop on FAIL:**
```
Validate task N → FAIL
  → Send verification_script + solution_script + error to AI
  → AI revises one or both scripts
  → Re-validate (attempt 2)
    → PASS → mark validated ✓
    → FAIL → re-validate (attempt 3)
      → PASS → mark validated ✓
      → FAIL → mark needs_manual_review ⚠ (don't block, flag it)
```

Validation results are shown per task in `ValidationStatusPanel`:
- `validated` ✓ — script tested and confirmed working
- `needs_manual_review` ⚠ — AI couldn't self-correct; instructor should test manually in a test session
- `skipped` — validation not run (instructor chose to skip or validating was not triggered)

#### Step 6 — Approve & Save (`completed`)

Instructor clicks "Save Lab". Triggers `POST /creation/:id/approve`:
1. Full draft JSON is written to `lab_tasks` (bulk insert) — **`solution_script` is dropped here**; it was validation-only and must never reach a student-readable table
2. `lab_definitions` row is created with the draft's metadata
3. `lab_creation_sessions.lab_id` is set
4. Session status → `completed`
5. Lab is saved as `is_published = false` — instructor still needs to publish manually (publish is what cuts the first `lab_task_versions` snapshot)
6. Instructor is redirected to the normal lab builder to make final edits or publish

Steps 1–5 run in a single transaction — a partial approve (tasks written but lab_id unset) must never be possible.

---

### Database Schema (AI Creation)

```sql
-- AI creation conversation session (one per lab being created)
CREATE TABLE lab_creation_sessions (
  id                  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id              UUID    REFERENCES lab_definitions(id),  -- NULL until approved
  org_id              UUID    NOT NULL REFERENCES orgs(id),
  created_by          UUID    NOT NULL REFERENCES users(id),
  status              TEXT    NOT NULL DEFAULT 'intent'
                        CHECK (status IN ('intent','planning','generating','reviewing','revising','validating','completed','abandoned')),
  intent              JSONB,                  -- gathered fields: topic, type, difficulty, task_count, etc.
  current_draft       JSONB,                  -- full live draft (updated on every AI revision)
  draft_version       INT     NOT NULL DEFAULT 0,
  validation_results  JSONB,                  -- { task_position: { status, error, attempts } }
  total_tokens_used   INT     NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at        TIMESTAMPTZ
);

-- Full conversation thread for a creation session
CREATE TABLE lab_creation_messages (
  id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  creation_id     UUID    NOT NULL REFERENCES lab_creation_sessions(id) ON DELETE CASCADE,
  role            TEXT    NOT NULL CHECK (role IN ('user','assistant','system')),
  content         TEXT    NOT NULL,
  message_type    TEXT    NOT NULL DEFAULT 'chat'
                    CHECK (message_type IN (
                      'chat','intent_complete','plan','draft','partial_revision',
                      'validation_start','ready_to_save','flag_issue',  -- AI/tool-driven
                      'validation_result','error'                       -- system-generated
                    )),
  metadata        JSONB,                  -- e.g., { "draft_version": 2, "tasks_changed": [3] }
  tokens_used     INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Versioned snapshots of the draft at each AI revision (for rollback)
CREATE TABLE lab_draft_versions (
  id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  creation_id     UUID    NOT NULL REFERENCES lab_creation_sessions(id) ON DELETE CASCADE,
  version         INT     NOT NULL,
  draft           JSONB   NOT NULL,           -- full lab spec snapshot
  change_summary  TEXT,                       -- AI-written diff summary
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (creation_id, version)
);

-- Indexes
CREATE INDEX ON lab_creation_sessions (created_by, status);
CREATE INDEX ON lab_creation_sessions (org_id, status);
CREATE INDEX ON lab_creation_messages (creation_id, created_at);
CREATE INDEX ON lab_draft_versions (creation_id, version);
```

---

### API Endpoints (AI Creation)

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/instructor/labs/creation` | Start a new AI creation session |
| `GET` | `/api/instructor/labs/creation` | List in-progress and recent creation sessions for this instructor |
| `GET` | `/api/instructor/labs/creation/:creationId` | Get session state, current draft, validation results |
| `POST` | `/api/instructor/labs/creation/:creationId/message` | Send a message to the AI (intent answer, revision, approval signal) |
| `GET` | `/api/instructor/labs/creation/:creationId/messages` | Get full conversation thread |
| `GET` | `/api/instructor/labs/creation/:creationId/draft` | Get current draft as typed JSON |
| `PUT` | `/api/instructor/labs/creation/:creationId/draft/task/:position` | Manually edit a task in the draft (bypasses AI) |
| `DELETE` | `/api/instructor/labs/creation/:creationId/draft/task/:position` | Remove a task from the draft |
| `POST` | `/api/instructor/labs/creation/:creationId/validate` | Trigger script validation on the current draft |
| `POST` | `/api/instructor/labs/creation/:creationId/approve` | Save draft → lab_tasks; mark session completed |
| `POST` | `/api/instructor/labs/creation/:creationId/abandon` | Mark as abandoned |
| `GET` | `/api/instructor/labs/creation/:creationId/versions` | List all draft version snapshots |
| `POST` | `/api/instructor/labs/creation/:creationId/versions/:version/restore` | Restore a specific version as the current draft |

---

### AI Prompting Strategy

#### System Prompt (sent on every call)

```
You are a lab designer for MindForge, a technical learning platform.
You help instructors create hands-on, verifiable labs for students.

Current lab context:
  - Environment: {environment} ({lab_type})
  - Target audience: {difficulty}
  - Network: containers are isolated by default (no internet unless egress proxy enabled)

Rules for verification scripts:
  - Must be bash; exit 0 = pass, non-zero = fail
  - Check real system state: file presence, service status, port availability, command output
  - Never check shell history — check state only
  - Always write a meaningful error to stderr on failure
  - Wrap in subshells where the check itself could corrupt state
  - Use: timeout 10 bash -c "..." wrappers for commands that may hang

Rules for descriptions:
  - Markdown; 3–6 sentences max
  - State the goal and expected outcome — not the method
  - Do not give away the answer

Rules for hints:
  - Suggest the concept or command category, not the exact syntax
  - Escalate specificity: level 1 = concept, level 2 = approach, level 3 = near-answer

When returning structured data always use the tool schema provided.
When you cannot complete a task (broken environment constraint, impossible verification),
say so explicitly rather than generating a placeholder.
```

#### Tool Schema (structured output via tool_use)

Claude uses `tool_use` to return structured lab data instead of free-form JSON. This ensures the backend can parse responses reliably without prompt-engineering the output format.

Tools defined (one per AI response type — the backend dispatches on which tool was called):
- `submit_intent` — finalises gathered intent fields → `intent_complete`
- `submit_plan` — returns ordered task outline (title + summary per task) → `plan`
- `submit_draft` — returns full lab spec (all task fields) → `draft`
- `submit_partial_revision` — returns only changed tasks with their new data → `partial_revision`
- `request_validation` — signals validation should run → `validation_start`
- `signal_ready_to_save` — signals the draft is complete and validated → `ready_to_save`
- `flag_issue` — flags a specific problem (impossible task, bad environment, etc.) → `flag_issue`

A turn with no tool call is a plain `chat` message. The backend rejects (and retries once) any
assistant turn that calls an unknown tool or none when one was required by the current state.

---

### Frontend Components (AI Creation)

| Component | File path | Description |
|---|---|---|
| `LabCreationEntry` | `components/instructor/lab-creation-entry.tsx` | Landing — "Create Lab with AI" button + resume in-progress sessions list |
| `LabCreationWizard` | `components/instructor/lab-creation-wizard.tsx` | Root container; owns state machine; renders correct sub-view per status |
| `LabCreationChat` | `components/instructor/lab-creation-chat.tsx` | Chat thread — user bubbles, AI bubbles, typed message cards |
| `IntentFormCard` | `components/instructor/intent-form-card.tsx` | Structured intent form embedded in chat when AI needs specific fields |
| `TaskOutlineReview` | `components/instructor/task-outline-review.tsx` | Numbered list of task titles/summaries for plan-phase review; inline edit per item |
| `DraftPreviewPanel` | `components/instructor/draft-preview-panel.tsx` | Full draft view; expandable task cards; per-task Edit / Regenerate / Delete |
| `TaskDraftCard` | `components/instructor/task-draft-card.tsx` | Single task card: description preview + Monaco script editor + validation badge |
| `RevisionInput` | `components/instructor/revision-input.tsx` | Natural language input at the bottom of the draft: "Make task 3 harder" |
| `ValidationStatusPanel` | `components/instructor/validation-status-panel.tsx` | Per-task validation progress: pending / running / validated / needs_review |
| `DraftVersionSidebar` | `components/instructor/draft-version-sidebar.tsx` | Collapsible history of all versions with change summaries and Restore button |
| `LabCreationSummary` | `components/instructor/lab-creation-summary.tsx` | Final approval screen: task count, duration, type, validation summary, Save button |

All AI streaming responses are consumed via SSE on the message endpoint. The chat UI appends tokens as they arrive.

> **Streaming exception (CLAUDE.md rule 9 — "no streaming unless explicitly needed").** The
> conversational creation flow is an explicit exception: full draft generation is a 4k–10k-token
> call that would otherwise leave the instructor staring at a spinner for 20–40s. Streaming is
> scoped to *this* endpoint only — student-facing hints, explanations, diagnosis, and the one-shot
> generate endpoint all remain non-streaming for predictable cost. Token cost is still bounded by
> the per-session `total_tokens_used` soft/hard caps, so streaming does not weaken cost control.

---

### Edge Cases — AI Creation Flow

#### Intent Gathering

| Case | Handling |
|---|---|
| **Instructor provides all intent upfront** | AI skips Q&A, goes straight to planning. No forced form wizard. |
| **Contradictory intent** (e.g., "beginner" + "Kubernetes RBAC webhook admission") | AI flags the conflict explicitly: "This topic is usually advanced. Should I keep it beginner-friendly by simplifying the scope, or match the topic difficulty?" Instructor resolves before generation. |
| **Topic changes mid-conversation** | AI asks: "Should I start over with this new topic, or incorporate it into the current draft?" — never assumes. |
| **Environment incompatible with topic** (e.g., `code` type requested for network labs) | AI corrects and explains: "Network labs need a terminal environment. I've selected `mindforge/lab-linux:24.04`. Let me know if you prefer a different image." |
| **Instructor asks for unsupported environment** | AI lists available images from the platform config. If the requested image doesn't exist, offers the closest match. |
| **Task count outside 3–10 range** | AI warns: <3 tasks makes a lab feel thin; >10 tasks exceeds typical session length. Suggests an adjusted count. Instructor can override. |

#### Planning Phase

| Case | Handling |
|---|---|
| **Instructor rejects entire plan** | AI asks what was wrong (too easy? wrong focus? bad order?) before generating a new plan. Prevents re-generating the same mistake. |
| **Instructor wants task that the environment can't support** | AI flags which image constraint is violated and either suggests an environment change or an alternative task that achieves the same learning goal. |
| **Instructor's reorder makes tasks logically backward** (task N requires state from task N+3) | AI notes the dependency when generating the full draft. Marks affected tasks `is_stateful: true` and reorders them automatically, explaining the change. |
| **Instructor doesn't respond for 30+ minutes during planning** | Session stays in `planning`. On return, UI shows full conversation history. No timeout during planning — only during validation (which has running containers). |

#### Generation

| Case | Handling |
|---|---|
| **Large lab (10 tasks) exceeds single Claude response** | Generate in two batches (tasks 1–5, then 6–10). Merge results. Shown as a single draft. |
| **AI generates duplicate task titles or overlapping verification logic** | Post-processing dedup check compares titles and verification scripts. Duplicates flagged inline before showing draft to instructor. |
| **Claude API timeout mid-generation** | Partial draft saved to `current_draft`. Remaining tasks stored as `{ "position": N, "status": "pending_generation" }`. Instructor sees a "Generation interrupted — resume?" banner. Resuming triggers a new AI call to complete only the missing tasks. |
| **AI generates a trivially passing verification script** (`exit 0` or always true) | Static analysis on the Go backend detects single-line always-true scripts before saving to the draft. Flagged as `invalid_verification` and sent back to AI for revision automatically. |
| **AI writes a setup_script that requires internet on an isolated image** | System prompt explicitly states the network constraint. If AI still produces it (e.g., `apt install curl`), validation catches it (the test container has no internet). Self-correction loop fires. |
| **AI generates solution_script that fails in validation** | AI sees its own solution didn't work and revises both the solution and the verification script together. |

#### Revision Loop

| Case | Handling |
|---|---|
| **Instructor manually edits a task, then asks AI to modify the same task** | AI receives the manually edited version as ground truth (current_draft is always the source). Manual edits are never overwritten by subsequent AI revisions unless the instructor specifically asks to regenerate that task. |
| **"Start over" requested after many revisions** | Current draft is archived as a version snapshot. A new planning pass begins (preserving the intent). Instructor can still restore the old draft from version history. |
| **Revision loop exceeds 10 rounds without approval** | At round 10, the UI surfaces: "You've revised this lab 10 times. Want to save your current draft and come back to it later?" to prevent unbounded token spend. |
| **Token budget exceeded** | `total_tokens_used` is tracked. At 100k tokens: warning banner shown. At 200k: AI calls blocked for this session; instructor must approve current draft or start a new session. |
| **Instructor asks AI to add a task between two existing stateful tasks** | AI inserts the new task and re-evaluates `is_stateful` for the surrounding tasks. Validation must re-run for all stateful tasks after the insertion point. |

#### Validation

| Case | Handling |
|---|---|
| **Validation container fails to start** | Task marked `needs_manual_review`. Validation continues for other tasks. Error logged. |
| **Solution_script hangs inside validation container** | `timeout 60` wrapper applied to solution execution. On timeout: AI is told "solution timed out" and revises it. |
| **Self-correction fails all 3 attempts** | Task marked `needs_manual_review ⚠`. Instructor is informed: "This task's script couldn't be auto-validated. Test it manually using a test session." Approval is not blocked. |
| **Stateful validation: task N fails but task N-1 passed** | Only task N is sent back to AI for self-correction. The container state up to task N-1's solution is preserved in the cumulative run. |
| **Validation passes but logic is wrong** (script exits 0 for wrong answer) | Validation only confirms scripts aren't broken — not that they test the right thing. This is the instructor's responsibility to verify in a test session before publishing. Analytics (low pass rates) surface logic bugs post-publish. |
| **Instructor triggers validation before generation is complete** | Rejected with 409: "Cannot validate while generation is in progress." |
| **Validation takes too long** (10 tasks × stateful) | Validation runs with a 10-minute hard cap. If not complete by then, remaining tasks are marked `skipped_validation`. Instructor notified. |

#### Approval & Save

| Case | Handling |
|---|---|
| **Instructor approves with `needs_manual_review` tasks present** | Allowed. Warning shown: "N tasks need manual verification. Publish after testing in a test session." Not blocked — instructor may know the scripts are fine. |
| **Instructor approves then immediately wants to edit** | Lab is `is_published=false`. Redirect to normal lab builder. Creation session is `completed` and read-only. All edits go through the standard lab builder UI from this point. |
| **Duplicate lab approved** (instructor runs creation twice for the same module) | Both create separate `lab_definitions` rows. Module can have multiple labs. Instructor manually assigns which one to the module. |
| **Creation session abandoned** | Row preserved for 7 days with full message history and draft. "Resume" option shown when instructor opens lab creation again. Auto-deleted after 7 days via background job. |
| **Resume after days away** | Full conversation history loaded. Current draft loaded into `DraftPreviewPanel`. AI context is reconstructed from message history — no state loss. |

---

### Background Jobs (AI Creation)

| Job | Schedule | Action |
|---|---|---|
| `cleanup_abandoned_creation_sessions` | Daily 03:00 | Delete `lab_creation_sessions` with `status='abandoned'` older than 7 days; cascade deletes messages and version snapshots |
| `auto_abandon_inactive_sessions` | Hourly | Mark sessions with `status NOT IN ('completed','abandoned')` and `updated_at < now() - 24h` as `abandoned` |
| `cleanup_validation_containers` | Every 10 min | Find containers named `mindforge-validate-*` older than 15 min → `docker rm -f` (catches orphans from crashed validation runs) |

---

## Scalability, Optimization & Platform Lessons

Research-backed guidance from production deployments (Katacoda, Instruqt, Killercoda) and academic literature on serverless cold starts, WebSocket scaling, and container orchestration.

---

### Cold Start Latency (Container Pre-warming)

Cold start is the single biggest UX problem for lab platforms. Users clicking "Start Lab" and waiting 15–30s for a container is a drop-off moment.

**Measured reality:** Container cold start latency varies up to 100× across runtime configurations. Unoptimized images with heavy dependencies can take 5–15s just to pull and start. The goal is sub-3s perceived start time for the student.

**Strategy — Layer 1: Image optimization**
- All lab images are multi-stage builds. Final image contains only the runtime, not build tools.
- Images are pre-pulled and cached on every host node (`docker pull` on node join, refreshed nightly).
- Use slim base images. `mindforge/lab-linux:24.04` is based on `ubuntu:24.04-slim`, not full Ubuntu.
- Minimize layers. Each `RUN` instruction is a layer add cost. Combine related commands.

**Strategy — Layer 2: Pre-warmed container pool**

For high-traffic lab images (the most-used environments), maintain a pool of started-but-unassigned containers:

```
Pre-warm pool per image (configurable):
  mindforge/lab-linux:24.04  → pool size: 10
  mindforge/lab-k8s:1.31     → pool size: 5
  others                     → pool size: 2 (on-demand)

On session start:
  1. Check if pool has an available container for the requested image
  2. If yes: assign container to session instantly → sub-500ms start
  3. If no: provision new container normally → 3–8s start
  4. Async: replenish pool after each assignment

Pool containers are kept alive but have setup_script run per-assignment (not per-start),
so each student gets a clean environment even from the pool.
```

**Strategy — Layer 3: Predictive pre-warming (Phase 5)**
- Track hourly lab start rates per image per day of week
- Use a sliding window forecast to pre-warm containers before anticipated demand spikes
- Example: if K8s labs peak Mon–Thu 6–9pm, pre-warm starts at 5:45pm

**Strategy — Layer 4: Checkpoint/restore (Phase 5)**
- Use CRIU (Checkpoint/Restore In Userspace) to snapshot a freshly initialized container to disk
- Restore from checkpoint instead of cold-starting: 300–500ms vs 5–8s for heavy images
- Trade-off: checkpoint size on disk (~500MB–2GB per image). Acceptable at scale.

---

### WebSocket Proxy Scaling

The Lab Proxy Service handles all WS connections. This is the stateful bottleneck.

**Problem:** WebSockets are long-lived, stateful connections. Standard HTTP load balancing (round-robin) will break them. A request that starts on Server A and reconnects to Server B will fail because Server B has no PTY handle for that session.

**Solution: Sticky sessions + connection registry**

```
Architecture (multi-node lab proxy):

Browser ──► Load Balancer (sticky by session_id cookie)
                │
         ┌──────┴──────┐
         ▼             ▼
    Proxy Node A   Proxy Node B
    (holds PTY A)  (holds PTY B)
         │             │
    Container A    Container B
```

Sticky sessions: the load balancer (NGINX/Envoy) pins each `session_id` to the same proxy node using a consistent-hash upstream. If a node dies, the session is re-established on another node (PTY state is lost — container is still running, student reconnects and gets a fresh PTY but session history is gone).

**Capacity:** A single well-tuned Go proxy node on 4 cores handles ~5,000 concurrent WS connections at sub-50ms latency. For 1,000 concurrent lab users: 1 proxy node is sufficient initially. Scale horizontally when node CPU sustains >70%.

**Heartbeat:** Proxy sends a ping frame every 15s. If no pong within 5s, connection is treated as dead. Client-side: `xterm.js` sends a pong and resets the reconnect backoff timer.

**Redis pub/sub for multi-node coordination:**
When a student reconnects and the load balancer routes to a different proxy node, that node needs to know which container to connect to. The container host is stored in `lab_sessions.container_host` (DB). On reconnect, the new proxy node reads the DB and re-establishes the container WS. No cross-node PTY sharing — each proxy connects directly to its container.

---

### Platform Design Lessons (From Katacoda, Instruqt, Killercoda)

**Why Katacoda died (2022–2023):**
- Offered unlimited free lab environments with no cost gate — unsustainable at scale
- Environments were limited to pre-configured VMs and small K8s clusters with no customization
- No instructor tooling — content creators had no visibility into completion rates or broken labs
- O'Reilly acquired it as a content play, not an infrastructure play — maintenance deprioritized
- **MindForge lesson:** Never offer unlimited free sessions. All sessions consume real compute. Enforce org-level caps from day one (`lab_org_config`). Give instructors analytics so they can fix broken labs before students quit.

**What Killercoda gets right:**
- Ephemeral environments with strict TTLs — no persistent state, no cleanup burden
- Browser-based with zero local setup — zero friction to start
- Kubernetes-native — each lab session is a K8s Job, not a raw container — inherits scheduler, eviction, and autoscaling
- **MindForge lesson:** Adopt K8s Jobs in Phase 5. Raw Docker works for single-node but won't scale past ~500 concurrent sessions on one machine.

**What Instruqt gets right:**
- Full VM support (not just containers) for labs that need real OS behavior
- Lab "tracks" — multi-step labs with state passing between steps
- Custom scoring and webhooks for enterprise customers
- **MindForge lesson:** The `is_stateful` task flag and cumulative validation (step 5 above) mirrors Instruqt's track model. Labs where later tasks depend on earlier state must be modeled explicitly — don't assume task isolation.

---

### Container Resource & Scheduling Optimization

**CPU:**
- Default: 1.0 CPU per session
- Burst: allow up to 1.5 CPU for 60s during heavy compile/build operations (Docker `--cpu-shares` + `--cpus`)
- Validation containers: 0.5 CPU (they run scripts briefly)

**Memory:**
- Default: 512 MB per session
- K8s/Docker-in-Docker labs: 1.5 GB (minikube needs headroom)
- OOM behavior: `--oom-kill-disable=false` — let Docker kill the container rather than the host process. Container goes to `failed` state, student sees "Environment crashed — please reset."

**Disk:**
- Default: 3 GB overlay storage per container
- Monitored via `df -h` inside container every 5 min (triggered by verify calls). At 80% full: warn student in UI. At 95%: block verify, show "Disk full" error.

**Image pull policy on hosts:**
- Pull images nightly via cron: `docker pull mindforge/lab-*` on all nodes
- Never pull at session start time. If image is missing at session start, return 503 immediately — do not make students wait for a pull.
- Image updates use rolling tags (`lab-linux:24.04`) not `latest`. Pin to digest in production.

**Garbage collection:**
- Stopped containers: removed after 5 min by `cleanup_dead_containers` job
- Unused images on a node: `docker image prune -a` weekly (2am Sunday) — keep images used in the last 7 days
- Overlay volumes: Docker handles automatically on `docker rm`

---

### Observability (Ops Requirements)

Labs generate a large volume of short-lived containers. Without observability, incidents are invisible.

**Metrics to instrument:**

| Metric | Alert threshold |
|---|---|
| Container provisioning P99 latency | > 10s |
| Pre-warm pool size (per image) | < 2 available |
| Active WS connections per proxy node | > 4,000 |
| Session start failure rate | > 1% in 5 min |
| Verification timeout rate | > 5% in 15 min |
| Claude API error rate (creation/hints) | > 3% in 5 min |
| Validation container orphans | > 0 alive > 15 min |
| CPU sustained >90% (any lab container) | Immediate kill check |

**Structured logs — emit for every session event:**
```json
{
  "event": "session_started|verified|expired|reset|failed",
  "session_id": "...",
  "lab_id": "...",
  "org_id": "...",
  "user_id": "...",
  "container_id": "...",
  "duration_ms": 4200,
  "task_id": "...",
  "outcome": "passed|failed|timeout"
}
```

**Distributed tracing:** Wrap container provisioning and verification in OpenTelemetry spans. Slow provisioning shows up immediately in the trace waterfall.

---

### Multi-Region Considerations (Phase 5+)

Lab containers run code on real infrastructure. Latency between student and container matters for terminal responsiveness.

- WS round-trip > 80ms makes typing feel laggy
- Acceptable range: < 50ms (same region), 50–80ms (cross-region on fast backbone)
- At Phase 5: deploy Lab Proxy + Docker/K8s cluster in 2–3 regions (US, EU, APAC)
- Route students to nearest region based on GeoIP at session start
- Sessions are region-pinned — no cross-region migration mid-session
- DB is the single source of truth (replicated globally); containers are regional

---

## Production Readiness & Operations

The pieces below are not optional polish — without them the platform either races, leaks, or
can't be billed/operated. They are grouped so each can be built and reviewed independently.

---

### Container Provisioning & Readiness Protocol

`POST /sessions` returns immediately with the session row in `status='provisioning'` — the
container may still be 3–30s from ready. The client must NOT try to open the WS until the
container is `running`, or the upgrade fails. Defined handshake:

```
POST /sessions
  → 202 Accepted { session_id, status: "provisioning" }   (NOT a WS token yet)

Client then either:
  (a) polls GET /sessions/:id every 1s until status == "running", or
  (b) subscribes to GET /sessions/:id/events (SSE) for a single "ready" / "failed" event

On "running":
  → client calls POST /sessions/:id/ws-token → opens WS
On "failed" (provision error / 30s timeout):
  → show error + "Retry" (which starts a fresh session)
```

This makes provisioning observable instead of a guess. The WS token is minted only after
`running`, so a token never points at a not-yet-ready container.

**Idempotent session start.** `POST /sessions` accepts an `Idempotency-Key` header. A repeated
request with the same key within 10 min returns the original session instead of provisioning a
second container — this, plus the `lab_sessions_one_active` index, makes double-click and
client-retry storms safe (no orphan containers from rapid re-submits).

**Pool-assignment readiness.** When a session is served from the pre-warm pool, `setup_script`
still runs per-assignment, so the session goes `provisioning → running` only after setup
completes. Pool hits skip the image pull/boot, not the setup — readiness semantics are identical.

---

### Egress Control

Containers have no internet by default. A lab that genuinely needs network access (e.g.
`apt install`, pulling a Helm chart) sets `lab_org_config.egress_proxy_enabled = true` for the
org and declares destinations in `lab_egress_rules`. Enforcement is layered:

1. The container's only route off its isolated bridge is the egress proxy (HTTP CONNECT).
2. The proxy permits a request only if `(host, port, protocol)` matches a `lab_egress_rules` row
   for that lab AND the host is NOT in the global SSRF denylist (`docs/infrastructure.md`:
   `169.254.0.0/16`, RFC1918, etc.). Denylist wins over allowlist, always.
3. Everything else gets a 403 from the proxy; the container cannot open arbitrary sockets.

This closes the data-exfiltration / SSRF path that "just give the container internet" would open.

---

### Proxy ↔ Container Channel Security

The lab proxy connects to `ttyd` inside the container. ttyd must not be reachable by anything
else on the host:

- ttyd binds to the container's network namespace only; its port is published **only** to the
  proxy's internal network, never to `0.0.0.0` on the host.
- The proxy presents a **per-session container token** (generated at provision, stored in
  `lab_sessions`, injected into the container env) on the ttyd connection. A co-located process
  that somehow reaches the port still can't attach without the token.
- Control frames between browser↔proxy↔ttyd are length-prefixed and validated; a malformed or
  oversized control frame closes the connection rather than being forwarded.

---

### Deployment & Operations

**Graceful proxy drain (every deploy, not just crashes).** On `SIGTERM` the proxy: (1) stops
accepting new WS upgrades (LB health check flips to draining), (2) keeps existing PTYs alive for
up to 90s so in-flight commands finish, (3) sends each client a `reconnect` control frame so the
browser re-establishes against a healthy node. Containers are untouched — they outlive the proxy
process — so a rolling deploy never destroys a student's environment, only briefly reconnects it.

**Migrations.** Lab tables ship as forward-only numbered migrations following the repo convention
(`backend/db/migrations/NNN_labs*.sql`, applied alphabetically, tracked in `schema_migrations`,
`*.down.sql` provided for local rollback but skipped by the runtime runner). Split across phases so
each phase's migration is independently deployable:
`0NN_labs_core.sql` (10 core tables + indexes + the deferred `published_version_id` FK) →
`0NN_labs_creation.sql` (3 AI-creation tables, ships with Phase 4A).
Additive only in production — never rewrite a shipped migration; new changes get a new number.

**Rollout safety.** New lab images are pinned by digest, scanned (`trivy`/`grype`) before being
added to `allowed_images`, and pre-pulled on all nodes before the lab referencing them can publish.
A lab cannot be published against an image that isn't yet present on every node.

**Audit log.** Every instructor/admin mutation (publish, unpublish, task edit, script change,
delete, egress-rule change, org-config change) is written to the platform audit log with
`{actor, org_id, lab_id, action, before, after, ts}`. Verification/setup scripts are
security-sensitive — their change history must be reconstructable.

---

### Scoring Model

- **Total score** = Σ `points` of passed non-optional tasks (+ optional tasks if passed).
- **Hint penalty (optional, per lab).** If `hint_penalty_pct > 0`, each hint used on a task docks
  that percentage of the task's points, floored at 0. `hints_used` already tracks this; the score
  is computed as `points * max(0, 1 - hints_used * hint_penalty_pct/100)`. Default 0 = hints free.
- **No negative scores, no penalty for failed attempts** — only hint usage can reduce points, and
  only when the instructor opts in.
- **Verify-all.** The task panel offers "Check all tasks", which runs each task's verification in
  order (respecting `is_stateful` cumulative semantics) so a student can confirm a finished lab in
  one action instead of clicking each task. Same rate limit applies per task.
- Scoring is computed server-side from `lab_task_completions` at each verify and at session end —
  the client never submits a score.

---

### Accessibility & Device Support

- **Terminal a11y.** xterm.js runs with its screen-reader mode enabled and an accessible live
  region for output; the terminal is fully keyboard-operable, focus order is defined, and the
  HintDrawer / TaskPanel meet the same WCAG AA contrast tokens as the rest of MindForge (per
  `frontend/CLAUDE.md`). All controls (verify, hint, reset, end) have visible focus + labels.
- **Reduced motion.** Timer pulse and drawer slide respect `prefers-reduced-motion`.
- **Mobile / small viewport.** Terminal labs require a keyboard and a viewport ≥ 768px. On
  smaller screens the launcher shows a "Best on a larger screen" notice and offers read-only
  task review rather than a cramped, unusable PTY. `code`-type labs (Monaco) degrade more
  gracefully and remain usable on tablets.

---

### Data Retention & Privacy

- `lab_ai_interactions.prompt`/`response` contain terminal history, which can include
  user-typed secrets — treat as PII. Retain for 90 days, then a `purge_ai_interactions` job
  redacts `prompt`/`response` (keeps `tokens_used`, `cache_key`, timestamps for analytics).
- Completed/expired session rows are retained 1 year for progress/audit; containers are always
  destroyed at session end (no persistent student data on disk).
- On user/org deletion, lab sessions, completions, and AI interactions cascade or are purged in
  the same GDPR delete path as the rest of the platform — labs are not a data-retention island.

---

### Testing Strategy

- **Unit**: verification-script wrapping, score computation (incl. hint penalty), state-machine
  transitions, cache-key generation, snapshot pinning — all pure-Go, no Docker.
- **Integration (Dockerized)**: provision → exec → verify → teardown against a real ephemeral
  container in CI (testcontainers / dind runner). Gated to a `labs-integration` CI job so the
  main suite stays Docker-free and fast.
- **Concurrency**: a test that fires N simultaneous `POST /sessions` for one org and asserts the
  cap holds (no over-provision) — guards the advisory-lock path against regressions.
- **AI**: tool-schema unmarshalling and the self-correction loop are tested against recorded
  Claude fixtures so generation logic is verified without live API spend.
- **Leak checks**: an integration test asserts `cleanup_dead_containers` reaps `lab`/`pool`/
  `validate` orphans, and that no terminal-status session leaves a live container behind.

---

## Build Phases

### Phase 1 — Foundation
- [ ] DB migration `0NN_labs_core.sql`: 10 core tables (`lab_definitions`, `lab_tasks`, `lab_task_versions`, `lab_sessions`, `lab_task_completions`, `lab_ai_interactions`, `lab_org_config`, `lab_analytics`, `lab_egress_rules`, `lab_usage_events`) + `lab_sessions_one_active` index + the circular `published_version_id` FK
- [ ] `cmd/labproxy` — Go WebSocket relay (token validation, per-session container token, unpause-on-connect, debounced heartbeat, graceful SIGTERM drain)
- [ ] Container provisioning service (start, stop, exec, status) — setup as root, verify as `labuser`, ttyd bound to proxy-only network
- [ ] Session lifecycle API: `POST /sessions` (202 + provisioning, `Idempotency-Key`, advisory-locked cap), readiness `GET /sessions/:id/events` (SSE) + poll, `ws-token`, `end` (terminal-status)
- [ ] `expire_lab_sessions` (running+paused), `cleanup_dead_containers` (provisioning-safe, lab/pool/validate prefixes) background jobs
- [ ] xterm.js terminal UI: readiness wait → connect, timer, token-refresh reconnect, a11y (screen-reader mode, keyboard), mobile fallback notice

### Phase 2 — Task Engine
- [ ] `lab_tasks` CRUD API (instructor) + publish snapshot into `lab_task_versions` (sets `published_version_id`)
- [ ] Verify endpoint: runs pinned-version script, atomic attempt/score increments (with `hint_penalty_pct`), completion transition, unpause-on-verify; `verify-all` endpoint
- [ ] TaskChecklist UI (checklist, status icons, verify + verify-all buttons)
- [ ] Reset endpoint (staged provision) + ResetModal UI (stateful-task warning)
- [ ] `idle_pause_sessions` + `resume_on_connect` (cost-only pause; `expires_at` is a fixed wall-clock deadline, `paused_seconds` recorded for accounting)
- [ ] `monitor_container_resources` job (CPU/disk over all session types, incl. playground)
- [ ] `meter_usage` + `purge_ai_interactions` jobs; audit-log writes on all instructor mutations

### Phase 3 — AI Layer
- [ ] Hint endpoint (3 levels, cached, rate-limited)
- [ ] Post-completion explanation (background job, cached)
- [ ] Failure diagnosis (auto-triggered at attempt 3)
- [ ] HintDrawer UI + explanation panel

### Phase 4 — Instructor Tools
- [ ] Lab builder UI (task CRUD, drag-to-reorder, script editor)
- [ ] Instructor test session (is_test flag, 2h cleanup)
- [ ] Lab publish validation (image existence check)
- [ ] Analytics endpoint + instructor analytics view

### Phase 4A — AI Lab Creation Flow
- [ ] DB migration `0NN_labs_creation.sql`: `lab_creation_sessions`, `lab_creation_messages`, `lab_draft_versions`
- [ ] Creation session API (start, message, draft CRUD, approve [strips `solution_script`], abandon)
- [ ] Claude integration: tool_use schema for all 7 tools (`submit_intent`/`plan`/`draft`/`partial_revision`, `request_validation`, `signal_ready_to_save`, `flag_issue`)
- [ ] Intent gathering + planning step (outline-only, cheap pass)
- [ ] Full draft generation with streaming SSE
- [ ] Partial revision (delta, not full redraft)
- [ ] Script validation engine (disposable containers, self-correction loop)
- [ ] Version history API + restore endpoint
- [ ] Token budget tracking + hard cap enforcement
- [ ] Frontend: `LabCreationWizard` + chat + `DraftPreviewPanel` + `ValidationStatusPanel`
- [ ] Background jobs: auto-abandon (24h), cleanup abandoned (7 days), validation container cleanup

### Phase 5 — Scale & Polish
- [ ] K8s Jobs as container backend (replaces raw Docker, multi-host)
- [ ] Pre-warmed container pool (configurable size per image)
- [ ] Sticky-session WS load balancer (NGINX consistent-hash upstream)
- [ ] Redis pub/sub for multi-proxy-node session coordination
- [ ] Per-org concurrency enforcement + queue (instead of hard 429)
- [ ] Egress proxy enforcing `lab_egress_rules` allowlist ∩ global SSRF denylist
- [ ] `lab_analytics_rollup` job + analytics dashboard; per-org usage/cost dashboard from `lab_usage_events`
- [ ] `lab-docker` privileged image gating (paid org plans only)
- [ ] OpenTelemetry spans on provisioning + verification
- [ ] Prometheus metrics + alert rules for all key metrics
- [ ] CRIU checkpoint/restore for heavy images (K8s, Terraform)
- [ ] Multi-region deployment (US → EU → APAC rollout)
- [ ] Predictive pre-warming via invocation history RNN model
