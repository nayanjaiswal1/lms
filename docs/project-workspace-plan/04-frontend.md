# Project Workspace — Frontend Plan

> **Overridden by [00-decisions.md](00-decisions.md) D3:** routes are `/workspaces/[id]/…` (not `/projects/requirements/[id]/…`) and the public page is `/join/[token]`. Components still live under `components/workspace/`, fetchers in `lib/workspace/`.

Source design: [../project-workspace.md](../project-workspace.md). Planning only — no code changed.

## 0. Grounding / architecture decision

`project-workspace.md` §1 reuses `project_requirements` + `project_applications` + `projectmarket/service_score.go` — the same tables the shipped marketplace Phase A uses (`app/(app)/projects/**`, `lib/projects/server.ts`, `lib/projects/types.ts`, `components/projects/**`). **Decision: extend the existing `projects` feature, do not fork a new one.**

- Existing marketplace routes/components stay untouched (`/projects`, `/projects/board`, `/projects/team/[teamId]`, `/projects/[assignmentId]`).
- New workspace routes nest under `/projects/requirements/[requirementId]/...` — that segment (`app/(app)/projects/requirements/[requirementId]/page.tsx`) becomes "Project Home" and grows child routes.
- New public share page: `app/(public)/p/[token]/page.tsx`, following `app/(public)/hire/[code]/page.tsx` (unauthenticated, `notFound()` on failure, `generateMetadata` from public payload).
- New components in `components/projects/workspace/` (same top-level feature — no cross-feature boundary edge).
- Server fetchers appended to `lib/projects/server.ts`, types to `lib/projects/types.ts`.
- Server actions appended to `app/(app)/projects/actions.ts`; split into `workspace-actions.ts` only once it would pass ~500 lines.

Reused UI confirmed in code:
- **Board/issue list**: `components/gitlab-planning/*` (`issue-list.tsx`, `issue-row.tsx`, `issue-drawer.tsx`, …) is the fixture UI replaced in Phase 2. It uses its own scoped token set (`--m-*`, `.ae`, `planning.css`). The new board reuses its **interaction structure only** and is built on standard Forge tokens per `frontend/CLAUDE.md`.
- **Owner review list**: `components/projects/application-review-list.tsx` (nuqs status tabs, `ConfirmDialog`, `UserLink`, `ActionResult`) — template for Interest Review.
- **Simple kanban**: `components/projects/task-board.tsx` — template for bug triage; too simple for the full board.
- **Doc pages**: `components/wiki/wiki-editor.tsx`, `wiki-comments-panel.tsx`, `wiki-version-history.tsx`, `wiki-template-picker.tsx` — used verbatim for Project Brief (Flow B2) and Feature Spec (Flow D).
- **Charts**: `components/projects/assignment-burndown.tsx` + `-inner.tsx` (Recharts via `dynamic(ssr:false)`, semantic token fills, `card-base` tooltip) — pattern for every dashboard chart. No new chart library.
- **Calendar**: `app/(app)/calendar/*` event CRUD + `Attendee`/`EventInvite` types — meetings attach via `project_id`.
- **RBAC**: `usePermissions()` / `<Can>` gate org-level actions only. Project roles need a new hook (§2).

## 1. Route map

| # | URL | Type | Data | Notes |
|---|---|---|---|---|
| 1 | `/p/[token]` | Server, `(public)` | `GET /api/p/{token}` | `notFound()` on 404/closed; no auth |
| 2 | `/p/[token]` form | Client island | `POST /api/p/{token}/interest` | `public-interest-form.tsx`; honeypot; `useFormStatus()`. Needs a public (no-cookie) action helper in `lib/server/api.ts` |
| 3 | `/projects/requirements/[id]` | Server | project, status, health, needs-attention | Existing page extended into Project Home; legacy rows keep old rendering |
| 4 | `…/interests` | Server + client | interests (paginated) | Owner/manager; adapted from `application-review-list.tsx` |
| 5 | `…/onboarding` | Server | steps + progress | Manager sees per-member %, member sees own |
| 6 | `…/requirement` | Server + client | raw requirement, versions, questions | Flow B2 Q&A with inline duplicate check |
| 7 | `…/brief` | Server, wiki view/edit | `brief_wiki_page_id` | Wiki components + approve bar |
| 8 | `…/tracks` | Server | tracks + members | CRUD, lead assignment |
| 9 | `…/board` | Server shell + client | items (cursor, filtered) | Kanban by status; WIP badge |
| 10 | `…/list` | Server shell + client | items | `<ResponsiveTable>`; mobile cards |
| 11 | `…/items/[key]` | Server | item + assignees + events + reviews + time logs + gitlab | See §4 |
| 12 | `…/bugs` | Server + client | `type=bug` | Severity-sorted triage queue |
| 13 | `…/meetings` | Server | project events + standups | Uses existing calendar create action with `project_id` |
| 14 | `…/sprints` | Server | sprints + burndown | Redirect if `sprints_enabled=false` |
| 15 | `…/releases` | Server | releases + rollup | Readiness checklist |
| 16 | `…/dashboard` | Server shell + client charts | `GET /api/projects/{id}/dashboard?…` | See §5 |
| 17 | `…/members/[userId]/report` | Server | member report | Owner/manager any; member own |
| 18 | `…/feedback` | Server + client | peer feedback | Owner sees per-rating; member aggregate only (≥3) |
| 19 | `…/settings` | Server | settings | Owner only; each control gated |

