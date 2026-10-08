# Ops Alerts

Operators are notified (in-app, and by email for high severity) when the job system fails. Package: `backend/internal/opsalert`. Jobs UI link in every alert: `/platform/jobs`.

## Dead-letter alerts
`Registry.OnAnyDead` fires for every dead job in addition to the per-handler `OnDead` hook. `Service.OnJobDead` never blocks or fails the worker; errors are only logged.

Routing:
- Job has `org_id` -> that org's active `owner`/`admin` members.
- Otherwise -> all `users.platform_role = 'super_admin'`, attributed to the super admin's oldest active org (`notifications.org_id` is NOT NULL); super admins with no org are skipped with a warning.

## Rules (`ops_alert_rules`)
One row per handler, `'*'` is the default. Columns: `severity` (low/normal/high), `dedupe_window_minutes`, `storm_threshold`, `storm_window_minutes`, `enabled`.

- `high` => notification priority high and `AlsoEmail` (except for `email.send` itself, which would loop on an SMTP outage).
- Seeded high: `email.send`, `invite.bulk`, `payments.reconcile`, `retention.purge`, `gitlab.token_refresh`, `lab.recipe_build`, `lab.recipe_verify`. Default: normal, 15 min, storm 10 in 10 min.
- `enabled = false` suppresses alerts for that handler.

## Frequency control
- Dedupe key `deadjob:<handler>:<orgOrPlatform>:<unix / window>`: repeats inside one window collapse to one notification per recipient.
- Storm: if dead jobs for the handler updated within `storm_window_minutes` exceed `storm_threshold`, one `deadstorm:` notification ("N dead X jobs in M min — likely systemic outage") replaces the per-job ones, deduped per storm window.

## Cron jobs
- `ops.health` (`*/5 * * * *`), super admins only, each condition deduped per hour:
  - queued one-time job waiting longer than `OPS_QUEUE_STALE_MINUTES` (default 15)
  - `email.send` dead rate over the last 15 min >= `OPS_EMAIL_DEAD_RATE_PERCENT` (50) with at least `OPS_EMAIL_DEAD_MIN_SAMPLE` (5) finished jobs
  - jobs `running` longer than 2x their `timeout_ms`
- `ops.digest` (`0 8 * * *`): one low-priority notification per super admin (platform-wide) and per org admin (their org) with dead jobs by handler (24h), failed runs (24h) and queue depth; skipped entirely when all zero.

## API (platform super admin only)
- `GET /api/admin/ops-alert-rules` - list rules, default first.
- `PUT /api/admin/ops-alert-rules` - upsert a rule (body: `handler, severity, dedupe_window_minutes, storm_threshold, storm_window_minutes, enabled`). Bounds: windows 1-1440, threshold 1-100000; invalid input returns 400.

DB: migration `063_ops_alerts`.
