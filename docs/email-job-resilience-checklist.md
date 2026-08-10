# Email & Job-Queue Failure Resilience Checklist

Working notes on where MindForge's email delivery is solid vs. where a
cascading failure (SMTP down, bad creds, rate limits, wrong recipient, etc.)
could go unnoticed or degrade something it shouldn't. Originally an audit
dated 2026-08-05; items below are marked with what was fixed the same day.
Re-verify line numbers if this file is read much later.

## Current architecture (for context)

- **Queued path**: `EmailHandler` (`backend/internal/jobs/handlers/email.go`)
  runs as a `jobs.Handler` for `email.send` jobs — used by auth
  verification/password-reset, eval-complete, SM-2/SRS reminders, calendar
  reminders, mentor escalation, and ticket notifications.
- **Sender**: single `mailer.Sender` implementation, `SMTPSender`, plus an
  exported `mailer.SendRaw` for callers (auth, invite) that build their own
  message — both go through one shared, context-bounded SMTP transaction
  (`backend/internal/mailer/smtp.go`). No provider abstraction, no bulk API
  — still a deliberate choice per the package doc, not an oversight.
- **Retry**: generic job-queue retry in `jobs.Fail`
  (`backend/internal/jobs/store.go`) — exponential backoff (`2^retryCount *
  2s`, capped at 5 min), default `maxRetries = 3`, then `status = 'dead'`,
  *unless* the handler wrapped its error in `jobs.Permanent(...)`, in which
  case it goes dead immediately regardless of retries remaining.
- **Dead-letter**: `Registry.OnDead` hooks are registered for both
  `HandlerEmailSend` and `HandlerBulkInvite` (`cmd/server/main.go`) — a dead
  job now produces a structured `slog.Error` instead of vanishing into
  `last_error` unseen.
- **Bulk invites**: org-invite-bulk handler
  (`backend/internal/orgs/handler.go`) chunks emails into groups of 50 and
  enqueues one `invite.bulk` job per chunk. Each job still sends serially,
  one SMTP connection per recipient — see item 6, still open.

---

## 1. Auth emails bypass the job queue entirely — FIXED

- [x] `register`, `resend-verification`, and `forgot-password`
      (`backend/internal/auth/handler.go`) now call `h.enqueueAuthEmail(...)`,
      which inserts an `email.send` job (type `auth_verify`/`password_reset`,
      idempotency-keyed on the token hash) instead of calling
      `auth.SendVerification`/`SendPasswordReset` inline. Those two functions
      are now called exclusively from `EmailHandler.Handle`'s
      `auth_verify`/`password_reset` cases — no longer dead code. An SMTP
      outage now delays the email (retried by the queue) instead of either
      blocking the HTTP response or silently dropping the send.
- [x] Bonus effect: the forgot-password anti-enumeration timing gap between
      "known email" (used to wait on a live SMTP round-trip) and "unknown
      email" (returned immediately) is narrowed — the known-email path now
      only does a fast `INSERT INTO jobs`, not a network call.
- [ ] **Still open, deliberately out of scope**: `SendDuplicateRegistration`
      and `SendPasskeyCloneAlert` (`auth/email.go`) remain synchronous. They
      have no corresponding job-queue `type` case in `EmailHandler` today;
      wiring them in is straightforward but wasn't part of this pass.

## 2. Job-level timeout doesn't actually bound the SMTP call — FIXED

- [x] `mailer.SendRaw` (`mailer/smtp.go`) now dials with `net.Dialer.DialContext`
      and sets a hard `conn.SetDeadline` from the context's deadline (default
      20s if the caller's context carries none), so the whole SMTP
      transaction — dial, handshake, `DATA` write — is actually bounded. Used
      by `SMTPSender.Send` (the job-queue path, which already had a job-scoped
      context), `auth.sendSMTP` (fixed 20s, since its callers don't carry a
      context), and `InviteHandler.sendInviteEmail` (now threads the job's own
      context through instead of building its own unbounded `net/smtp` call).

## 3. No error classification — permanent vs. transient — FIXED (SMTP layer)

- [x] `mailer.SendRaw` classifies any 5xx SMTP reply (`*textproto.Error`,
      code 500–599 — bad credentials, rejected recipient, rejected sender) as
      a `mailer.PermanentError`. `jobs.Permanent(err)`
      (`backend/internal/jobs/errors.go`, new) lets a handler mark its error
      as non-retryable; `jobs.Fail` now checks `errors.As` for it and skips
      straight to `dead` regardless of retries remaining. `EmailHandler`'s
      `classifyErr` helper wires the two together for all four email types
      (`auth_verify`, `password_reset`, `eval_complete`, `notification`).
