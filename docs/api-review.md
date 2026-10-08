# Backend API Review

> Review of ~600 endpoints across 48 route packages in `backend/internal`.
> Rubric: **APIs must be resource-oriented and self-describing so an AI/MCP client can adapt to them — not shaped around one UI widget or page.**
> Status: findings only, no changes made yet.

---

## 1. Broken contract (fix immediately)

- **Jobs pause/resume is dead**: backend has `PATCH /api/orgs/{orgID}/jobs/{jobID}` (`internal/jobs/handler_http.go:42`), frontend calls `POST .../pause|resume` which **doesn't exist** → UI 404s, backend endpoint unused.
- **Certificate threshold mismatch**: frontend calls `/api/courses/{id}/certificate-rule`, backend only has `.../certificate-threshold` (`internal/certificates/routes.go:45-46`) — one side is wrong; `certificate-rule` has 0 hits in backend.
- **Focus wall categories**: frontend does `POST`/`DELETE /api/focus-wall/categories`, backend only registers `GET` (`internal/focuswall/routes.go:28`) → 405s today.
- **`POST /api/orgs/{id}/domains/verify`** (`internal/orgs/handler.go:583`) is the only domains route missing the owner/admin guard its siblings have (add:556, auto-join:620, remove:652).

## 2. Security

- **HIGH — Cross-org job admin bypass**: jobs routes name the param `{orgID}` but `RequireOrgMember` only resolves org from `{id}` (`internal/middleware/org.go:50`) → falls back to `X-Org-Id` header, while `RequireOrgRole` authorizes against `claims.OrgID` (`internal/middleware/role.go:85-93`). An attacker with an admin role in org A + plain membership in org B can cancel/retry/pause org B's jobs. **Fix:** rename param to `{id}` and make the role check compare against the org actually being accessed.
- **HIGH — `PUT /api/projects/tasks/{taskID}/assignee`** writes any UUID with no membership check (`internal/gitlab/service_task.go:73-78`) → cross-org user reference or FK 500. **Fix:** validate assignee ∈ team/org members, 422 otherwise.
- **MED — `ToggleReaction` takes no `orgID`** (`internal/messaging/repo.go:256`) — the one message mutation missing the org `EXISTS` guard every sibling has (IDOR-shaped). Thread `orgID` through.
- **MED — `POST /api/privacy/delete-account` / `GET /api/privacy/export`**: PII actions gated only by session+CSRF, no step-up/MFA re-verify. Self-scoped (no IDOR), but add step-up auth.
- **MED — `GET /api/admin/orgs`**: cross-tenant listing with no limit/cursor (unbounded PII-adjacent query).

## 3. UI-coupled / widget-shaped endpoints (main concern)

