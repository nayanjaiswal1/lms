# Environment Variables

Full rationale for every variable across the project's `.env*` files. The files
themselves only carry the variable, a Required/Optional tag, and its default —
the "why" lives here so the `.env*` files stay short and scannable.

## Files

| File | Read by | Committed? |
|---|---|---|
| `.env` | `docker-compose.dev.yml` | No (gitignored) |
| `.env.example` | — template for `.env` | Yes |
| `.env.prod.example` | — template for `.env.prod`, used by `docker-compose.prod.yml` | Yes |
| `backend/.env` | Go server run outside Docker | No (gitignored) |
| `backend/.env.example` | — template for `backend/.env` | Yes |
| `frontend/.env.local` | Next.js dev server / frontend container | No (gitignored) |
| `frontend/.env.example` | — template for `frontend/.env.local` | Yes |

`backend/.env.example` is a subset of the root `.env.example` — just the vars
the Go server itself reads, for running it standalone outside docker-compose.
The root file is the authoritative full reference.

---

## Database

Credentials used by both docker-compose (to create the Postgres container) and
the Go backend (`DATABASE_URL`, via pgx/v5) to connect. `POSTGRES_*` and
`DATABASE_URL` must match — `DATABASE_URL` is the full DSN built from the same
values. In prod, Postgres runs inside Docker with no external port exposure.

## Redis

No password in dev — Redis runs with `--save ""` (no persistence). In
production, `REDIS_PASSWORD` sets `--requirepass` and must also be embedded
into `REDIS_URL` as `redis://:<REDIS_PASSWORD>@host:6379/0`.

## Code Execution (Piston / Judge0)

