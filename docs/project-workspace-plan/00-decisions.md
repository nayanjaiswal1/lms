# 00 — Reconciled Decisions (read this first)

Five planning slices were produced in parallel:

| File | Slice |
|---|---|
| [01-database.md](01-database.md) | DDL, migrations, concurrency |
| [02-auth-security.md](02-auth-security.md) | RBAC, project roles, threat model |
| [03-backend.md](03-backend.md) | packages, services, jobs, AI, webhook |
| [04-frontend.md](04-frontend.md) | routes, components, UX states, dashboard |
| [05-metrics-and-tests.md](05-metrics-and-tests.md) | metric queries, tests, walkthrough |

Where they disagree, **this file wins**. It also overrides [../project-workspace.md](../project-workspace.md) wherever the two differ.

---

## D1. Own table `workspace_projects` (not extending `project_requirements`)

01 wanted to extend `project_requirements`; 03 wanted a new table. **New table.**
- Workspaces never use `project_applications` (interests are the only intake), so extending buys nothing but two status columns kept in sync by a CHECK, plus a filter on the legacy board.
- Marketplace (`projectmarket`) stays untouched.
- Name `projects` is taken (026) → `workspace_projects`. The raw requirement is its own `requirement text` column (current version) with history in `requirement_versions`.
- **Apply to 01's DDL:** rename `project_requirements` → `workspace_projects` for all new FKs (`project_id → workspace_projects(id)`); drop the `status`/`project_status` sync CHECK and the `project_status IS NULL` legacy rule; everything else in 01 (composite FKs, citext, partial indexes, `lock_timeout`) stands.

## D2. Do **not** migrate or drop `project_tasks`

01 flagged that dropping `project_tasks` forces a synthetic workspace per classroom team. **Keep `project_tasks` for the classroom/batch product.** Workspace `work_items` start empty.
- Migrations 038/039 from 01 are **removed**.
- Only the planning fixtures (`handler_planning.go`, `planningdata/*.json`) are replaced by work-item reads.

## D3. Routes

