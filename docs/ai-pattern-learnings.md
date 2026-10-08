# AI Pattern Learnings

Shortcut patterns found and fixed in AI-written code, recorded so the same
pattern isn't reintroduced elsewhere in the codebase (by a human or an AI
agent). Unlike `docs/frontend-gotchas.md` (bugs discovered by hitting them),
these are patterns caught by a deliberate review pass (`/ponytail-audit` +
`/ponytail-debt`, 2026-08-01, full remediation 2026-08-10) before they caused
an incident. Each entry: the pattern, why it's a problem, the fix, and the
rule to apply when writing new code.

This file is updated as new instances of these patterns (or new patterns) are
found — not just at the end of a review pass.

---

## Cost-bearing endpoints shipped with no rate limit

**Pattern:** an endpoint that does real exec/DB work (e.g. `labs/service_ports.go`'s
port scan, which shells out per request) shipped with no throttle, on the
assumption that "nobody will abuse this yet."

**Why it's a problem:** the throttle is cheap to add at write time and
expensive to retrofit once the endpoint is public and someone finds it. The
absence isn't a deliberate scope decision, it's an omission — AI-generated
handlers default to "make the happy path work" and skip the abuse case unless
asked.

**Fix:** wire `internal/ratelimit` (Redis sliding window) — already the
established pattern (`auth/handler.go`, `middleware/ratelimit.go`).

**Rule:** any new handler with real exec/DB cost gets a rate limit in the same
PR that adds the handler, not as a follow-up.

---

## Global-cap/counter checks that aren't locked

**Pattern:** `mentoring/service_purchase.go`'s coupon redemption cap was a
plain read-then-compare against `MaxRedemptions`, with no row lock — two
concurrent requests can both read "under cap" and both redeem, blowing past
the limit.

**Why it's a problem:** this only shows up under real concurrent load, so it
passes every single-request test and code review that doesn't specifically
think about races. AI-generated CRUD code defaults to the simplest
read-then-write shape unless the concurrency requirement is spelled out.

**Fix:** `FOR UPDATE` on the row being checked, matching the existing pattern
in `courses/repo.go` (proposal approvals) and `labs/repo_warm.go` (warm pool
claiming).

**Rule:** any check-then-write against a shared counter/cap that must hold
under concurrency needs an explicit row lock (`FOR UPDATE`) or an atomic
`UPDATE ... WHERE count < cap RETURNING`, chosen at write time — not "we'll
add locking if it becomes a problem."

---

## List endpoints shipped unpaginated

**Pattern:** `courses/repo.go`'s pending-proposals query had no `limit`/
`offset`, capped with a hardcoded 100-row `LIMIT` and a comment to "add
pagination if a course ever needs more than 100."

**Why it's a problem:** the existing pagination pattern (`ListPublicCourses`)
was sitting right there in the same file, so this wasn't a missing capability
— it was one query that didn't reuse the established shape. AI code is prone
to this drift when generating similar-but-not-identical endpoints in the same
session.

**Fix:** copy the `limit`/`offset` pattern from `ListPublicCourses`
(`courses/repo.go:209`) through repo → handler → route.

**Rule:** before writing a new list endpoint, grep for an existing one in the
same package and match its pagination shape — don't invent a fresh
hardcoded-cap variant.

