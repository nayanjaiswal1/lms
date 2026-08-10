# Support Ticket Notifications — RBAC Decision

## Background

Support ticket create/reply now sends email (see `backend/internal/tickets/service.go`,
`notifyCreated`/`notifyReply`). The "who's staff" side of that notification reuses the existing
`support.manage` permission check — the same one the ticket queue API/UI already gates on
(`ManagePermission[KindSupport]`, `backend/internal/tickets/models.go`).

There is no dedicated "support team" concept in MindForge. `support.manage` is a permission, and
per the baseline seed (`backend/db/migrations/001_baseline.sql:3885-3887`) it's granted by default
to three system roles:

- `instructor`
- `mentor`
- `tenant_admin`

So today, every instructor and every mentor in an org — not just people actually doing support —
gets emailed on every new ticket, and on every reply to an unclaimed ticket. That's fine for a
small org; it gets noisy fast once an org has more than a handful of instructors/mentors who have
nothing to do with support.

## The fork

`support.manage` isn't just a notification switch — it's the same permission that gates the
support ticket queue API and UI (view queue, reply, close). Narrowing who gets emailed and
narrowing who can *manage* tickets are the same code path today, so the decision has to cover both.

### Option A — Revoke `support.manage` from `instructor`/`mentor` (recommended)

Add a new system role, `support_agent`, scoped to just `support.manage`. Remove `support.manage`
from `instructor` and `mentor` in the seed. Only `tenant_admin` (kept as a fallback so tickets are
never silently unhandled) and whoever an org assigns to `support_agent` can see the queue, reply,
or get emailed.

- **Pro:** matches the actual goal — instructors/mentors shouldn't be fielding general support
  tickets, so they shouldn't have the capability *or* the inbox noise.
- **Con:** real capability change, not just a notification change. Any org currently relying on an
  instructor or mentor to handle support tickets loses that ability the moment this ships, until
  someone is explicitly assigned `support_agent` or `tenant_admin`.

### Option B — Keep instructor/mentor's access, narrow only the email list

Leave `support.manage` on `instructor`/`mentor` as-is (queue/reply/close unchanged). Add the
`support_agent` role purely as an opt-in "notify list" — introduce a second, narrower permission
(or a role-based notify filter) that `notifyCreated`/`notifyReply` check instead of
`support.manage`, defaulting to `support_agent` + `tenant_admin`.

- **Pro:** zero capability regression — nobody who could manage tickets before loses that.
- **Con:** two separate concepts to maintain going forward ("can manage" vs "gets paged"), and an
  org has to actively assign `support_agent` or the new list is just `tenant_admin` — same
  cold-start problem as Option A, without the cleanup benefit of narrowing the queue's blast
  radius too.

## Status

**Decided: Option A.** Implemented in `001_baseline.sql` — added system role `support_agent`
(id `11111111-1111-1111-1111-000000000006`, `support.manage` only), and removed `support.manage`
from `instructor`/`mentor`'s `role_permissions` rows. `tenant_admin` keeps it as the fallback so
tickets are never silently unhandled. No code change needed (per the note below — `notifyCreated`/
`notifyReply` already resolve whoever currently holds `support.manage`), but this is a live
capability change: any org relying on an instructor or mentor to handle support tickets loses that
ability until someone is assigned `support_agent` or `tenant_admin`. Existing seeded/dev orgs should
assign `support_agent` to whoever was actually doing support before this shipped.
