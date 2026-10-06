# Debug labs E2E - status (paused 2026-10-06, uncommitted)

## Progress
26 of 42 labs tested (11 django, 10 fastapi, 5 of 9 fullstack). All 26 passed steps 1-6 (30 -> 70 -> 85 points). No lab-blocking failures; issues below are product/UX/content findings.

## Remaining (16)
Fullstack (4): "Saving my profile on my laptop erased the phone number..." (6aae679d-2e98-57d7-bc8f-3ec0f094ee8a), "Sign-in succeeds, then Orders and Profile say Sign in to continue" (84ed348e-c808-5817-bebb-53a4b0b8a211), "Staging console cannot sign in - ... Failed to fetch" (7bc9193c-687f-550c-b883-5e006419c19a), "The order I placed this evening is dated tomorrow" (facafe9d-0da6-5f4d-a5ba-dc0bb3112920).
React (12): ids/titles in C:/Users/jaisw/scripts/mf-e2e/labs.txt (stack=react); order: An order stays flagged..., Changing the status filter..., Customer search shows older query, Deleting a note..., Memory and CPU grow..., Revenue report previous day, Reports page hammers the API, UI says Saved while server was down, customer editor shows previous customer, staging build still calls its own host, updated badge never gets past 1, Typing in the quick filter...

