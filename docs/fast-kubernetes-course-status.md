# Fast Kubernetes Course — Session Status / Resume Point

This is a point-in-time record of the "import Fast-Kubernetes as a full interactive course"
feature: what was built, what was verified, and how to pick the work back up. It is not a
living reference doc — for the actual architecture reference, see `docs/content-pipeline.md`
(the pipeline itself), `docs/courses.md` (courses domain), and `docs/labs.md` (labs domain,
authoritative design spec).

The original plan this session executed against: `C:\Users\jaisw\.claude\plans\steady-jingling-mccarthy.md`.

**Nothing described here has been committed to git.** Everything is sitting in the working tree.

---

## Status: feature-complete and verified

All 10 planned workstreams are done. The course is loaded in the dev database and has been
exercised end-to-end through the real HTTP API and a real browser session (not just unit tests).

| # | Workstream | State |
|---|---|---|
| 0 | Canonical markdown schema package | Done |
| 1 | Vendor Fast-Kubernetes repo + importer | Done |
| 2 | Author canonical course content (14 labs, 10 quizzes) | Done |
| 3 | Fixture generator + `coursegen` CLI | Done |
| 4 | Terminal-lab verification (`docker exec` grading) | Done |
| 5 | File-ops / validate / resources backend | Done |
| 6 | Frontend labs UI (file tree, editor, resources panel) | Done |
| 7 | Retire old `k8s_01`–`k8s_16.sql` fixtures | Done |
| 8 | Documentation | Done |
| 9 | End-to-end verification | Done |

---

## What's actually in the database right now

1 course ("Fast Kubernetes", slug `fast-kubernetes`), 10 sections, 34 modules:

| Section | Lesson | Labs | Quiz |
|---|---|---|---|
| Pod Fundamentals | ✓ | Pod | ✓ |
| Workloads & Controllers | ✓ | Deployment, DaemonSet, StatefulSet, Job, CronJob | ✓ |
| Networking | ✓ | Service, Ingress | ✓ |
| Configuration & Secrets | ✓ | ConfigMap, Secret | ✓ |
| Storage | ✓ | PersistentVolume | ✓ |
| Health & Scheduling | ✓ | Liveness, Affinity, Taint/Toleration | ✓ |
| Cluster Setup & Operations | ✓ | — (reference only, see below) | ✓ |
| Helm & Packaging | ✓ | — (reference only) | ✓ |
| Observability | ✓ | — (reference only) | ✓ |
| Reference | ✓ | — (cheat sheet, no lab) | ✓ |

14 interactive labs total, all published. 100% of the upstream repo's content is covered
(mechanically proven by `coursegen audit`, not a manual checklist) — the 3 sections with no
interactive lab still contain the full lesson text (every command, every YAML block) from
kubeadm/Helm/Prometheus-Grafana; they're reference-only because those tools genuinely can't run
in the single-container `kwok`-based sandbox (no real multi-VM, no `helm`/`prometheus` binaries in
the image).

---

## Real production bugs found and fixed this session

These were caught by actually running the system (live containers, real HTTP API, real browser),
not by unit tests. All are fixed and re-verified.

1. **`/home/labuser` permission gotcha** — `--cap-drop ALL` strips `CAP_DAC_OVERRIDE` even from
   root, so a root-run `setup_script` couldn't traverse `labuser`'s `0750` home directory to write
   starter files.
   Fixed in `lab-images/lab-k8s/entrypoint.sh` (chmod 755 the home dir, pre-create a
   world-writable workdir). Documented in `docs/labs.md` under "Container Runtime" so no future
   lab image regresses this.

2. **Importer `source:` path bug** — lab stubs recorded bare filenames instead of paths relative
   to the vendor root, so `coursegen audit` couldn't match them against the vendored tree.
   Fixed in `backend/internal/contentpipeline/importer/importer.go`.

3. **Container provisioning race** — `ContainerService.Start()` ran `setup_script` immediately
   after `docker run -d` with no wait for the image's internal services (etcd/kube-apiserver) to
   come up, causing intermittent `status: failed` sessions.
   Fixed with a bounded retry (10 attempts, 500ms apart) in `backend/internal/labs/container.go`.

4. **Session completion never fired** (the most significant one) — `finalizeTaskPass`'s
   completion check queried `CountPassedNonOptionalTasks` via the connection pool instead of the
   open transaction, so it could never see its own just-written `MarkTaskPassed` row. Every lab
   session — not just the new K8s ones — would pass all its tasks but never flip to `completed`,
   and course-module progress would never fire.
   Fixed by adding a `rowQuerier` interface (satisfied by both `*pgxpool.Pool` and `pgx.Tx`) so the
   count can run against either the open transaction or a standalone connection. See
   `backend/internal/labs/repo.go` (`CountPassedNonOptionalTasks`) and the two call sites in
   `backend/internal/labs/service.go` (`finalizeTaskPass`, `EndSession`).

---

## Files touched

