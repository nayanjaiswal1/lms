# Infrastructure

Project file structure, all environment variables, AI rules, payments, and security constraints for infrastructure-level concerns.

---

## Project Structure

```
mindforge/
├── CLAUDE.md
├── .env.example
├── docker-compose.yml
├── Makefile
│
├── backend/                         ← Go 1.26.4
│   ├── go.mod
│   ├── cmd/server/main.go
│   └── internal/
│       ├── config/config.go
│       ├── llm/
│       │   ├── llm.go               ← Provider interface
│       │   ├── openai.go
│       │   └── anthropic.go
│       ├── db/
│       │   ├── db.go                ← pgxpool
│       │   ├── migrate.go
│       │   ├── migrations/001_schema.sql
│       │   ├── models.go
│       │   ├── users.go
│       │   ├── auth.go
│       │   ├── orgs.go
│       │   ├── courses.go
│       │   ├── modules.go
│       │   ├── enrollments.go
│       │   ├── progress.go
│       │   ├── coding.go
│       │   ├── quiz.go
│       │   ├── cards.go
│       │   ├── mentors.go
│       │   ├── revision.go
│       │   ├── certificates.go
│       │   ├── wiki.go
│       │   ├── designs.go
│       │   ├── interviews.go
│       │   └── load_tests.go
│       ├── srs/sm2.go               ← pure SM-2, no DB
│       ├── ws/
│       │   └── interview.go         ← WebSocket hub (Yjs relay)
│       ├── loadtest/
│       │   └── runner.go            ← async HTTP load generator
│       ├── executor/
│       │   ├── executor.go          ← interface: Execute(code, lang, tests) → Result
│       │   └── docker.go            ← server-side sandbox for Go/Java/C++
│       ├── middleware/
│       │   ├── auth.go              ← JWT parse → jti_blocklist → session_version → set context
│       │   ├── role.go              ← RequireRole(roles...) middleware
│       │   └── tenant.go            ← resolve org context from JWT claims
│       └── api/
│           ├── router.go
│           ├── respond.go
│           ├── auth.go
│           ├── oauth.go
│           ├── password.go
│           ├── orgs.go
│           ├── courses.go
│           ├── modules.go
│           ├── enrollments.go
│           ├── progress.go
│           ├── code.go
│           ├── quiz.go
│           ├── cards.go
│           ├── mentors.go
│           ├── revision.go
│           ├── certificates.go
│           ├── wiki.go
│           ├── designs.go
│           ├── interviews.go
│           └── load_tests.go
│
└── frontend/                        ← Next.js 16.2.9
    ├── package.json
    ├── tsconfig.json
    ├── next.config.ts
    ├── middleware.ts                 ← UX-only route protection (see note below)
    ├── app/
    │   ├── globals.css
    │   ├── layout.tsx
    │   ├── page.tsx
    │   ├── (auth)/login/page.tsx
    │   ├── (auth)/register/page.tsx
    │   ├── (auth)/forgot-password/page.tsx
    │   ├── (auth)/reset-password/page.tsx
    │   ├── (auth)/verify-email/page.tsx
    │   ├── (auth)/org-select/page.tsx
    │   ├── dashboard/page.tsx
    │   ├── courses/
    │   ├── review/page.tsx
    │   ├── certificates/[uuid]/page.tsx
    │   ├── sheets/
    │   ├── mentor/
    │   ├── instructor/
    │   ├── interview/
    │   ├── load-test/page.tsx
    │   ├── design/
    │   └── wiki/
    ├── lib/
    │   ├── types.ts
    │   ├── api.ts
    │   ├── auth.ts
    │   ├── routes.ts
    │   └── utils.ts
    └── components/
        ├── ui/                      ← shadcn primitives
        ├── shared/
        ├── auth/
        ├── layout/
        ├── course/
        ├── editor/
        ├── sheets/
        ├── quiz/
        ├── review/
        ├── mentor/
        ├── interview/
        ├── load-test/
        ├── design/
        └── wiki/
```

**Next.js middleware note:** `middleware.ts` is UX-only — it redirects unauthenticated browsers to prevent a flash of protected content. It is NOT a security boundary. All role and permission enforcement happens in Go middleware (`middleware/auth.go`, `middleware/role.go`).

---

## Environment Variables