UI copy: "Marketplace board" (`/projects/board`) vs "Backlog board" (`…/[id]/board`) — never just "board".

## 2. Project-role hook (new)

- `lib/projects/workspace-roles.ts` — `type ProjectRole = "owner"|"manager"|"member"|"viewer"`; track lead = member whose track has `lead_user_id = me`.
- Server: every workspace response embeds `my_role` + `my_track_ids` (no extra round trip).
- Client: `<ProjectRoleProvider>` + `useProjectRole()` + `useCanOnItem(item, action)` — a function of `(role, item)`, because rules like "reviewer ≠ developer on this item" can't be a static permission set.

## 3. Component inventory

All new components live in `components/projects/workspace/` unless noted.

| Component | Reuse / New |
|---|---|
| `public-interest-form.tsx` | New |
| `interest-review-list.tsx` | Adapted from `application-review-list.tsx` |
| `accept-interest-dialog.tsx` (seat check, existing user vs invite) | New |
| `project-status-menu.tsx`, `health-badge.tsx` | New |
| `onboarding-checklist.tsx` | New |
| `question-thread.tsx`, `question-composer.tsx` | New |
| `brief-approval-bar.tsx` | New wrapper around wiki components |
| `track-list.tsx` | New |
| `item-board.tsx`, `item-board-column.tsx`, `item-card.tsx` | New, structure from `gitlab-planning`, Forge tokens |
| `item-list.tsx` | New, `issue-row.tsx` structure in `<ResponsiveTable>` |
| `duplicate-check-panel.tsx`, `create-item-dialog.tsx` | New |
| `item-detail/transition-buttons.tsx`, `assignee-picker.tsx`, `events-timeline.tsx`, `gitlab-panel.tsx`, `time-logs.tsx`, `links-panel.tsx` | New |
| `conflict-dialog.tsx` (409) | New |
| `doc-review-bar.tsx`, `change-request-banner.tsx` | New |
| `bug-triage-list.tsx` | Adapted from `task-board.tsx` |
| `meeting-list.tsx`, `standup-form.tsx` | New (calendar CRUD reused) |
| `sprint-panel.tsx`, `release-panel.tsx` | New |
| `dashboard/*.tsx` (each chart has an `-inner.tsx` dynamic import) | New, burndown pattern |
| `member-report.tsx`, `peer-feedback.tsx`, `project-settings-form.tsx` | New |
| `project-role-provider.tsx` | New |
| `ConfirmDialog`, `UserLink`, `ResponsiveTable`, `Breadcrumb`, `FormInputField`, Sonner | Reuse |
| Wiki editor / comments / versions / template picker | Reuse |

## 4. Item detail page (`…/items/[key]`)

One `Promise.all` server fetch: item, assignees by role, events, reviews, time logs, gitlab links, my role/tracks.

```
Breadcrumb: Project / Epic / Feature / MF-123
┌ Header: key · type · title (inline edit if allowed) · status · priority · severity · doc_status ┐
├ Left (flex-1)                                  ┬ Right rail (w-72)                         ┤
│ Description                                    │ Assignees: Owner / Developers /           │
│ Change-request / blocked / duplicate banners   │   Reviewers / Testers  [+ Assign]         │
│ Tabs: Overview | Doc | Discussion | Activity   │ Status transition buttons (legal + role)  │
│       | MRs/CI                                 │ Links (blocks / relates / duplicates)     │
│ Activity = events timeline (who/from/to/why)   │ Time logs (mine + team) [+ Log time]      │
│ MRs/CI = MRs, pipeline status, "sync pending"  │ Sprint / Release chips                    │
└────────────────────────────────────────────────┴───────────────────────────────────────────┘
```