| Endpoint | Location | Problem | Resource-oriented fix |
|---|---|---|---|
| `GET /api/learn/hub-stats` | `learnhub/routes.go:7` | Literal "9 counts for the Learn page cards" blob; AI can't discover the 9 domains from this URL | `GET /api/me/summary?resources=courses,labs,…` or count params on owning collections |
| `GET /api/mentor-tickets/{id}/detail` | `mentoring/routes.go:105` | "the single aggregate behind the ticket detail page" — overlaps `GET /api/tickets/{id}` | `GET /api/tickets/{id}?include=change_requests,reports` |
| `GET /api/courses/{id}/final-test/edit` | `certificates/routes.go:43` | Path names a UI surface ("edit"); same resource as `.../final-test`, split by caller role instead of permission | One `GET .../final-test`; field filtering by permission |
| `POST .../certificates/check-threshold` | `certificates/routes.go:62` | Button-RPC called "on every load" | `POST /api/courses/{id}/certificates` (award-if-eligible, idempotent) |
| Batch import `parse`/`validate`/`confirm` + `report` | `assessment/routes.go:103-106` | Mirrors a 4-step wizard; state lives client-side between calls | An `imports` resource: `POST /api/batches/{id}/imports`, `POST /api/imports/{id}/commit` |
| `PATCH /api/progress/{topic_tag}` ×5 (`/notes`,`/revision`,`/review`,`/star`) | `sheets/routes.go:38-42` | 5 sibling PATCHes = 5 UI buttons, at collection root, `sheet_id` in body — duplicates existing `PATCH /api/sheets/{id}/items/{itemId}` | Single nested `PATCH /api/sheets/{sheetId}/items/{itemId}` with partial body |
| `POST .../tasks/{id}/complete\|pause\|revive` | `whatnow/routes.go:22-25` | 3 verbs `PATCH {status}` already expresses (`TaskPatch` carries `Status`) | Fold into `PATCH /api/whatnow/tasks/{id}`; keep only `/stuck`, `/breakdown` |
| `GET /api/my/projects/{teamID}/detail` | `gitlab/routes.go:148` | "replacing four separate round trips" — page blob; made 4 sibling endpoints dead | `GET /api/projects/teams/{teamID}?include=assignment,contributions,checkpoints` |
| `GET /api/gitlab/planning/board\|issues` | `workspace/routes.go:33-34` | UI nouns, served by the **workspace** package under the **gitlab** prefix | `GET /api/work-items?assignee=me&status=open` |
| `PUT /api/profile/me/last-page` | `profile/routes.go:34` | Writes a browser route string; no GET, pure widget state | Fold into `PATCH /api/profile/me {last_page}` |
| `GET /api/me/bootstrap` | `api/router.go:432` | Hardcoded 5-key app-shell fan-out; backend encodes one page's layout | `GET /api/me?include=me,permissions,features` |
| `GET /api/project-marketplace/board` | `projectmarket/routes.go:46` | "board" is a UI noun; it's a filtered requirements list | `GET .../requirements?status=open&include=application_count,my_status` |
| `GET /api/habits?month=` | `habit/routes.go:24` | Collection GET is a mandatory calendar-widget aggregate; no plain resource list exists | `GET /api/habits?from=&to=` returning resources |
| `POST /api/courses/generate-outline` | `courses/routes.go:40` | AI action named after one wizard step | `POST /api/courses/outlines` (draft resource) |
| `GET /api/whats-new` | `whatsnew/routes.go:24` | "sidebar's sparkle-icon panel"; fixed `LIMIT 20`, no params | `GET /api/changelog?since=&limit=&cursor=` + `GET /api/changelog/{id}` |
| `GET /api/journal/graph` | `journal/routes.go:23` | Mind-map view blob, unfiltered | `GET /api/journal?include=similar` |
| Dashboard/blob family | `workspace/routes.go:64`, `gitlab/routes.go:134,137-138`, `courses/routes.go:84,79` | `workspaces/{id}/dashboard`, `assignments/{id}/dashboard|leaderboard|burndown`, `purchase-status`, `random-topic` — fixed composites, no `include`/`fields` params | Named report resources or `?include=`/`?fields=` on the base resource |

**Symptom across all of these**: no query params, no `include`, no paging — a client can only call the one page the backend imagined, not compose.

## 4. Dead / duplicate / redundant

### ~45 endpoints with zero frontend consumer (MCP also doesn't route through these — it calls services directly)

