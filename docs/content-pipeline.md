# Content Pipeline

How MindForge imports third-party course material (e.g. the Fast-Kubernetes repository) into the platform: **vendor → canonical markdown → generated SQL → database**. Canonical Markdown is the single source of truth. Fixtures are always generated, never hand-edited — the 16 hand-written `backend/db/fixtures/k8s_*.sql` files this pipeline replaced are gone; editing generated SQL directly is a discarded change the moment `coursegen generate` runs again.

---

## Architecture

```
Upstream repo (e.g. github.com/omerbsezer/Fast-Kubernetes)
        │  git clone --depth 1, one-time, reviewed diff
        ▼
content/<repo>/                     — vendored snapshot, committed, byte-exact
        │  coursegen import
        ▼
content/courses/<course>/**.md      — scaffolded Canonical Markdown (WIP hand-off)
        │  hand-authored: tasks, quizzes, verification scripts
        ▼
content/courses/<course>/**.md      — finished Canonical Markdown
        │  coursegen generate
        ▼
backend/db/fixtures/<course>.generated.sql   — idempotent SQL
        │  scripts/db-seed-courses.sh (docker cp + psql -f)
        ▼
PostgreSQL
```

Three Go packages, each with one job:

| Package | Owns |
|---|---|
| `backend/internal/contentpipeline/canonical/` | The Canonical Markdown schema — frontmatter structs, parse, validate, deterministic ID generation (`canonical.ID`). The only package the other two depend on. |
| `backend/internal/contentpipeline/importer/` | Reads a vendored snapshot, writes scaffolded Canonical Markdown. Course-specific (e.g. `importer/sections.go` hardcodes the Fast-Kubernetes section-grouping table) — not a general-purpose importer. |
| `backend/internal/contentpipeline/generator/` | Reads Canonical Markdown, renders idempotent SQL matching the courses/labs/assessment schema exactly. Content-agnostic — it has no Kubernetes-specific logic, only schema-specific logic. |

`backend/cmd/coursegen` is the CLI wrapping all three: `import`, `generate`, `audit`.

---

## Canonical Markdown Format

One `.md` file = one module. YAML frontmatter (between `---` lines) + a markdown body. A `kind` field selects the document type: `lesson`, `quiz`, or `lab`. Struct definitions: `backend/internal/contentpipeline/canonical/types.go`.

### `kind: lesson` → `course_modules(type='notes')`

```yaml
---
kind: lesson
id_key: k8s/workloads/lesson        # stable string, seeds every derived UUID for this doc
course: fast-kubernetes
section: workloads
section_title: "Workloads & Controllers"
section_position: 2
title: "Workloads & Controllers"
position: 0                          # lessons are always position 0 within their section
estimated_minutes: 90
source: [K8s-Deployment.md, K8s-Rollout-Rollback.md, ...]   # upstream files this lesson covers — required for audit
---

## K8s-Deployment.md

... full markdown body, every command/YAML block preserved verbatim ...
```

### `kind: lab` → `lab_definitions` + `lab_tasks` + `lab_task_versions` + `course_modules(type='lab')`

```yaml
---
kind: lab
id_key: k8s/pod-fundamentals/lab-pod
course: fast-kubernetes
section: pod-fundamentals
title: 'Lab: Pod'
position: 1
source: [labs/pod/multicontainer.yaml, labs/pod/pod1.yaml]
lab_type: terminal
environment: mindforge/lab-k8s:1.31
max_duration: 60
max_resets: 3
hint_penalty_pct: 10
is_required: true
setup_script: |
  #!/bin/bash
  kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
files:                                # written into /home/labuser/work at session start
  - path: pod1.yaml
    content: |
      apiVersion: v1
      kind: Pod
      ...
tasks:
  - id_key: create-firstpod
    title: Create the firstpod Pod
    points: 10
    is_optional: false
    is_stateful: true                 # true if a later task depends on this one's resource existing
    description: |
      Apply `pod1.yaml` to create a Pod named **firstpod** ...
    verification_script: |
      #!/bin/bash
      kubectl get pod firstpod --no-headers 2>/dev/null | grep -q Running
    hint_context: Use `kubectl apply -f pod1.yaml`.
    explanation_context: |
      A bare Pod is created directly from the manifest ...
    solution_script: kubectl apply -f pod1.yaml   # generator self-test only — NEVER emitted to any DB row
---
```

