# MindForge

## Model Routing for MindForge Tasks

Always pick the lowest tier that does the job correctly. Switch with `/model <alias>` before starting.

| Task | Model |
|---|---|
| Read docs, search codebase, grep for symbols | `haiku` |
| Add/rename env vars, update Docker Compose | `haiku` |
| Additive SQL migration (add column/index, no schema rethink) | `haiku` |
| Add a new route handler identical in shape to existing ones | `haiku` |
| Write sqlc queries for existing table patterns | `haiku` |
| Fix a typo, rename a constant, update a config value | `haiku` |
| New API endpoint (handler + sqlc query + types, 1–3 files) | `sonnet` |
| Frontend page or component build | `sonnet` |
| Bug fix requiring logic changes | `sonnet` |
| Write/update integration tests | `sonnet` |
| Refactor within one Go package or one frontend module | `sonnet` |
| LLM provider interface work (AI calls, prompt templates) | `sonnet` |
| DB schema design for a new domain (new tables, FK strategy) | `opus` |
| Auth / JWT / session / RBAC critical path changes | `opus` |
| Multi-package Go refactor (5+ files, cross-domain) | `opus` |
| SM-2 algorithm or spaced-repetition logic design | `opus` |
| Payment / subscription / entitlement system design | `opus` |
| Security audit or threat model for any phase | `opus` |
| Architecture decision: new service, new pattern, phase design | `opus` |

The table is guidance for choosing a model tier; nothing enforces it.

---

The post-edit hook is wired in `.claude/settings.json` — `post-edit.sh` runs `go vet ./...` after `.go` edits and `bun x tsc --noEmit` plus `vp lint` after `.ts/.tsx` edits, so Claude self-corrects before moving to the next file.

---

**MindForge** — multi-tenant learning platform. LeetCode + KodeKloud + Udemy + Notion, delivered as SaaS.
Stack: Go (see `backend/go.mod`) + Chi v5 + pgx/v5 · Next.js (see `frontend/package.json`) + React 19 + Tailwind v4 + shadcn/ui · PostgreSQL · Docker Compose.

---

## Docs

Each file is self-contained for its domain — features, API endpoints, DB schema, and rules all in one place.