- **workspace** (`workspace/routes.go`): `POST .../items/{id}/move` (:92), `PUT .../items/{id}/release` (:106), `PUT .../items/{id}/sprint` (:152), `POST .../interests/{id}/rank` (:176), `PATCH .../onboarding/{stepID}` (:187)
- **gitlab** (`gitlab/routes.go`): `PATCH .../installations/{id}` (:54), `GET /api/projects/teams/{id}/members` (:98), `.../activity` (:102), `.../contributions` (:135), `GET .../checkpoints/{id}/submissions` (:111), `GET /api/my/projects/{id}` (:147), `.../contributions` (:149), `.../checkpoints` (:151)
- **labs**: `GET /api/labs/sessions/active` (:49 — bootstrap serves it)
- **project**: `POST /api/projects` (:23 — only GET has a consumer)
- **labauthor**: `DELETE .../recipes/{id}` (:48)
- **certificates**: `GET|PUT /api/courses/{id}/certificate-threshold` (:45-46 — FE calls nonexistent `/certificate-rule`), `GET /api/certificates/me`
- **assessment**: `POST .../batches/{id}/invite`, `GET /api/invitations/preview/{token}`, `POST /api/invitations/accept|decline`, `GET .../attempts/{id}/evaluation/status`, `GET .../compare/{otherID}`, `POST .../questions/auto-select`, `GET|DELETE .../assignments*`, `PATCH .../candidates/{id}/override`, `PATCH .../answers/{id}/override`, `GET|PATCH /api/questions/{id}`, `GET /api/cohort-groups/{id}`, `GET /health/eval-queue`, deprecated `POST /api/p/{code}/submit/{token}` + `GET .../result/{token}` (marked deprecated in code — violates the no-dead-code rule)
- **courses**: `POST /api/courses/generate-outline`, `POST /api/upload/course-asset`, `POST .../fork`, `GET .../reviews/me`, `PUT|DELETE .../translations/{locale}`
- **messaging**: `PATCH|DELETE /api/messages/{id}`, `POST .../pin`, `POST .../reactions`, `POST /api/courses/{id}/faqs`, `PATCH|DELETE /api/faqs/{id}`, `PUT .../faqs/order`
- **wiki**: `PATCH|DELETE /api/wiki/spaces/{id}`, `GET .../spaces/{id}/pages`, `DELETE /api/wiki/pages/{id}`, `GET|PUT .../pages/{id}/okf`, `GET .../spaces/{slug}/okf`, `GET .../versions/{version}`, `GET .../comments`, `DELETE .../templates/{id}`
- **interviewexp**: `PATCH|DELETE /api/interview-exp/qna/{id}`, `PATCH|DELETE .../comments/{id}`
- **others**: `GET /api/practice/technologies`, `PATCH /api/practice/sessions/{id}`, `PATCH /api/sheets/{id}/items/{itemId}` (FE uses `/api/progress/*` instead), `POST /api/srs/cards`, `GET /api/journal/graph`, `GET /api/rewards/definitions`, `GET|PUT /api/admin/ops-alert-rules`, `GET /api/profile/user/{userID}`, `POST /api/auth/logout-all`, `GET /api/auth/csrf-token`, `POST /api/orgs/join`, `GET /api/me/permissions` (only consumed in-process by bootstrap), `PUT /api/admin/users/{id}/tier`

### Exact duplicates

- `GET /api/project-marketplace/board/{id}` = `GET .../requirements/{id}` (same handler; FE even comments "same underlying handler")
- `GET /api/bundles/manage` vs `GET /api/bundles` — differ only by view; **both consumed**, so both must be maintained
- `GET /api/tickets/me` vs `GET /api/tickets?mine=`
- `POST /api/wiki/pages/{id}/move` ⊂ `PATCH /api/wiki/pages/{id}` (`MovePageRequest` is a strict subset of `UpdatePageRequest`)
- `GET /api/highlights/me` vs `GET /api/highlights` — only diff is a filter that belongs in a query param
- Two feedback collections over one table: `/api/feedback` + `/api/experience-reports` (differ by `kind`)
- Two ticket trees: `/api/tickets` + `/api/mentor-tickets` with `/detail` overlapping `/api/tickets/{id}`
- Two write APIs over one sheet item row: `PATCH /api/sheets/{id}/items/{itemId}` (MCP uses this) vs 5 × `/api/progress/*` (FE uses these)
- `POST /api/assessments/{id}/publish` + `POST .../status` — two RPCs for one status field

## 5. Best-practice violations (systemic)

### Pagination — biggest gap

~30+ list endpoints have no `limit`/`offset`/`cursor`:
gitlab lists, labs catalog, projectmarket, tickets, coupons, content-reports, FAQs, notifications (fixed `LIMIT 50`), whats-new, wiki spaces/versions/comments/search, sheets (all 3 lists), captures, focus-wall, srs due, `/api/admin/orgs` (unbounded cross-tenant), batch rosters/invitations, `GET /api/courses/{id}/progress` (all students).

