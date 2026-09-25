# Project Workspace (Design Draft — not yet built)

> **Implementation plans:** [project-workspace-plan/](project-workspace-plan/00-decisions.md). Where this doc and `00-decisions.md` differ, `00-decisions.md` wins (table name, routes, key prefix, schema additions, visibility, invite linking).

A corporate-style project lifecycle for learners: someone posts a **vague requirement** (rough idea, like a real client) →
shares a link → people express interest → owner accepts → team onboards, clarifies the requirement with the owner, splits into tracks
(AI / backend / UI …) → plans work as Epic → Feature → Task/Bug → every feature goes
**doc → review → approve → code → review → test → done** → MindForge tracks all of it,
including GitLab activity, per-person roles and effort, with a manager-level view.

Builds on [project-marketplace.md](project-marketplace.md) (Phase A shipped:
`backend/internal/projectmarket`) and the GitLab project system (`backend/internal/gitlab`).

---

## 1. What is reused (not rebuilt)

| Need | Existing piece |
|---|---|
| Scoring pattern for AI ranking (interests) | `projectmarket/service_score.go` (pattern only — workspaces use their own `workspace_projects` table and `project_interests` intake, marketplace untouched) |
| Invite a person who has no account | `orgs/invite.go` (token invite → `Join`) |
| GitLab repo/team provisioning, MR/CI webhooks, commit mirroring, AI MR review | `gitlab/service_provision.go`, `service_webhook.go`, `service_ai_review.go` |
| Classroom team tasks | `project_tasks` stays as-is for batches — **not** migrated; workspace `work_items` start empty |
| Design proposals + voting | `gitlab/handler_design.go` |
| Feature docs with versions + comments | Wiki pages (`wiki_page_versions`, comments) — one wiki space per project |
| Duplicate detection | `pg_trgm similarity()` convention from `wiki/repo.go` |
| Meetings | Calendar events with attendees (`docs/calendar-sync.md`) |
| Rate limiting | `internal/ratelimit` (Redis sliding window) |
| Notifications / email | `internal/notifications`, `internal/mailer` |
| File ownership / contribution rollups | `gitlab/repo_dashboard.go` |

`planningdata/*.json` fixtures behind `/api/gitlab/planning/*` are **replaced** by real
`work_items` reads in Phase 2.

---

## 2. Decisions (locked — see §20 for the resolved open questions)

| Question | Proposal |
|---|---|
| Who can create a project | Org members with RBAC permission `projects.create` (granted to owners/mentors by default; org admin can grant to students) |
| Vague requirement | Owner posts a rough idea in plain words. It is **not** cleaned up before publishing — clarifying it is part of the team's work (Flow B2). The owner plays the client |
| Interest form | Anonymous, never creates a user. Rate-limited, honeypot. One row per `(project, email)` |
| Acceptance | Human decides; AI only ranks |
| Ticket source of truth | MindForge. GitLab holds code / MRs / CI only — **no two-way issue sync**. Linking by ticket key (`{PREFIX}-123` (per-project prefix, e.g. `PAY-123`)) |
| Multi-role on one ticket | One ticket, many assignees, each with role `owner` / `developer` / `reviewer` / `tester` |
| Coding gate | A feature's tasks can't enter `in_progress` until the feature doc is `approved` |
| Separation of duties | You can't approve your own doc, review your own MR, or test your own code |
| AI authority | Suggest only. A human confirms every write |
| Deletion | Nothing with history is hard-deleted — items/projects are archived; only `draft` items with no history can be deleted |

---

## 3. Roles & permissions

Project roles are separate from org roles. Org owner/admin always acts as project `owner`.

