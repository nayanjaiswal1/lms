# Debug Labs — Build Status

Last updated: 2026-10-02 · Branch: `debug-labs` (not merged to `master`, not pushed)
Design: [debug-labs.md](debug-labs.md)

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
| 1d-ii | 11 Django fault blocks, ticket blocks, production-debugging course; `coursegen blocks verify`; probe stderr diagnostics. All 11 recipes verified in Docker | see `git log` |
| 1e | Builder wizard UI, block library, candidates endpoint, "Create debug lab here" | see `git log` |

## Remaining after Phase 1

1. **Phase 2 — Builder depth.** The backend is mostly built; this is UI plus the remaining pieces:
   - multi-fault chains and fault pools
   - AI ticket drafting in the UI
   - org text blocks editor
   - update-available and yank flows
2. **Phase 3 — FastAPI:** `fa-orders` app block, ~10 faults, Alembic migration slots, latency harness.
3. **Phase 4 — React:** `re-dashboard` app block, JSX/TS slots, vitest/Profiler/listener harnesses, ~10 faults.
4. **Phase 5 — Fullstack:** `fs-shop` + cross-stack (XS) faults; `custom` block support in the build.
5. **Deferred verification.** Tests were deliberately not written until all phases are done:
   - Write the test suite: Go unit tests + DB tests for library, labs, labauthor, labbuild, credential, hints, semaphore.
   - Start Docker Desktop and run all DB tests (they use testcontainers).
   - ~~Build the `lab-debug` image~~ done 2026-10-02 (builds locally; all 11 recipes verified with `coursegen blocks verify`). Push it with `scripts/push-lab-images.sh`.
   - Apply migrations 044–048 on a **throwaway** database. Never on the shared Neon DB first — dev and prod share it.
   - End-to-end: sync blocks → build a recipe → verify → publish → run as a student, and click through the builder UI (never run in a browser yet).
6. **Small known gaps to clean up:**
   - `isLabAuthError` still matches on message text.
   - Some rarer labs errors have no `code`.
   - The `debug-ide` 5 GB disk limit isn't enforced by either runtime.
   - Chained faults don't get separate "1a/1b" tasks.
7. **Ship:** review the whole branch, merge `debug-labs` → `master`, push, deploy image + migrations.

## Rough size of what's left

- Phase 2: medium
- Phases 3–5: large (each is a new app block + ~10 faults, content-heavy)
- Deferred tests + Docker/E2E verification: medium–large
