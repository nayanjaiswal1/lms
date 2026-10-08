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
  one SMTP connection per recipient — paced and tracked per invite, see items 6 and 8.

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
- [x] **FIXED**: `SendDuplicateRegistration` and `SendPasskeyCloneAlert` are now
      `auth.DuplicateRegistrationMessage` / `PasskeyCloneAlertMessage` builders;
      `EmailHandler` handles types `duplicate_registration` and
      `passkey_clone_alert`, enqueued with idempotency keys like
      `enqueueAuthEmail`.

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
- [x] **FIXED**: SMTP 4xx/429 replies become `mailer.ThrottleError`, handled as
      `jobs.RetryAfter` (min `EMAIL_THROTTLE_BACKOFF`, honoured by `jobs.Fail`,
      does not consume retries). A Redis-backed circuit breaker
      (`mailer/breaker.go`, `EMAIL_BREAKER_*`) pauses all sends after repeated
      transient failures.
- [x] **FIXED**: `EmailHandler.Handle` validates `to` with `net/mail` before
      SMTP; malformed addresses fail via `jobs.Permanent`.
## 4. No dead-letter follow-through for email — PARTIALLY FIXED (operators alerted; end users not)

- [x] `handlers.NewEmailDeadHook()` and `handlers.NewInviteDeadHook()`
      (registered in `cmd/server/main.go`) log a structured, alertable
      `slog.Error` — including `job_id`, `email_type`/`org_id`, `to`/
      `email_count`, and `last_error` — whenever either job type permanently
      dies. A downed relay or bad creds is now visible in logs at the moment
      it stops being retryable, not just discoverable by querying the `jobs`
      table's `last_error` column after the fact.
- [x] **Admin alerting**: every dead job (including `email.send` and
      `invite.bulk`) now raises an in-app notification to the right operators
      via `internal/opsalert` (org jobs -> that org's owners/admins, platform
      jobs -> super admins; high-severity handlers also email, except a dead
      `email.send` which never emails to avoid looping on an SMTP outage).
      Repeats are deduped per window and bursts collapse into one storm alert;
      `ops.health` (every 5 min) also alerts on a high `email.send` dead rate.
      See [ops-alerts.md](ops-alerts.md).
- [ ] Not built — needs product decision: the user-facing dead
      `password_reset`/`auth_verify` banner. A dead job reaches operators only;
      the requesting user has no status to poll.
- [x] **FIXED** for `invite.bulk`: the dead hook marks the chunk's unsent invites
      `email_status = failed`, visible to org admins (item 8).

## 5. No delivery status / bounce tracking — not built

- [ ] Not built — needs provider webhook. `job_runs.status` only reflects "SMTP
      accepted the send for relay", not delivery/bounce/complaint.

## 6. Bulk-provider / rate-limit posture — FIXED

- [x] `invite.bulk` paces sends inside a chunk by `INVITE_SEND_DELAY`.
- [x] Per-org send quota (`EMAIL_ORG_MAX_PER_MINUTE` / `EMAIL_ORG_MAX_PER_DAY`,
      overridable via `org_settings.jobs`) is enforced in `EmailHandler` for
      org jobs; exceeding it returns `jobs.RetryAfter` (deferred, never dead).

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
- [x] **FIXED**: migration 064 adds `org_invites.email_status`
      (`pending`/`sent`/`failed`) and `email_error`. `invite.bulk` records the
      result per invite, the dead-letter hook marks the chunk's unsent invites
      failed, the invite API exposes both fields, and the invite list shows
      "Failed — resend" using the existing Resend action (which resets the
      status to `pending`).