**More instances found (2026-09-16 full-codebase code audit):** `highlights.ListMine`,
`focuswall.ListMine`/`ListCategories`, `mistakes.List` (also the admin
`useroverview` aggregator's call into it), `journal.ListEntries` (same
aggregator), `interviewexp.ListPosts` (had a hardcoded `LIMIT 100` with no
offset — reachable, but nothing past the newest 100 ever was), and
`moderation.ListReports`/`roadmap.ListForUser` (fully unbounded). Fixed with
the same `limit`/`offset` (or, for the two canvas/graph-shaped views —
`focuswall`'s spatial board and `journal.GetGraph`'s mind-map, neither of
which has page UI — a fixed high safety-net `LIMIT` instead of real
pagination, since paging a canvas doesn't make sense).

---

## Trusting authenticated input as a substitute for real validation

**Pattern:** `gitlab/handler_connection.go`'s admin-supplied GitLab base URL
had no IP-range checking, reasoned as "this is authenticated admin input, not
untrusted user input, so SSRF denylisting belongs elsewhere."

**Why it's a problem:** auth answers "is the caller allowed to configure
this," not "is the configured value safe to connect to." A validated hostname
can still resolve to an internal IP later (DNS rebinding), and "trusted
caller" doesn't change what the server ends up connecting to. Treating
authorization as a stand-in for input safety is a common AI-generated-code
shortcut — it's a real security control that "sounds" satisfied by the
auth check already being present nearby.

**Fix:** `internal/netguard` (new) — a private/loopback/link-local/cloud-
metadata IP denylist, checked both at validation time (resolve + check) and
at actual dial time via a custom `DialContext` (closes the TOCTOU/DNS-
rebinding gap validation-only leaves open).

**Rule:** "the caller is authenticated/trusted" is never sufficient
justification to skip a real input-safety check on a value that results in an
outbound network connection — check dial-time IP, not just parse-time syntax.

---

## New DB-touching packages shipped with zero DB-backed tests

**Pattern:** `courses`, `mcpconnect`, `roadmap`, and `whatnow` all had only
pure-Go unit tests — nothing exercised the actual repo/DB layer, reasoned as
"no DB test infra exists yet" (true, but never actually built).

**Why it's a problem:** a "no test infra yet" note left in 4 different
packages independently is a sign the infra should have been built once and
reused, not deferred package-by-package. AI agents writing a new package in
isolation tend to match the *local* file's existing test style rather than
noticing the cross-package gap.

**Fix:** `internal/testdb` — a shared testcontainers-go + Postgres-template-
clone helper, reusing the existing migration runner (`db.RunMigrations`).

**Rule:** a new package that talks to the DB uses `internal/testdb` for its
repo-layer tests from the first PR — "we'll add DB test infra later" is not
an acceptable deferral once the infra exists.

**Concrete cost of skipping it, found while closing out this very item:**
building `internal/testdb` and actually running a real DB against
`assessment`'s batch/offline-test code (which had never been exercised
against a live database) surfaced **four separate, independent, silently-
broken bugs stacked in two functions** — none caught by any existing test,
build, or vet, because nothing had ever actually run the SQL:
- `CreateBatch` etc. (`internal/assessment/repo_batch.go`) referenced
  `batches.mentor_id`, a column no migration had ever created — every batch
  creation/update/list call was failing at the DB.
- `mcpconnect/repo.go`'s `InsertActionLog` inserted into `audit_logs.user_id`
  — the real column is `actor_user_id` — so every MCP tool-call audit-log
  write was failing at the DB.
- `CreateOfflineTestScores` (`internal/assessment/repo_offline_tests.go`)
  left `assessments.slug` (`NOT NULL`) unset on insert.
- The same function's score-insert query joined `unnest(...) AS x(user_id)`
  against a separate `unnest(...) WITH ORDINALITY` subquery aliased
  `scores`, then selected `x.score` (a column that only existed on the
  *other* alias) and filtered on `x.ordinality` (which `x` was never given
  an ordinality column to have) — then its `ON CONFLICT (assessment_id,
  user_id)` didn't even match the table's real unique constraint, which
  includes `attempt_number` too.

Each bug alone would have been a two-line fix if caught at write time. Four
of them compounding, undiscovered until a live DB finally ran the code, is
what "no DB test infra" actually costs — not a hypothetical, an outage
waiting for the first real batch/offline-test/MCP-log write in production.

---

## "Add a lock" isn't enough — the lock must span the check AND the write

**Pattern:** `mentoring/service_purchase.go`'s coupon race fix looked like it
just needed `FOR UPDATE` added to the existing read. It doesn't: locking the
coupon row, releasing it, then writing the purchase row in a second
transaction re-opens the exact same race — the lock only closes the gap
while it's held continuously from the cap check through the insert that
consumes the slot.