Server returns the legal next-status set for the current user; client renders only those and re-checks before firing. A stale page gets the 409 conflict dialog, never a silent failure.

Mobile: single column; right rail becomes accordion sections below description (reuse `WikiSidebarDrawer` disclosure); sticky bottom bar for the primary transition.

## 5. Manager dashboard (`…/dashboard`)

Recharts via the burndown pattern. One server fetch; filters `from/to/track/user/release` live in the URL (nuqs) and are shared with board/list views.

```
Header: status · days left · release target · HealthBadge (click → why)
Needs attention: clickable rows → filtered board/list
Delivery | Quality | Team
  Delivery: burndown/burnup, throughput, cycle/lead time tiles, scope churn
  Quality: bugs by severity, reopen rate, CI pass rate, MR size (>400 lines flagged)
  Team: load table by role, WIP vs limit (.progress-track), time logged next to GitLab signal
Plan tree: Epic → Feature roll-up (expand/collapse like wiki-tree-node)
Tracks · People · Release view · AI weekly summary (.ai-surface, regenerate max 3/day)
```

Every tile is a `<Link>` to the filtered item list — navigation, not modals.

## 6. Mobile

| Surface | Mobile (`<lg`) | Desktop |
|---|---|---|
| Board | One column at a time with segment control; status change via menu, no touch drag | Multi-column; drag only to legal columns, illegal targets disabled |
| Item detail | Single column, accordions, sticky action bar | Two columns |
| Dashboard | Tiles 1-col, charts full width, Needs-attention first, plan tree collapsed | 3-col grid, tree expanded |

## 7. Key UX states

- **Share page**: invalid/rotated token → `notFound()`; closed/full → "closed" banner instead of form; success → static confirmation, no login prompt.
- **Interest review**: empty state with copy-link button; accept seat race → specific 409 "Seats are full — raise the team size limit first".
- **Brief (B2)**: question composer runs debounced similarity; match shows "Already asked — view thread". Submit-for-approval disabled with a reason tooltip until approval is possible.
- **Duplicate check**: create dialog queries `/items/similar` while typing; "Link as duplicate instead" per row; submit stays enabled.
- **WIP limit**: warning toast + "3/3 in progress" on the picker row; owner/manager can still assign.
- **Doc gate**: task transition buttons show a lock icon + tooltip "Feature doc not approved yet" instead of being hidden.
- **Stale edit (409)**: conflict dialog showing your version vs current; "Reload current" or (owner/manager only) "Overwrite".
- **Forbidden**: "You don't have access to this section" for members lacking a role; `notFound()` only where probing is the risk (share token, cross-project ids).

## 8. Risks & design-doc corrections

1. **`apiAction` drops the body on non-2xx**, so a 409 can't carry the current row. Fix once: add `conflict?: T` to `ActionResult`, populated on 409 in `apiAction`/`apiUpload`.
2. **"Board" naming collision** — use "Marketplace board" / "Backlog board" everywhere.
3. **`gitlab-planning` tokens (`--m-*`) must not leak** into the real board — reuse structure, not CSS.
4. **Project-role hook must exist before any board/item work** (Phase 1), or every page reinvents checks.
5. **Time-log validation** (≤1440 min/day, 7-day edit window) has no UI precedent — budget design time.
6. **Async standup** has no precedent — small new component.
7. **Board/dashboard are blocked on the Phase 2 `work_items` migration** — prototype visuals against fixtures only.

## 9. Phase checklist

- **Phase 1**: `/p/[token]` + form, Project Home, interests + accept dialog, members, tracks, onboarding, `useProjectRole()` infra.
- **Phase 2**: board, list, item detail, create dialog + duplicate panel, conflict dialog + `ActionResult` fix.
- **Phase 3**: requirement Q&A, brief, doc review bar + change-request banner, bug triage, meetings + standups.
- **Phase 4**: GitLab panel, time logs, member-leave banners, dashboard (all tiles, health, alerts via notification center).
- **Phase 5**: sprints, releases, peer feedback, member report, certificate hook-in, AI breakdown/assignee suggestion, CSV export.

## Critical files

- `frontend/lib/projects/server.ts`, `frontend/lib/projects/types.ts`
- `frontend/app/(app)/projects/requirements/[requirementId]/page.tsx`
- `frontend/components/gitlab-planning/issue-row.tsx`
- `frontend/components/wiki/wiki-editor.tsx`
- `frontend/lib/server/api.ts`
- `frontend/components/projects/assignment-burndown-inner.tsx`
