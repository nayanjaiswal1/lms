# Debug Labs — Build Status

Last updated: 2026-10-06 · Branch: `debug-labs` (not merged to `master`, not pushed)
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
| 1d-ii | 11 Django fault blocks, ticket blocks, production-debugging course; `coursegen blocks verify`; probe stderr diagnostics. All 11 recipes verified in Docker | `069e1bb` |
| 1e | Builder wizard UI, block library, candidates endpoint, "Create debug lab here" | `160a13c` |

## Phase 3 — FastAPI (committed, Docker verification pending)

`fa.orders` app block (11 slots, 9 history features, 6 carriers, 47 regression tests), `seed.fa-small`, 10 fault blocks
(`fa.mig.divergent-heads`, `fa.mig.not-null-without-default`, `fa.perf.order-list-n-plus-one`, `fa.async.bcrypt-blocks-event-loop`,
`fa.async.wallet-lost-update`, `fa.svc.payments-no-timeout`, `fa.err.payment-failure-returns-200`, `fa.data.patch-wipes-fields`,
`fa.cfg.docs-ignore-root-path`, `fa.sec.order-idor`), 10 recipes (`content/courses/production-debugging/recipes/fa-*.yaml`) and a
"FastAPI" section group in the `production-debugging` course (6 lessons, 10 labs). Checked without Docker: manifests and recipes validate
(`coursegen blocks sync --dry-run`), `mf-build` renders all 10 recipes, rendered code lints, and the regression, hidden and fix tests
and the two migration probes were run against a real PostgreSQL for the broken, fixed and cheat states. Not yet run: the Q, L, C and P
probes against the live app, and `coursegen blocks verify` (needs Docker). Regenerate `lab-blocks.generated.sql` and
`production-debugging.generated.sql` when shipping.

## Phase 4 — React (committed, Docker verification pending)

`re.dashboard` app block (12 slots, 5 history features, 5 carriers), `check.vitest-node` (probe J), `ticket.ui-bug-report`, 12 fault blocks
(hooks x3, races x2, state x2, perf x2, api x2, config x1) and 12 recipes (`recipes/re-*.yaml`). Checked locally with real vitest + jsdom:
broken fails hidden tests, fix passes, every cheat fails. Fixed `trackListeners()` in `grader/js/harness.js`. React course content: a "React" section group (13-17: 5 lessons, 12 labs, one per recipe) in `production-debugging`; `coursegen generate` validates it.
Not done: error-boundary / SSR / StrictMode faults, prettier + Go-builder render path, `coursegen blocks verify` (Docker).

## Phase 5 — Fullstack (content written, uncommitted except the `fs.shop` block, Docker verification pending)

`fs.shop` app block (React storefront + FastAPI, committed in `07566e4`), 10 fault blocks in `content/lab-blocks/fullstack/fault/`
(`fs.cors.credentials-disabled`, `fs.err.detail-shaped-errors`, `fs.auth.cookie-path-narrow`, `fs.auth.csrf-cookie-httponly`,
`fs.api.search-query-not-encoded`, `fs.csrf.wrong-cookie-name`, `fs.page.offset-skips-first-page`, `fs.data.naive-placed-at`,
`fs.data.total-in-dollars`, `fs.state.profile-version-ignored`), 10 recipes (`recipes/fs-*.yaml`) and a "Fullstack" section group
(18-20: 3 lessons, 10 labs). Checked without Docker: `coursegen blocks sync --dry-run` and `coursegen generate` pass; per fault, hidden tests
fail broken, pass fixed, every cheat fails (real pytest + vitest + uvicorn). Not done: `coursegen blocks verify` (Docker), the
`revert-the-commit` cheat run for `fs.auth.cookie-path-narrow`, and a fix in the `@mf/fullstack` harness `createBrowser`
(jsdom AbortSignal is rejected by Node fetch, so `OrdersPage` fails against a real backend; tests currently stub fetch).
`fs.api.search-query-not-encoded` and `fs.csrf.wrong-cookie-name` are frontend-only, so only their vitest checks catch them.
Regenerate `lab-blocks.generated.sql` and `production-debugging.generated.sql` when shipping.

## Where things stand

Phase 1 (Django end to end: runtime, authoring engine, build/verify pipeline, 11 labs, builder UI) is done and committed. Nothing has run against a database yet: migrations 044–048 are unapplied, and the student flow and builder UI have never run in a browser.

**Next up:** the end-to-end check on a throwaway database (item 5 below) before starting Phase 2, so Phase 2 builds on a stack that has actually run.

## Remaining after Phase 1

1. ~~**Phase 2 — Builder depth**~~ done (landed in `e9b51b0`/`ddc36bf`; browser-untested): chains and fault pools in the block step (`fault-links.tsx`, `candidate-card.tsx`), AI ticket drafting (`ticket-draft-panel.tsx`, cached by recipe hash), org text-block editor (`teach/debug-labs/blocks/new|[id]/edit`), update-available list and yank flow with affected-labs preview.
2. ~~**Phase 3 — FastAPI**~~ content done (see above); only the Docker verification remains (item 5).
3. ~~**Phase 4 — React**~~ content done (see above); only the Docker verification remains (item 5).
4. ~~**Phase 5 — Fullstack**~~ content done (see above); only the Docker verification remains (item 5).
5. **Deferred verification.** Tests were deliberately not written until all phases are done:
   - Write the test suite: Go unit tests + DB tests for library, labs, labauthor, labbuild, credential, hints, semaphore.
   - Start Docker Desktop and run all DB tests (they use testcontainers).
   - ~~Build the `lab-debug` image~~ done 2026-10-02 (builds locally; all 11 recipes verified with `coursegen blocks verify`). Push it with `scripts/push-lab-images.sh`.
   - Apply migrations 044–048 on a **throwaway** database. Never on the shared Neon DB first — dev and prod share it.
   - End-to-end: sync blocks → build a recipe → verify → publish → run as a student, and click through the builder UI (never run in a browser yet).
6. **Small known gaps to clean up:**
   - ~~`isLabAuthError` matched on message text~~ now checks HTTP 401 (`res.status`).
   - ~~Some rarer labs errors have no `code`~~ every `writeDomainError` branch now emits a code (`labs/codes.go`, mirrored in `lib/labs.ts`).
   - The `debug-ide` 5 GB disk limit isn't enforced by either runtime.
   - Chained faults don't get separate "1a/1b" tasks.
7. **Ship:** review the whole branch, merge `debug-labs` → `master`, push, deploy image + migrations.

## Rough size of what's left

- Phase 2: medium
- Phases 3–5: large (each is a new app block + ~10 faults, content-heavy)
- Deferred tests + Docker/E2E verification: medium–large