| File | Contents |
|---|---|
| [docs/overview.md](docs/overview.md) | Vision, user roles, multi-tenancy, tech stack, build phases |
| [docs/auth.md](docs/auth.md) | Auth flows, all API endpoints, DB schema, env vars, security rules |
| [docs/rbac.md](docs/rbac.md) | RBAC — permission codes, roles, DB schema, Go engine, API, frontend hooks, admin UI, recipes |
| [docs/courses.md](docs/courses.md) | Course structure, lifecycle, fork, enrollment, progress, API, DB schema |
| [docs/learning.md](docs/learning.md) | Coding challenges, in-browser compiler, quiz, SM-2 cards, revision, certificates, API, DB schema |
| [docs/labs.md](docs/labs.md) | Lab feature — terminal/code/guided sandboxed environments, AI hints, DB schema, edge cases, build phases |
| [docs/labs-audit.md](docs/labs-audit.md) | Labs/container execution audit (2026-10-08) — runtime architecture, session flow, security & scalability findings, capacity math, hosting cost comparison, reduction plan |
| [docs/session-booking.md](docs/session-booking.md) | Mentor session booking — org toggle, availability/slots, session credits, cancellation policy, feedback + notes, batch sessions, calendar projection, API, DB schema |
| [docs/orgs.md](docs/orgs.md) | Organizations, members, roles, API, DB schema |
| [docs/wiki.md](docs/wiki.md) | Wiki spaces, pages, TipTap editor, versioning, comments, templates, search, API, DB schema |
| [docs/design.md](docs/design.md) | System design canvas, palette, interactions, versioning, embed, API, DB schema |
| [docs/interview.md](docs/interview.md) | Interview board, load test simulator, Yjs sync, API, DB schema |
| [docs/project-workspace.md](docs/project-workspace.md) | Workspaces (replaces the Projects UI + marketplace) — share-link interest form, discover/apply, accept/invite, tracks, Epic→Feature→Task work items, feature doc review gate, multi-role assignees, GitLab ticket-key linking and team GitLab surfaces, GitLab cohorts, manager dashboard |
| [docs/project-marketplace.md](docs/project-marketplace.md) | SUPERSEDED by project-workspace.md (history only) |
| [docs/sheets.md](docs/sheets.md) | Sheet tracker, overlap view, subscribe/fork, API, DB schema |
| [docs/learning-journal.md](docs/learning-journal.md) | Personal day-by-day learning log, free-typed categories, similar-entry detection, API, DB schema, MCP tools |
| [docs/captures.md](docs/captures.md) | Knowledge Captures — screenshot/PDF/link inbox, vision-AI + pdftotext extraction, note/question classification, dedup into journal/SRS, API, DB schema |
| [docs/diary.md](docs/diary.md) | Free-form daily diary — AI habit/task detection writing into Habits/What Now?, Fix English grammar diff, API, DB schema |
| [docs/roadmap.md](docs/roadmap.md) | AI personalized roadmaps — goal-to-plan generation, catalog matching, GENERATED/DEFINED mode, API, DB schema |
| [docs/anonymous.md](docs/anonymous.md) | Public tests, anonymous attempts, API, DB schema |
| [docs/calendar-sync.md](docs/calendar-sync.md) | Opt-in Google Calendar account sync — OAuth flow, push/pull, DB schema, API, edge cases |
| [docs/ai-connector.md](docs/ai-connector.md) | AI Connector (MCP) — connect the student's own Claude/ChatGPT via OAuth 2.1+PKCE, course/notes/calendar tools, DB schema, API |
| [docs/entity-schedules-and-calendar-sync.md](docs/entity-schedules-and-calendar-sync.md) | starts_at/ends_at on batches/courses/lessons, auto-synced read-only into the in-app calendar |
| [docs/infrastructure.md](docs/infrastructure.md) | Project file structure, all env vars, AI rules, payments, SSRF denylist |
| [docs/dev-box-runbook.md](docs/dev-box-runbook.md) | Remote dev box (hot reload on k3s) — architecture, one-time setup, 31 problems with cause and fix, MFA/email/lab recipes, open items |
| [docs/ops-alerts.md](docs/ops-alerts.md) | Admin alerting for dead-letter jobs and job-system health — routing, per-handler rules, dedupe/storm frequency control, ops.health + ops.digest crons, API |
| [docs/activity.md](docs/activity.md) | Activity tracker — day-by-day timeline aggregating module/course completions, quiz attempts, MCP reflections, sheet progress, lab sessions, SM-2 reviews, API, DB schema |
| [docs/analytics.md](docs/analytics.md) | Instructor & org analytics — completion funnel, per-lesson drop-off, hardest quiz questions, at-risk students, enrollment trend, API, RBAC, query cost |
| [docs/entitlements.md](docs/entitlements.md) | Tier & entitlement system — plans, add-ons, seats, quota engine (partially implemented) |
| [docs/support-ticket-rbac-decision.md](docs/support-ticket-rbac-decision.md) | Why support ticket access moved to the dedicated `support_agent` role |
| [docs/interview-experiences.md](docs/interview-experiences.md) | Crowd-sourced interview experience board — posts, continuation, Q&A, voting |
| [docs/interview-practice.md](docs/interview-practice.md) | Subjective assessment questions with AI grading |
| [docs/content-pipeline.md](docs/content-pipeline.md) | Importing third-party course material: vendor → canonical markdown → SQL → DB |
| [docs/flow-map.md](docs/flow-map.md) | Feature-wise code flow trace: frontend → API → handler → repo → DB |
| [docs/api-review.md](docs/api-review.md) | Review of ~600 endpoints against the resource-oriented/MCP-friendly rubric |
| [docs/audit-root-cause-analysis.md](docs/audit-root-cause-analysis.md) | Consolidated audit — findings, root causes, fixes, status |
| [docs/schema-refactor-decisions.md](docs/schema-refactor-decisions.md) | Schema overlap review and refactor decisions record |
| [docs/email-job-resilience-checklist.md](docs/email-job-resilience-checklist.md) | Email and job-queue failure resilience checklist |
| [docs/local-k3s-dev.md](docs/local-k3s-dev.md) | Local k3s dev environment in WSL using the cloud manifests |
| [docs/erd.md](docs/erd.md) | Auto-generated DB ER diagram (`scripts/db-erd.sh`) — do not edit by hand |
| [docs/debug-labs-status.md](docs/debug-labs-status.md) | Debug labs build status; E2E logs in `debug-labs-e2e-status.md` and `debug-labs-e2e-report-2026-10-10.md` |
| [docs/frontend-gotchas.md](docs/frontend-gotchas.md) | Non-obvious frontend bugs and regressions worth not repeating (e.g. Popover-in-Dialog scroll lock) |
| [docs/ai-pattern-learnings.md](docs/ai-pattern-learnings.md) | Shortcut patterns found in AI-written code (unthrottled endpoints, unlocked counters, unpaginated lists, trusted-input-as-validation, missing DB test infra) — updated as new instances are found, not just at the end of a review |

