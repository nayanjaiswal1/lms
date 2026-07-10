# Calendar Account Sync

Opt-in, two-way sync between a user's MindForge calendar and their personal
Google Calendar account. Off by default for every user; nothing about a
user's Google account is touched until they explicitly connect it from
Settings, and disconnecting fully stops and unwinds sync.

This is additive to the existing in-app calendar (`backend/internal/calendar`)
and its one-way ICS subscribe feed (`GET /api/calendar/events.ics?token=`).
The ICS feed stays as the zero-setup, no-OAuth option; this feature is for
users who want their MindForge events to actually appear as real Google
Calendar events (and vice versa), live.

## Non-Negotiables

- **Opt-in only.** No account is ever connected, and no data ever leaves or
  enters MindForge via this path, without the user completing an explicit
  OAuth consent screen they initiated from Settings. No auto-prompt, no
  silent background enrollment, no org-admin-forced sync.
- **Separate consent from login.** The existing `google` OAuth flow in
  `backend/internal/auth/social.go` is login-only (`AccessTypeOnline`,
  `openid email profile` scopes, no refresh token persisted). Calendar sync
  is a distinct, incremental-auth flow with its own scope and its own
  callback route — logging in with Google must never implicitly grant
  calendar access.
- **Least privilege scope.** Request `https://www.googleapis.com/auth/calendar.events`
  only (create/read/update/delete events), not the full `.../auth/calendar`
  scope, which also exposes calendar list management and ACLs MindForge
  never needs.
- **Fully revocable.** Disconnecting from Settings must: revoke the token at
  Google, stop all sync jobs for that user, delete the stored token, and
  delete the sync watch channel. No orphaned server-side state after
  disconnect.

## Architecture

### OAuth Flow (Incremental Auth)

1. User clicks "Connect Google Calendar" in Settings → hits
   `GET /api/calendar/google/connect` (new, distinct from
   `/api/auth/google`).
2. Backend redirects to Google's consent screen with
   `AccessTypeOffline`, `ApprovalForce`/`prompt=consent` (required to
   guarantee a `refresh_token` on every connect, including reconnects),
   scope `calendar.events`, and a signed CSRF `state` cookie — same
   state-cookie pattern as `social.go`.
3. Callback `GET /api/calendar/google/callback` exchanges the code, stores
   the encrypted access + refresh token in `calendar_account_links`, and
   redirects back to the Settings page with a success/error flag.
4. Immediately after first connect, run one bootstrap sync (pull existing
   Google events for the sync window, push existing eligible MindForge
   events) synchronously or as an immediate job enqueue — the user should
   see something happen right away, not wait for the next poll cycle.

### Push (MindForge → Google)

- Applies to `calendar_events` rows the connected user owns or is an
  attendee of (`EventTypeMentorSession`, `EventTypeLiveClass`,
  `EventTypeDeadline`, `EventTypeCustom`, `EventTypeTask` — never the
  virtual `EventTypeAssessment` rows, which have no backing row to link).
- On create/update/delete of an eligible event, enqueue a push job (reuse
  the existing `backend/internal/jobs` worker pattern, alongside
  `calendar_reminder.go`) that calls Google's `events.insert` /
  `events.patch` / `events.delete`.
- Store the link in a new `calendar_event_google_links` table
  (`event_id, user_id, google_calendar_id, google_event_id, updated_at`) so
  updates/deletes target the right Google event instead of creating
  duplicates.
- Recurring events: MindForge's `recurrence_rule` is already an RFC 5545
  RRULE subset (`backend/internal/calendar/recurrence.go`) — pass it through
  to Google's event `recurrence` field as-is rather than expanding
  occurrences before push.
- Tag every pushed event with
  `extendedProperties.private.mindforge_event_id = <event.ID>`. Pull must
  skip events carrying this property — otherwise a MindForge-originated
  event echoes back as a duplicate "external" import.

### Pull (Google → MindForge)

- Pull is for visibility/conflict-avoidance, not full import: external
  Google events land as a read-only, non-editable event type in the user's
  MindForge calendar view (do not silently merge them into
  `calendar_events` as first-class editable rows).
- Use `events.list` with a stored `sync_token` for incremental sync
  (`calendar_account_links.sync_token`); a full resync only happens when
  Google returns `410 GONE` (sync token expired).
- Prefer push notifications (`events.watch`) over polling for near-real-time
  pull: register a webhook channel, receive `X-Goog-Resource-State`
  notifications on `POST /api/calendar/google/webhook` (public route, no
  session — validated by matching the opaque channel token, not by
  trusting the request), and trigger an incremental sync on notification.
  Channels expire (~7 days) — a renewal job must re-register before
  expiry. Fall back to a periodic poll job if webhook delivery fails
  repeatedly (self-hosted deployments may not have a publicly reachable
  callback URL — see Edge Cases).

## Database Schema

New migration (next number after `032_calendar_tasks.sql`):

```sql
CREATE TABLE calendar_account_links (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider            TEXT NOT NULL DEFAULT 'google',
    provider_account_email TEXT NOT NULL,
    google_calendar_id  TEXT NOT NULL DEFAULT 'primary',
    access_token_enc    BYTEA NOT NULL,
    refresh_token_enc   BYTEA NOT NULL,
    token_expires_at    TIMESTAMPTZ NOT NULL,
    sync_token          TEXT,
    watch_channel_id    TEXT,
    watch_resource_id   TEXT,
    watch_expires_at    TIMESTAMPTZ,
    status              TEXT NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active', 'expired', 'error')),
    last_synced_at      TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, provider)
);

CREATE TABLE calendar_event_google_links (
    event_id          UUID NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    google_calendar_id TEXT NOT NULL,
    google_event_id   TEXT NOT NULL,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, user_id)
);

CREATE TABLE calendar_external_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    google_event_id     TEXT NOT NULL,
    title               TEXT NOT NULL,
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ,
    all_day             BOOLEAN NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, google_event_id)
);
```