**Why it's a problem:** "add a lock" sounds like a one-line fix, so it's
tempting to bolt `FOR UPDATE` onto the existing read without restructuring
around it. The actual fix required moving the check *and* the create into
one transaction (`internal/mentoring/repo.go`'s `LockCouponRedeemedCount` /
`CreatePurchaseTx`), not just adding a clause to the read.

**Rule:** when a debt comment says "lock the row" as the fix, verify the
write it's protecting happens inside the same transaction as the lock —
not just somewhere after it.

---

## A ledger's own suggested fix isn't automatically implementable

**Pattern:** the debt-ledger comment for labproxy's port cookie named its own
upgrade path: `8080.previewid.labs.mindforge.test`. That format can't actually
get a TLS certificate — a wildcard cert covers exactly one DNS label, and
`*.*.domain` isn't issuable by any CA. The real fix needed a different
hostname shape (`p<port>-<sessionID>.domain`, one label) that the original
comment never considered.

**Why it's a problem:** a debt comment's "upgrade" note captures what its
author was thinking at the time, not a verified design — treating it as
already-designed skips exactly the verification step comments like this are
supposed to save you from needing.

**Rule:** verify a named "upgrade path" is actually implementable (cert
issuance, API availability, whatever the mechanism depends on) before
building toward it — the comment is a lead, not a spec.

---

## Check the sibling function in the same package before reaching for a different package's pattern

**Pattern:** `labs/service_ports.go`'s rate-limit fix was initially specced
to use `internal/ratelimit` (the Redis sliding-window package used by
`auth/handler.go`). The `labs` package already has its own established
rate-limit idiom — a plain Redis `SetNX` cooldown key, used by three sibling
functions in the same package (`RunScript`, `SubmitAll`, `VerifyTask` in
`service_sandbox.go`/`service.go`). The locally consistent pattern was a
better fix than importing a different package's mechanism.

**Rule:** before wiring in a cross-package utility, check whether the target
package already has its own established idiom for the same concern —
consistency with immediate siblings usually beats consistency with a
different subsystem's approach.

---

## Ceiling comments that describe the fix instead of applying it

