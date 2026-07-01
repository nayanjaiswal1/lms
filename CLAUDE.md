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

**Subagents:** set `model: "haiku"` for read-only research agents, `model: "sonnet"` for implementation agents, `model: "opus"` for architecture/security agents. Never let subagents inherit the default implicitly.

**Advisor Strategy for Opus tasks:** Opus plans and reviews — Sonnet executes. Never use Opus to write bulk code. Ask Opus for the approach and risks first, then switch to Sonnet to implement, then optionally return to Opus for final review of critical paths (auth, payments, data integrity).

**Context protection via subagents:** Spin a Haiku subagent (not inline tools) when a task would flood the main conversation — searching 3+ files, grepping large output, auditing a spec. Ask for a concise summary back, not raw output. This keeps the main context lean for the actual implementation work.

**Parallel agents for phase builds:** When building a full phase, spawn independent work in parallel — one Sonnet agent for Go handlers, one for sqlc queries, one for frontend components. They share no state during writing, so all three run simultaneously. Wall-clock time drops 60–80%. Only run sequentially when Agent B needs Agent A's output.

**Gemini CLI (escape hatch only):** Use `!gemini review mindforge/backend/internal/<module>/` inside the chat when you need a second opinion on a critical path or need to dump a large module into Gemini's 2M-token context. Gemini does not know your CLAUDE.md rules — use it for spot-checks, then ask Claude to apply the valid suggestions.

---

## Custom Skills (Slash Commands)

Run these in the Claude Code chat. They live in `.claude/commands/`.

| Command | What it does |
|---|---|
| `/go-endpoint` | Scaffold a complete Go endpoint: Chi route + handler + sqlc queries + migration + integration test |
| `/fe-component` | Scaffold a complete Next.js component following MindForge conventions (server/client, shadcn, tokens, responsive) |
| `/phase-status` | Read docs + git log and report what's done, what's in-progress, and what's next for the current phase |
| `/frontend-design` | Official Anthropic skill — aesthetic direction, typography, intentional visual choices before writing code |
| `/ui-ux-pro-max` | Design intelligence: UX guidelines, accessibility checklist, interaction patterns, spacing, chart types |

### ui-ux-pro-max adapter rule (MindForge only)
When `/ui-ux-pro-max` suggests colors, typography, or a design system — **ignore those and use MindForge's existing tokens** (`--primary`, `--ai`, `bg-background`, etc. from `globals.css`). Use it only for: UX patterns, accessibility rules, interaction timing, spacing rhythm, layout composition, chart selection, and the pre-delivery checklist. MindForge's design system is already defined — the skill adds UX intelligence on top, not a replacement palette.

To query the skill's knowledge base directly:
```bash
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "dashboard learning edtech" --design-system --stack nextjs
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "progress charts" --domain chart
python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "form validation" --domain ux
```

---

## MCP Servers for MindForge

| Server | Why you need it |
|---|---|
| `@modelcontextprotocol/server-postgres` | Query the local Docker PostgreSQL directly — inspect schema, validate migrations, debug data issues without leaving Claude |
| `@upstash/context7-mcp` | Pulls real-time Next.js 16 / React 19 / Go docs from source — prevents Claude from suggesting deprecated APIs |
| `@modelcontextprotocol/server-github` | Create PRs, review diffs, manage issues from inside Claude Code sessions |

---

## Hooks for MindForge

Add to `dream/.claude/settings.json` (project-level, not global):

```json
"hooks": {
  "PostToolUse": [{
    "matcher": "Write|Edit",
    "hooks": [{ "type": "command", "command": "bash mindforge/.claude/hooks/post-edit.sh" }]
  }],
  "SessionStart": [{
    "hooks": [{ "type": "command", "command": "echo 'MindForge: go vet runs after .go edits | pnpm tsc runs after .ts edits'" }]
  }]
}
```

`post-edit.sh` logic: read stdin → get `file_path` → if `.go` run `go vet ./...` in backend → if `.ts/.tsx` run `pnpm tsc --noEmit` in frontend. Claude sees the output immediately and self-corrects before moving to the next file.

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
| [docs/orgs.md](docs/orgs.md) | Organizations, members, roles, API, DB schema |
| [docs/wiki.md](docs/wiki.md) | Wiki spaces, pages, TipTap editor, versioning, comments, templates, search, API, DB schema |
| [docs/design.md](docs/design.md) | System design canvas, palette, interactions, versioning, embed, API, DB schema |
| [docs/interview.md](docs/interview.md) | Interview board, load test simulator, Yjs sync, API, DB schema |
| [docs/sheets.md](docs/sheets.md) | Sheet tracker, overlap view, subscribe/fork, API, DB schema |
| [docs/anonymous.md](docs/anonymous.md) | Public tests, anonymous attempts, API, DB schema |
| [docs/infrastructure.md](docs/infrastructure.md) | Project file structure, all env vars, AI rules, payments, SSRF denylist |

---

## Frontend Rules
See [frontend/CLAUDE.md](frontend/CLAUDE.md) — enforced on every frontend file.

---

## Frontend API Helpers — `lib/server/api.ts`

All server-side fetch calls go through helpers in `lib/server/api.ts`. Never write raw `fetch()` calls with manual auth headers in actions or server components.

| Helper | Use case |
|---|---|
| `apiGet<T>(path)` | Server component reads — throws on error, propagates to `error.tsx` |
| `apiPost<T>(path, payload)` | Server component one-shot POSTs — throws on error |
| `apiAction<T>(method, path, payload?)` | Server actions — returns `ActionResult<T>`, never throws |
| `apiUpload<T>(path, formData)` | Multipart file uploads — returns `ActionResult<T>`, omits `Content-Type` so the browser sets the correct multipart boundary |

**Rule:** `export type { ActionResult }` must never appear in a `"use server"` file. Next.js registers every export in a server action module as a server reference at runtime. TypeScript erases type-only exports, leaving a missing reference that crashes the page. Import `ActionResult` directly from `@/lib/server/api` wherever the type is needed.

**File upload pattern:**
```ts
// In a "use server" actions file:
export async function uploadAssetAction(formData: FormData): Promise<ActionResult<{ url: string; storage_key: string }>> {
  return apiUpload<{ url: string; storage_key: string }>("/api/upload", formData);
}

// In a client component:
const fd = new FormData();
fd.append("file", file);
const res = await uploadAssetAction(fd);
```

---

## Coding Rules (Non-Negotiable)

1. **DRY** — shared logic (response helpers, role checks, AI calls) lives in one place only
2. **No stubs** — every file written is complete and production-ready, no `// TODO`
3. **No hardcoded values** — all config from env vars, all strings from constants
4. **Complete error handling** — `fmt.Errorf("context: %w", err)` everywhere
5. **Validate inputs at boundary** — before DB or AI calls
6. **AI called once** — always check DB first, return cached result if exists
7. **Role middleware** — every protected route uses `RequireRole(...)` middleware
8. **Transactions** — multi-table writes always in a DB transaction
9. **No streaming** unless explicitly needed (predictable cost)
10. Use `TaskCreate/TaskUpdate` to track all phases

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
