# Infrastructure

Project file structure, all environment variables, AI rules, payments, and security constraints for infrastructure-level concerns.

---

## Project Structure

See [README.md](../README.md)'s "Project Structure" section for the current, authoritative file tree — 37 domain packages under `backend/internal/`, generated fixtures, k8s manifests, and scripts. (An older single-package layout — `internal/db/*.go`, `internal/executor/`, `internal/ws/` — used to be documented here; it no longer matches the codebase and has been removed rather than left to drift further.)

**Next.js Proxy note:** `frontend/proxy.ts` (renamed from `middleware.ts` — Next.js 16 deprecated the `middleware` convention in favor of `proxy`) is UX-only — it redirects unauthenticated browsers to prevent a flash of protected content. It is NOT a security boundary. All role and permission enforcement happens in Go middleware (`internal/auth`, `internal/authz`).

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
PAYMENTS_CURRENCY=INR               # single platform currency for all course prices (default INR).
                                    # Served to the frontend by GET /api/public/payments/config
                                    # (never mirrored into a NEXT_PUBLIC_ build var) — every
                                    # *_cents amount the API returns is in this currency's
                                    # smallest unit, and lib/money.ts formats it via Intl.
COUPON_RATE_LIMIT_MAX=10            # coupon-code attempts per user per window
COUPON_RATE_LIMIT_WINDOW=1m

# Lab sandbox runtime
LABS_RUNTIME=docker                  # docker | kubernetes
LABS_K8S_NAMESPACE=mindforge-labs    # kubernetes runtime only
LABS_WARM_POOL_GLOBAL_MAX=20         # total warm containers allowed across all images (0 disables warming)
# LABS_WARM_POOL_OVERRIDES pins or disables the warm pool for a specific
# image, overriding the automatic Little's Law sizing. The pool is shared
# platform infrastructure, so this is the ONLY way to set mode/size — there
# is deliberately no per-org write endpoint (see docs/labs.md). Format:
# comma-separated image=mode[:size], where mode is auto | fixed | off, and
# size is required for "fixed" (0..20). The image may contain its own ":"
# tag — the FIRST "=" separates image from mode. Unset = every image sizes
# automatically, which is the intended steady state. An unparseable value is
# fatal at boot rather than silently ignored.
# e.g. LABS_WARM_POOL_OVERRIDES=mindforge/lab-k8s:1.31=fixed:3,mindforge/lab-docker:27=off
LABS_WARM_POOL_OVERRIDES=
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
# Lab host / lab agent (production Docker runtime). The app host holds NO Docker
# socket: when LABS_AGENT_URL is set the backend talks to backend/cmd/labagent on
# the separate lab host over mTLS (docker-compose.labhost.yml). Unset = the
# backend shells out to the local Docker daemon (local dev compose only).
LABS_AGENT_URL=                      # https://<lab-host-private-ip>:8443 — selects the agent runtime
LABS_AGENT_CA_FILE=                  # CA that signed the agent's server cert (required with LABS_AGENT_URL)
LABS_AGENT_CERT_FILE=                # backend's client cert (required with LABS_AGENT_URL)
LABS_AGENT_KEY_FILE=                 # backend's client key (required with LABS_AGENT_URL)
LABPROXY_UPSTREAM=                   # Caddy only — labproxy host:port on the lab host (default labproxy:8081)
LABS_NETWORK_PER_SESSION=true        # default true: one Docker network per session (no sibling reachability)
LABS_NETWORK_INTERNAL=false          # true = per-session networks with no egress at all (breaks pip/npm installs)
LABS_STORAGE_QUOTA_ENABLED=false     # direct-Docker path default false; the agent defaults TRUE and refuses to start if the host cannot enforce it (XFS pquota)
# Lab agent process (backend/cmd/labagent, lab host only). It also reads
# LABS_IMAGE_PROFILES, LABS_NESTED_DOCKER_RUNTIME, LABS_PIDS_LIMIT,
# LABS_NETWORK_PER_SESSION, LABS_NETWORK_INTERNAL, LABS_PROXY_CONTAINER and
# LABS_STORAGE_QUOTA_ENABLED with the meanings above.
LABAGENT_LISTEN_ADDR=:8443           # bind to the private interface via compose port mapping
LABAGENT_TLS_CERT_FILE=              # server cert
LABAGENT_TLS_KEY_FILE=               # server key
LABAGENT_CLIENT_CA_FILE=             # CA that must have signed the backend's client cert (mTLS, required)
LABAGENT_ALLOWED_IMAGES=             # comma-separated exact image names the agent will start; anything else is a 400
# LABS_IMAGE_REGISTRY (Kubernetes runtime only) — prepended as "<registry>/<image>"
# when the Kubernetes runtime pulls a lab image; classification against
# LABS_IMAGE_PROFILES always happens on the bare name first. Empty (default) =
# images pulled bare, must already be present wherever the runtime pulls from.
# See ENV_VARS.md and docs/local-k3s-dev.md.
LABS_IMAGE_REGISTRY=