Four paging styles coexist: cursor (workspace, library), limit/offset (labauthor, roadmap, authz, rewards), after+next_cursor (jobs), none (most). **Only `activity` is fully correct** (`activity/handler.go:40-66`) — copy it: `?limit=&cursor=` + `{items, next_cursor}`.

Also: `limit` without cursor (highlights, mistakes, journal) **silently truncates** at the cap.

### Naming chaos (breaks SDK/MCP generation)

- **Path params — 5 conventions**: `{courseID}` / `{labId}` / `{id}` / `{invite_id}` / `{member_id}`. Same org resource is `{id}` in orgs but `{orgID}` in jobs (which caused the security bug in §2).
- **"My resource" — 4 conventions**: `/api/my/*`, `/{res}/me`, `/api/me/*`, `/api/<res>/me`.
- **JSON casing**: whatnow is camelCase (`taskIds`, `resumeNote`…); all 15 sibling domains are snake_case.
- **Slug vs id**: wiki/sheets read by `{slug}` on GET but `{id}` on PATCH/DELETE under the same URL pattern — client can't know which to pass.

### Verb-in-path RPC soup (where a field update fits)

- mentor-tickets: `claim|assign|close|change-request` → `PATCH /api/tickets/{id} {status, assigned_to}`
- change-requests: `approve|deny` → `PATCH .../change-requests/{id} {status}`
- messages: `pin|resolve|promote-faq` — `pin` flips a toggle on POST (non-idempotent) → `PATCH /api/messages/{id} {pinned}`
- notifications: `read|read-all` → `PATCH /api/notifications/{id} {read}`
- calendar: `complete` + `notes` as two routes → one `PATCH /api/calendar/events/{id}`
- rbac: `POST .../roles/{id}/enable` vs `DELETE .../roles/{id}` → `PATCH ... {active}`
- captures: `dismiss` is a delete → `DELETE /api/captures/{id}`
- srs: `POST /api/srs/review` with `card_id` in body → `PATCH /api/srs/cards/{id} {quality}`
- privacy: `POST .../delete-account` → `DELETE /api/me`
- workspace: `transfer-owner` → `PATCH .../members/{userId} {role:"owner"}`; `status` as own path → `PATCH /api/workspaces/{id}`
- gitlab: `POST /api/gitlab/disconnect` → `DELETE /api/gitlab/connection`
- legal: `POST .../accept` → `PUT /api/legal/consents/{doc_type}`

(Defensible as-is: `/publish`, `/enroll`, `/checkout` — genuine state transitions.)

### Transactions missing (violates repo rule 6)

- `whatnow/plan/today`: N separate `repo.UpdateTask` calls, no `BeginTx` (`whatnow/service.go:671-688`) → half-selected plan on mid-loop failure.
- `diary/{date}/analyze/apply`: writes habit completions + tasks + analysis across 3 domains, no tx (`diary/service.go:107-124`; comment admits it, relies on dedup-on-retry).
- `projectmarket create-team`: team + member inserts with `continue`-on-failure, no tx (`projectmarket/service.go:263-292`).

### Validation gaps

- `PATCH /api/project-marketplace/requirements/{id}` skips `validateRequirementRequest` that Create runs (`handler_requirement.go:93-122`) → can write `team_size_max < team_size_min`.
- whatnow task capture: only `raw != ""` — no max length (every other domain caps content).
- `GET /api/whatnow/plan/day?date=`: malformed date silently falls back to today instead of 422; same for `?energy=` and oversized `taskIds`.
- feedback `subjectType` cast from path/body without enum whitelist at the handler boundary.
- `PATCH .../applications/{id}` bad status → 409 instead of 422 (validation ≠ conflict).

### Auth / permission inconsistency

