# AI Connector (MCP)

Lets a student connect **their own** Claude or ChatGPT account to MindForge as
a remote MCP (Model Context Protocol) connector, instead of MindForge running
its own chat UI on its own API key. The student's client calls a handful of
MindForge tools to read their enrolled courses and lesson content, read/write
a personal lesson-notes overlay, log what they understood or struggled with,
and manage their MindForge calendar. MindForge never makes an LLM call for
this feature and pays nothing per token — the "AI" in the loop is entirely
the student's own client and their own subscription.

This is additive to two features that already existed: `backend/internal/highlights`
(select lesson text → AI explanation, platform-key-driven) and the per-module
"Reflect" box (`lesson_reflections`, student-typed understanding signal with
no consumer until `revisionplan` was built). The connector reuses
`lesson_reflections` for its `log_understanding` tool rather than creating a
second signal table.

## Non-Negotiables

- **Opt-in only, per user.** Nothing is connected until the student pastes
  the connector URL into their own client and completes the consent screen
  below. No org-admin toggle grants access on a student's behalf.
- **OAuth 2.1 + PKCE, no client secret.** MCP clients (Claude Desktop, Claude.ai
  Connectors, ChatGPT) are public/native apps — PKCE substitutes for a secret
  they cannot safely hold. Every token is scoped to exactly one user + one
  client; a tool call can never act on another user's data.
- **All-or-nothing scope, all mapped to the student's own data.** There is no
  cross-user or admin-level scope to request — every scope this connector can
  grant only ever reads or writes the connecting student's own account.
- **Fully revocable.** Settings → Integrations lists every active connection
  with a one-click Disconnect, which invalidates its refresh token
  immediately (its current access token, if any, simply expires within the
  hour).

## Architecture

### OAuth Flow

1. Student pastes the connector URL (`{BACKEND_URL}/mcp`) into their client's
   connector settings.
2. Client discovers endpoints via `GET /.well-known/oauth-authorization-server`
   and `GET /.well-known/oauth-protected-resource`, then self-registers via
   `POST /oauth/register` (Dynamic Client Registration, RFC 7591) — no admin
   approval step.
3. Client redirects the student's browser to `GET /oauth/authorize`, which
   validates `client_id`/`redirect_uri`/PKCE params, then hands off to
   MindForge's own consent screen at `/settings/integrations/authorize`
   (existing `/settings/*` auth middleware enforces login, including bouncing
   through `/login?next=` if needed).
4. Student approves → `POST /oauth/authorize/approve` mints a single-use
   authorization code, and the frontend navigates the browser to the
   client's own `redirect_uri` carrying that code.
5. Client exchanges the code (with its PKCE `code_verifier`) at
   `POST /oauth/token` for an access token (1h) and refresh token (30d,
   rotated on every use).

### MCP Server

A single stateless `POST /mcp` endpoint implements just the JSON-RPC methods
this tool set needs (`initialize`, `tools/list`, `tools/call`) — hand-rolled
rather than pulled from an SDK, since no MCP Go SDK dependency was
reachable/verifiable in the environment this was built in, and three
JSON-RPC methods with no streaming is a small enough surface that hand-rolling
carried less risk than an unverified new dependency. Every tool call carries
its own bearer access token, so no `Mcp-Session-Id`/SSE session state is
needed between requests.

Tools, each a thin wrapper over an existing domain service (no new business
logic, no new authorization rules beyond what the student-facing API already
enforces):