# labproxy live preview — preview subdomains are p<port>-<sessionID>.<this>
# (see backend/cmd/labproxy/host.go), one origin per port+session instead of
# the old single shared preview origin. A wildcard cert only covers one
# dynamic DNS label ("*.domain", never "*.*.domain"), which is why the port
# and session are packed into a single label instead of two path/subdomain
# segments — and a wildcard cert needs DNS-01 issuance, since HTTP-01 can't
# prove control of a wildcard name. Required; dev uses "localhost" (see
# docker-compose.dev.yml/Caddyfile.dev — *.localhost needs no DNS-01 at all).
LABPROXY_PREVIEW_DOMAIN=labs.yourdomain.com   # Required; dev uses "localhost". Must be a subdomain of DOMAIN (SameSite=Lax).
# Compose/Caddy only — Kubernetes deploys use cert-manager's DNS-01
# ClusterIssuer instead (see k8s/base/certificate-preview.yaml) and ignore
# both vars below entirely.
CADDY_DNS_PROVIDER=cloudflare                 # Required (compose only) — caddy-dns module name, see Dockerfile.caddy
CADDY_DNS_API_TOKEN=                          # Required (compose only) — zone-edit token for CADDY_DNS_PROVIDER
```

### Lab proxy isolation (audit C4)

labproxy runs on the lab network and must not be able to forge login tokens or read the app DB:

- `LAB_TOKEN_SECRET` (backend + labproxy, min 32 bytes) signs lab ws-tokens and derives the per-session ttyd/IDE credentials. The backend refuses to start if it is empty or equal to `JWT_SECRET`. labproxy never receives `JWT_SECRET` (`LABPROXY_JWT_SECRET` is gone).
- `LABPROXY_DB_URL` must use the `labproxy` role created (NOLOGIN) by `001_baseline.sql` (end of file): `SELECT` on `lab_sessions`, `lab_definitions`, `lab_build_variants` and `UPDATE(last_active_at)` on `lab_sessions` only. Enable it once per environment, out of band:
  `ALTER ROLE labproxy LOGIN PASSWORD '<value from secrets store>';` then set `LABPROXY_DB_URL=postgres://labproxy:<password>@<host>/<db>` (compose prod: `LABPROXY_DB_PASSWORD`).
- `LABS_SNIPPET_DAILY_LIMIT` (backend, default 200) caps `POST /api/labs/run` executions per user per rolling 24h (Redis, 429 when exceeded).
- Per-user terminal cap (5) is global across labproxy replicas via the Redis semaphore (`labproxy:conns:<user>` leases, 30s TTL, auto-renewed).

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
- `PUBLIC_RATE_LIMIT_MAX` / `PUBLIC_RATE_LIMIT_WINDOW` — per-IP budget on unauthenticated routes (`/oauth/*`, `/mcp`, `/api/p/`, `/api/public/`, `/api/certificates/`, `/api/invitations/`, the ICS feed) (default 120 / 1m)
- `OAUTH_REGISTER_RATE_LIMIT_MAX` / `_WINDOW` — dynamic client registration `/oauth/register` (default 10 / 1h)
- `USER_RATE_LIMIT_MAX` / `USER_RATE_LIMIT_WINDOW` — per-user budget on every authenticated route (default 600 / 1m)
- `LLM_USER_MAX_PER_HOUR` / `LLM_USER_MAX_PER_DAY` — per-user LLM call caps, enforced by `ai.QuotaProvider` wrapping the provider so every AI feature shares one budget; exceeding it returns `429` (default 60 / 300)
- `COUPON_RATE_LIMIT_MAX` / `COUPON_RATE_LIMIT_WINDOW` — coupon-code attempts on
  `/coupon/preview` and `/checkout` (default 10 / 1m). Keyed **per user**, not per IP:
  browser-facing calls all arrive from the Next.js server on one address, so an IP-keyed
  limit would let one attacker exhaust the budget for the entire user base.