`solution_script` is parsed but never appears in generated SQL, `lab_tasks`, `lab_task_versions`, or any student/proxy-facing payload — the same rule `docs/labs.md` documents for the live product's instructor-authoring flow.

### `kind: quiz` → `questions` + `question_versions` + `assessments` + `assessment_questions` + `course_modules(type='assessment')`

```yaml
---
kind: quiz
id_key: k8s/pod-fundamentals/quiz
course: fast-kubernetes
section: pod-fundamentals
title: 'Quiz: Pod Fundamentals'
position: 2
pass_percentage: 60
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq                         # mcq | coding | subjective
    difficulty: intermediate
    points: 2
    prompt: "Which of the following best describes a Kubernetes Pod?"
    multiple: false
    options:
      - text: "..."
        correct: false
      - text: "..."
        correct: true
    explanation: "..."
  - id_key: q2
    type: coding
    points: 5
    prompt: "..."
    languages: [python, javascript]
    starter_code: { python: "...", javascript: "..." }
    test_cases:
      - stdin: "..."
        expected: "..."
        hidden: false
        weight: 1
---
```

---

## Deterministic IDs

Every row's UUID is `canonical.ID(idKey, suffix)` = `uuid.NewSHA1(Namespace, idKey+":"+suffix)`, where `Namespace` is a fixed constant (`backend/internal/contentpipeline/canonical/ids.go`). Same input → same UUID, forever — this is what makes `coursegen generate` idempotent: editing a lesson's body and regenerating produces the identical `id`, so the SQL's `ON CONFLICT (id) DO UPDATE` updates the existing row instead of inserting a duplicate.

Suffixes in use: `course`, `section`, `module`, `lab`, `task:<task-id_key>`, `version`, `assessment`, `question:<q-id_key>`, `qversion:<q-id_key>`, `aq:<q-id_key>`, `enrollment:<user-id>`.

### The `lab_task_versions` dev-time exception

`lab_task_versions` snapshots are contractually immutable in the live product — publishing a lab cuts a *new* version, it never mutates an existing one (see `docs/labs.md`). The generator does not follow that rule: it always emits `version=1` with `ON CONFLICT (lab_id, version) DO UPDATE`, rewriting the same snapshot row on every regenerate. **This is safe only because `coursegen generate` targets dev/seed databases with no in-flight student sessions at generate time.** It is not how content changes reach a production database — a live instructor edit still goes through the real `POST /api/instructor/labs/:id/publish` endpoint, which correctly cuts a new version. The `UPDATE lab_definitions ... WHERE published_version_id IS NULL` guard on first publish means a regenerate never clobbers a version a real instructor action has since advanced past v1.

---

## CLI

Run from `backend/` (matches every other `go run ./cmd/...` invocation in this repo):

```bash
cd backend

# Scaffold canonical markdown from a vendored snapshot.
# Defaults: --vendor ../content/fast-kubernetes --out ../content/courses/fast-kubernetes
go run ./cmd/coursegen import

# Render canonical markdown into idempotent SQL.
# Defaults: --in ../content/courses/fast-kubernetes --out db/fixtures/k8s_fastkube.generated.sql
go run ./cmd/coursegen generate

# Prove every vendored file is cited by some canonical document's source: list.
# Exits 1 and lists uncovered files if coverage is incomplete.
# Defaults: --vendor ../content/fast-kubernetes --canonical ../content/courses/fast-kubernetes
go run ./cmd/coursegen audit
```

Then load the generated SQL:

```bash
bash scripts/db-seed-courses.sh   # or: make seed-courses
```

`audit` is the mechanical proof of "100% of the repository was imported" — not a manual checklist. It fails the build if a single vendored file (lesson, cheatsheet, or lab manifest) has zero canonical coverage. `LICENSE`, `index.html`, and the pipeline's own `UPSTREAM.md` are the only files exempt (not educational content).

---

## Known Constraints When Authoring Lab Tasks

**Read this before writing a new `verification_script`.** The `mindforge/lab-k8s:1.31` sandbox (`lab-images/lab-k8s/`) runs a real control plane (etcd, kube-apiserver, kube-controller-manager, kube-scheduler) with `kwok` standing in for the kubelet — real object reconciliation, fake container processes. Consequences:

1. **No real container process exists.** `kubectl exec`, `kubectl logs` and `kubectl port-forward` fail (`no preferred addresses found`), probes never run, and image names are never pulled (a typo'd image still goes `Running`). Verification scripts check control-plane state (`kubectl get ... -o jsonpath=...` + `test`/`grep`), never runtime output. Lesson text tells students to try exec/logs on minikube/kind instead.

2. **`kube-controller-manager` runs an explicit `--controllers` allowlist** (`lab-images/lab-k8s/entrypoint.sh`). It now includes every controller the course teaches: `deployment, replicaset, daemonset, statefulset, job, cronjob, ttl-after-finished, persistentvolume-binder, pvc-protection, pv-protection, namespace, endpoint(slice), resourcequota, garbagecollector, node-lifecycle-controller, taint-eviction-controller, podgc, disruption, horizontalpodautoscaling`. So DaemonSets/StatefulSets create pods, Jobs run to `Complete` (kwok's pod-complete stage), CronJobs fire, static PVs bind to PVCs, drains respect PodDisruptionBudgets, and `NoExecute` taints evict pods. Missing pieces that bite if forgotten: `taint-eviction-controller` needs `node-lifecycle-controller` (it registers the `spec.nodeName` pod index); PVC deletion hangs forever without `pvc-protection` (the admission plugin adds its finalizer); drains are refused without `disruption` (PDB status is never computed).

   Still absent by design: a storage provisioner (no StorageClass — labs create PVs up front), metrics-server (HPA `TARGETS` shows `<unknown>`), an ingress controller (Ingress objects are stored and validated but route nothing), and authorization (`--authorization-mode=AlwaysAllow`, so `kubectl auth can-i` always says yes — RBAC labs verify the Role/RoleBinding objects instead). Pod Security Admission *is* active, so `pod-security.kubernetes.io/enforce` labels really reject pods. `helm` (v3) is installed for the Helm section; charts must be local (`helm create`), since the lab network has no internet.

   Extra nodes can be registered from a manifest with the annotation `kwok.x-k8s.io/node: fake` (see `content/courses/fast-kubernetes/workloads/04-lab-daemonset.md`'s `node2.yaml`) — useful for DaemonSet, drain and spreading exercises.

3. **Test every lab against the real image before seeding.** `python scripts/test-k8s-labs.py <lab-or-lesson.md> ...` starts a fresh `mindforge/lab-k8s:1.31` container per lab, writes `files:`, runs `setup_script` as root, and for each task checks that `verification_script` **fails** before `solution_script` runs (catches always-true checks) and **passes** after it. Rebuild the image first if `lab-images/lab-k8s/` changed: `docker build -t mindforge/lab-k8s:1.31 lab-images/lab-k8s`.

---

## How to Add a New Course

1. **Vendor**: `git clone --depth 1` the upstream repo into `content/<slug>/`, write a `content/<slug>/UPSTREAM.md` recording the commit SHA and re-vendor procedure (see `content/fast-kubernetes/UPSTREAM.md` for the template).
2. **Import**: write a course-specific importer (or extend the existing one if the new course shares a similar shape) that maps upstream files to a section-grouping table and calls `importer.Import(vendorDir, outDir)`. This produces scaffolded lessons and lab stubs with empty `tasks: []`. Import is a one-time scaffold: it refuses to overwrite any existing file (an earlier version silently overwrote finished content, and its own test `RemoveAll`'d the real course directory on every `go test`, which is how the Fast-Kubernetes lab tasks, quizzes and course.yaml were lost).
3. **Author**: hand-write real `tasks:` for every lab stub (verification scripts, hints, explanations) and author quizzes — the importer deliberately cannot do this, it requires domain judgment about what to actually grade. Validate each file as you go: `canonical.ParseFile(path)` then `.Validate()`.
4. **Generate**: `go run ./cmd/coursegen generate`. Refuses to write anything if any document fails validation — fix every reported error before it emits SQL.
5. **Audit**: `go run ./cmd/coursegen audit`. Must exit 0 before considering the course complete.
6. **Seed**: `bash scripts/db-seed-courses.sh`, then start a real lab session against the new content and confirm `kubectl` commands + verification actually work — a canonical-markdown file that merely *parses* is not proof the underlying commands work against the real sandbox image. Empirically test at least one lab per new resource kind directly (`docker run` the lab image, `kubectl apply` the starter files, run the verification script) before trusting it in front of a student.