| Tool | Scope | Delegates to |
|---|---|---|
| `list_my_courses` | `courses:read` | `courses.Repo.GetMyEnrollments` — includes the student's own self-courses too, since their owner is auto-enrolled at creation |
| `get_lesson` | `courses:read` | `courses.Service.GetModuleContent` |
| `get_my_lesson_note` | `notes:write` | `courses.Service.GetMyLessonNote` |
| `save_my_lesson_note` | `notes:write` | `courses.Service.SaveLessonNote` (source="ai") |
| `log_understanding` | `signals:write` | `courses.Service.LogUnderstanding` → `lesson_reflections` (source="ai") |
| `create_self_course` | `courses:write` | `courses.Service.CreateSelfCourse` / `ForkSelfCourseFromOrgCourse` — first checks `Repo.FindSimilarSelfCourse` (pg_trgm title match against the owner's own self-courses, same `> 0.3` threshold `internal/roadmap/matcher.go` uses); a match returns the existing course (`matched_existing: true`) instead of creating a duplicate |
| `add_self_course_module` | `courses:write` | `courses.Service.AddSelfCourseModule` — first checks `Repo.FindSimilarModuleInCourse`; a same-course match appends the new content to the existing module (`matched_existing: true`) instead of a duplicate lesson. Also checks `Repo.FindSimilarModuleElsewhere` (other self-courses the owner has); a match is returned as `similar_elsewhere` without touching either module — cross-course overlap is only ever surfaced, never auto-merged |
| `update_self_course_module` | `courses:write` | `courses.Service.UpdateSelfCourseModule` |
| `propose_module_to_org_course` | `courses:write` | `courses.Service.ProposeModuleToOrgCourse` → `course_content_proposals` (`status='pending'`); given `source_module_id`, copies that self-course lesson's title/content server-side and records `source_course_id`/`source_module_id` for traceability instead of trusting retyped text |
| `get_learning_context` | `courses:read` | `courses.Service.GetLearningContext` — enrolled courses + progress, recent reflections, recent self-course activity, all in one call |
| `get_random_topic` | `courses:read` | `courses.Service.GetRandomTopic` — one published course the student hasn't tried yet, weighted toward `user_profiles.topics_interest` |
| `list_calendar_events` | `calendar:manage` | `calendar.Service.ListRange` |
| `create_calendar_event` | `calendar:manage` | `calendar.Service.CreateEvent` |
| `update_calendar_event` | `calendar:manage` | `calendar.Service.GetEvent` + `UpdateEvent` (merges patch onto the current row — a bare partial struct would silently wipe `batch_id`/`course_id`/`entity_type` etc., since `Repo.Update` overwrites every column it touches) |
| `delete_calendar_event` | `calendar:manage` | `calendar.Service.DeleteEvent` |
| `list_interview_prep_plans` | `interview_prep:manage` | `interviewprep.Service.ListPlans` |
| `get_interview_prep_plan` | `interview_prep:manage` | `interviewprep.Service.GetPlan` — plan + rounds, but not a conceptual/behavioral round's question text (see `get_interview_prep_round`) |
| `create_interview_prep_plan` | `interview_prep:manage` | `interviewprep.Service.CreatePlan` — quick or targeted, same validation and 5/day rate limit (`interviewprep.MaxPlansPerDay`) as the in-app form, since both go through the same `Service.CreatePlan` |
| `get_interview_prep_round` | `interview_prep:manage` | `interviewprep.Service.GetRoundSession` → `practice.Service.GetSession` — every plan's round 1 (conceptual or behavioral) is a practice session; this is the only way to read its actual question text/answers/AI feedback, since `get_interview_prep_plan` only returns the opaque `practice_session_id` |
| `submit_interview_prep_round_answer` | `interview_prep:manage` | `interviewprep.Service.SubmitRoundAnswer` → `practice.Service.SubmitAnswer` |
| `submit_interview_prep_coding_item` | `interview_prep:manage` | `interviewprep.Service.SubmitCodingItem` — round 2 (technical targeted plans only) |
| `get_interview_prep_report` | `interview_prep:manage` | `interviewprep.Service.GetReport` |
| `list_system_design_attempts` | `system_design:manage` | `systemdesign.Service.ListAttempts` |
| `create_system_design_attempt` | `system_design:manage` | `systemdesign.Service.CreateAttempt` — blank-canvas attempt; earlier attempts are kept, not overwritten |
| `get_system_design_attempt` | `system_design:manage` | `systemdesign.Service.GetAttempt` — scene (Excalidraw elements/appState) plus any saved feedback |
| `save_system_design_scene` | `system_design:manage` | `systemdesign.Service.SaveScene` — replaces the whole scene; the connected AI can draw/edit the whiteboard directly |
| `generate_system_design_feedback` | `system_design:manage` | `systemdesign.Service.GenerateFeedback` |
| `list_system_design_chat` | `system_design:manage` | `systemdesign.Service.ListChat` |
| `send_system_design_chat_message` | `system_design:manage` | `systemdesign.Service.SendChatMessage` |

### `interview_prep:manage` — one combined scope, no revert on generation

Every interview-prep tool shares one scope rather than splitting read/write, mirroring `calendar:manage` — every call is already scoped to the connection's own plans. `create_interview_prep_plan` and both submit tools have no `Revert`: `CreatePlan` is capped at `interviewprep.MaxPlansPerDay` (5/day) via `CountRecentPlans`, and deleting a plan on revert would let a connected client bypass that cap by looping create+revert; the two submit tools have already run AI grading (and, for coding items, executed the code) by the time they return, so there's no meaningful undo for the stored answer alone.

### `courses:write` — the one write scope that touches course content

Every other write scope (`notes:write`, `signals:write`, `calendar:manage`) only ever touches a table scoped 1:1 to the connecting user. `courses:write` is different — it can create/edit **courses**. The non-negotiable boundary (see `docs/courses.md`'s "Kind: org vs. self"):

- `create_self_course`/`add_self_course_module`/`update_self_course_module` only ever read/write a `kind='self'` course whose `owner_id` is the connection's own `user_id` — enforced by `courses.Repo.GetOwnedSelfCourse` on every call, the same choke point the in-app self-course endpoints use. There is no tool that edits a `kind='org'` course's modules.
- `propose_module_to_org_course` never writes to an org course either — it only inserts a `pending` `course_content_proposals` row. An org course only gains a new module when that course's own instructor/admin approves it through the ordinary web app (`docs/courses.md`'s proposal review queue), a plain session-authenticated, RBAC-gated endpoint — never reachable via `/mcp`.

### `system_design:manage` — the whiteboard tool, not the (unbuilt) canvas doc describes

This scope covers `internal/systemdesign`, the actual system-design feature: an Excalidraw whiteboard a student fills in against one `course_modules` row of `type='system_design'`, with AI feedback and a clarifying-question chat (`system_design_attempts`, `system_design_chat_messages`). It is unrelated to the standalone React-Flow canvas / `system_designs` table `docs/design.md` describes — that feature was never built; `docs/design.md` is stale. `save_system_design_scene` is the "update the design" tool: it takes a full Excalidraw scene (`{elements, appState}`) and replaces the attempt's canvas wholesale, the same as `SaveScene` does for the in-app autosave. One combined scope rather than a read/write split, same reasoning as `interview_prep:manage` — every call is already scoped to the connection's own attempts.

## Database Schema

Introduced by migration `015_add_lesson_notes_and_mcp_connections.sql` (now folded into `001_baseline.sql` — migrations `002`–`027` were squashed 2026-07-30):

```sql
lesson_notes (id, org_id, user_id, module_id, content, source, created_at, updated_at)
  UNIQUE (user_id, module_id) -- one overlay per user per module, upserted

lesson_reflections.source  -- added column: 'manual' | 'ai'

mcp_clients (client_id, client_name, redirect_uris, created_at)
mcp_connections (id, org_id, user_id, client_id, scopes, refresh_token_hash,
                  refresh_token_expires_at, status, last_used_at, created_at, revoked_at)
  UNIQUE (user_id, client_id)
mcp_access_tokens (id, connection_id, token_hash, expires_at, created_at)
mcp_auth_codes (code, client_id, org_id, user_id, scopes, code_challenge,
                redirect_uri, expires_at)
```

Access and refresh tokens are stored **hashed** (SHA-256, compare-only),
mirroring the existing login `refresh_tokens` table — never encrypted-and-
reversible, since nothing ever needs to recover the raw token server-side.

## API Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/.well-known/oauth-authorization-server` | none | RFC 8414 discovery |
| GET | `/.well-known/oauth-protected-resource` | none | RFC 9728 discovery |
| POST | `/oauth/register` | none | Dynamic Client Registration |
| GET | `/oauth/authorize` | none (hands off to session-protected frontend) | Authorization redirect entry point |
| GET | `/oauth/authorize/details` | session | Consent screen data (client name, scopes) |
| POST | `/oauth/authorize/approve` | session + CSRF | Mint auth code, return client's redirect URL |
| POST | `/oauth/authorize/deny` | session + CSRF | Return client's redirect URL with `error=access_denied` |
| POST | `/oauth/token` | PKCE / refresh token (form-encoded, RFC 6749) | Code/refresh → access + refresh token |
| POST | `/mcp` | Bearer access token | JSON-RPC tool calls |
| GET | `/api/mcp-connections` | session | List my active connections |
| DELETE | `/api/mcp-connections/{id}` | session + CSRF | Revoke a connection |
| GET / PUT | `/api/modules/{moduleID}/notes(/me)` | session | Manual (non-AI) lesson-notes read/write, same overlay the `save_my_lesson_note` tool writes |

## Frontend

- `Settings → Integrations` (`app/(app)/settings/integrations/page.tsx`): the
  connector URL to paste into a client, plus a list of active connections
  with a Disconnect action — same list/revoke shape as the Passkeys page.
- `app/(app)/settings/integrations/authorize/page.tsx`: the consent screen
  the OAuth redirect lands on. Protected by the existing `/settings/*` edge
  middleware, so an unauthenticated visitor is bounced through `/login?next=`
  and back automatically.
- Lesson page: a "My notes" side panel (`components/courses/lesson-notes.tsx`)
  — a `<Sheet>`, separate from the existing "Reflect" box. The lesson content
  underneath is always visible; closing the panel is "view original."

## Security

- PKCE mandatory (`S256` only), refresh tokens rotate on every use, every
  query is scoped by the token's resolved `user_id`/`org_id` — never a
  client-supplied id.
- `redirect_uri` is validated against the client's registration at every step
  (`/oauth/authorize`, `/oauth/authorize/approve`, `/oauth/token`) before it
  is ever redirected to, closing the open-redirect risk an unchecked
  client-supplied URL would otherwise create.
- Protocol-facing responses (discovery, register, authorize, token, `/mcp`)
  return bare JSON — never MindForge's usual `{"data": ...}` app envelope,
  which a real OAuth/MCP client would not know to unwrap.