| Action | Owner | Manager | Track lead | Member | Viewer |
|---|:-:|:-:|:-:|:-:|:-:|
| Edit project, requirement, share link | ✅ | — | — | — | — |
| Change project status / transfer ownership | ✅ | — | — | — | — |
| Review interests, accept/reject, add/remove members | ✅ | ✅ | — | — | — |
| Create/edit tracks, releases, sprints | ✅ | ✅ | — | — | — |
| Create epic | ✅ | ✅ | — | — | — |
| Create feature | ✅ | ✅ | ✅ (own track) | — | — |
| Create task/bug/subtask | ✅ | ✅ | ✅ | ✅ | — |
| Assign others | ✅ | ✅ | ✅ (own track) | — | — |
| Self-assign (take ownership) | ✅ | ✅ | ✅ | ✅ (unassigned items, own tracks) | — |
| Change status of an item | assignees in the matching role (see §7) + owner/manager |
| Approve doc / code | assignees with role `reviewer` only |
| Log time | own time only |
| View everything | ✅ | ✅ | ✅ | ✅ | ✅ |

Every mutating route checks the project role in one middleware (`RequireProjectRole`) —
same pattern as org middleware, never re-checked ad hoc in handlers.

---

## 4. Project lifecycle

```
draft ──publish──► recruiting ──start──► active ◄──resume── paused
                       │                   │  └──pause──►
                       └──cancel──► cancelled   └──complete──► completed ──► archived
```

| Status | Allowed | Blocked |
|---|---|---|
| `draft` | Edit everything, add existing users | Share link returns 404, no interests |
| `recruiting` | Share link live, interests, accept/invite | Work items can be planned but not moved past `todo` |
| `active` | All work. Share link stays live only if `accepting_interests=true` | — |
| `paused` | Read, comments, docs | Status changes on items, time logs, new members |
| `completed` | Read, peer feedback, reports | Every write except feedback. GitLab repo → handed off/read-only (existing `service_handoff.go`) |
| `cancelled` / `archived` | Read only | Everything else |

Restrictions:
- `start` requires ≥ `team_size_min` members, ≥1 track, and a GitLab repo (if GitLab enabled).
- `complete` requires no item in `in_progress` / `in_review` / `testing` — owner must finish,
  move to backlog, or close them as `wont_do` first.
- Owner can't leave; must transfer ownership to an existing manager first.

---

## 5. Flow A — Recruiting (share link → interest → accept)

```
Owner publishes ─► /join/{share_token}  (public page: raw requirement, skills, deadline, seats left)
                         │
                         ▼
              Interest form: name, email, skills, portfolio, message
                         │  (captcha/honeypot, rate limit 5/hour/IP, 20/day/email)
                         ▼
              project_interests row (status=new)  ─► owner notified (digest, not per row)
                         │
          Owner/manager reviews, AI rank shown (cached per interest, one call)
                         │
               ┌─────────┴──────────┐
            reject                accept
               │                    │
        email sent (optional)   seat check (row lock on project, count ≤ team_size_max)
                                    │
                     email matches existing user?
                        ├─ yes, already org member ─► add to project_members directly
                        ├─ yes, not in org ─► org invite (role=learner) scoped to project
                        └─ no ─► org invite email; on Join, auto-added to project
```

Edge cases:
| Case | Handling |
|---|---|
| Same email submits twice | Upsert same row; `updated_at` bumped; no duplicate for owner to review |
| Email is already a project member | Form returns "already on this project" without revealing other data |
| Rejected person reapplies | Allowed after 30 days; before that the form returns a neutral "already received" message |
| Seats full | Public page shows "closed"; accept returns 409; owner can raise `team_size_max` |
| Two managers accept the last seat at once | `SELECT … FOR UPDATE` on project row before counting (unlocked-counter rule in `ai-pattern-learnings.md`) |
| Deadline passed | Form closed automatically; owner can extend |
| Invite accepted after project was cancelled | `Join` still joins org but skips project add; user sees "project no longer active" |
| Invite never accepted | Invite expires per org invite TTL; interest shows `invite_expired`; owner can resend |
| Share link leaked | Owner regenerates token → old link 404s immediately |
| Private data | Rejected/never-accepted interests purged after 90 days (privacy) |
| Owner adds existing user directly | Must be an org member; skips the form; same seat check |

---

## 6. Flow B — Onboarding

On member add (any path):
1. Welcome notification with project wiki space link.
2. Onboarding checklist assigned (`onboarding_steps` — e.g. read brief, read coding standards,
   set up repo, join kickoff, pick a track). Steps can link wiki pages.