`access_token_enc`/`refresh_token_enc` are AES-GCM ciphertext, not plaintext
— see Security below. No existing encryption-at-rest helper exists in the
codebase today; this feature introduces the first one.

## API Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/calendar/google/connect` | session | Start incremental-auth OAuth redirect |
| GET | `/api/calendar/google/callback` | OAuth state cookie | Exchange code, store link, redirect to Settings |
| GET | `/api/calendar/google/status` | session | Connected? account email, last synced, calendar picked |
| POST | `/api/calendar/google/disconnect` | session + CSRF | Revoke token at Google, delete link + mappings |
| PATCH | `/api/calendar/google/settings` | session + CSRF | Change target Google calendar (default `primary`) |
| POST | `/api/calendar/google/webhook` | channel token (public) | Google push notification receiver |

## Frontend

- Settings → a new "Calendar Sync" section (alongside `profile/page.tsx` in
  `frontend/app/(app)/settings/`), not auto-surfaced anywhere else.
- States: **Not connected** (single "Connect Google Calendar" button, plain
  language about what will sync) → **Connected** (account email, last
  synced timestamp, calendar picker, "Disconnect" button) → **Error/expired**
  (reconnect prompt, e.g. after the user revokes access from their Google
  account settings directly).
- Disconnect requires no additional confirmation beyond the button itself —
  it's reversible (reconnect any time) and non-destructive to MindForge
  data.

## Background Jobs

- `calendar_google_push` — per-event push job, enqueued on
  create/update/delete of an eligible `calendar_events` row for any user
  with an active link.
- `calendar_google_pull` — per-account incremental sync, triggered by
  webhook notification or, as fallback, a periodic poll (e.g. every 15 min)
  for accounts whose watch channel isn't currently healthy.
- `calendar_google_watch_renew` — daily job renewing watch channels expiring
  within 24h.
- All three follow the existing `backend/internal/jobs/handlers` pattern
  (see `calendar_reminder.go`).

## Security

- Access + refresh tokens encrypted at rest with AES-GCM, key from
  `CALENDAR_TOKEN_ENC_KEY` (new env var, 32-byte key, never derived from a
  guessable default — startup fails fast if unset in production, matching
  the existing "no hardcoded fallback" rule).
- Webhook endpoint is unauthenticated by necessity (Google can't carry a
  session cookie) — validate by looking up the channel ID Google sends
  against `calendar_account_links.watch_channel_id` and treat the payload
  as a sync trigger only, never as a source of event data (always re-fetch
  from Google's API using the stored token, never trust webhook body
  content).
- Revoke-at-Google on disconnect is not optional — call
  `https://oauth2.googleapis.com/revoke` with the token before deleting the
  local row, so a user who disconnects in MindForge also sees the grant
  disappear from their Google account's third-party access list.
- `google_event_id`/`google_calendar_id` values are never exposed to other
  users — sync state is strictly per-user, even for shared/attendee events.

## Env Vars

Reuses `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` (same OAuth app as login,
different scope + redirect URI — Google OAuth apps support multiple
redirect URIs). New:

| Var | Purpose |
|---|---|
| `CALENDAR_TOKEN_ENC_KEY` | 32-byte key for AES-GCM encryption of stored OAuth tokens |
| `GOOGLE_CALENDAR_WEBHOOK_URL` | Publicly reachable HTTPS URL for `events.watch` push notifications (backend's public origin + `/api/calendar/google/webhook`) |

## Edge Cases

- **Self-hosted deployment with no public HTTPS origin.** `events.watch`
  requires a verified HTTPS callback URL; if `GOOGLE_CALENDAR_WEBHOOK_URL`
  is unset or unreachable, fall back to poll-only sync — don't fail the
  whole feature.
- **Refresh token revoked externally** (user removes MindForge from
  [myaccount.google.com/permissions](https://myaccount.google.com/permissions)).
  Next push/pull gets `invalid_grant` → mark `status = 'expired'`, stop
  retrying, surface a reconnect prompt in Settings. Do not silently retry
  forever against a dead token.
- **Same event edited on both sides between syncs.** Last-write-wins by
  `updated_at`/Google's `updated` field — no merge UI. Document this as the
  accepted behavior rather than building conflict resolution nobody asked
  for.
- **User deletes a MindForge event that was pushed to Google.** Push a
  delete to Google, then remove the `calendar_event_google_links` row.
- **User deletes the Google-side copy of a pushed event directly in
  Google Calendar.** Next push attempt gets `404`/`410` from Google →
  treat as "already gone," clear the link row, re-create on next relevant
  update rather than erroring.
- **Assessment virtual events (`IsVirtual = true`).** Never pushed — they
  have no stable backing row to link, and are already visible read-only in
  the in-app calendar.
- **Org member leaves the org / account deleted.** `ON DELETE CASCADE` on
  `calendar_account_links.user_id` and `calendar_event_google_links.user_id`
  cleans up rows; also revoke the Google token as part of user deletion,
  not just cascade the DB row.
