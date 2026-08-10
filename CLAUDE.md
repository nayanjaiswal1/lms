# MindForge

> Say **"hi"** to resume. Say **"start phase N"** to build. Say **"update design: [feature]"** before adding features.

---

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

Subagent, advisor-strategy, context-protection, and parallel-agent rules are already covered in the global `~/.claude/CLAUDE.md` and the `dev-env-setup` skill — not repeated here. The table above is the MindForge-specific addition.

---

MCP server list and hooks.json template: see the `dev-env-setup` skill. The post-edit hook is already wired in `.claude/settings.json` — `post-edit.sh` runs `go vet ./...` after `.go` edits and `pnpm tsc --noEmit` after `.ts/.tsx` edits, so Claude self-corrects before moving to the next file.

---

**MindForge** — multi-tenant learning platform. LeetCode + KodeKloud + Udemy + Notion, self-hosted, no vendor lock.
Stack: Go 1.26.4 + Chi v5 + pgx/v5 · Next.js 16.2.9 + React 19 + Tailwind v4 + shadcn/ui · PostgreSQL · Docker Compose.

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
| [docs/session-booking.md](docs/session-booking.md) | Mentor session booking — org toggle, availability/slots, session credits, cancellation policy, feedback + notes, batch sessions, calendar projection, API, DB schema |
| [docs/orgs.md](docs/orgs.md) | Organizations, members, roles, API, DB schema |
| [docs/wiki.md](docs/wiki.md) | Wiki spaces, pages, TipTap editor, versioning, comments, templates, search, API, DB schema |
| [docs/design.md](docs/design.md) | System design canvas, palette, interactions, versioning, embed, API, DB schema |
| [docs/interview.md](docs/interview.md) | Interview board, load test simulator, Yjs sync, API, DB schema |
| [docs/sheets.md](docs/sheets.md) | Sheet tracker, overlap view, subscribe/fork, API, DB schema |
| [docs/roadmap.md](docs/roadmap.md) | AI personalized roadmaps — goal-to-plan generation, catalog matching, GENERATED/DEFINED mode, API, DB schema |
| [docs/anonymous.md](docs/anonymous.md) | Public tests, anonymous attempts, API, DB schema |
| [docs/calendar-sync.md](docs/calendar-sync.md) | Opt-in Google Calendar account sync — OAuth flow, push/pull, DB schema, API, edge cases |
| [docs/ai-connector.md](docs/ai-connector.md) | AI Connector (MCP) — connect the student's own Claude/ChatGPT via OAuth 2.1+PKCE, course/notes/calendar tools, DB schema, API |
| [docs/entity-schedules-and-calendar-sync.md](docs/entity-schedules-and-calendar-sync.md) | starts_at/ends_at on batches/courses/lessons, auto-synced read-only into the in-app calendar |
| [docs/infrastructure.md](docs/infrastructure.md) | Project file structure, all env vars, AI rules, payments, SSRF denylist |
| [docs/activity.md](docs/activity.md) | Activity tracker — day-by-day timeline aggregating module/course completions, quiz attempts, MCP reflections, sheet progress, lab sessions, SM-2 reviews, API, DB schema |
| [docs/frontend-gotchas.md](docs/frontend-gotchas.md) | Non-obvious frontend bugs and regressions worth not repeating (e.g. Popover-in-Dialog scroll lock) |
| [docs/ai-pattern-learnings.md](docs/ai-pattern-learnings.md) | Shortcut patterns found in AI-written code (unthrottled endpoints, unlocked counters, unpaginated lists, trusted-input-as-validation, missing DB test infra) — updated as new instances are found, not just at the end of a review |

---

## Frontend Rules
See [frontend/CLAUDE.md](frontend/CLAUDE.md) — enforced on every frontend file. Covers design tokens, the `lib/server/api.ts` helpers, and the `ui-ux-pro-max` adapter rule — not repeated here since this file loads for backend work too.

---

## Coding Rules (Non-Negotiable)

1. **DRY** — shared logic (response helpers, role checks, AI calls) lives in one place only
2. **Complete error handling** — `fmt.Errorf("context: %w", err)` everywhere
3. **Validate inputs at boundary** — before DB or AI calls
4. **AI called once** — always check DB first, return cached result if exists
5. **Role middleware** — every protected route uses `RequireRole(...)` middleware
6. **Transactions** — multi-table writes always in a DB transaction
7. **No streaming** unless explicitly needed (predictable cost)
8. Use `TaskCreate/TaskUpdate` to track all phases

No-stubs and no-hardcoded-values are covered by the banned-patterns table below.

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

**Decision rule:** If a proper implementation would take longer, do the proper implementation. Do not ship the shortcut and plan to revisit. The shortcut becomes the implementation.

**When asked to bypass or workaround:**
- Refuse and implement the correct solution
- If the correct solution is unclear, ask the user — do not guess and patch
- If an external dependency (Redis, SMTP, etc.) is needed, wire it now, not later