3. GitLab access granted via existing team provisioning (if repo exists).
4. Member picks track(s) → track lead approves (or owner assigns directly).

Restrictions:
- Member can't self-assign tickets until mandatory onboarding steps are done
  (`onboarding_steps.required=true`).
- Manager sees onboarding % per member; stuck > 3 days → reminder to member + manager.

---

## 6b. Flow B2 — Vague requirement → agreed brief

Real clients never hand over a clean spec. The owner posts a rough idea on purpose; turning it
into a clear brief is the team's first job and is tracked and graded like any other work.

```
Owner writes raw_requirement   e.g. "I want an app where students can book mentors,
     (plain words, ≥ 50 chars)       something like Calendly but for our college"
   ▼
brief_status = raw ─► shown as-is on share page and to the team
   ▼  project becomes active
brief_status = clarifying
   ├─ Members post questions on the requirement (one thread per question)
   │     "Who pays?", "Mobile or web?", "How many users?", "What happens on no-show?"
   │     duplicate check on question text (pg_trgm) before posting
   ├─ Owner answers each (acts as client). Owner may answer "you decide" → becomes an
   │     assumption the team must write down
   ├─ AI (optional, suggest-only): lists gaps the team hasn't asked about yet
   │     (users, scope, non-functional, edge cases) — one call per requirement version, cached
   ▼
Team (manager / track leads) writes the brief = wiki page from "Project Brief" template:
   problem · target users · in scope · out of scope · assumptions · success criteria ·
   non-functional needs · open risks · Q&A log (auto-linked)
   ▼
Brief review: owner approves (client sign-off) + manager approves
   ▼
brief_status = agreed ─► epics/features planned from it (AI can suggest epics, human accepts)
```

Restrictions & cases:
| Case | Handling |
|---|---|
| Work before brief agreed | Epics and features can be drafted; no item may move past `todo` until `agreed` |
| Owner doesn't answer a question in 3 days | Reminder to owner; after 5 days manager may mark it an assumption |
| Owner changes the requirement after `agreed` | New brief version → `brief_status=clarifying`; goes through Change request (Flow F) for affected features |
| Question already answered | Duplicate check shows the existing thread; asker is linked to it |
| Owner is also the manager | Allowed; brief still needs one other member (track lead) to approve so it isn't self-approved |
| Raw requirement too short / empty | Publish blocked (min 50 chars) — share page needs something real to show |

Metrics (added to §16): questions asked, answered, time to answer, assumptions count,
days from `active` to `agreed`, brief versions after agreement (scope churn at project level).

---

## 7. Flow C — Planning & work items

### Hierarchy

```
Epic            (owner/manager)             e.g. "Payments"
 └─ Feature     (manager / track lead)      e.g. "Refund flow"     ← has design doc, release
     ├─ Task    (anyone)                    e.g. "Refund API"      ← has track, assignees
     │   └─ Subtask
     └─ Bug                                  bugs may also sit under epic or project root
```

Rules (enforced in service, one place):
- Parent type must be valid: epic→feature→task|bug→subtask. No deeper nesting.
- Parent must be in the same project. Moving an item re-validates type rules and cycle-free.
- Feature must have a `track` set before its tasks can be assigned.
- Key `{PREFIX}-{n}` from a per-project counter row updated under lock — never `MAX(n)+1`.
- Edits use optimistic locking (`version` column). Stale edit → 409 with the current row.
- Epic/feature status is a roll-up of children; never set by hand.

### Duplicate prevention
1. Hard — unique constraints (interest per email, assignee per role, link per pair).
2. Soft — on create, `pg_trgm` similarity vs open items in the project; UI shows
   "similar tickets" before submit. User can link as `duplicates` instead of creating.
3. Marking an item `duplicate` closes it and moves its watchers to the original.