- **`interviewprep` has no permission gate** (`interviewprep/routes.go:27` takes no `authzSvc`) — burns LLM + code-executor quota for any authenticated member, while sibling content domains gate. Outlier along with `mistakes` (sibling of gated `content.*`).
- Personal-tool split: 9 domains gated (`content.*`/`practice.*`), 7 auth-only (interviewprep, mistakes, highlights, focuswall, habit, whatnow, activity). Personal-note domains may be intentional; interviewprep + mistakes are not.
- `labauthor` gate mismatch: `RequirePermission(PermCompose, PermManageBlocks)` requires **ALL** codes (`authz/middleware.go:14-23`) but frontend `canManageBlocks()` checks only `MANAGE_BLOCKS` → UI shown, 403 returned.
- `POST /api/privacy/export|delete-account` — no step-up/MFA (see §2).

### AI endpoints / idempotency

- No `Idempotency-Key` on `POST /api/interview-prep`, batch `import/confirm`, workspace AI calls, labauthor `ticket-draft`, highlights `explain` (only projectmarket `score` honors one) → double-click = double LLM cost. Violates "AI called once". Frontend helper `apiAction(..., extraHeaders)` already supports it.

### Response conventions

- DELETE varies: `200 {}` (workspace), `200 {"message"}` (gitlab), `200 {"deleted":true}` (wiki), `204` (habit/focuswall/sheets). → standardize on **204**.
- List envelopes vary: bare array / `{roadmaps:}` / `{plan:}` / `{entries:}` / `{items, next_cursor}`. → one envelope.
- `POST /api/user/onboarding` returns `200 {"message"}` while every other write returns 201/204.

### Misc

- `GET /health/eval-queue` mounted **inside** the authed staff group (`assessment/routes.go:173`) — unreachable by uptime probes; outside `/api` prefix too.
- `POST .../recipes/{id}/validate` is a side-effect-free read exposed as POST (frontend admits it) → `GET .../analysis`.
- `r.Use(idem)` applied to the whole `/api/orgs/{id}` group incl. GET/DELETE (`orgs/handler.go:69`) — idempotency keys belong only on resource-creating POSTs.
- `labs` `RegisterAdminRoutes` hardcodes `"admin.manage_org"` string (`labs/routes.go:91`) — use a constant.
- Labs file API: `GET .../files/read?path=`, delete by query param on a collection — address files by path in the URL instead.
- Route ownership is unclear: `workspace` serves `/api/gitlab/planning/*`, `gitlab` serves `/api/projects/*`, `labauthor` + `labbuild` both serve `/api/instructor/lab-authoring/*` — URL prefix no longer implies implementing package (matters for MCP tool registry).
- Two namespaces for teams: `/api/projects/teams/*` vs `/api/my/projects/*`; two owners of `/api/projects/*` (personal `project` package vs `gitlab` package); personal lists not org-scoped at all (`project/repo.go:34`).

### MCP coverage gap

`mcpconnect/tools.go` covers courses, calendar, journal, habit, sheets, srs, wiki, systemdesign, interviewprep, mistakes — **zero tools** for workspaces, labs, roadmaps, marketplace, projects, gitlab, tickets. Consistent with the diagnosis: those APIs were shaped for one UI each and never made generatable.

## 6. Fix order

1. **Security**: jobs `{orgID}` param + `RequireOrgRole` vs `claims.OrgID`; assignee membership check; reaction org guard; domains/verify guard.
2. **Broken contracts**: jobs pause/resume, certificate-rule vs threshold, focus-wall categories, (check `certificate-rule` both sides).
3. **Conventions** (highest leverage for AI adaptability): one path-param convention (`{id}`/`{slug}`), one "me" convention, one cursor pagination spec (`activity` as template), one list envelope, snake_case JSON everywhere (fix whatnow), 204 on DELETE.
4. **Kill dead weight**: ~45 unconsumed endpoints + exact duplicates (§4).
5. **De-widget**: hub-stats, ticket `/detail`, `final-test/edit`, `progress`×5, whatnow verbs, bootstrap `?include=`, planning board → work-items list, dashboard blobs → reports.
6. **Correctness**: transactions for whatnow plan / diary apply / create-team; validator on PATCH requirements; idempotency keys on AI POSTs; interviewprep permission gate.

---

*Generated from a full review of `backend/internal/**/routes.go` + handler/service sampling + frontend consumer grep across `frontend/{app,components,lib}`.*
