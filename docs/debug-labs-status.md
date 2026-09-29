# Debug Labs — Build Status

Last updated: 2026-09-30 · Branch: `debug-labs` (not merged to `master`, not pushed)
Design: [debug-labs.md](debug-labs.md)

## Blocker right now

The implementation subagents hit the **weekly API limit** (resets **Oct 5, 4:30am IST**). Phase 1d-ii stopped mid-way. Resume it after the reset.

## Done (committed on `debug-labs`)

| Phase | What | Commit |
|---|---|---|
| Design | Debug labs, scenario builder, course library design doc | `342b83d` |
| A | Course library ("Add from library") + fork-breaks-labs bug fix | `6fa3c5c` |
| 0 | ttyd auth (cross-container shell fix), `ImageProfile.Elevated`, preview heartbeat, lab hints | `c665a83` |
| 1a | Generic lab-kind plugin architecture, debug kind, private bundle storage, clean-room grading, `lab-debug` image | `2e7a6ec` |
| 1b | Student workspace (ticket, IDE, Check, hints, write-up), debrief, catalog | `fbeaea1` |
| 1b fixes | Finish-on-click completion, persisted write-up review, Retry-After, grader type on API | `762b9b2` |
| 1b fixes | Student diff captured on every close path; completed-at-deadline outcome | `02d0548` |
| 1b fixes | Machine-readable error `code` in the API envelope | `3f1202f` |
| 1c-i | Authoring engine: block manifests, composition validator, variants, recipe hash, blocks sync, recipe/block API, permissions | `3509321` |
| 1c-ii | `mf-build` renderer, build/verify jobs, preview, one-transaction publish, platform recipes, build GC | `5d9c783` |
| 1c fix | Global per-org verify cap via Redis lease semaphore | `39b468a` |
| 1d-i | `dj-shop` base app (78 slots, 10 features, 5 carriers, 108 regression tests) + check/seed/stub/env blocks | `27d0346` |
| cleanup | Stop tracking Python bytecode caches | `1acf1ab` |

## In progress — Phase 1d-ii (uncommitted, in working tree)

- **Fault blocks:** 11 written under `content/lab-blocks/django/fault/`:
  - `perf`: n-plus-one-order-list, dashboard-repeated-queries
  - `data`: customer-delete-cascades, float-money-rounding, report-utc-days
  - `conc`: stock-lost-update, signup-race
  - `mig`: conflicting-leaf-nodes, backfill-duplicate-slugs
  - `svc`: payments-no-timeout
  - `cfg`: static-files-missing-in-prod
- **Other files already written:**
  - common ticket blocks: `content/lab-blocks/common/ticket/`
  - the production-debugging course: `content/courses/production-debugging/` (6 sections + recipes) and its generated fixture
  - an interview-prep pointer lesson: `backend-django/06-debugging-in-production.md`
- **Also modified:**
  - `dj-shop` regression tests and test settings
  - seed blocks
  - `run_grade.py` and `mfbuild/grader.py` (fixes found while verifying faults)
- **Still to do in 1d-ii:**
  - Finish and confirm the per-fault verification matrix: broken fails, fix passes, every cheat fails, student-test.
  - Delete the throwaway tool `backend/cmd/zzlgspec/`.
  - Re-run `coursegen generate` + `blocks sync --dry-run`.
  - Update docs, review, commit.

## Remaining after 1d-ii

1. **1e — Builder wizard UI:**
   - the 12-step recipe wizard with live validation
   - build/verify progress view, preview, publish
   - block library browser
   - "Create debug lab here" in the course editor
2. **Phase 2 — Builder depth.** The backend is mostly built; this is UI plus the remaining pieces:
   - multi-fault chains and fault pools
   - AI ticket drafting in the UI
   - org text blocks editor
   - update-available and yank flows
3. **Phase 3 — FastAPI:** `fa-orders` app block, ~10 faults, Alembic migration slots, latency harness.
4. **Phase 4 — React:** `re-dashboard` app block, JSX/TS slots, vitest/Profiler/listener harnesses, ~10 faults.
5. **Phase 5 — Fullstack:** `fs-shop` + cross-stack (XS) faults; `custom` block support in the build.
6. **Deferred verification.** Tests were deliberately not written until all phases are done:
   - Write the test suite: Go unit tests + DB tests for library, labs, labauthor, labbuild, credential, hints, semaphore.
   - Start Docker Desktop and run all DB tests (they use testcontainers).
   - Build the `lab-debug` image (`scripts/push-lab-images.sh`).
   - Apply migrations 044–048 on a **throwaway** database. Never on the shared Neon DB first — dev and prod share it.
   - End-to-end: sync blocks → build a recipe → verify → publish → run as a student.
7. **Small known gaps to clean up:**
   - `isLabAuthError` still matches on message text.
   - Some rarer labs errors have no `code`.
   - The `debug-ide` 5 GB disk limit isn't enforced by either runtime.
   - Chained faults don't get separate "1a/1b" tasks.
8. **Ship:** review the whole branch, merge `debug-labs` → `master`, push, deploy image + migrations.

## Rough size of what's left

- 1d-ii: small (finish + verify + commit)
- 1e: medium (frontend wizard)
- Phase 2: medium
- Phases 3–5: large (each is a new app block + ~10 faults, content-heavy)
- Deferred tests + Docker/E2E verification: medium–large