### Assignment rules
| Rule | Why |
|---|---|
| Assignee must be an active project member in the item's track (owner/manager exempt) | No work to outsiders |
| Exactly one `owner` per task/bug; many developers/reviewers/testers allowed | Clear accountability |
| `reviewer` ≠ any `developer` on the same item | Can't review own code |
| `tester` ≠ any `developer` on the same item | Can't test own code |
| Doc reviewer ≠ doc author | Can't approve own doc |
| WIP limit per person (project setting, default 3 `in_progress`) | Stop hoarding tickets |
| Self-assign only on unassigned items | No stealing work |
| AI assignee suggestion = ranked list (track, skills, current load); human picks | AI suggest-only |

### Link rules
- `blocks` links must be acyclic (checked on insert).
- Item with an open blocker can't move to `in_progress`.
- Links only within one project.

---

## 8. Flow D — Feature lifecycle (doc-first)

```
Feature created ─► doc_status=draft  (wiki page auto-created from "Feature Spec" template:
                                       problem, scope, out of scope, API, UI, test plan, risks)
     │  author submits (needs ≥1 reviewer assigned)
     ▼
in_review ─► reviewers comment on wiki page (existing comments)
     │
     ├─ any reviewer: changes_requested ─► author revises (new wiki version) ─► in_review
     │
     └─ all reviewers approve the SAME latest version ─► approved
                                            │
                              (optional) AI breakdown → suggested tasks → human accepts
                                            │
                                  tasks unlocked for in_progress
```

Restrictions & cases:
| Case | Handling |
|---|---|
| Doc edited after approval | Becomes a **change request** (Flow F) — status back to `in_review`; in-progress tasks flagged "spec changed", not blocked |
| Reviewer removed mid-review | Their vote dropped; if 0 reviewers left, status stays `in_review` and manager alerted |
| Approval on an old version | Rejected — approval stores `wiki_version_id`, must equal latest |
| Review idle > 3 days | Reminder to reviewers, escalate to manager at 5 days |
| Discussion needs a meeting | "Schedule design review" creates a calendar event with doc link + reviewers as attendees |
| Bugs / subtasks | No doc gate (bug has its own triage flow) |

---

## 9. Flow E — Task / bug execution

| Status | Who can move into it | Auto trigger |
|---|---|---|
| `todo` | anyone creating | — |
| `in_progress` | owner/developer | first commit or branch with key |
| `in_review` | developer | MR with key opened |
| `testing` | — | MR merged **and** pipeline green |
| `done` | tester (or owner if no tester assigned) | — |
| `blocked` | any assignee (reason required) | open `blocks` link |
| `reopened` | tester / reporter | — back to `in_progress` |
| `wont_do` | owner/manager (reason required) | — |

- Every transition written to `work_item_events` (who, from, to, reason, at) — the audit trail
  and the source for cycle-time and effort reports.
- Illegal transitions (e.g. `todo → done`) rejected in service.
- Tester failing a test → `reopened` with required note; count of reopens tracked per item.

### Flow E2 — Bug reporting & triage (new)

```
Anyone reports bug (steps, expected, actual, environment, severity guess, screenshot)
   ▼
triage (manager / track lead): confirm severity S1–S4, link feature/release, assign owner
   ├─ duplicate ─► link + close
   ├─ not a bug ─► wont_do + reason
   └─ confirmed ─► normal execution flow; S1 skips WIP limit and notifies manager immediately
```
- Bug found on a `done` feature in a shipped release → tagged `regression`, linked to release.
- Bug must reference the item/feature it came from when known (for quality stats per feature).

---

## 10. Flow F — Change request (scope change, new)

When a requirement changes after doc approval:
1. Requester edits doc → system snapshots approved version, diff shown to reviewers.
2. Feature goes back to `in_review`; tasks keep running but show "spec changed" banner.
3. On re-approval, AI (optional) suggests which tasks are affected; manager adds/closes tasks.
4. Change request counted per feature — manager sees scope churn.

---

## 11. Flow G — Meetings & rhythm (new)

Uses calendar events with a `project_id` link. Types: kickoff, sprint planning, standup,
design review, retro, demo.
- Meeting has a notes wiki page (template per type). Action items in notes can be turned into
  tickets in one click (with duplicate check).