- `ANALYTICS_RATE_LIMIT_MAX` / `ANALYTICS_RATE_LIMIT_WINDOW` — per-user budget on the analytics endpoints (default 60 / 1m); the queries aggregate a whole course's enrollment.

---

## Data Retention

The `retention.purge` job (`internal/jobs/handlers/retention_purge.go`, DPDP s.8(7)) deletes old rows, each class in its own transaction so one failure does not block the others. A window of `0` disables that class.

| Class | Env | Default |
|---|---|---|
| Audit logs (non-MCP) | `RETENTION_AUDIT_DAYS` | 730 |
| MCP action log | `RETENTION_MCP_ACTION_DAYS` | 180 |
| `auth_events` | `RETENTION_AUTH_EVENTS_DAYS` | 365 |
| Assessment `attempt_events` (proctoring) | `RETENTION_ATTEMPT_EVENTS_DAYS` | 730 |
| `xp_events` | `RETENTION_XP_EVENTS_DAYS` | 730 |
| Lab AI interactions | `RETENTION_LAB_AI_DAYS` | 180 |
| Public-test candidate name/email/phone (nulled, attempt kept) | `RETENTION_PUBLIC_CANDIDATES_DAYS` | 180 |
| Revoked / refresh-expired `mcp_connections` | `RETENTION_MCP_CONNECTION_DAYS` | 90 |
| Expired MCP auth codes and access tokens | fixed: past `expires_at` | - |

Audit trails default to at least the 180-day CERT-In log minimum.

## Object storage lifecycle (Backblaze B2)

Uploads use S3 POST policies (`/api/upload/*`), so abandoned or orphaned objects accumulate unless the bucket expires them. There is no IaC in this repo; apply once per bucket (B2 console > Bucket Settings > Lifecycle Settings, or `b2 bucket update --lifecycle-rules`):

```json
[
  {"fileNamePrefix": "", "daysFromUploadingToHiding": null, "daysFromHidingToDeleting": 1},
  {"fileNamePrefix": "tmp/", "daysFromUploadingToHiding": 2, "daysFromHidingToDeleting": 1}
]
```

- Incomplete multipart/large-file uploads: B2 keeps unfinished large files (and bills for their parts) until they are cancelled; add a lifecycle rule that aborts them (S3 API: `AbortIncompleteMultipartUpload` with `DaysAfterInitiation: 2`) so half-finished uploads stop billing.
- Hidden (deleted/overwritten) versions are purged 1 day after hiding (first rule), so deletes by the app actually free space.
- Orphans: objects uploaded but never attached to a row (staging prefix `tmp/` if used) expire after 2 days. Durable prefixes (`courses/`, `captures/`, `certificates/`) must never get an upload-age expiry rule: only the hide-then-delete rule applies to them.

## Payment reversals