Optional — coding-question auto-grading. Piston takes priority when both
`PISTON_URL` and `JUDGE0_URL` are set; Judge0 is the fallback. When neither is
set, coding answers are left pending for manual grading (MCQ auto-grading is
unaffected). Self-host: [Piston](https://github.com/engineer-man/piston), or a
self-hosted Judge0 CE.

## JWT / Session

`JWT_SECRET`, `COOKIE_SECRET`, `ENCRYPTION_KEY` must each be at least 32 bytes
of random data — generate with `openssl rand -hex 32`. In production all three
must additionally differ from the dev values. `ENCRYPTION_KEY` must be exactly
32 bytes (AES-256-GCM). Token lifetimes use Go duration format (`15m`, `1h`,
`720h`).

## Tenant

`DEFAULT_ORG_ID` is the org self-registered users are assigned to — seeded in
migration `001_init.sql`. Do not change this UUID unless you reseed.

## OAuth

Create OAuth apps at the [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
and [GitHub Developer Settings](https://github.com/settings/developers). Leave
a provider's client ID/secret blank to disable it. Callback URLs must be
registered exactly:
- Dev: `http://localhost:3000/api/auth/{google,github}/callback`
- Prod: `https://<domain>/api/auth/{google,github}/callback`

`FRONTEND_URL` is the redirect target after the OAuth callback, and also
derives the WebAuthn RPID/RPOrigin (see the dev-tunnel note below).

## Email (SMTP)

Dev: use [Mailpit](https://github.com/axllent/mailpit)
(`docker run -p 1025:1025 -p 8025:8025 axllent/mailpit`, then
`SMTP_HOST=localhost SMTP_PORT=1025`) or Mailtrap. Prod: use a transactional
provider (Postmark, Resend, SendGrid, SES) — e.g. Postmark is
`SMTP_HOST=smtp.postmarkapp.com SMTP_PORT=587`. `EMAIL_FROM` must be verified
with the provider in prod.

`DEV_EMAIL_ALLOWLIST` (backend only) is a comma-separated list of recipients
that get real email even when `ENV=development`; every other address just
logs to stdout (`DEV EMAIL: ...`).

## Server

`ENV` must be `development`, `staging`, or `production` — `production` enables
the Secure cookie flag and strict logging.

## Frontend

`NEXT_PUBLIC_*` values are embedded in the browser bundle at build time —
never put secrets in them. `BACKEND_URL` is server-to-server only (not in the
browser bundle).

Root `.env`: the `NEXT_PUBLIC_*` vars here are docker-compose *build args* for
the frontend image (`docker-compose.dev.yml` frontend `build.args`) — they
must live here, not just in `frontend/.env.local`, since they're inlined into
the client bundle at build time. Keep them in sync with `frontend/.env.local`.
Same split in prod (`docker-compose.prod.yml`).

`frontend/.env.local`: `NEXT_PUBLIC_API_URL` is deliberately left empty for
the single-Caddy-origin dev setup — the browser calls the API same-origin
(`${API}/api/...` in `lib/client/api.ts` resolves to `/api/...`), and
`Caddyfile.dev`'s `/api/*` rule routes it to the backend. Only set it to a
real absolute origin for a tunnel/another-device setup.

`MCP_PUBLIC_URL` is the AI Connector (MCP) public URL shown on
Settings → Integrations — must match `backend/.env`'s `MCP_PUBLIC_URL`.

`NEXT_PUBLIC_MEDIA_URL` must match the backend's `MINIO_PUBLIC_ENDPOINT`.

`NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED` / `NEXT_PUBLIC_GITHUB_OAUTH_ENABLED` only
control social-login button visibility (enabled/disabled/grayed-out) — they
don't carry the actual client ID (not needed client-side; the button just
links to `/api/auth/<provider>`). Set to `"true"` only once the matching
`GOOGLE_CLIENT_ID`/`GITHUB_CLIENT_ID` + secret are set in `backend/.env`.

`ANTHROPIC_API_KEY` — server-side only, used for resume parsing (never
exposed to the browser).

## Payments (Stripe / Razorpay)

Each gateway is independently optional — `payments.Registry.FromConfig`
registers whichever has a secret key set. `PAYMENTS_DEFAULT_PROVIDER` picks
which one `StartCheckout` uses when a request doesn't name one explicitly
(empty = whichever registered first). When neither gateway is configured,
checkout falls back to a local stub provider — **never in production**. A
gateway's webhook secret (`STRIPE_WEBHOOK_SECRET` / `RAZORPAY_WEBHOOK_SECRET`)
is **required the moment its secret key is set** — startup fails otherwise,
since a checkout that can charge but never confirm is worse than one that's
simply absent.

No `NEXT_PUBLIC_*` key is needed: Stripe uses a hosted Checkout redirect and
Razorpay's client key flows through the checkout API response — neither
reaches the browser bundle directly.

`PAYMENTS_CURRENCY` is the single platform currency all course prices are
charged in (default USD at the root/prod level, INR in `backend/.env.example`
— a Razorpay account must have the chosen currency enabled; INR by default).
Every `*_cents` amount in the API is this currency's smallest unit (paise for
INR), matching what both gateways expect on the wire.

`COUPON_RATE_LIMIT_MAX` / `COUPON_RATE_LIMIT_WINDOW` (backend only) — coupon-
code attempts per user per window, a brute-force guard against guessable
discount codes.

## Object Storage (MinIO) — prod only

Runs inside Docker with no external port exposure — reached internally by the
backend, and by browsers via Caddy, which proxies the bucket path so
presigned URL signatures (signed against `MINIO_PUBLIC_ENDPOINT`) stay valid.
`MINIO_ACCESS_KEY`/`MINIO_SECRET_KEY` must match
`MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`. `MINIO_PUBLIC_ENDPOINT` must match
`DOMAIN` (no scheme, no port). `MINIO_BUCKET` must match the bucket path in
the Caddyfile.

Dev's `backend/.env` MinIO block: `MINIO_ENDPOINT` is the Docker-network
hostname the backend container uses to reach MinIO; `MINIO_PUBLIC_ENDPOINT`
is what gets baked into URLs returned to the browser and must be reachable
from the host machine. MinIO doesn't publish its own port in dev — this
points at Caddy's port-80 `/mindforge/*` proxy (`Caddyfile.dev`) instead of
`:9000` directly; the bucket name happens to match that proxy prefix.

## Labs (terminal sandbox relay / labproxy)

`labproxy` is a separate service/binary (`cmd/labproxy`). `LABPROXY_JWT_SECRET`
must equal the main server's `JWT_SECRET` — the backend mints lab session
tokens that labproxy verifies. In prod, `LABPROXY_DB_URL`/`LABPROXY_REDIS_URL`
mirror `DATABASE_URL`/`REDIS_URL`.

### Nested Docker-in-Docker (`backend/.env` dev example)

Off by default — an empty `LABS_NESTED_DOCKER_RUNTIME` means the feature
doesn't exist on that deploy. Must ALSO be in each org's
`lab_org_config.allowed_images` to actually be usable — see `docs/labs.md`
"Nested Docker labs". `config.go` reads `LABS_IMAGE_PROFILES` (not
`LABS_NESTED_DOCKER_IMAGES` — that key was never read by anything, which was
the historical reason nested-Docker labs never provisioned: every such
session silently ran with the ordinary `--cap-drop ALL`/no-new-privileges
config instead of the elevated one rootless dind needs, and always failed).

`mindforge/lab-docker-sysbox:27` can be mapped in `LABS_IMAGE_PROFILES` so the
profile exists the moment a lab environment references it, but it stays inert
unless `LABS_NESTED_DOCKER_RUNTIME=sysbox-runc` is also set on a host that
actually has sysbox-runc installed — otherwise `buildRunArgs` still emits the
rootless-dind grant for every nested-docker image regardless of which one a
course points at, which would run the sysbox image under the wrong mechanism
and fail. Docker Desktop cannot run sysbox-runc at all (see `docs/labs.md`) —
only a real Docker Engine host can.

## LLM Provider

Optional — leave `LLM_PROVIDER=disabled` to skip AI features entirely (course
generation, revision plans, hints). Fatal at startup if
`LLM_PROVIDER != disabled` and `LLM_API_KEY` is empty.

### Nightly AI Revision Digest cost caps (backend only)

`LLM_COST_INPUT_PER_MTOK`/`LLM_COST_OUTPUT_PER_MTOK` default to Gemini 2.5
Flash list rates. At ~3k input + ~800 output tokens/digest that's
~$0.003/digest, so the `DIGEST_USER_MONTHLY_BUDGET_USD`/
`DIGEST_GLOBAL_MONTHLY_BUDGET_USD` defaults are a runaway guard (~170 digests
of headroom per user), not rationing — raise or lower per deployment via env,
no code change needed.

## Domain (prod only)

`DOMAIN` is used by Caddy to obtain a TLS certificate via ACME (Let's
Encrypt) — must be a real domain with DNS already pointing at the server
before deploying.

## Backups (prod only)

Used by `scripts/backup-prod.sh` / `scripts/restore-prod.sh`.
`BACKUP_ALERT_WEBHOOK` is a Slack/Discord/generic incoming-webhook URL posted
to if a backup or restore run fails.

## Dev tunnel note (`backend/.env` example)

`FRONTEND_URL` doubles as the tunnel URL: a Caddy container (`Caddyfile.dev`)
fronts the frontend, this backend (including `/oauth`, `/.well-known`,
`/mcp`, not just `/api/*`), MinIO, and labproxy behind one origin/port (only
Caddy publishes a host port in `docker-compose.dev.yml`), so the whole app is
reachable from another device through the tunnel. This also changes the
WebAuthn RPID/RPOrigin (derived from `FRONTEND_URL`) and the CORS-allowed
origin — expected, not a bug: any passkey registered under the old
`localhost` RPID stops working until re-registered under the new host.
Disposable/testing-only: rotates every time the tunnel container restarts;
revert both URLs to `localhost` when done.