### New packages
- `backend/internal/contentpipeline/canonical/` — schema (types, parse, validate, deterministic IDs)
- `backend/internal/contentpipeline/importer/` — vendored snapshot → scaffolded canonical markdown
- `backend/internal/contentpipeline/generator/` — canonical markdown → idempotent SQL
- `backend/cmd/coursegen/` — CLI (`import` / `generate` / `audit`)

### New content
- `content/fast-kubernetes/` — vendored upstream snapshot + `UPSTREAM.md` provenance
- `content/courses/fast-kubernetes/**` — 34 authored canonical markdown files (10 lessons, 14 labs, 10 quizzes)
- `backend/db/fixtures/k8s_fastkube.generated.sql` — generated output (regenerate, don't hand-edit)

### Backend changes
- `backend/internal/labs/service.go` — `VerifyTask` split into dispatcher + `verifyCodeTask` +
  `verifyContainerTask` + shared `finalizeTaskPass`; new `ensureContainerResumed` helper
- `backend/internal/labs/container.go` — setup-script retry loop
- `backend/internal/labs/repo.go` — `rowQuerier` interface, transaction-aware `CountPassedNonOptionalTasks`
- `backend/internal/labs/handler_session.go` — verify handler only requires `code`/`language` for `code`-type labs
- `backend/internal/labs/errors.go`, `handler.go` — new `ErrInvalidPath`
- `backend/internal/labs/service_files.go`, `handler_files.go` (new) — file-ops/validate/resources
- `backend/internal/labs/service_files_test.go` (new) — path-traversal guard tests
- `backend/internal/labs/routes.go` — 7 new file-management routes

### Frontend changes
- `frontend/lib/labs/files.ts` (new) — types
- `frontend/app/(app)/labs/sessions/[sessionId]/files-actions.ts` (new) — server actions
- `frontend/hooks/use-lab-files.ts`, `use-lab-resources.ts` (new)
- `frontend/components/labs/lab-file-tree.tsx`, `lab-file-editor.tsx`, `lab-resources-panel.tsx`,
  `lab-container-workspace.tsx` (new)
- `frontend/components/labs/lab-environment.tsx` — wired in `LabContainerWorkspace` for non-code labs

### Infra
- `lab-images/lab-k8s/entrypoint.sh` — permission fix (rebuild the image if you haven't:
  `docker build -t mindforge/lab-k8s:1.31 lab-images/lab-k8s`)
- `scripts/db-seed-courses.sh` (new), `Makefile` (`seed-courses` target, wired into `dev-reset`)
- `backend/db/fixtures/k8s_01_setup.sql` … `k8s_16_enrollments.sql` — **deleted**

### Docs
- `docs/courses.md` (new — this file didn't exist before despite being referenced from root `CLAUDE.md`)
- `docs/content-pipeline.md` (new)
- `docs/labs.md` — additive edits (implementation status notes, permission gotcha, file-management API table)
- `docs/fast-kubernetes-course-status.md` — this file

---

## How to verify it yourself / resume from here

```bash
# Rebuild the lab image if you haven't already (picks up the entrypoint.sh permission fix)
docker build -t mindforge/lab-k8s:1.31 lab-images/lab-k8s

# Regenerate + reload content from canonical markdown (idempotent — safe to re-run)
cd backend
go run ./cmd/coursegen audit      # should report 100% coverage
go run ./cmd/coursegen generate   # writes db/fixtures/k8s_fastkube.generated.sql
cd ..
bash scripts/db-seed-courses.sh   # or: make seed-courses

# Full backend check
docker exec mindforge_backend_dev sh -c "cd /app && go build ./... && go vet ./... && go test ./..."

# Frontend check
cd frontend && node_modules/.bin/tsc --noEmit && node_modules/.bin/eslint .
```

Log in as `student@mindforge.dev` / `Admin123!`, open the Fast Kubernetes course, start any lab.

---

## Known gaps / explicitly out of scope

- **Not committed.** All changes are in the working tree only.
- **AI hints/explanations** (`docs/labs.md`'s "AI Integration" section — hint levels, post-completion
  explanation, failure diagnosis) were not touched. This is a pre-existing gap in the labs domain
  unrelated to the K8s course work — the AI endpoints were never implemented for any lab type.
- **Instructor authoring UI / conversational AI lab-creation flow** was intentionally not built —
  the plan generates fixtures directly from canonical markdown instead.
- **`skip` endpoint for optional tasks** (documented in `docs/labs.md`'s API table) was not verified
  to exist — none of the 14 K8s labs have optional tasks, so this was never exercised.
- **Quiz-taking UI** was not live-browser-tested this session (only the labs UI was) — the
  assessment domain itself predates this work and wasn't modified, so risk is low, but it's untested
  in combination with this specific content.
- **Mobile layout** for the new Files/Resources tabs was not tested — they're desktop-only by
  design (same constraint the existing terminal already has: "The terminal requires a larger screen").