Gateway refund and dispute events (`charge.refunded`, `charge.dispute.created`, Razorpay `refund.processed` and `payment.dispute.created`) reverse a purchase. Course purchases revoke the enrollment and release the coupon redemption. Credit-pack purchases claw back unspent credits through a `purchase_reversal` ledger entry capped at the current balance (the ledger never goes negative); credits already spent are the shortfall, recorded in the ledger note and `purchases.granted.reversal_shortfall`. Both are idempotent (guarded status transition) and set `purchases.status='refunded'`. Admin refunds first persist `status='refunding'` before calling the gateway, so a crash mid-way leaves a retryable row instead of a refunded charge marked `completed`. Pack refund: `POST /api/session-booking/purchases/{purchaseID}/refund` (`payments.manage_refunds`). A webhook that fails internally answers non-2xx and keeps the event unprocessed so the gateway's redelivery re-runs it; `ReconcilePayments` alerts on anything still pending or unprocessed past `PAYMENT_RECONCILE_STALE_MINUTES`.

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

## Observability

Structured logging is `log/slog` throughout (no separate setup — every package logs directly).

Metrics are Prometheus (`internal/metrics`):

- `GET /metrics` on the backend — request counters/latency histograms (by method + chi route pattern, not raw path, so per-user IDs don't blow up cardinality) and job counters/latency histograms (by handler + final status), fed from `internal/jobs`' worker pool.
- Protected by `METRICS_TOKEN`: Prometheus must send it as `Authorization: Bearer <token>`. With the token unset, `/metrics` is open outside production and answers `404` in production, so a missing secret can never expose it. Not proxied by Caddy (only `/api/*` is — see `Caddyfile`).
- `prometheus.yml` + the `prometheus` service in `docker-compose.dev.yml`/`docker-compose.prod.yml` scrape it on a 15s interval. No published port by default (same pattern as `adminer`) — use `docker compose port prometheus 9090` for a temporary local tunnel.

Dashboards are Grafana (`grafana` service in both compose files), provisioned automatically from `grafana/provisioning/` (Prometheus datasource) and `grafana/dashboards/mindforge-overview.json` (request rate/latency/5xx, job run rate by handler+status, job duration p95) — no manual setup needed after `compose up`. Also no published port; tunnel the same way as Prometheus. Dev login is `admin`/`admin`; prod reads the password from `GRAFANA_ADMIN_PASSWORD` (see `ENV_VARS.md`).

No alerting configured yet — add Grafana alert rules against the same Prometheus datasource when that's actually needed.

No distributed tracing — this is a single Go monolith, not multiple services calling each other, so span-level tracing has little payoff today. Revisit if the architecture actually splits into separate services.

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

## Self-host host-root hardening (audit H-10)

`docker-compose.prod.yml`:

- The backend image runs as non-root (`USER 10001`) and no longer mounts `/var/run/docker.sock`. It reaches Docker through the `docker-proxy` service (tecnativa/docker-socket-proxy) over the internal-only `mindforge_dockerapi` network (`DOCKER_HOST=tcp://docker-proxy:2375`), with only the CONTAINERS, EXEC, NETWORKS, IMAGES and POST API groups enabled.
- **Residual risk (not solved):** the proxy filters by API path/method, not request body. A compromised backend can still call `containers/create` with `Privileged` or host bind mounts, which is host root. This reduces the surface (no volumes/swarm/secrets/build/info APIs) but is not a boundary; the real fix is running labs on a separate runner host or the Kubernetes runtime (`LABS_RUNTIME=kubernetes`).
- **Piston stays `privileged: true`.** Its isolate sandbox needs cgroup/namespace/mount privileges and cannot run unprivileged; there is no safe alternative short of a VM/gVisor runtime. Mitigation applied: Piston is on its own `mindforge_piston` network shared only with the backend, so it has no network path to Postgres, Redis or MinIO.
- `docker-compose.dev.yml` still mounts the socket into the backend (dev only; not changed).
- New env: `LABS_PIDS_LIMIT`, `LABS_NETWORK_PER_SESSION`, `LABS_NETWORK_INTERNAL`, `LABS_PROXY_CONTAINER`, `MAX_BODY_BYTES` (default 8 MiB cap on non-multipart bodies), `LABPROXY_ALLOWED_ORIGINS` (required by labproxy).
- `POST /api/upload/course-asset` now returns `upload_url` plus `upload_fields` (S3 POST policy: pinned key, content type, 1..2 GiB); clients must POST multipart form with those fields then a `file` part last. No frontend code called it.