- Async standup option: each member posts yesterday / today / blockers; blockers become
  `blocked` flags visible to manager.
- Attendance recorded (joined / missed) — shown in member report.

### Sprints (optional per project)
- `sprints`: 1–4 week time box. Items added to a sprint during planning.
- Unfinished items at sprint end: manager chooses carry-over or back to backlog — never silent.
- Burndown from `work_item_events` (no extra table).

---

## 12. Flow H — GitLab integration

- Branch / MR title / commit message contains `{PREFIX}-123` (per-project prefix, e.g. `PAY-123`) → existing webhook handler links it into
  `work_item_gitlab`, updates status per §9.
- Webhook events deduped by GitLab event id (replays are safe).
- Key from another project, or author not a project member → ignored + logged, not linked.
- Multiple MRs per item allowed; item reaches `testing` only when all linked open MRs merged.
- MR closed without merge → item back to `in_progress`.
- Assignees with role `reviewer` set as MR reviewers via `client_mr.go`; changes on ticket
  sync to the MR (one direction).
- GitLab API failure → job retried with backoff; ticket shows "sync pending", never blocks UI.
- Existing AI MR review keeps running (cached per SHA).

---

## 13. Flow I — Releases & versioning

- `releases`: `planned → frozen → released`. Features target a release.
- `frozen`: no new features can be added; bugs only.
- `released` requires every targeted feature `done` or explicitly moved to the next release.
- Release notes generated from done features/bugs (AI polish optional, cached per release).
- Feature doc version at release time recorded — "what spec shipped in v1.2".

---

## 14. Flow J — Member leaves / removed (new)

| Case | Handling |
|---|---|
| Member leaves or is removed | Open items: owner role → unassigned + manager notified; reviewer/tester → role removed. GitLab access revoked. History kept |
| Inactive member (no activity 7 days) | Manager alert; after 14 days suggested for removal (human decides) |
| Removed then re-added | Old history and contributions reattached (same `user_id`) |
| Track lead leaves | Track has no lead → owner/manager must assign new lead; features in that track can't get new assignments until then |
| Account deleted (privacy) | Name shown as "Former member"; contributions stay in stats |

---

## 15. Flow K — Completion & outcome (new)

On `complete`:
1. Peer feedback round (each member rates teammates they worked with on ≥1 item, 1–5 +
   comment; anonymous to peers, visible to owner).
2. Member report auto-built: items owned/reviewed/tested, reopens, doc approvals, MRs,
   review comments, time logged, meetings attended, peer rating.
3. Owner can issue a completion certificate (existing `certificates`) + experience note.
4. Public showcase page (opt-in per member).

---

## 16. Manager dashboard & metrics

Visible to owner/manager (full), track lead (own track), member (own row + project totals).
All numbers computed from `work_item_events`, `work_items`, `work_item_assignees`,
`work_item_time_logs`, `work_item_gitlab`, and existing `gitlab_commits` — **no separate
aggregation tables** unless a query measures slow; then a nightly materialized view.
Every metric has a date range filter (default: current sprint, else last 14 days) and a
track / person / release filter.

### 16.1 Dashboard layout

```
┌ Header ── project status · days left · release target · health: 🟢 / 🟡 / 🔴 ─────────┐
├ Needs attention (action list, top) ────────────────────────────────────────────────┤
│  blocked items · overdue items · reviews waiting > 3d · S1/S2 open bugs            │
│  members stuck in onboarding · inactive members · tracks without lead               │
├ Delivery ──────────────┬ Quality ─────────────────┬ Team ─────────────────────────┤
│ burndown / burnup      │ bugs open by severity    │ per-person load (by role)     │
│ throughput / week      │ reopen rate              │ WIP vs limit                  │
│ cycle & lead time      │ escaped bugs (regression)│ time logged vs GitLab signal  │
│ scope churn            │ CI pass rate             │ review responsiveness         │
├ Plan tree: Epic → Feature (roll-up %, doc status, release, owner, risk flag) ──────┤
├ Tracks table · People table · Release view · AI weekly summary ────────────────────┤
└────────────────────────────────────────────────────────────────────────────────────┘
```

