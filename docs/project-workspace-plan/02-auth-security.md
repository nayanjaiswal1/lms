# 02 — Authorization, RBAC & Security Threat Model

Source design: [../project-workspace.md](../project-workspace.md). Planning only — no code changed. Checked against code as of 2026-09-25. Reconciled decisions that override parts of this file are in [00-decisions.md](00-decisions.md).

## 0. Facts from the code

| Fact | Where | Consequence |
|---|---|---|
| RBAC module `projects` has `projects.view` (all roles) and `projects.manage` (instructor, tenant_admin) — both for the GitLab assignment system | `001_baseline.sql:3645-3646, 3875-3881` | New codes use plural `projects.` prefix; leave existing two alone |
| Only `tenant_admin` is auto-synced (org owner/admin, `orgs/rbac_sync.go:syncTenantAdminRole`). Instructor/mentor/learner get no `user_roles` row unless an admin assigns one | `rbac_sync.go`, `invite.go:398`, `member.go:182,247` | "`projects.create` for mentors by default" only works if the RBAC role is assigned. Member routes must **not** be gated on `projects.view` |
| Org roles: `owner, admin, instructor, mentor, learner` | `001_baseline.sql:2109, 2092` | No `student` — invites use `learner` |
| `RequireOrgMember` reads `chi.URLParam(r,"id")` as org id | `middleware/org.go` | Project routes must use `{workspaceID}` / `{itemID}`, never `{id}` |
| `RequireOrgRole` / `LiveOrgRole` read org role live from DB, ignore JWT claim and `X-Org-Id` | `middleware/role.go` | Project role lookup copies this: live, org from `claims.OrgID`, no cache |
| `/api/p/{code}` (+ start/submit/result) already owned by public assessments | `assessment/routes.go:207-210` | Share-link routes must use another prefix |
| `ratelimit.Limiter.Allow(ctx,key,max,window)` Redis sliding window; `middleware.RateLimit` keys on path+IP | `internal/ratelimit`, `middleware/ratelimit.go` | Interest limits need custom keys (IP, email hash, project) like `auth/handler.go:128` |
| `RealIP` trusts XFF only from `TrustedProxyCIDRs`; Next server calls arrive from one IP | `middleware/realip.go` | Interest POST goes browser → Go directly; SSR GET forwards XFF; Next egress in `TRUSTED_PROXY_CIDRS` |
| `orgs.Join`: (a) no check that account email == `inv.Email`; (b) `accepted_at` check outside tx, `UPDATE … WHERE id=$3` without `accepted_at IS NULL` → double-accept race; (c) `ON CONFLICT DO UPDATE SET role=EXCLUDED.role` can demote an existing member | `orgs/invite.go:341-428` | **Existing bug.** Fix before invites link to projects (§4.6) |
| `InviteService.Create` requires `CanGrantRole(actorRole, role)` | `invite.go:38` | A learner who is project manager can't invite → internal `CreateForProject` path |
| Webhook: constant-time `X-Gitlab-Token` vs per-installation secret; dedupe on `X-Gitlab-Event-UUID`; async ingest; author via `FindUserIDByGitlabUserID`; push uses pusher's id | `gitlab/handler_webhook.go`, `service_webhook.go` | Authenticity + dedupe exist; linking goes into async `IngestEvent`; never trust commit-author email |
| Wiki `canEditPage`: admin edits all, instructor/mentor own pages, **learners never edit**; org-wide spaces visible to every member | `wiki/service.go:43-57` | Needs project-scoped space mode (§7.0) |
| AI scoring prompt concatenates motivation/resume without delimiters (JSON mode, clamped) | `projectmarket/service_score.go:94-135` | Anonymous interest text = prompt-injection vector |
| `privacy.AnonymizeAndDeletePII` / `exportQueries` list tables explicitly | `privacy/repo.go` | New PII tables added to both |
| Cron jobs: `jobs.CronJobDef` in `cmd/server/main.go:266`, handlers in `jobs/handlers` | | Purge job follows this |
| Audit: `authz.AuditRepo.Write` / `orgs.writeAuditLog` → `audit_logs` | `authz/audit_repo.go:54`, `orgs/audit.go` | Security events → `audit_logs`; item changes → `work_item_events` |
| `internal/project` name taken (026 personal list) | | Package name `workspace` |

## 1. Permission codes

Migration seeds (`INSERT … ON CONFLICT DO NOTHING` + `role_permissions` by fixed role UUID, like `002_ticket_merge.sql`), constants added to `frontend/lib/auth/permission-codes.ts`.