---

## Frontend Rules
See [frontend/CLAUDE.md](frontend/CLAUDE.md) — enforced on every frontend file. Covers design tokens, the `lib/server/api.ts` helpers, and the UX-skill adapter rule — not repeated here since this file loads for backend work too.

---

## Coding Rules (Non-Negotiable)

1. **DRY** — shared logic (response helpers, role checks, AI calls) lives in one place only
2. **Complete error handling** — `fmt.Errorf("context: %w", err)` everywhere
3. **Validate inputs at boundary** — before DB or AI calls
4. **AI called once** — always check DB first, return cached result if exists
5. **Permission middleware** — every protected route uses `authz.RequirePermission(...)` / `RequireAnyPermission(...)`
6. **Transactions** — multi-table writes always in a DB transaction
7. **No streaming** unless explicitly needed (predictable cost)
8. Use `TaskCreate/TaskUpdate` to track all phases

No-stubs and no-hardcoded-values are covered by the banned-patterns table below.
9. **Permission codes only** — nav items, route guards, and handlers check permission codes (`requiredPermission`, `authz.RequirePermission`), never `org_members.role` strings. A nav item with no `requiredPermission` must carry a `// public` comment saying why.

---

## Production-Ready From Day One (Non-Negotiable)

Every line of code written here is production code. There are no phases, shortcuts, or "we'll fix this later" passes.

**Banned patterns — reject immediately, do not write, do not accept:**

| Pattern | Example | Why banned |
|---|---|---|
| Stub / placeholder logic | `return nil // TODO implement` | Silently wrong in prod |
| Commented-out workaround | `// rdb := redis.NewClient(...)` | Accumulated debt ships |
| Dev-only bypass | `if isDev { skip auth }` | Security hole in prod |
| Hardcoded fallback | `secret := "change_me"` | Credential leak |
| Feature flag deferral | `if featureEnabled { ... }` without wiring | Dead code ships |
| `sync.Map` instead of Redis "for now" | In-process cache for shared state | Breaks at 2 replicas |
| `// TODO`, `// FIXME`, `// HACK` | Any variant | Signals incomplete work |
| `panic("not implemented")` | Any variant | Crashes prod |

Not banned: a comment recording a *deliberate, shipped* simplification (`ponytail:` marker naming its ceiling), or a note that a route/feature is intentionally absent until it ships (e.g. in `frontend/lib/nav.ts`). Banned is unfinished code, not documented scope.

**Decision rule:** If a proper implementation would take longer, do the proper implementation. Do not ship the shortcut and plan to revisit. The shortcut becomes the implementation.

**When asked to bypass or workaround:**
- Refuse and implement the correct solution
- If the correct solution is unclear, ask the user — do not guess and patch
- If an external dependency (Redis, SMTP, etc.) is needed, wire it now, not later