```env
# Server
PORT=8080
WS_PORT=8081
DATABASE_URL=postgres://mindforge:mindforge@localhost:5432/mindforge?sslmode=disable
FRONTEND_URL=http://localhost:3000

# Auth secrets — app exits on startup if unset, matches 'change-me' default, or under 32 bytes
JWT_SECRET=change-me-to-a-long-random-string
COOKIE_SECRET=change-me-to-a-long-random-string
ENCRYPTION_KEY=change-me-32-byte-key

# Auth token TTLs
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=720h              # 30 days
PASSWORD_RESET_TTL=30m
EMAIL_VERIFICATION_TTL=24h
MAGIC_LINK_TTL=10m
INVITE_TTL=168h                     # 7 days

# Social OAuth (optional; enable per-provider)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
MICROSOFT_CLIENT_ID=
MICROSOFT_CLIENT_SECRET=

# Geo / impossible-travel (optional)
MAXMIND_DB_PATH=./GeoLite2-City.mmdb

# LLM
LLM_PROVIDER=openai                 # openai | anthropic
LLM_BASE_URL=https://api.openai.com/v1
LLM_API_KEY=sk-...
LLM_MODEL_SMART=gpt-4o             # revision plans, course outlines
LLM_MODEL_CHEAP=gpt-4o-mini        # quizzes, flashcards, error hints
LLM_RATE_LIMIT_PER_HOUR=10         # per user

# Code Execution — Piston takes priority when both are set
# Self-host Piston: https://github.com/engineer-man/piston
PISTON_URL=http://localhost:2000     # Optional — Piston self-hosted instance (preferred)
PISTON_TIMEOUT=30s                   # Optional — default 30s
JUDGE0_URL=                          # Optional — Judge0 CE endpoint (fallback)
JUDGE0_TOKEN=                        # Optional — X-Auth-Token for Judge0 cloud
JUDGE0_TIMEOUT=30s                   # Optional — default 30s

# Payments (optional)
PAYMENT_PROVIDER=stripe             # stripe | razorpay
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Frontend
NEXT_PUBLIC_API_URL=http://localhost:8080   # used in browser; for server-to-server use API_URL
API_URL=http://localhost:8080               # server-only; internal hostname in prod
NEXT_PUBLIC_ENABLE_PAYMENTS=false
```

---

## AI Usage Rules

**AI is called ONCE per artifact. Stored forever. Never auto-regenerated.**

| Action | AI Called? | Model Tier | Stored In |
|---|---|---|---|
| Generate revision plan | Yes | Smart | `revision_plans` |
| Generate module quiz | Yes | Cheap | `quizzes` |
| Generate flashcards | Yes | Cheap | `cards` |
| Generate course outline (instructor) | Yes | Smart | stored with course |
| Explain a coding error (on demand) | Yes | Cheap | Not stored |
| Student opens lesson | No | — | Served from DB |
| Student opens quiz again | No | — | Served from DB |
| Any anonymous attempt | No | — | Cost control |

Provider swap without code changes: change `LLM_PROVIDER` + keys. The `llm.go` interface abstracts both OpenAI-compat and Anthropic.

Spaced repetition (SM-2): pure math — no AI.

---

## Rate Limiting

**Implementation:** `internal/middleware/ratelimit.go`

**Strategy:** Sliding window per client IP per URL path.

| Layer | When active | Accounting |
|---|---|---|
| Redis sorted set (primary) | Redis reachable | Global across all replicas |
| In-process sliding window (fallback) | Redis unreachable | Per-replica — still limits, doesn't bypass |

**Why sliding window over fixed window:**
- Fixed window allows 2× burst at the window boundary (attack sends `max` requests at end of window, then `max` more at the start of the next)
- Sliding window counts requests in the trailing `window` duration — no boundary exploitation

**Why Lua script:**
- `INCR` + `EXPIRE` are two separate commands — if `EXPIRE` fails, the key has no TTL and becomes a permanent counter
- The Lua script runs `ZREMRANGEBYSCORE` + `ZCARD` + `ZADD` + `PEXPIRE` atomically

**Response headers on 429:**
- `Retry-After: <seconds>` — tells clients when they can retry

**Current limits** (configured via env):
- `AUTH_RATE_LIMIT_MAX` — max requests per window on `/api/auth/*` (default 10)
- `AUTH_RATE_LIMIT_WINDOW` — window duration (default 1m)

---

## Type Sync (Go → TypeScript)

Keep frontend types in sync with backend Go structs. Prevents drift without manual duplication.

**Tool:** `tygo` — reads Go source, outputs TypeScript interfaces.

**Config:** `backend/tygo.yaml` — covers 7 packages: assessment, courses, practice, profile, srs, orgs, authz.

**Output:** `frontend/types/generated/*.ts` — each file has a `// Code generated` header.

**Run:**
```bash
./scripts/gen-types.sh     # installs tygo if missing, generates all types
```

Re-run whenever you add or change a Go model that the frontend needs. Generated files are committed to the repo.

---

## Load Test SSRF Denylist

All URLs submitted to `POST /api/load-tests` are validated server-side:

1. Parse URL — reject any scheme that is not `http` or `https`
2. Resolve hostname to all IP addresses
3. Reject if any resolved IP falls in:
   - `127.0.0.0/8` (loopback)
   - `10.0.0.0/8` (RFC 1918)
   - `172.16.0.0/12` (RFC 1918)
   - `192.168.0.0/16` (RFC 1918)
   - `169.254.0.0/16` (link-local / cloud metadata — AWS, GCP, Azure, DigitalOcean)
   - `::1` (IPv6 loopback)
   - `fc00::/7` (IPv6 ULA)
   - `fe80::/10` (IPv6 link-local)
   - `0.0.0.0`
4. Pin the HTTP client to the validated IP (no re-resolution on connect)
5. Disable or re-validate on every redirect — redirecting to internal addresses is a bypass vector

---

## Payments

```
POST /api/courses/:id/enroll    free: immediate enrollment
                                paid: creates payment intent → returns client_secret to frontend
                                frontend completes payment with Stripe/Razorpay SDK
                                webhook: on payment success → update payment status + enroll user
```

See `courses.md` for the `payments` table schema.