Every tile drills down to the filtered item list that produced the number.

### 16.2 Delivery metrics

| Metric | Definition | Source |
|---|---|---|
| Progress % (epic/feature/release) | done leaf items ÷ all non-`wont_do` leaf items (count; weighted by estimate if set) | `work_items` |
| Burndown / burnup | open vs done leaf items per day in sprint/release | `work_item_events` |
| Throughput | items reaching `done` per week, per track | events |
| Lead time | `created → done` (median, p85) | events |
| Cycle time | first `in_progress → done` (median, p85), split into stages below | events |
| Stage time | time in `in_progress`, `in_review`, `testing`, `blocked` — shows the bottleneck | events |
| Blocked time | total hours items spent `blocked`, top blockers | events + links |
| Overdue | open items past `due_at` | `work_items` |
| Scope churn | items added/removed after sprint start or release freeze; change requests per feature; brief versions after `agreed` |
| Requirement clarity | questions asked / answered, median time to answer, assumptions, days `active → agreed` (Flow B2) | `requirement_questions` + events |
| Sprint commitment | done ÷ committed at sprint start | `sprints` + events |
| Forecast | remaining items ÷ avg throughput of last 3 weeks → projected finish date vs release target | computed |
| Doc turnaround | feature `draft → approved` time; review rounds per doc | events + reviews |

### 16.3 Quality metrics

| Metric | Definition |
|---|---|
| Open bugs by severity | S1–S4, with age |
| Bug inflow vs fix rate | bugs created vs closed per week |
| Reopen rate | reopened ÷ items reaching `testing`, per track/person |
| Escaped bugs | `regression` bugs against a released feature |
| Bug density | bugs linked to a feature ÷ that feature's tasks |
| CI pass rate | green pipelines ÷ total on linked MRs |
| MR review rounds | review cycles before merge (from `work_item_reviews` target=code) |
| MR size | lines changed per MR (median); flag > 400 lines |
| Test coverage signal | tasks with a tester assigned and passed ÷ done tasks |

### 16.4 Team & person metrics

| Metric | Definition |
|---|---|
| Load by role | open items where person is owner / developer / reviewer / tester |
| WIP | `in_progress` owned items vs project `wip_limit` |
| Completed | items done as owner/developer; reviews done; tests done |
| Review responsiveness | median time from review request to first review action |
| Time logged | minutes from `work_item_time_logs`, per day/week |
| GitLab signal | commits, MRs opened/merged, MR comments (from existing mirrors) — shown **next to** time logged, never combined |
| Estimate accuracy | logged time ÷ estimate on done items (only if estimates used) |
| Reopens caused | reopened items where the person was developer |
| Meeting / standup | attendance %, standups posted ÷ working days |
| Onboarding | required steps done % |
| Last active | latest event / commit / time log |
| Peer rating | avg from `peer_feedback` (after completion, owner only) |

Person metrics are shown for coaching, not ranking: no leaderboard of individuals inside a
project team (the existing course leaderboards are unaffected).

### 16.5 Track metrics

Per track: members, open/done items, throughput, cycle time, bugs, WIP vs capacity,
lead, features waiting on doc approval, cross-track blockers (items blocked by another track).

### 16.6 Release metrics

Per release: features done / total, bugs open by severity, days to target, forecast finish,
scope added after freeze, docs not approved, release readiness checklist
(all features done, 0 S1/S2 bugs, all MRs merged, CI green).

### 16.7 Project health (header badge)

Rule-based, not AI — each rule shows why it fired:
- 🔴 any S1 bug open > 24h, forecast > target by > 20%, or > 25% items blocked
- 🟡 forecast > target, reviews waiting > 3d, reopen rate > 20%, or inactive member
- 🟢 otherwise

Thresholds are per-project settings with these defaults.

### 16.8 Alerts (notifications to manager)

Daily digest (one email/notification, not per event): new blockers, overdue items, stale
reviews, S1 bugs (S1 also sent immediately), inactive members, WIP limit breaches, health
changed colour.