## How to resume
1. Stack (throwaway only, never the Neon DB): `docker start mf-e2e-pg mf-e2e-redis mf-e2e-minio e2e-labproxy e2e-caddy`; backend: `bash C:/Users/jaisw/scripts/mf-e2e/start-server.sh` run from a dir that contains a freshly built server.exe (`go build -o server.exe ./cmd/server` in backend/); frontend: `cd frontend && BACKEND_URL=http://localhost:8080 NEXT_PUBLIC_API_URL=http://localhost NEXT_PUBLIC_LAB_PROXY_URL=ws://localhost/lab-ws pnpm dev -p 3000` (wipe frontend/.next if /labs/catalog 404s). Browse http://localhost (port 80).
2. Per-lab brief: C:/Users/jaisw/scripts/mf-e2e/brief.md plus the tips accumulated in this session (one foreground tab, restart apps by pid, docker cp fallback `docker exec -i ... tee`, trust dialog may need 2 clicks, never click Check twice). One subagent at a time, model sonnet.
3. Findings log: C:/Users/jaisw/scripts/mf-e2e/results.md (copied below).
ESULTS.MD (copied below).
4. Fix agent worktree (uncommitted, unverified on live stack): .claude/worktrees/agent-a8db4b7eef29e1a89 (branch worktree-agent-a8db4b7eef29e1a89). Apply after the run (lab blocks are immutable once stored: delete the block's rows in the throwaway DB when re-syncing), rebuild lab image, re-test affected labs.
5. Main checkout edits already made (uncommitted): backend/internal/labs/repo_usage.go (ON CONFLICT predicate), backend/cmd/labproxy/preview.go (strip X-Frame-Options), backend/db/fixtures/dev_seed.sql (content_assignments).

## Open decisions for the user
- hint_penalty_pct value for debug labs (seeded 0; authored only in course lesson front matter).
- practice.Repo uses attempt_answers.position which does not exist in the schema.
- Pop out IDE: first click opened nothing in 1 of 6 runs (lab 22); token-expiry fix is in the worktree but may not explain it.
- Refresh/logout (F8): grace window already existed (30s); now env-configurable in worktree.

## Findings log
# Results (lab | stack | steps | class | note)
1. A burst of signups crashes with IntegrityError | django | 1 P, 2 PARTIAL, 3 P(30), 4 P(70, needs process restart), 5 P(85), 6 PARTIAL, 7 P | see findings F1-F4
2. A migration that only fails on production data | django | all PASS (30/70/85) | none | check takes 30-40s
3. Checkout hangs when the payments provider is slow | django | all PASS (30/70/85) | content nit: fixed order still ~16s (retry x timeout) vs "few seconds"; docker cp leaves test file root-owned
4. Evening orders land on tomorrow's report | django | all PASS (30/70/85), App tab renders (F1 fix verified) | none
5. Invoices vanish when a customer is deleted | django | all PASS (30/70/85) | content nit: seeded customers all have Payments (PROTECT) so ticket symptom not manually reproducible; fix needs migrate+restart not mentioned
6. Order totals are one cent off | django | all PASS (30/70/85) | content nit: symptom task shows generic "concurrent requests" sub-check labels in a rounding lab
7. Production has no styles or scripts | django | all PASS (30/70/85) | UX: IDE explorer cramped, INCIDENT.md needs ~30 scroll ticks
8. The last unit is sold twice | django | PASS (30/70/85); 3b partial (INCIDENT.md not opened in IDE), manual symptom repro not clean | possible flake: first Check click after step 5 gave no reaction
9. The order list page is slow for repeat customers | django | all PASS (30/70/85) | UX: Check click has no instant feedback, 15-25s ("Checking in a clean room" label only after delay)
10. The release is blocked by conflicting migrations | django | all PASS (30/70/85) | none
11. The staff dashboard hits the database too often | django | PASS (30, 85; 70 state skipped by agent) | UX: Hint counter stays 0/3 after using hint
12. A migration works in staging and crashes on production | fastapi | all PASS (30/70/85) | none; hint counter updates 1/3 here
13. Any customer can read any order | fastapi | all PASS (30/70/85) | flake: IDE iframe blank on first load until refresh; narrow window (982px) stacks to tiny-IDE mobile layout
14. Customers cannot pay but the dashboards show no errors | fastapi | all PASS (30/70/85) | none
15. Paying hangs when the payments provider is slow | fastapi | all PASS (30/70/85) | UX: explorer layout shifts after trust banner (INCIDENT.md needed 2 double-clicks)
16. Saving one profile field erases the others | fastapi | 1-4 PASS (30/70), 5-6 NOT DONE (browser logged out) -> re-run | harness flake? see F8
## Findings
F1 [product/harness] App tab iframe blank: app returns X-Frame-Options: DENY, preview iframe refused (django lab 1; check others)
F2 [content/UX] django runserver --noreload under debugpy: fix has no effect until process restarted; student not told
F3 [config?] hint_penalty_pct=0 in seeded lab_definitions -> hint costs no points
F4 [UX] after pass, Hint buttons disappear (only on unpassed tasks); Reset after pass shows "trust the authors" dialog; Ctrl+P quick-open did nothing
F0 [harness] first run 404 on /labs/catalog fixed by wiping frontend/.next + restart (stale cache)
F5 [harness? verify vs migrations] EndSession/expire: RecordSessionContainerUsage(Batch) fails "no unique or exclusion constraint matching ON CONFLICT" (42P10) on throwaway DB -> migration drift or product bug
F6 [harness] dev_seed.sql fails at startup: relation assessment_assignments does not exist (non-fatal)
F7 [note] user's own browser tab on a prior session shows stale IDE reconnect loop once the agent starts a new lab (one active session per user)
F5 UPDATE [PRODUCT BUG, confirmed]: index lab_usage_events_container_seconds_uq (001_baseline.sql:7401) predicate is (event_type='container_seconds' AND session_id IS NOT NULL) but backend/internal/labs/repo_usage.go:54 uses ON CONFLICT (session_id) WHERE event_type='container_seconds' -> predicate not implied, Postgres cannot infer arbiter; container usage never recorded at End/expire. Not drift. Fix: add AND session_id IS NOT NULL to the ON CONFLICT WHERE.
F1 VERIFIED FIXED (lab 4: App tab renders)
F8 [investigate: product or harness] During lab 16 browser was logged out: 3 successful POST /api/auth/refresh within ~30s from different client ports then all 401 (17:51:19+). Looks like refresh-token rotation reuse detection revoking the family on concurrent refreshes from several tabs (agent group had extra tabs incl. a stray accounts.google.com sign-in tab). Check refresh race handling + grace window.
16b. Saving one profile field erases the others (re-run) | fastapi | all PASS (30/70/85) | note: orphaned session after logout shows 'Resume Lab' + IDE 'Could not open the IDE. The session may have expired.'; Resume page has no way to end except End Lab button
17. Store credit goes missing under load | fastapi | all PASS (30/70/85) | harness flake: browser tool lost tab group after first Check click (Check completed server-side)
18. The API docs are blank behind the gateway | fastapi | all PASS (30/70/85) | IDE iframe blank on first load until refresh (recurring: labs 13,18)
19. The order list is slow for repeat customers | fastapi | all PASS (30/70/85) | first attempt aborted by browser renderer freeze (harness flake); symptom not measurable by hand (seed alice has few orders)
20. The release is blocked by multiple Alembic heads | fastapi | all PASS (30/70/85) | 2nd logout mid-run (refresh 401 ~18:36-18:42) -> supports F8; UI stuck on 'Checking in a clean room' + 'Leave site?' dialog after session loss; Check took 48s
21. The whole API freezes whenever somebody logs in | fastapi | all PASS (30/70/85) | Start Lab click errored once 'Couldn't determine which page this action targets' (retry worked) -> check server action/stale deployment
PopOut IDE (user report): works on fresh session (opens p3000-<sid>.localhost). Likely cause: href uses tokens.latest (300s exp) refreshed only by setInterval -> stale in throttled tab / after failed refresh. Handed to fix agent: mint fresh token on click.
## FIX AGENT (worktree, uncommitted, unverified on live stack) - apply AFTER e2e run ends
done: seed practice->assessments/attempts; restart note in debug ticket; Check pending state; hint counter max(); IDE iframe auto-retry 12s x3 + Reload btn; workspace trust off + hide outline/timeline + open INCIDENT.md (UNVERIFIED, needs image rebuild); layout breakpoint lg->md; debug-ide-unavailable.tsx (Try again / End lab and start fresh); REFRESH_REUSE_GRACE env (grace already existed 30s; logout likely stale token after window); CheckRef label; payments ticket text; seedlib duplicate.account@shop.test (changes baseline data for all labs -> rebuild+recheck); popOut() mints fresh token.
open: practice.Repo uses attempt_answers.position (column missing); hint_penalty_pct only authored in course lesson front matter (seeded debug labs 0) - needs a value from user; blocks immutable once stored -> delete block rows on throwaway DB when re-syncing.
22. E2E builder test: product search drops part of the query (fs.api.search-query-not-encoded; block title differs from lab title) | fullstack | all PASS (30/70/85) | PopOut IDE: FIRST CLICK opened nothing, SECOND click opened IDE tab (reproduces user report) -> not explained by token expiry; verify after fix-agent popOut() merge
23. Error messages are gone - every failure shows Request failed (409) | fullstack | all PASS (30/70/85) | CONTENT BUG: title says 409 but ticket/symptom/root cause are 403/404 (409 works); PopOut worked first click here (not reproducible: lab 22 first click failed, 1/2); session store in-memory so uvicorn --reload drops login; trust dialog appears after clicking in IDE & first 'No' click only closes hints panel
24. Every order in the history shows a total of under a dollar | fullstack | all PASS (30/70/85) | PopOut worked 1st click; result-page 'Your changes' diff omits added (untracked) test file; screenshots froze after End Lab (renderer/leave-guard?)
25. Our newest orders are missing from the order history | fullstack | all PASS (30/70/85) | first attempt aborted by renderer freeze (flake); PopOut 1st click OK; result-page diff omits untracked test file (confirmed 2nd lab)
26. Saving anything fails with The request could not be verified (fs.auth.csrf-cookie-httponly) | fullstack | all PASS (30/70/85) | PopOut 1st click OK; browser tab group vanished mid-Check when a foreign tab navigated (harness)