| Surface | Route |
|---|---|
| Authenticated API | `/api/workspaces`, `/api/workspaces/{workspaceID}/…`, items nested: `/api/workspaces/{workspaceID}/items/{itemID}/…` |
| Public API | `/api/public/workspaces/{shareToken}`, `…/interest` |
| Frontend app | `/workspaces`, `/workspaces/[id]/…` (04's `/projects/requirements/[id]/…` routes map 1:1 onto this) |
| Frontend public | `/join/[token]` (added to `frontend/proxy.ts` allowlist) |

Never use a `{id}` URL param on these routes (`RequireOrgMember` reads `{id}` as the org id).

## D4. Package and middleware

`backend/internal/workspace`. `RequireProjectRole`, `ProjectStatusGate` and `sod.Check` live **in that package** (02), not in `internal/middleware`. Role is read live on every request, never cached.

## D5. Permissions

`projects.create` (tenant_admin, instructor, mentor) and `projects.oversee` (tenant_admin). Org role for invites is `learner`. Mentor/instructor defaults only take effect when an admin has assigned the RBAC role (documented; auto-sync is a separate PR).

## D6. Invite → member linking inside `orgs.Join`

03 proposed a polling reconcile job; 02 proposed doing it inside `Join`. **Inside `Join`, same transaction.** No reconcile job. `Join` also gets the three fixes from 02 §4.6 (see D16). Existing org members get `project_members.status='invited'` + in-app accept.

## D7. Ticket keys: per-project prefix

`workspace_projects.key_prefix` (2–6 uppercase letters, `UNIQUE(org_id, key_prefix)`, fixed once items exist). Keys look like `PAY-123`, not a global `MF-`. Webhook resolves only prefixes belonging to the workspace that owns the team. Link requires an active member; status automation requires the author to be `owner`/`developer` on the item; automation is forward-only.

## D8. GitLab team for a workspace

`workspace_projects.team_id` (nullable, unique). GitLab provisioning for workspaces needs a `project_assignments` row, which requires `batch_id NOT NULL`. **Decision:** the backend creates one hidden "workspace" batch per org on first GitLab-enabled workspace and hangs assignments off it — no schema change to `project_assignments`. Revisit only if that batch shows up in batch UIs (filter it by a `kind` flag then).

## D9. `work_item_gitlab`

`UNIQUE(item_id, kind, gitlab_ref)` with state upsert. Replay safety comes from existing `gitlab_webhook_events`. Pipeline status stored once on `gitlab_merge_requests.head_pipeline_status`. Also verify / add `additions`, `deletions` there for MR size.

## D10. Wiki

- No `wiki_page_versions` table — versions live in `content_versions`. Store integer version numbers (`approved_doc_version`, `wiki_version`) compared to `wiki_pages.version`.
- `CreatePage` must write the v1 `content_versions` row.
- `wiki_spaces.project_id` = project-scoped space with project ACL (02 §7.0).
- Separate small fix: the unused trgm index from 035 (expression mismatch) — use the `%` operator on the exact indexed column in new similarity queries.

## D11. Schema additions (merged from 01, 05, 02)

| Addition | Why |
|---|---|
| `work_item_events.project_id`, `source (user|gitlab|system)`, extra kinds (`sprint`, `release`, `parent`, `severity`, `archive`) | dashboard index path, scope churn, import/automation filtering |
| `work_items.epic_id`, `feature_id` (maintained with `parent_id`) | roll-ups without recursive CTE |
| `work_items.is_regression`, `spec_changed_at`, `severity`, `estimate_minutes` | quality metrics, change requests |
| `blocked` transition must reference a `blocks` link | top blockers |
| `sprint_commitments(sprint_id, item_id, committed_at)` | sprint commitment % |
| `workspace_projects.activated_at`, `brief_agreed_at` + `audit_logs` for lifecycle | days active→agreed (no separate `project_events` table) |
| `workspace_digests(project_id, digest_date, health_color, sent_at)` unique per day | digest idempotency, health change |
| `brief_approvals(project_id, requirement_version, user_id, role)` | two-person brief approval |
| `workspace_ai_cache(project_id, kind, cache_key, output)` | AI called once |
| `meeting_attendance.occurrence_at` | recurring meetings |
| `releases.target_at`, `release_snapshots` | release metrics, "what spec shipped" |
| `project_members.status (invited|active|left|removed)` + partial unique active owner | membership lifecycle |
| `project_members.showcase_opt_in`, `feedback_closes_at` on project | completion |
| `comments.subject_type` widened (`work_item`, `requirement_question`) | item and question threads |
| `project_interests.invite_id` (non-unique) | link to pending org invite |

## D12. Things removed / simplified

- **No watchers table** — duplicates notify assignees + reporter.
- **No `draft` item status** — deletable = `todo` with only a `create` event; everything else archived.
- **Standup blockers** may reference ticket keys → shown on dashboard; no automatic status change.
- **No reconcile-invites job** (D6).
- **No `project_tasks` migration** (D2).

## D13. Team size and separation of duties

- `team_size_min ≥ 2` enforced at create, so a brief always has a second approver and SoD is always satisfiable.
- `done` is set by the tester, or if none, by an assignee who is **not** a developer, or by manager+ who is not a developer on the item. Owners/managers/overseers never bypass `sod.Check`.

## D14. Public form responses

One generic `202` for every submission outcome (no "already on this project" / "already received" messages). Seats-full and deadline-passed show on the GET page. No email is sent on submission. Supersedes design §5 edge-case wording.

## D15. Visibility

02 §7.2 matrix replaces design §3 "View everything" for member/viewer (no person metrics, time logs, interests or peer feedback). Peer feedback released to the rated member only after the 14-day window closes and ≥3 raters; managers see no individual ratings.

## D16. Existing bug found — fix in Phase 1a

`orgs.Join` (`backend/internal/orgs/invite.go:341-428`), affects **all org invites today**:
1. No check that the joining account's email matches the invited email → a forwarded link can be used by anyone.
2. `accepted_at` checked outside the tx; UPDATE has no `accepted_at IS NULL` guard → double accept race.
3. `ON CONFLICT DO UPDATE SET role=EXCLUDED.role` can demote an existing admin/mentor.

Fix 2 and 3 unconditionally. Fix 1 for project-linked invites; applying it to all org invites is a product call (recommended: yes).

## D17. Frontend contract fix first

`apiAction` drops the response body on non-2xx, so a 409 can't return the current row. Add `conflict?: T` to `ActionResult`, filled on 409 in `apiAction` / `apiUpload` (04 §8.1). Ship in Phase 2a.

## D18. Migration safety (shared prod DB)

Local DB **is** production and migrations auto-run at startup, tracked by filename, downs manual. Develop and test migrations only against a Neon branch (`DATABASE_URL` override) or `internal/testdb`; run against the shared DB only after merge. Every file altering an existing table starts with `SET LOCAL lock_timeout = '5s'`. No `CREATE INDEX CONCURRENTLY` (runner wraps each file in a tx).

## D19. Migration file order (replaces 01 §5)

| # | Phase | Contents |
|---|---|---|
| 036 | 1 | `workspace_projects`, members, tracks, track members, interests, requirement versions, onboarding; `wiki_spaces.project_id`; permission seeds |
| 037 | 2 | `work_items`, assignees, links, events; `comments.subject_type` widened |
| 038 | 3 | requirement questions, brief approvals, reviews, meetings, attendance, standups, AI cache |
| 039 | 4 | `gitlab_merge_requests.head_pipeline_status` (+additions/deletions if missing), `work_item_gitlab`, time logs, digests |
| 040 | 5 | releases, release snapshots, sprints, sprint commitments, `work_items.release_id/sprint_id`, peer feedback |

Renumber if another branch claims 036 first.

## D20. AI exceptions

Assignee suggestion is **not** cached (live WIP) — rate-limited instead. Interest ranking runs only when the owner clicks "rank", never on submit. Existing `projectmarket/service_score.go` gets the same prompt-delimiting fix in Phase 1b.