### 16.9 AI on the dashboard

- Weekly summary: what shipped, risks, who needs help — one call per project per week,
  cached; regenerated only on manual request (max 3/day).
- "Why is this late?" on a feature: AI reads its events + blockers → short explanation,
  cached per feature per day.
- AI never changes data from the dashboard.

### 16.10 Exports & API

- `GET /api/workspaces/{id}/dashboard?from=&to=&track=&user=&release=` — all tiles in one call.
- `GET /api/workspaces/{id}/metrics/{metric}` — drill-down series.
- CSV export of items, time logs, and member report (owner/manager only).

---

## 17. DB schema (new / changed)

```
workspace_projects    id, org_id, title, requirement text, skills text[], team_size_min (≥2), team_size_max (≤50),
                      deadline, key_prefix, created_by, share_token text unique, share_token_rotated_at,
                      accepting_interests bool, raw_requirement text, brief_wiki_page_id,
                      brief_status (raw|clarifying|agreed), project_status (draft|recruiting|active|paused|
                      completed|cancelled|archived), wiki_space_id, team_id, gitlab_enabled bool default true, sprints_enabled bool default false,
                      wip_limit int default 3, item_seq int default 0,
                      health_thresholds jsonb (defaults in §16.7)

project_interests     id, requirement_id, name, email, skills text[], portfolio_url, message,
                      status (new|accepted|rejected|invite_expired|joined), invite_id?, user_id?,
                      ai_score?, ai_rationale?, reviewed_by, reviewed_at, created_at, updated_at
                      UNIQUE (requirement_id, lower(email))

project_members       project_id, user_id, role (owner|manager|member|viewer),
                      status (active|left|removed), joined_at, left_at
                      PK (project_id, user_id)
project_tracks        id, project_id, name, lead_user_id?   UNIQUE (project_id, lower(name))
project_track_members track_id, user_id

requirement_questions id, project_id, asked_by, question, answer?, answered_by?, answered_at?,
                      is_assumption bool, requirement_version int, created_at
requirement_versions  project_id, version, raw_requirement, created_by, created_at
                      PK (project_id, version)

onboarding_steps      id, project_id, title, wiki_page_id?, required bool, position
onboarding_progress   step_id, user_id, done_at

releases              id, project_id, version, status (planned|frozen|released), released_at
                      UNIQUE (project_id, version)
sprints               id, project_id, name, starts_at, ends_at, status

work_items            id, project_id, key_num int, type (epic|feature|task|bug|subtask),
                      parent_id?, track_id?, release_id?, sprint_id?, title, description,
                      status, priority, severity? (bugs), estimate_minutes?, doc_wiki_page_id?, doc_status?,
                      approved_doc_version_id?, reopen_count, version int, due_at,
                      created_by, archived_at, created_at, updated_at
                      UNIQUE (project_id, key_num)
work_item_assignees   item_id, user_id, role (owner|developer|reviewer|tester), assigned_by,
                      assigned_at   PK (item_id, user_id, role)
work_item_links       from_id, to_id, kind (blocks|relates|duplicates)  PK (from_id,to_id,kind)
work_item_events      id, item_id, actor_id, kind (status|assign|link|doc|comment),
                      from_value, to_value, reason, created_at        -- append-only
work_item_reviews     item_id, reviewer_id, target (doc|code), verdict, comment,
                      wiki_version_id?, created_at
work_item_time_logs   id, item_id, user_id, minutes (1–720), note, logged_on, created_at
                      -- sum per user per day ≤ 1440, editable 7 days
work_item_gitlab      item_id, kind (branch|mr|commit), gitlab_ref, state, pipeline_status,
                      UNIQUE (item_id, kind, gitlab_ref)

project_meetings      calendar_event_id, project_id, kind, notes_wiki_page_id?
meeting_attendance    calendar_event_id, user_id, status (attended|missed)
standup_updates       project_id, user_id, date, yesterday, today, blockers
                      UNIQUE (project_id, user_id, date)
peer_feedback         project_id, from_user, to_user, rating 1–5, comment
                      UNIQUE (project_id, from_user, to_user), from ≠ to
```