**Pattern:** several `ponytail:` comments named the exact correct fix (e.g.
`recurrence.go`: "fixed 2000-step scan cap instead of closed-form window
jump") but shipped the cheaper workaround anyway, with the real fix left as a
future "upgrade."

**Why it's a problem:** when the comment already states the proper
implementation, shipping the workaround isn't really saving effort — it's
deferring effort that's already been designed, onto whoever hits the ceiling
later (with less context than the person who wrote the comment had).

**Rule:** if a shortcut's own comment names the concrete correct
implementation, prefer doing that up front unless there's a real reason
(unclear requirements, genuinely speculative need) — not just "this cap is
big enough for now."

---

## A cross-domain batch that aborts on the first failure, discarding already-applied work

**Pattern:** `diary.Service.applyHighlights` (called from `Apply`) looped over
AI-detected highlights, writing each one's mutation to either `diary`'s own
repo or `habit.Service` (a separate domain, separate DB call — no shared
transaction is possible without a bigger cross-package refactor). On the
first mutation error, it returned immediately with `nil, err` — discarding
every highlight already applied earlier in the same loop. Because `Apply`
never called `SaveAnalysis` on a nil/error result, none of that partial
progress was recorded as "already applied" in `entry.Highlights` either.

**Why it's a problem:** the individual mutations mostly self-heal on retry
(title/date-based dedup), so this wasn't silent data corruption — it was
silently redone work plus an all-or-nothing batch that looked atomic in the
code's control flow but wasn't backed by an actual transaction spanning two
domains. A reviewer skimming the `return nil, err` pattern would reasonably
assume the whole batch is transactional, when it demonstrably isn't.

**Fix:** continue processing remaining highlights past a failed one
(collecting errors with `errors.Join` instead of returning immediately), and
always call `SaveAnalysis` with whatever succeeded — even when returning an
error to the caller. Partial success is now persisted instead of discarded.

**Rule:** when a loop's mutations cross a package/domain boundary a single DB
transaction can't span, don't reach for "abort on first error" as a stand-in
for atomicity — it isn't atomic, it just discards partial progress. Either
build a real cross-domain transaction (bigger lift, only worth it if the
mutations aren't independently idempotent) or make the loop resilient:
continue past failures, persist partial results, and rely on per-mutation
dedup to make retries safe.

## A test that writes to the real content tree instead of a temp dir

**Where found:** `backend/internal/contentpipeline/importer/importer_test.go`
(fixed 2026-09-27). `TestImport_RealSnapshot` ran `os.RemoveAll` on the real
`content/courses/fast-kubernetes/` directory and re-scaffolded it, "because
the output is the actual deliverable content". Every `go test ./...` after
the course was hand-authored silently deleted its lab tasks, quizzes and
`course.yaml`, replacing them with empty stubs. The importer itself also used
`os.WriteFile`, so even a deliberate `coursegen import` overwrote finished
files without a warning. The loss went unnoticed because the
stubbed labs still parsed; only `generate` (which rejects `tasks: []`) would
have caught it, and nobody re-ran it.

**Fix:** the test now imports into `t.TempDir()` and asserts a second import
is refused; the importer opens files with `O_EXCL` and errors on any existing
file.

**Rule:** a test may read real repo content but must never write, delete or
regenerate it. Tests write to `t.TempDir()`. Scaffolding commands that feed a
hand-authoring step must refuse to overwrite existing files, not "regenerate"
them.

## A negative check that accepts any failure

**Found in:** the debug-lab fault `dj.mig.backfill-duplicate-slugs` (Phase 1d-ii, 2026-10-02).

The verification matrix requires the broken version to fail its symptom
check. It did fail, so the build "passed". But the migration probe failed for
an unrelated reason: the authored migration added a `SlugField` (indexed by
default) and then made it unique, and Django on Postgres tried to create the
`_like` index twice. The reference fix hit the same crash, which is the only
reason it was noticed at all. The probe raised a bare failure with no
diagnostic, so nothing showed *why* it failed.

**Fix:** probes can attach an author-only `detail` (stderr, never the student
JSON); the migration probe reports the failing step, exit code and output tail.
The migration now adds the column with `db_index=False`, and the broken run
fails with the duplicate-slug `IntegrityError` the ticket describes.

**Rule:** an "expected to fail" check proves nothing unless the failure is the
intended one. Make failing checks say why (to a channel the end user can't
see), and read that reason when authoring, not just the pass/fail bit.


## Money paths written for the happy path only

**Found in:** `sessions` credit packs and `mentoring` webhooks (compliance audit, 2026-10-07).

Three instances of one pattern. (1) `CreatePackPurchase` never wrote the `granted` JSON that `CompletePurchase` later read, so a pack payment could not credit the ledger; no test ran the two calls together. (2) Refund and dispute events were parsed but nothing acted on credit packs, and the admin refund called the gateway before recording any intent, so a crash left a refunded charge marked `completed`. (3) The webhook swallowed internal failures with a 2xx and deduped redeliveries by event id alone, so a failed confirm could never be retried.

**Fix:** persist a `refunding` status before the gateway call; reverse through a guarded status transition plus a capped ledger entry (never negative, shortfall recorded); dedupe only events with `processed_at` set; return non-2xx on retryable failures; add a reconcile sweep that alerts on stuck rows.

**Rule:** for every write whose result another function reads, add one test that runs both. Any external side effect (gateway refund) is preceded by a persisted intent. A dedupe key must mean "fully handled", not "seen".

## Docs claiming features the code does not have

**Found in:** `auth.md`, `interview.md`, `calendar-sync.md`, `design.md` (2026-10-07): magic link, OIDC/SAML, device list, `switch-org`, the Yjs relay, Google Calendar sync, the `/design` embed.

Design docs written before the build read as if the feature shipped, and a schema column (`allow_magic_link`, `oidc_*`) made the claim look real. A reader (or an agent) then trusts a route that returns 404.

**Fix:** each unbuilt claim is marked "planned (not built)" at the top of its section.

**Rule:** a design doc gets a status line the day it is written, and the line is removed only by the change that builds it. A column without a route is not a feature.

## Personal data reachable through an org-scoped door

**Found in:** admin user overview, leaderboards, public-test tokens (2026-10-07).

The admin overview joined tables that have no `org_id` (journal, mistakes, habits), so any org admin could read a user's private history from before they joined. Leaderboards built their Redis key from a client-supplied `scope_id`. Public-test tokens were valid for any test code and never expired.

**Fix:** drop the personal tabs; pin scopes to the caller's org and verify ownership of batch/group/course ids; anonymise the global board; bind tokens to their test and expire them.

**Rule:** a query that crosses a tenant boundary needs the tenant id in the query itself. A table without `org_id` never appears in an org-admin view. An id from the request is a claim to verify, not a key to use.

## Consent and retention bolted on after the data flow

**Found in:** captures, diary AI, `auth_events`, public candidates (2026-10-07).

AI features shipped sending user text to a third party with no opt-in, security events had no append-only guarantee or purge, and candidate PII was kept forever.

**Fix:** a shared `privacy.RequireAIConsent` check at every AI entry point, an append-only trigger with a purge-only escape hatch, and a single `retention.purge` job with per-class windows.

**Rule:** a new feature that sends user content to a model, or stores identifying data, names its consent check and its retention window in the same change.

## Whole-repo audit (2026-10-08)

Patterns found across the backend and frontend during the audit pass. Each entry names the shape to look for and the rule that prevents it.

### Best-effort writes swallowed silently
**Found in:** gitlab roster sync and provision status, rewards leaderboard, sessions decode, whatnow energy dial, profile avatar cleanup.
**Shape:** `_ = call()`, `x, _ := call()`, or `.catch(() => {})` where the failure changes what the user sees or what is stored.
**Rule:** best-effort writes are logged; reads that feed a response are checked and returned as errors.

### Scan or lookup error discarded before branching
**Found in:** gitlab DeleteAssignment existence check, assessment hasResult check, calendar invite consume.
**Shape:** the error from `Scan`/`QueryRow` is dropped and the zero value is branched on, so a DB failure becomes a wrong domain answer.
**Rule:** check the error before using the value.

### Multi-statement write outside a transaction
**Found in:** auth logout-all (refresh revoke plus session-version bump), calendar invite accept.
**Rule:** a multi-table or multi-statement change runs in one transaction; a token is consumed inside the same transaction as the action it authorises.

### Fail-open authz helper
**Found in:** `middleware.LiveOrgRole` returns `(role, bool)` and swallows DB errors, so a mentor's batch scope silently widens on error.
**Rule:** authz helpers return an error and the caller denies on error.

### AI call bypassing the backend
**Found in:** frontend `parseResumeAction` called Anthropic directly from the Next server, with a hardcoded model and no consent check.
**Rule:** every model call goes through the backend provider, behind `privacy.EnforceAIConsent` and the quota wrapper.

### Untyped JSON from the DB or a model
**Found in:** calendar invite payload (unchecked `.(string)`), resume extract.
**Rule:** decode into a struct with an error return; never assert on map values from stored or model output.

### Unpaginated lists and hardcoded caps
**Found in:** roadmap Discover (`LIMIT 50`, no offset), interviewexp `ListEntries` (`LIMIT 500`), and several list endpoints still unpaginated (diary tasks, assessment attempts, student progress).
**Rule:** public or growing lists take `limit`/`offset` with a bounded default and max.

### Dead exports and orphaned UI
**Found in:** about 80 lib declarations and about 35 app exports with zero callers after their UI was removed.
**Rule:** delete the endpoint wrapper and action together with the UI that calls it.

### Env value copied into each consumer
**Found in:** `ws://localhost:18081` read and defaulted in three frontend files.
**Rule:** read an env var once in one exported constant and import it.

### Test that runs a copy of the code
**Found in:** db seed-order comparator duplicated in `seed_test.go`.
**Rule:** tests call the production function, never a re-implementation of it.

### Helper copied per call site
**Found in:** `formatDate` (4 copies), SQL cell formatter (2), countdown formatter (2), GetClaims+401 block (16), consent check (2).
**Rule:** extract on the second use, not after the fifth.
