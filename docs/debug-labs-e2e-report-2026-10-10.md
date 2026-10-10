# Debug labs E2E run: report (2026-10-09 → 2026-10-10)

Companion to [debug-labs-e2e-status.md](debug-labs-e2e-status.md), which holds the full per-issue log (C1–C15). This file summarises the whole run: what was tested, what broke, what was fixed, and what is left.

PR: [#21 Debug labs E2E fixes, git course, lab UI redesign](https://github.com/nayanjaiswal1/lms/pull/21) (draft), branch `fix/debug-labs-e2e-2026-10-10`.

## 1. How the labs were tested

- One subagent per lab, acting as a real student in Chrome against the throwaway E2E stack (`http://localhost`, isolated Postgres/Redis/MinIO, never the shared Neon DB).
- Fix applied **only through the browser IDE**: no `docker exec`, no API calls, no DB edits.
- Steps per lab: start → ticket/IDE/App check → Check on unfixed workspace (expect 30) → open INCIDENT.md → fix in IDE (expect 70) → add student test in IDE (expect 85) → End Lab → result page.
- Test account: seeded member `jaiswal2062+member@gmail.com` (the main account requires 2FA setup).

## 2. Results: remaining 16 labs (26 were done in the earlier run)

| # | Lab | Stack | Result |
|---|---|---|---|
| 1 | Revenue report shows the previous day for US users | react | PASS 30 → 66 → 81 (one hint used, −4) |
| 2 | Saving my profile on my laptop erased the phone number | fullstack | PASS 30 → 70 → 85 |
| 3 | Sign-in succeeds, then Orders and Profile say "Sign in to continue" | fullstack | PASS 85 (first run lost login → found auth bug C8; rerun clean) |
| 4 | Staging console cannot sign in ("Failed to fetch") | fullstack | PARTIAL: 70/100, student-test step not run through the IDE |
| 5 | The order I placed this evening is dated tomorrow | fullstack | PASS 30 → 70 → 85 |
| 6 | An order stays flagged after the server refused it | react | PASS 30 → 70 → 85 |
| 7 | Changing the status filter does not reload orders | react | PASS 30 → 70 → 85 |
| 8 | Customer search shows results for an older query | react | PASS 30 → 70 → 85 |
| 9 | Deleting a note makes the next note show the wrong text | react | PASS 30 → 70 → 85 |
| 10 | Memory and CPU grow every time Orders is opened | react | PASS 30 → 70 → 85 |
| 11 | The Reports page hammers the API | react | PASS 30 → 70 → 85 (alternative fix `[options.days]` accepted) |
| 12 | The UI says Saved while the server was down | react | PASS 30 → 70 → 85 |
| 13 | The customer editor shows the previous customer | react | PASS 30 → 70 → 85 (stray `>` still scored 70 → C14) |
| 14 | The staging build still calls its own host | react | PASS 30 → 70 → 85 |
| 15 | Typing in the quick filter makes every page re-render | react | PASS 30 → 70 → 85 |
| 16 | The updated badge never gets past 1 | react | PASS 30 → 70 → 85 (rerun through the IDE; first run used docker exec and is discarded) |

The 15 points never earned are the optional root-cause write-up, which testers skipped on purpose.

## 3. Issues found and their status

| # | Issue | Status |
|---|---|---|
| C1 | IDE/App pane blank when labproxy is down (empty 502 in iframe) | Fixed: Caddy `handle_errors` page for `/lab-ws/*` |
| C2 | IDE iframe blank on first load / error page treated as loaded | Partly fixed: readiness probe + retry; probe only catches network failures, not HTTP error pages |
| C3 | "Do you trust the authors" dialog in every lab, explorer layout shift | Fixed in image settings; dialog not re-checked in a browser |
| C4 | "Check my fix" returned 500 after ~15s; UI stuck on "Checking…" | Fixed: `ReadHeaderTimeout`, `LABS_GRADE_TIMEOUT` (4m), typed 503/504, inline retry; not re-checked live |
| C5 | Hint penalty 0 for debug labs; hint counter inconsistent | WIP: default 10% (migration 003); agent stopped mid-edit |
| C6 | New (untracked) files missing from "Your changes" | Fixed (commit 9a59e54d), verified live |
| C7 | Pop out IDE: first click opens nothing | Not reproduced; blocked pop-up now shows a toast instead of navigating away |
| C8 | Logout mid-session (refresh 401s, family revoked) | Fixed and verified live: `proxy.ts` cookie ordering + deterministic successor token within grace |
| C9 | Stale labproxy binary used the wrong token secret (`unauthorized` in IDE) | Infra: proxy rebuilt, `env.sh` fixed |
| C10 | Stale `k8s_fastkube.generated.sql` aborted SeedDev on a fresh DB | Fixed: regenerated + generator test |
| C11 | Fresh dev DB has an empty lab catalog until labs are built and published | Open (backend, owner: user) |
| C12 | `/labs` and `/lab` returned 404 | Fixed: redirects to `/labs/catalog` |
| C13 | Student vitest test passed on the broken baseline | Fixed: grader sets `MF_WORKDIR` to the baseline worktree; image rebuilt |
| C14 | Broken JSX (stray `>`) still passed the checks | Fixed: strict-JSX vite plugin in the grader |
| C15 | Lab builds reused by recipe hash only, so grader/image changes never re-verify | WIP: runtime id on builds (migration 004); agent stopped mid-edit |
| — | `practice.Repo` used missing column `attempt_answers.position` | Already fixed in commit 9a2e7786 (orders via `assessment_questions.position`) |

## 4. UI work (in PR #21)

- **Lab result page**: score ring, verdict line, "Points you missed", compact checks, "What went wrong", change viewer (file list, line numbers, git headers stripped, Your fix / Reference / side by side), Next section, toast no longer covers content.
- **Lab catalog**: distinct stack tiles, max 2 meaningful skill chips, "Lab:" prefix stripped, whole card clickable, per-lab and per-level progress, labelled filters with count and Reset, title "Labs".
- **Session header**: Reset and End Lab separated (44px targets, Reset keeps its confirm).
- **IDE**: frame focused when ready so Ctrl+P reaches VS Code.
- **/learn**: "Debug labs" → "Labs".
- **Difficulty chip**: `.difficulty-intermediate` text colour fixed (was unreadable in dark mode).

Checks: `pnpm tsc --noEmit` and `pnpm lint:strict` pass. Browser-verified: result pages, `/learn`, catalog filters. Not verified: session header / IDE focus / pop-out in a live lab, mobile width, final chip colour. Catalog skills need a lab republish before stored data is clean (frontend filters generic skills meanwhile).

## 5. New content: Git course

- `content/courses/git/`: 8 lessons with nested labs + a cheat-sheet lesson; `backend/db/fixtures/git.generated.sql`.
- Sections: first commits, clone/remotes, branch/merge, conflicts, rebase (incl. interactive), undo/recovery (reset, reflog, revert, cherry-pick, stash), investigation (blame, pickaxe, bisect), capstone team workflow.
- 60 tasks, each proven in `mindforge/lab-debug:1` (verification fails before the solution, passes after).
- ASCII before/after diagrams and "what you should see" samples (the renderer has no mermaid support).
- Caveats: uses the 2.6 GB lab-debug image; not viewed in the browser yet.

## 6. Process rules added

- `CLAUDE.md` coding rule #9: no unnecessary or duplicate tests (grep existing coverage first; one test per behaviour; tests must fail when the logic breaks). Not in the PR (file had other uncommitted edits).

## 7. Checks run on the branch

| Check | Result |
|---|---|
| `go build ./...` | pass |
| `go vet ./...` | pass |
| `pnpm tsc --noEmit` | pass |
| `pnpm lint:strict` | pass |
| `go test ./...` | not run |

## 8. Left to do

- Finish C5 (hint penalty + counter), C15 (build reuse by runtime), C11 (fresh-DB catalog). Owner: user.
- Run `go test ./...`; restart the stack and re-verify all labs against the rebuilt grader image (strict JSX could fail a lab whose own code triggers an esbuild warning).
- Rerun the staging-console lab through the IDE.
- Check the redesigned pages at mobile width and inside a live lab session.
- View the git course in the browser.
- Uncommitted user files not in the PR: `backend/internal/gitlab/*`, calendar page, landing footer, sessions section, both `CLAUDE.md` files.

## 9. Fresh E2E stack setup (what it took)

1. Recreate `mf-e2e-pg`, `mf-e2e-redis`, `e2e-caddy`, `e2e-labproxy` with published ports and `--restart unless-stopped`.
2. Labproxy built from current code with `LAB_TOKEN_SECRET` and `LABPROXY_ALLOWED_ORIGINS`; backend `LABS_PROXY_CONTAINER=e2e-labproxy`.
3. Apply `production-debugging.generated.sql` in one transaction (`psql -1`) if SeedDev stopped early.
4. Apply RBAC bindings (`roles.sql`) and grant `labauthor.*` to instructor.
5. `go run ./cmd/coursegen blocks sync` to upload block payloads to MinIO.
6. Build and publish recipes: `~/scripts/mf-e2e/build_publish_all.py`.