All list endpoints are cursor-paginated (unpaginated-list rule in `ai-pattern-learnings.md`).

---

## 18. API (sketch)

```
POST   /api/workspaces                         create (requirement + wiki space)
PATCH  /api/workspaces/{id}/status             lifecycle transitions (§4)
POST   /api/workspaces/{id}/share-token        rotate link
POST   /api/workspaces/{id}/transfer-owner
GET    /api/public/workspaces/{share_token}                  public listing (no auth, rate-limited)
POST   /api/public/workspaces/{share_token}/interest         public form (rate-limited + honeypot)
GET    /api/workspaces/{id}/interests          owner/manager, paginated
PATCH  /api/workspaces/{id}/interests/{iid}    accept → add member or invite / reject
CRUD   /api/workspaces/{id}/members            add existing user, change role, remove
CRUD   /api/workspaces/{id}/tracks | onboarding | releases | sprints
CRUD   /api/workspaces/{id}/items              ?parent=&type=&track=&assignee=&status=&sprint=
GET    /api/workspaces/{id}/items/similar?q=   duplicate check
POST   /api/workspaces/{id}/items/{itemID}/transition            status change (validated per §9)
PUT    /api/workspaces/{id}/items/{itemID}/assignees
POST   /api/workspaces/{id}/items/{itemID}/links
POST   /api/workspaces/{id}/items/{itemID}/doc/submit | reviews
POST   /api/workspaces/{id}/items/{itemID}/time-logs
GET    /api/workspaces/{id}/items/{itemID}/events                audit trail
POST   /api/workspaces/{id}/items/{itemID}/ai/breakdown          suggest child tasks (cached per doc version)
GET    /api/workspaces/{id}/requirement        raw + versions + brief status
PUT    /api/workspaces/{id}/requirement        new requirement version (owner)
CRUD   /api/workspaces/{id}/questions          ask / answer / mark assumption
POST   /api/workspaces/{id}/brief/submit | approve
POST   /api/workspaces/{id}/standups
POST   /api/workspaces/{id}/feedback
GET    /api/workspaces/{id}/dashboard
GET    /api/workspaces/{id}/members/{uid}/report
```

---

## 19. Build phases

| Phase | Scope |
|---|---|
| 1 | Project lifecycle + raw requirement, roles & `RequireProjectRole`, share link, interest form, accept → add/invite, members, tracks, onboarding checklist |
| 2 | `work_items` hierarchy + keys + optimistic lock, assignees + role rules, links + cycle check, events audit, dedup, board/list UI (replaces planning fixtures) |
| 3 | Requirement clarification (Flow B2), feature doc gate (wiki template, submit/review/approve), change requests, bug triage, meetings + notes + standups |
| 4 | GitLab key linking + status automation + MR reviewer sync, time logs, member leave flow, manager dashboard (delivery + quality + team + track metrics, health badge, alerts) |
| 5 | Releases/sprints + release metrics + forecast, completion (peer feedback, member report, certificate), AI breakdown / assignee suggestion / weekly summary, CSV exports |

Phase 2 migration and the permission matrix get an Opus review before build (data integrity + auth).

---

## 20. Resolved decisions

| # | Question | Decision | Reason |
|---|---|---|---|
| 1 | Who creates projects | **Owners/mentors by default** via `projects.create`; org admin can grant it to any student | Keeps spam and junk listings out; students still get it when trusted |
| 2 | GitLab repo | **Owner toggle, default on.** Off = no auto-status from MRs; items move by hand | Some projects (design, research, AI prompt work) have no repo; default on because code is the main use case |
| 3 | Sprints | **Optional per project, default off.** Kanban board works without them | Small teams don't need ceremony; turning on sprints enables sprint metrics (§16.2) |
| 4 | Peer feedback visibility | **Owner sees individual ratings; the rated member sees only their average + comments once ≥3 ratings exist, never who gave what** | Honest feedback needs anonymity; ≥3 prevents guessing the rater |
