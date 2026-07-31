# Infrastructure

Project file structure, all environment variables, AI rules, payments, and security constraints for infrastructure-level concerns.

---

## Project Structure

See [README.md](../README.md)'s "Project Structure" section for the current, authoritative file tree — 37 domain packages under `backend/internal/`, generated fixtures, k8s manifests, and scripts. (An older single-package layout — `internal/db/*.go`, `internal/executor/`, `internal/ws/` — used to be documented here; it no longer matches the codebase and has been removed rather than left to drift further.)

**Next.js middleware note:** `frontend/middleware.ts` is UX-only — it redirects unauthenticated browsers to prevent a flash of protected content. It is NOT a security boundary. All role and permission enforcement happens in Go middleware (`internal/auth`, `internal/authz`).

---

## Environment Variables

The full reference lives in [README.md](../README.md)'s "Environment Variables" section (database, Redis, JWT/session, OAuth, email, server, frontend) and [auth.md](auth.md)'s (auth-specific TTLs and secrets). Variables below are infra-specific and not covered there:

```env
# LLM
LLM_PROVIDER=anthropic               # anthropic | gemini | noop — see internal/ai/
LLM_API_KEY=
LLM_MODEL_SMART=                     # revision plans, course outlines, roadmaps
LLM_MODEL_CHEAP=                     # quizzes, flashcards, error hints
LLM_RATE_LIMIT_PER_HOUR=10           # per user

# Code Execution — Piston takes priority when both are set
# Self-host Piston: https://github.com/engineer-man/piston
PISTON_URL=http://localhost:2000     # Optional — Piston self-hosted instance (preferred)
PISTON_TIMEOUT=30s                   # Optional — default 30s
JUDGE0_URL=                          # Optional — Judge0 CE endpoint (fallback)
JUDGE0_TOKEN=                        # Optional — X-Auth-Token for Judge0 cloud
JUDGE0_TIMEOUT=30s                   # Optional — default 30s

# Payments (optional) — Stripe and Razorpay can both be configured at once;
# payments.Registry (internal/payments/registry.go) registers whichever have
# a secret key set. PAYMENTS_DEFAULT_PROVIDER picks which one a checkout uses
# when the request doesn't name one explicitly (empty = whichever registers
# first). Falls back to a local stub provider when neither is configured, but
# only outside production. Each gateway's webhook secret is required the
# moment its secret key is set (fatal at startup otherwise).
STRIPE_SECRET_KEY=                  # sk_test_... / sk_live_...
STRIPE_PUBLISHABLE_KEY=
STRIPE_WEBHOOK_SECRET=              # whsec_...
RAZORPAY_KEY_ID=                    # rzp_test_... / rzp_live_...
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=
PAYMENTS_DEFAULT_PROVIDER=          # stripe | razorpay
PAYMENTS_CURRENCY=USD               # single platform currency for all course prices

# Lab sandbox runtime
LABS_RUNTIME=docker                  # docker | kubernetes
LABS_K8S_NAMESPACE=mindforge-labs    # kubernetes runtime only
LABS_WARM_POOL_GLOBAL_MAX=20         # total warm containers allowed across all labs (0 disables warming)
# LABS_IMAGE_PROFILES maps a lab environment image to a named ImageProfile
# (see internal/labs/profile.go) from the small in-code catalog built in
# cmd/server/main.go — today just "nested-docker" (Docker-in-Docker labs,
# see docs/labs.md "Nested Docker labs"). Comma-separated image:profileName
# pairs; the image itself may contain its own ":" tag — only the LAST colon
# in each entry separates the profile name. Empty/unset = no image is
# classified, every lab runs the platform's normal unelevated container.
LABS_IMAGE_PROFILES=mindforge/lab-docker:27:nested-docker,mindforge/lab-k8s:1.31:nested-docker
LABS_NESTED_DOCKER_RUNTIME=          # Optional — "sysbox-runc" switches the "nested-docker" profile's Docker mechanism (default: scoped rootless-dind)
LABS_NESTED_DOCKER_RUNTIME_CLASS=    # Kubernetes only — RuntimeClassName (e.g. "sysbox-runc"/"kata-containers") REQUIRED for any image mapped to "nested-docker" under LABS_RUNTIME=kubernetes
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
POST /api/courses/:id/enroll             free courses only — immediate enrollment, 402 if paid
POST /api/courses/:id/checkout           paid courses — creates a pending course_purchases row,
                                          opens a checkout with the requested (or default) gateway,
                                          returns a redirect URL (Stripe) or client params (Razorpay)
GET  /api/courses/:id/purchase-status    polled by the frontend return page — reflects the
                                          webhook-confirmed status, never the redirect itself
POST /api/courses/:id/coupon/preview     read-only discount preview for a coupon code
POST /api/payments/webhooks/:provider    public route, gateway-signed — the only path that ever
                                          transitions a purchase to 'completed' and enrolls the student
```

Coupons: `GET/POST /api/coupons`, `GET/PATCH/DELETE /api/coupons/:id`, gated by the
`payments.manage_coupons` permission (see [rbac.md](rbac.md)).

Access to paid course content is enforced independently of all this —
`courses.GetModuleContent` blocks non-enrolled users regardless of purchase
status, so a webhook that never arrives simply means "never enrolled," not an
access-control gap.

See [courses.md](courses.md) for the `course_purchases`/`coupons`/
`coupon_redemptions`/`payment_events` table schemas and the full
checkout → webhook → enrollment flow.