- [ ] **Still open**: 4xx "too many messages" / provider-throttle replies are
      *not* given special treatment beyond the existing exponential backoff —
      there's no longer-than-normal backoff specifically for rate-limit
      responses, and nothing pauses the whole handler when a burst of jobs
      are all hitting the same throttle. Only matters once a real
      rate-limited provider is in the loop (see item 6).
- [ ] **Still open**: `to` address *shape* still isn't validated before a
      worker attempts SMTP delivery for `eval_complete`/`notification`/
      calendar-reminder jobs — only the org-invite-bulk endpoint validates
      shape before enqueueing. A malformed `to` now correctly dies fast
      instead of retrying (RCPT TO will 5xx), so the cost of this gap is
      lower than before, but it's still a wasted round-trip per job.

## 4. No dead-letter follow-through for email — PARTIALLY FIXED

- [x] `handlers.NewEmailDeadHook()` and `handlers.NewInviteDeadHook()`
      (registered in `cmd/server/main.go`) log a structured, alertable
      `slog.Error` — including `job_id`, `email_type`/`org_id`, `to`/
      `email_count`, and `last_error` — whenever either job type permanently
      dies. A downed relay or bad creds is now visible in logs at the moment
      it stops being retryable, not just discoverable by querying the `jobs`
      table's `last_error` column after the fact.
- [ ] **Still open**: this is logging only, not a feedback loop. A dead
      `password_reset`/`auth_verify` job still leaves the requesting user
      with no signal beyond "check your email" and nothing ever arriving —
      there's no UI-facing status to poll. Wiring that up is a larger,
      product-facing decision (does the frontend poll job status? show a
      banner?) that wasn't part of this pass.
- [ ] **Still open**: for `invite.bulk`, the dead-letter hook logs the chunk
      but doesn't (yet) do anything an org admin can see — see item 8.

## 5. No delivery status / bounce tracking — still open

- [ ] No change. `job_runs.status` still only reflects "SMTP accepted the
      send for relay," not actual delivery/bounce/complaint status — that
      would require either a transactional-email provider with delivery
      webhooks, or explicitly documenting the gap. Unchanged by this pass.

## 6. Bulk-provider / rate-limit posture — still open

- [ ] `invite.bulk` still sends up to 50 emails one SMTP connection each,
      serially, no throttle (`jobs/handlers/invite.go`) — now at least
      context-bounded per connection (item 2), but no pacing between them.
      Matters once a real rate-limited provider replaces the dev relay.
- [ ] No per-org send-rate quota exists — `jobs.CheckEnqueueQuota` still only
      caps pending+queued job *count* per org, not emails/minute against a
      provider. Unchanged by this pass.

## 7. Config safety net — FIXED

- [x] `config.Load()` now calls `os.Exit(1)` if `cfg.IsProd()` and
      `SMTP_HOST` is still the `localhost` default — mirrors the existing
      Stripe/Razorpay-webhook-secret fail-fast pattern. A missing
      `SMTP_HOST` in production now fails at boot instead of silently
      pointing every send at a relay that doesn't exist.
- [x] `invite.go`'s dev/prod email gate now uses `cfg.ShouldSendRealEmail(to)`
      instead of `cfg.IsProd()`, matching every other email path and
      honoring `DEV_EMAIL_ALLOWLIST` — org-invite emails can now be tested
      against a real inbox in dev the same way auth/eval-complete emails can.

## 8. Per-org invite specifics (answering "if we allow per-org invite")

- [x] Bulk invite already validates address shape, dedupes, and skips
      existing members *before* enqueueing (`orgs/handler.go`) — keeps
      obviously-bad input out of the job queue.
- [x] Chunking at 50/job bounds blast radius of a single job retry.
- [x] Dev/prod gate now aligned with the rest of the codebase (item 7).
- [x] Sends now go through the same context-bounded, classified SMTP path as
      everything else (items 2/3), and a permanently-dead chunk is now
      logged (item 4) instead of silent.
- [ ] **Still open**: a failed *individual* invite email inside a chunk is
      still swallowed as a warning (`invite.go`, "invite created, will need
      resend") — the invite row exists and `InviteService.Resend` works, but
      nothing surfaces to the inviting admin which specific emails in their
      batch need a manual resend. Would need a per-invite delivery-status
      column (or reusing `revoke_reason`-style tracking) surfaced on the
      invite list — a small schema change, not done here.