| Code | Meaning | Default roles |
|---|---|---|
| `projects.create` | Create a workspace and become its owner | tenant_admin (`…0005`), instructor (`…0003`), mentor (`…0004`) |
| `projects.oversee` | Act as owner on every workspace in the org (design: "org owner/admin always acts as owner") | tenant_admin |

- `projects.oversee` instead of checking org role names (rbac.md §1). Admin can grant it to a coordinator via overrides.
- No per-action codes inside a project — project role + item assignment are the only source of truth there.
- Member routes are gated by project membership, not `projects.view`.
- Mentor/instructor defaults only take effect when the RBAC role is assigned by an admin (documented). Auto-syncing all org roles into RBAC is a separate cross-cutting PR.

## 2. `RequireProjectRole` middleware

Lives in the `workspace` package (needs project tables + `authz.Service`; `internal/middleware` stays domain-free).

```
Protected: RealIP → RequireAuth → RequireCSRF
  POST /api/workspaces                         authz.RequirePermission("projects.create")
  /api/workspaces/{workspaceID}/...            workspace.RequireProjectRole(min) [+ ProjectStatusGate(...)]
Public (no auth): /api/public/workspaces/{shareToken}[/interest]
```

Lookup — one indexed query per request, **never cached** (a cached role keeps a removed member's access):

```sql
SELECT p.id, p.org_id, p.project_status, p.brief_status, p.gitlab_enabled, o.status,
       pm.role, pm.status
FROM workspace_projects p
JOIN orgs o ON o.id = p.org_id
JOIN org_members om ON om.org_id = p.org_id AND om.user_id = $2 AND om.status = 'active'
LEFT JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $2
WHERE p.id = $1 AND p.org_id = $3   -- $3 = claims.OrgID
```

Effective role (rank viewer 1 < member 2 < manager 3 < owner 4):
1. `pm.status='active'` → `pm.role`.
2. Not member or below minimum → `authz.HasPermission("projects.oversee")` (Redis-cached authz); true → effective `owner`, `Overseer=true`.
3. Not an active member (missing / left / removed / invited) and not overseer → **404** (no existence leak).
4. Active member below minimum → **403**.

- Bad UUID / other org / no row → 404.
- Track lead is derived from `project_tracks.lead_user_id`, checked in service (`repo.IsTrackLead`).
- Overseers **do not bypass separation of duties** — SoD checks look at assignee/review rows. Overseer mutations without membership write `audit_logs` `project.oversee_action`.
- Nested routes reuse the `ProjectCtx` already on the context.

`ProjectStatusGate(statuses...)` — copy of `OrgStatusGate`, 409 with status message. Named sets:
- `StatusesPlanning = {draft, recruiting, active}` — structure edits, members, item create/edit
- `StatusesWork = {active}` — transitions past `todo`, time logs, standups
- `StatusesDiscuss = {draft, recruiting, active, paused}` — comments, questions, docs, reviews
- `StatusesFeedback = {completed}`
- `cancelled`, `archived` — GET only. Org not `active` → mutations rejected.

Membership lifecycle:
- `left`/`removed` → 404 from next request; history kept.
- Leave/remove in one tx: set status + `left_at`, unassign open `owner` items, delete their reviewer/tester rows, delete pending doc-review votes on the current version, enqueue GitLab roster sync after commit.
- **Org removal (`orgs/member.go`) runs the same routine for every workspace in that org, same tx.**
- Owner can't leave; transfer only to an active `manager`. Partial unique `UNIQUE(project_id) WHERE role='owner' AND status='active'`.

All item routes nest under the workspace (`/api/workspaces/{workspaceID}/items/{itemID}/…`) so every query is `WHERE id=$item AND project_id=$ws` — IDOR guard by construction.

## 3. Enforcement map

PR = minimum project role; St = status gate; all authenticated routes behind RequireAuth + RequireCSRF.

| Endpoint | Org | PR | St | Service checks |
|---|---|---|---|---|
| `POST /workspaces` | `projects.create` | — | — | One tx: project, owner member, project wiki space, key prefix. 10/day/user. `team_size_max ≤ 50` |
| `PATCH …/status` | — | owner | — | Transition table under `FOR UPDATE`; publish needs requirement ≥50 chars; start needs members ≥ min, ≥1 track, repo if GitLab on; complete needs nothing in progress/review/testing. Audited |
| `POST …/share-token` | — | owner | not cancelled/archived | New token; 10/hour/project; audited |
| `POST …/transfer-owner` | — | owner | not archived | Target = active manager; swap in one tx; audited |
| `GET /public/workspaces/{token}` | public | — | recruiting or active+accepting | §4 |
| `POST /public/workspaces/{token}/interest` | public | — | recruiting/active+accepting, before deadline, seats left | §4 |
| `GET …/interests` | — | manager | — | Cursor pagination; PII never shown to member/viewer |
| `PATCH …/interests/{id}` | — | manager | recruiting, active | Idempotency middleware; accept locks project row, seat count (below) ≤ max else 409; invite via §4.6; reject ≤1 optional email; 50 accepts/day/project |
| `GET …/members` | — | viewer | — | Emails only for manager+ |
| `POST …/members` | — | manager | planning | Same-org active member; seat check under lock; `status='invited'` + in-app confirm |
| `PATCH …/members/{uid}` | — | manager | planning | Manager sets member/viewer only; only owner grants/revokes manager; owner only via transfer. Audited |
| `DELETE …/members/{uid}` | — | manager / self | not archived | Manager removes member/viewer; only owner removes manager; nobody removes owner. Audited |
| tracks, onboarding CRUD | — | read viewer, write manager | planning | Lead must be active member |
| `POST …/onboarding/{step}/done` | — | member | non-terminal | `user_id = caller` only |
| releases / sprints | — | read viewer, write manager | planning (sprints: active) | Frozen release refuses features |
| `GET …/items`, item, events | — | viewer | — | Cursor pagination |
| `POST …/items` | — | member | planning | epic manager+; feature manager+ or TL of track; others member+; parent same project + valid chain; key from counter under lock |
| `PATCH …/items/{id}` | — | member | planning (+paused: description) | Creator / assignee / manager+ / TL; optimistic `version` → 409 + current row |
| `DELETE …/items/{id}` | — | member | planning | Only `todo` items with only a `create` event, by creator or manager+; otherwise archive |
| `GET …/items/similar?q=` | — | viewer | — | `q ≤ 200`; 30/min/user |
| `POST …/items/{id}/transition` | — | member | past `todo`: Work | Role per §9; brief gate; doc gate; open blocker → no `in_progress`; WIP limit locks `project_members` row (S1 exempt); `blocked`/`wont_do` need reason; SoD on `done`; event in same tx |
| `PUT …/items/{id}/assignees` | — | member | planning | Self-assign only unassigned, own tracks, onboarding done; others by manager+/TL; assignee active in track; one owner; reviewer ≠ developer; tester ≠ developer; `FOR UPDATE` on item |
| `POST …/items/{id}/links` | — | member | planning | Same project; `blocks` acyclic under `pg_advisory_xact_lock(hashtext(project_id))` |
| `POST …/doc/submit` | — | member | Discuss | Feature owner/developer or creator; ≥1 reviewer; no reviewer authored a version since last approval |
| `POST …/doc/reviews` | — | member | Discuss | Caller holds `reviewer`; version = latest (locked); caller authored no version since last approval |
| `POST …/time-logs` | — | member | Work | Own only; 1–720 min; ≤1440/day under member-row lock; editable 7 days |
| `POST …/ai/breakdown` | — | manager / TL | active | Doc approved; cached per approved version; AI caps |
| `PUT …/requirement` | — | owner | draft, recruiting, active | New version; agreed → clarifying; 50–20k chars |
| `POST …/questions` | — | member | Discuss | Dup check; ≤2000 chars; only while raw/clarifying |
| answer / mark assumption | — | owner (manager after 5d unanswered) | Discuss | — |
| `POST …/brief/submit` / `approve` | — | manager / TL; owner or manager | active | `agreed` needs owner **and** a different manager/TL on the same version |
| `POST …/standups` | — | member | active | Own only; unique per day |
| `POST …/feedback` | — | member | completed, in window | §7.1 |
| `GET …/dashboard` | — | viewer | — | Filtered by role (§7.2) |
| member report | — | member | — | Self, manager+, or TL of their track |
| CSV export | — | manager | — | 10/hour/user |
| AI weekly summary regen | — | manager | active | 3/day/project |

**Seat** = active manager/member rows + `invited` rows + unexpired pending project invites. Owner and viewers excluded.

## 4. Public surface

### 4.1 Routes
`GET /api/public/workspaces/{shareToken}`, `POST /api/public/workspaces/{shareToken}/interest` via `RegisterPublicRoutes`; no auth, no CSRF. Frontend page `/join/[token]` added to the public allowlist in `frontend/proxy.ts`.

### 4.2 Token
- 32 bytes `crypto/rand`, base64url (256 bits). Plain text under UNIQUE (it's shared, not a credential).
- Rotation overwrites → old link 404s immediately.
- Same 404 body/timing for unknown, draft, cancelled, archived, rotated.
- Headers: `Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex`, `Cache-Control: no-store`.
- Response: title, requirement as **plain text**, skills, deadline, team size, seats left, open/closed, org display name. Never names, emails, internal ids.

### 4.3 Abuse controls (`ratelimit.Allow`, limits from config)

| Surface | Key | Limit |
|---|---|---|
| GET page | `rl:pw:view:ip:{ip}` | 60/min |
| POST interest | `rl:pw:int:ip:{ip}` | 5/hour |
| POST interest | `rl:pw:int:email:{sha256(lower(email))}` | 20/day |
| POST interest | `rl:pw:int:proj:{id}` | 200/day |
| Rotate token | `rl:pw:rotate:{id}` | 10/hour |
| Accept | `rl:pw:accept:{id}` | 50/day |

- 429 with `Retry-After`.
- Honeypot field `website` → normal 202, dropped. No captcha in Phase 1 (none in repo); add only if abuse shows in metrics.
- Validation: body ≤16 KB (`MaxBytesReader`); name 1–100; email `net/mail`, ≤254, lower-cased; ≤15 skills × 40 chars; `portfolio_url` `https?://` ≤500, **never fetched**, rendered `rel="noopener noreferrer nofollow ugc"`; message ≤2000; control chars stripped.
- **No email is ever sent on submission** (would be a relay). Owner gets the digest.

### 4.4 No membership / email oracle
Every submission returns the same `202 {"message":"Thanks — the project owner will review your interest."}` — new, duplicate, already member, inside reject cooldown, honeypot. Seats-full / deadline-passed show on the GET page. On accept the owner always sees "Invitation sent" — never whether the email is an existing MindForge account.

### 4.5 Invite spam relay
Invites only from interest rows (no free-form email); pending invites count as seats; `team_size_max ≤ 50`; 50 accepts/day; invite email says "someone expressed interest using this address; ignore if not you".

### 4.6 Accept → invite → Join
- Link via `project_interests.invite_id` (non-unique — one pending invite per org+email).
- New `orgs.InviteService.CreateForProject(ctx, tx, orgID, actorUserID, email, interestID)`: role fixed `learner`, skips `CanGrantRole` (authorized by `RequireProjectRole(manager)`), audited.
- **Join fixes (also fix plain org invites):**
  1. `UPDATE org_invites SET accepted_at=now() WHERE id=$1 AND accepted_at IS NULL AND revoked_at IS NULL AND expires_at > now()` inside the tx; require 1 row.
  2. Project-linked invites: `lower(users.email) = lower(inv.email)` else `invite_email_mismatch`.
  3. `ON CONFLICT … SET role = CASE WHEN org_members.status='active' THEN org_members.role ELSE EXCLUDED.role END` — never demote.
  4. Same tx: lock interest + project; if project recruiting/active → insert `project_members(status='active', role='member')`, interest `joined`; else join org only and return "project no longer active".
- Email already an org member → `project_members.status='invited'` + in-app accept/decline (no adding people without consent). Same for owner's "add existing user".
- Expired invite → interest `invite_expired`, seat released; `Resend` reused.

### 4.7 PII retention
- Daily cron `workspace.purge_interests`: delete `new/rejected/invite_expired` interests older than 90 days, and non-joined interests of projects cancelled/archived 90+ days; batched with `LIMIT`.
- Joined rows: null `message`, `portfolio_url` after 90 days.
- `privacy.AnonymizeAndDeletePII`: read old email first, delete interests by `user_id` or email. Standups and given feedback stay as "Former member".
- `privacy.exportQueries`: add interests, members, time logs, standups, **given** peer feedback only.
- AI ranking gets no name/email — only skills, message, portfolio host.

## 5. GitLab webhook
- Authenticity already covered; linking added inside async `IngestEvent`; keep 200-fast.
- Per-installation (not per-project) secret — accepted; students never see it.
- Replay: existing `X-Gitlab-Event-UUID` dedupe. `work_item_gitlab` unique on `(item_id, kind, gitlab_ref)`, upsert state.
- Automation **forward-only and idempotent**: `todo→in_progress` only from todo; `in_review` only from in_progress; `testing` only from in_review when every linked open MR merged and latest pipeline green; MR closed unmerged → `in_progress` only from in_review. Never overrides done / wont_do / blocked.
- **Per-project `key_prefix`** (2–6 uppercase, `UNIQUE(org_id, key_prefix)`, fixed once items exist). Regex `\b([A-Z]{2,6})-(\d{1,9})\b`; resolve only if prefix belongs to the project owning this team. Others logged `ignored: foreign key`.
- Author mapping via `FindUserIDByGitlabUserID` (pusher for push, `user.id` for MR); never commit email.
  - **Link** only if active project member.
  - **Automate status** only if that user is `owner`/`developer` on the item.
  - No automation while paused/completed+; no linking when archived.
- CI green is not a quality gate (students control CI) — `testing → done` stays human.
- MR reviewer sync only for reviewers with linked GitLab identity, through `client_mr.go` on `netguard.GuardedTransport`, retried.

## 6. AI calls

| Call | Untrusted input | Trigger / cache | Cap |
|---|---|---|---|
| Interest rank | anonymous message, skills, portfolio host | Owner clicks "rank" — **never on submit**; cached on interest row, invalidated on re-upsert | 1/interest; shared `rl:pw:ai:{id}` 50/day |
| Requirement gap list | requirement + questions | per requirement version | shared |
| Epic suggestion / breakdown | brief / doc text | per approved version | shared; manager/TL |
| Weekly summary | events, titles | per ISO week; regen 3/day | shared |
| Why late | one feature's events | per feature per day | shared |

Injection controls: user fields inside delimiters (delimiter stripped from input); system prompt says delimited content is data; JSON mode + strict parse + clamp, reject off-schema; no tools / URL fetch; suggest-only, suggestions go through normal create path; AI text rendered as plain text; **never** send peer feedback, others' time logs, or interest PII to AI. Weekly summary shown to manager+ only. Apply the same delimiting fix to the existing `service_score.go` in the same PR.

## 7. Visibility

### 7.0 Project-scoped wiki space
`wiki_spaces.project_id` (like `course_id`). Read: active members + overseers. Edit: role ≥ member on pages of items they may edit; viewer read-only. Delete: manager+. `wiki.Service` uses project membership instead of `canEditPage` for these spaces. Otherwise briefs/docs leak org-wide and learners can't author.

### 7.1 Peer feedback
- Submit only while `completed`, window `feedback_closes_at = completed_at + 14 days`; `from ≠ to`; both shared ≥1 item; editable until close.
- Owner/overseer: individual rows. Managers: nothing individual.
- Rated member: average + comments only when ≥3 distinct raters **and** window closed (prevents 3→4 diffing); no rater ids/timestamps; comments sorted by text. <3 → `{"available": false}`.

### 7.2 Metrics visibility

| Viewer | Dashboard | Person rows | Time logs | Interests | Member report |
|---|---|---|---|---|---|
| owner / overseer | full | all | all | yes | all |
| manager | full | all | all | yes | all |
| track lead | project totals + own track | own track | own track | no | own track |
| member | project totals | own | own | no | own |
| viewer | project totals | none | none | no | none |

Filtering in service; `user=`/`track=` outside scope → 403.

## 8. Risks
1. **`orgs.Join` email binding + accept race + demotion** — existing bug; forwarded link takes a seat.
2. Global key prefix links wrong items; any committer moves any ticket → per-project prefix + assignee requirement.
3. Public form: oracle, invite relay, injection + AI cost → generic 202, owner-triggered ranking, caps.
4. RBAC defaults don't reach mentors/instructors without assigned roles.
5. Wiki ACL mismatch breaks doc gate.
6. SoD holes in owner/manager overrides → single `sod.Check`.
7. Races (seats, WIP, daily time cap, blocks cycles, approval vs new version) — each lock spans check + write.
8. IP buckets collapse if public POST routes through Next or egress not trusted.

### SoD helper (one place)
`sod.Check(ctx, tx, itemID, actorID, action)`: `approve_doc` (reviewer, authored no version since last approval), `review_code` (reviewer, not developer), `test_pass`/`test_fail`/`set_done` (not developer), `approve_brief` (§6b rule). Called from every transition/review/brief path; nobody skips it.

### Phase 1 security tests (`internal/testdb`)
RequireProjectRole matrix (non-member 404, left 404, below-min 403, overseer passes, other org 404); concurrent last-seat accept → one 200 + one 409; Join email mismatch, double join, no demotion; public POST identical body for all cases + rate-limit keys; purge deletes only eligible rows; webhook foreign prefix ignored, non-assignee links without transition, replay no-op.

## Critical files
- `backend/internal/middleware/role.go`, `middleware/org.go`
- `backend/internal/orgs/invite.go`, `orgs/member.go`, `orgs/rbac_sync.go`
- `backend/internal/gitlab/service_webhook.go`
- `backend/internal/api/router.go`, `internal/assessment/routes.go`
- `backend/internal/wiki/service.go`, `internal/privacy/repo.go`
