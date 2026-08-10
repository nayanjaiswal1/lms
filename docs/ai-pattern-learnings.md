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
upgrade path: `8080.previewid.labs.example.com`. That format can't actually
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
