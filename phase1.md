# Phase 1 — Auth, Roles & Tenant Bootstrap

**Prerequisite: Phase 0 must be complete.** Postgres and Redis are expected to already be running via `docker-compose.dev.yml`. The migration (`001_schema.sql`) must have been applied and the default org seeded before any Phase 1 code runs.

**Goal:** Working login, register, social auth (Google + GitHub), email verification, password reset, JWT session management, and role-gated UI. After this phase a user can sign up, log in on any device, and the UI renders correctly for every role.

---

## Tenant Decision for First Cut

**Strategy: Single default tenant, auto-assigned on register.**

There is no org onboarding flow yet. Every self-registered user goes into a seeded `default` org. The schema is already multi-tenant (`tenant_id` FK exists), so this is purely a UX/product decision — the infrastructure supports multi-tenancy from day 1.

```sql
-- Seeded once in the migration (not a runtime operation)
INSERT INTO organizations (id, slug, name, created_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'default', 'MindForge', now())
ON CONFLICT DO NOTHING;

INSERT INTO org_auth_config (org_id, allow_password, allow_google, allow_github)
VALUES ('00000000-0000-0000-0000-000000000001', true, true, true)
ON CONFLICT DO NOTHING;
```

**Registration flow with default tenant:**
1. User submits `{email, name, password}`
2. Handler creates `users` row (email_verified=false)
3. Handler inserts `org_members` row: `(org_id=DEFAULT_ORG_ID, user_id=new_id, role='student')`
4. Sends verification email
5. Returns `{message: "Check your email"}`

**JWT claims include `org_id` from first cut.** When proper org onboarding ships, `switch-org` is already wired.

**`DEFAULT_ORG_ID`** lives in env var `DEFAULT_ORG_ID=00000000-0000-0000-0000-000000000001` — never hardcoded in handler logic.

---

## Scope

| Area | What ships |
|---|---|
| Backend | DB migrations, all auth handlers, JWT middleware, role middleware, social OAuth (Google + GitHub) |
| Frontend | Register, Login, Verify Email, Forgot/Reset Password, role-gated shell |
| Roles | `super_admin` sees platform admin nav; `org_admin` sees org settings; `instructor`/`mentor`/`student` see their respective dashboards |
| Out of scope | Magic link, Microsoft OAuth, SAML/OIDC, org invite flow, payments |

---

## Backend

### File Structure

```
backend/
  cmd/
    server/
      main.go                    — startup, env validation, DB pool, router mount
  internal/
    config/
      config.go                  — all env vars parsed once at startup; fatal exit on missing secrets
    db/
      pool.go                    — pgxpool setup
      migrations/
        001_schema.sql           — full schema (see below)
    auth/
      handler.go                 — HTTP handlers for all auth endpoints
      jwt.go                     — sign, verify, claims struct
      middleware.go              — RequireAuth, RequireRole, RequirePlatformRole
      oauth.go                   — Google + GitHub OAuth flow
      password.go                — bcrypt hash/compare, timing-safe dummy compare
      tokens.go                  — refresh token CRUD (hash, rotate, revoke family)
      blocklist.go               — jti_blocklist: add, check (Redis primary, Postgres fallback, 30s TTL)
      session_version.go         — Redis cache (30s TTL) for session_version; fallback to DB
      ratelimit.go               — RateLimiter interface + RedisRateLimiter + MemoryRateLimiter (tests)
    email/
      mailer.go                  — resolve org email config, assemble TemplateData, dispatch to sender
      sender.go                  — EmailSender interface + PlatformSMTPSender + FallbackSender
      sender_smtp.go             — OrgSMTPSender (org's own SMTP credentials)
      sender_sendgrid.go         — SendGridSender (org's SendGrid API key)
      sender_ses.go              — SESSender (org's AWS SES credentials)
      templates/
        verify_email.html
        reset_password.html
        security_alert.html
    orgs/
      handler.go                 — GET/PUT /api/orgs/:id/auth-config, GET/PUT /api/orgs/:id/email-config
    shared/
      respond.go                 — JSON success/error helpers
      validate.go                — input validation helpers
  go.mod
  go.sum
  .env.example
```

---

### Migration 001_schema.sql

```sql
-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- Organizations (created before users — users FK into orgs via org_members)
CREATE TABLE organizations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Users
CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email            CITEXT NOT NULL UNIQUE,
  name             TEXT NOT NULL,
  password_hash    TEXT,
  avatar_url       TEXT,
  platform_role    TEXT NOT NULL DEFAULT 'user'
                   CHECK (platform_role IN ('super_admin', 'user')),
  email_verified   BOOLEAN NOT NULL DEFAULT false,
  session_version  INT NOT NULL DEFAULT 1,
  max_sessions     INT NOT NULL DEFAULT 2,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

-- Org membership
CREATE TABLE org_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL DEFAULT 'student'
             CHECK (role IN ('admin', 'instructor', 'mentor', 'student')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (org_id, user_id)
);

-- Per-org auth configuration
CREATE TABLE org_auth_config (
  org_id              UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  allow_password      BOOLEAN DEFAULT true,
  allow_google        BOOLEAN DEFAULT false,
  allow_github        BOOLEAN DEFAULT false,
  allow_microsoft     BOOLEAN DEFAULT false,
  allow_magic_link    BOOLEAN DEFAULT false,
  require_sso         BOOLEAN DEFAULT false,
  oidc_issuer_url     TEXT,
  oidc_client_id      TEXT,
  oidc_client_secret  TEXT,
  saml_metadata_xml   TEXT,
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- Refresh tokens
CREATE TABLE refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  device_hint TEXT,
  ip          TEXT,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  rotated_at  TIMESTAMPTZ,
  family_id   UUID NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX ON refresh_tokens (user_id, revoked_at);
CREATE INDEX ON refresh_tokens (family_id);

-- JTI blocklist
CREATE TABLE jti_blocklist (
  jti        TEXT PRIMARY KEY,
  user_id    UUID NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  reason     TEXT
);
CREATE INDEX ON jti_blocklist (expires_at);

-- Social accounts
CREATE TABLE social_accounts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider     TEXT NOT NULL CHECK (provider IN ('google', 'github', 'microsoft')),
  provider_uid TEXT NOT NULL,
  email        TEXT,
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (provider, provider_uid)
);

-- Password reset tokens
CREATE TABLE password_reset_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ
);

-- Email verification tokens
CREATE TABLE email_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ
);

-- Per-org email config: branding slots + optional BYOE (Bring Your Own Email) credentials
--
-- Tiers:
--   Phase 1 : table exists, no row for any org → all emails use platform SMTP
--   Phase 2 : org_admin fills branding slots (from_name, logo_url, brand_color, footer_text)
--   Phase N  : BYOE — org provides their own provider + credentials; platform verifies before activating
--             custom from_email domain requires SPF/DKIM DNS verification (separate flow)
--
-- SECURITY INVARIANT: emails where IsSecurity=true always use platform identity.
-- email_provider, from_name, from_email — all ignored for security emails.
CREATE TABLE org_email_config (
  org_id       UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,

  -- Branding slots (Phase 2)
  from_name    TEXT,          -- "Acme Training" — fallback: platform name
  from_email   TEXT,          -- noreply@acmecorp.com — requires DNS verify (Phase N)
  reply_to     TEXT,          -- support@acmecorp.com
  logo_url     TEXT,          -- must be https; validated before storing
  brand_color  TEXT,          -- hex e.g. "#1D4ED8" — CTA button color in email templates
  footer_text  TEXT,          -- plain text only, max 500 chars (no HTML — XSS/phishing risk)

  -- BYOE provider (Phase N)
  email_provider           TEXT NOT NULL DEFAULT 'platform'
                           CHECK (email_provider IN ('platform','smtp','sendgrid','ses','mailgun')),

  -- SMTP (works with any provider: Gmail, Postmark, Mailgun, custom)
  smtp_host                TEXT,
  smtp_port                INT,
  smtp_user                TEXT,
  smtp_pass_encrypted      TEXT,   -- AES-256-GCM (same key as oidc_client_secret)
  smtp_tls                 BOOLEAN DEFAULT true,

  -- SendGrid
  sendgrid_key_encrypted   TEXT,   -- AES-256-GCM

  -- AWS SES
  ses_region               TEXT,
  ses_access_key           TEXT,
  ses_secret_encrypted     TEXT,   -- AES-256-GCM

  -- Verification gate: platform sends a test email via org's provider before activating
  -- email_provider is only used when provider_verified = true
  provider_verified        BOOLEAN NOT NULL DEFAULT false,
  provider_verified_at     TIMESTAMPTZ,

  updated_at               TIMESTAMPTZ DEFAULT now()
);

-- Default org seed
INSERT INTO organizations (id, slug, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'default', 'MindForge')
ON CONFLICT DO NOTHING;

INSERT INTO org_auth_config (org_id, allow_password, allow_google, allow_github)
VALUES ('00000000-0000-0000-0000-000000000001', true, true, true)
ON CONFLICT DO NOTHING;
```

---

### config/config.go

Parse all env vars at startup. Fatal exit if any secret is missing, empty, or matches the `change-me` default, or under 32 bytes.

```go
type Config struct {
  // Infrastructure (set up by Phase 0)
  DatabaseURL  string
  RedisURL     string        // redis://localhost:6379 — required; fatal exit if unset

  // Secrets — fatal exit if missing/default/under 32 bytes
  JWTSecret      string
  CookieSecret   string
  EncryptionKey  string     // exactly 32 bytes (AES-256-GCM)

  // Session TTLs
  AccessTokenTTL   time.Duration // default 15m
  RefreshTokenTTL  time.Duration // default 720h
  PasswordResetTTL time.Duration // default 30m
  EmailVerifyTTL   time.Duration // default 24h

  // Tenant
  DefaultOrgID string        // UUID of the seeded default tenant

  // Platform OAuth (Google + GitHub apps registered by MindForge — not per-tenant)
  GoogleClientID     string
  GoogleClientSecret string
  GitHubClientID     string
  GitHubClientSecret string
  FrontendURL        string  // redirect after OAuth callback

  // Platform email (used when org has no BYOE config or email is a security email)
  SMTPHost  string
  SMTPPort  int
  SMTPUser  string
  SMTPPass  string
  EmailFrom string  // e.g. "MindForge <noreply@mindforge.dev>"

  // Optional
  MaxMindDBPath string // enables impossible-travel detection
}
```

---

### auth/jwt.go — Claims Struct

```go
type Claims struct {
  jwt.RegisteredClaims                    // includes JTI, Exp, Iat
  UserID      string `json:"user_id"`
  OrgID       string `json:"org_id"`
  OrgRole     string `json:"org_role"`   // "admin" | "instructor" | "mentor" | "student"
  PlatformRole string `json:"platform_role"` // "super_admin" | "user"
  AuthMethod  string `json:"auth_method"` // "password" | "google" | "github"
}
```

JWT algorithm pinned to `HS256`. Algorithm from token header is always ignored in verification.

---

### auth/middleware.go — Role Guards

```go
// RequireAuth: validates JWT, checks jti_blocklist, checks session_version → sets Claims in ctx
func RequireAuth(cfg *Config) func(http.Handler) http.Handler

// RequireRole: requires user to have the given org_role in their current org context
// Usage: r.With(RequireRole("admin", "instructor")).Get(...)
func RequireRole(roles ...string) func(http.Handler) http.Handler

// RequirePlatformRole: checks platform_role in claims
// Usage: r.With(RequirePlatformRole("super_admin")).Get(...)
func RequirePlatformRole(roles ...string) func(http.Handler) http.Handler
```

Both `jti_blocklist` check and `session_version` check are cached in **Redis** (30s TTL, shared across all Go instances). On Redis miss: fall back to Postgres and backfill the cache. This is what makes revocation safe across horizontal scaling — an in-process cache would leave a 30s window where a revoked token is still accepted on other instances.

---

### auth/handler.go — Endpoints

Implement all endpoints exactly as specified in `docs/auth.md`. Key notes:

- `POST /api/auth/register`: create user → insert `org_members` with `org_id=cfg.DefaultOrgID, role='student'` → send verification email. All in one DB transaction.
- `POST /api/auth/login`: rate-limit 5/15min per IP+email → validate password (always run bcrypt even when user not found) → check `email_verified` → issue access+refresh tokens → return `{user, orgs}`.
- Cookies: `httpOnly=true · SameSite=Lax · Secure=(env==prod) · Path=/`
- `POST /api/auth/refresh`: verify token hash in DB → check `session_version` → detect impossible travel (if MaxMind DB present) → rotate token → issue new access token.
- `POST /api/auth/logout`: revoke current refresh token → blocklist JTI → clear cookies.
- `GET /api/auth/me`: return `{user, orgs: [{id, slug, name, role}]}`.

---

### auth/oauth.go — Social Auth

**Flow (Google and GitHub share the same pattern):**

1. `GET /api/auth/google?org=:slug`
   - Check `org_auth_config.allow_google` for the given org (default org if no slug)
   - Generate CSRF state token → store in `httpOnly` cookie (10-min TTL)
   - Redirect to provider authorization URL

2. `GET /api/auth/google/callback`
   - Verify state cookie with constant-time compare
   - Exchange code for tokens via provider
   - Fetch user info: email + `email_verified` flag
   - GitHub: call `GET /user/emails` — use only `primary=true, verified=true` entry
   - If `email_verified=false` from provider → reject (401)
   - Lookup `social_accounts` by `(provider, provider_uid)`
     - Found → get associated user → issue session
     - Not found → lookup `users` by email
       - Email exists + verified → link: insert `social_accounts` → issue session
       - Email exists + unverified → 409 "Account exists with unverified email. Verify first."
       - No user → auto-register: insert `users` (email_verified=true, no password_hash) + `org_members` (default org, student) + `social_accounts` → issue session
   - Emit `access_token` + `refresh_token` cookies via Next.js route handler
   - Redirect to `${FRONTEND_URL}/dashboard`

---

### email/ — Mailer + Sender Abstraction

#### `email/sender.go` — Interface + resolution logic

```go
type EmailMessage struct {
  To        string
  ToName    string
  Subject   string
  BodyHTML  string
  BodyText  string
}

type EmailSender interface {
  Send(ctx context.Context, msg EmailMessage) error
}

// Implementations in this package:
//   PlatformSMTPSender   — platform's own SMTP (always available, always used for security emails)
//   OrgSMTPSender        — org's own SMTP credentials (decrypted from org_email_config)
//   SendGridSender       — org's SendGrid API key
//   SESSender            — org's AWS SES access key + secret
//   FallbackSender       — tries org sender; on any error falls back to PlatformSMTPSender + alerts org admin
```

**Sender resolution (in `email/mailer.go`):**
```
IsSecurity == true                       → PlatformSMTPSender  (hardcoded, no override ever)
org has no org_email_config row          → PlatformSMTPSender
org.email_provider == 'platform'         → PlatformSMTPSender
org.provider_verified == false           → PlatformSMTPSender
org has verified BYOE provider           → FallbackSender(OrgSender, PlatformSMTPSender)
```

#### `email/mailer.go` — TemplateData + dispatch

```go
type TemplateData struct {
  // Org branding slots — resolved from org_email_config, fallback to platform defaults
  OrgName    string // "Acme Training" or "MindForge"
  LogoURL    string
  BrandColor string // hex, e.g. "#B45309"
  FooterText string
  FromName   string
  FromEmail  string // platform address until custom domain verified (Phase N)
  ReplyTo    string

  // Per-email variables
  RecipientName string
  ActionURL     string
  ExpiresIn     string

  // When true: ignore all org slots, send as platform identity unconditionally
  IsSecurity bool
}
```

**What tenants can customise per phase:**

| Slot | Phase 1 | Phase 2 | Phase N |
|---|---|---|---|
| `from_name`, `logo_url`, `brand_color`, `footer_text` | Platform default | Org can set | Org can set |
| `reply_to` | Platform default | Org can set | Org can set |
| `from_email` (custom domain) | Platform only | Platform only | Org — requires SPF/DKIM verify |
| BYOE provider credentials | Not available | Not available | Org provides; platform verifies before activating |
| Security emails | Always platform | Always platform | Always platform |

**BYOE API endpoints (Phase N — schema is ready, endpoints ship later):**
```
PUT  /api/orgs/:id/email-config          (org_admin) — save provider + credentials (encrypted)
POST /api/orgs/:id/email-config/verify   (org_admin) — platform sends test email via org's provider
                                                        → sets provider_verified=true on success
GET  /api/orgs/:id/email-config          (org_admin) — config with credentials masked
```

---

### Rate Limiting

Rate limiter backed by **Redis** (shared across all Go instances). Interface abstraction keeps the implementation swappable.

```go
type RateLimiter interface {
  Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, error)
}
// RedisRateLimiter  — production (sliding window via Redis sorted sets)
// MemoryRateLimiter — test/local fallback when Redis is not configured
```

| Endpoint | Limit |
|---|---|
| `POST /api/auth/login` | 5 attempts / 15 min per IP+email |
| `POST /api/auth/forgot-password` | 3 per email/hour + 10 per IP/hour |
| `POST /api/auth/resend-verification` | 3 per email/hour |

---

## Frontend

### File Structure

```
frontend/
  app/
    (auth)/                        — auth layout (centered card, no sidebar)
      layout.tsx                   — minimal: logo + centered content
      login/
        page.tsx                   — server component; redirect to /dashboard if already authed
        _components/
          login-form.tsx           — "use client"; react-hook-form + zod
          social-auth-buttons.tsx  — Google + GitHub buttons
      register/
        page.tsx
        _components/
          register-form.tsx
      verify-email/
        page.tsx                   — unverified users land here; shows resend button
        _components/
          verify-email-form.tsx
      forgot-password/
        page.tsx
        _components/
          forgot-password-form.tsx
      reset-password/
        page.tsx                   — reads ?token= from URL
        _components/
          reset-password-form.tsx
    (app)/                         — app shell (sidebar + header)
      layout.tsx                   — RequireAuth wrapper; loads user + feature flags
      dashboard/
        page.tsx                   — role-aware: renders RoleDashboard
      admin/                       — platform super_admin only
        page.tsx                   — requirePlatformRole("super_admin") server-side guard
        _components/
          admin-overview.tsx
      org/
        [slug]/
          settings/
            page.tsx               — requireOrgRole("admin") server-side guard
            _components/
              org-settings-form.tsx
              auth-config-form.tsx
      instructor/
        page.tsx                   — requireOrgRole("instructor", "admin") guard
      mentor/
        page.tsx                   — requireOrgRole("mentor", "admin") guard
  lib/
    auth/
      session.ts                   — getSession(): reads + verifies access_token cookie server-side
      actions.ts                   — loginAction, registerAction, logoutAction, etc. (server actions)
      guards.ts                    — requireAuth(), requireOrgRole(), requirePlatformRole() for page.tsx
    api/
      client.ts                    — typed fetch wrapper (attaches cookies server-side, handles 401)
    routes.ts                      — all route constants (already exists, extend it)
  middleware.ts                    — Next.js edge middleware: protect /dashboard, /admin, /org
  components/
    auth/
      role-dashboard.tsx           — "use client"; renders correct dashboard by role
      user-menu.tsx                — avatar dropdown: profile, switch org, logout
      org-switcher.tsx             — shows orgs user belongs to; calls switch-org action
```

---

### Auth Pages

#### `/login`

- Email + password form (react-hook-form + zod)
- Social auth buttons: Google, GitHub (rendered from org auth config fetched server-side)
- "Forgot password?" link
- "Create account" link
- On submit: calls `loginAction` (server action) → sets cookies → redirects to `/dashboard`
- Error states: wrong credentials (generic "Invalid email or password"), email not verified (redirect `/verify-email`), SSO required

#### `/register`

- Name, email, password fields
- Social auth buttons (same as login)
- On submit: calls `registerAction` → redirects to `/verify-email` with a success message
- Zod schema: name (2–100 chars), email (valid format), password (8–72 chars, min 1 uppercase, 1 number)

#### `/verify-email`

- Unverified users are held here after login. Access token is still issued — they just can't reach `/dashboard`.
- Shows: "Check your inbox at [email]" + "Resend email" button (rate-limited)
- `GET /api/auth/verify-email?token=...` (from email link) → on success redirect to `/dashboard`

#### `/forgot-password` + `/reset-password`

- Forgot: email input → submit → always shows "If an account exists, we sent a link" (no enumeration)
- Reset: reads `?token=` from URL → new password + confirm → on success redirect to `/login`

---

### Role-Gated Shell

#### `middleware.ts` (Next.js Edge)

```ts
// Protects routes — runs before page renders
// /dashboard, /org/*, /admin, /instructor, /mentor → require valid access_token cookie
// /admin → require platform_role = super_admin in JWT claims (decode without verify at edge,
//           verify fully in page.tsx server component)
// Unauthed → redirect to /login?next=<path>
// Authed + hitting /login or /register → redirect to /dashboard
```

#### `lib/auth/guards.ts`

```ts
// Called at the top of page.tsx (server component)
// These fully verify the JWT (signature + blocklist + session_version)

async function requireAuth(): Promise<Claims>
async function requireOrgRole(...roles: string[]): Promise<Claims>
async function requirePlatformRole(...roles: string[]): Promise<Claims>
// Each function redirects (via Next's redirect()) or throws notFound() on failure
```

#### Role-Aware Dashboard (`/dashboard`)

The `/dashboard` page calls `requireAuth()` then renders a different component per role:

| Role | What they see |
|---|---|
| `super_admin` (platform) | Platform stats: total users, orgs, courses, revenue; links to `/admin` |
| `org_admin` | Org member count, pending invites, recent course activity; link to `/org/[slug]/settings` |
| `instructor` | My courses: draft/published/archived; quick "New Course" CTA |
| `mentor` | Assigned students list; recent submissions to review |
| `student` | Enrolled courses progress; streak counter; upcoming review cards |

Implementation: `role-dashboard.tsx` receives `{ role, orgRole, user }` as props from the server page. It `switch`es on `orgRole` (falling back to `platformRole === 'super_admin'`) to render the correct section. No `if (user.role === 'admin')` strings in JSX — role string comes from JWT claims, not hardcoded.

---

### Platform Admin Panel (`/admin`)

Accessible only to `platform_role = 'super_admin'`. Server-side guard: `requirePlatformRole("super_admin")`.

**What super_admin sees:**
- User table: search, filter by org/role, disable account, force logout all sessions
- Org table: create/disable org, view org auth config
- Platform metrics: signups today/week/month, active sessions, error rate

**Navigation:** Admin link in sidebar only renders when `platformRole === 'super_admin'` — implemented as a config-driven nav item with `mode="hide"` on the `<AccessGate>`.

---

### Org Settings (`/org/[slug]/settings`)

Accessible to `org_role = 'admin'`. Guard: `requireOrgRole("admin")`.

**What org_admin sees:**
- Org profile: name, slug (read-only after creation)
- Auth config: toggle Google, GitHub, magic link; enable SSO (phase 2)
- Members: list, change role, remove
- Pending invites (phase 2 — show placeholder)

---

### User Menu

Top-right avatar dropdown (present in `app-header` on all `(app)` routes):

```
[Avatar] [Name]
  ───────────────
  My Profile
  Switch Org          ← shows if user belongs to >1 org
  ───────────────
  [if org_admin]  Org Settings
  [if super_admin] Platform Admin
  ───────────────
  Log out
  Log out all devices
```

---

### Cookies — Next.js ↔ Go

All auth cookie operations go through **server actions or Next.js route handlers**, never browser→API directly.

```
Register/Login form → server action → fetch Go API server-to-server
                   → forward Set-Cookie headers to browser via next/headers cookies()
OAuth callback     → Next.js route handler at /api/auth/[provider]/callback
                   → receives redirect from Go → issues cookies → redirects to /dashboard
Refresh            → Next.js route handler at /api/auth/refresh (called by server action on 401)
Logout             → server action → calls Go API → clears cookies
```

Cookie settings: `httpOnly=true · SameSite=Lax · Secure=true (prod) · Path=/`
Strip `Domain` attribute from Go's `Set-Cookie` before re-emitting — keeps cookies first-party.

---

## Security Checklist

- [ ] Startup: fatal exit if `JWT_SECRET`, `COOKIE_SECRET`, `ENCRYPTION_KEY` are missing/default/under 32 bytes
- [ ] JWT algorithm pinned to `HS256`; token header algorithm ignored
- [ ] bcrypt cost ≥ 12; password length 8–72 enforced at API; above 72 → reject (bcrypt silently truncates)
- [ ] Dummy bcrypt compare when user not found (equalize timing)
- [ ] OAuth state CSRF token in httpOnly cookie; constant-time compare on callback
- [ ] GitHub OAuth: use `/user/emails` primary+verified, not `/user` email field
- [ ] Social link only when provider asserts `email_verified=true`
- [ ] Session cap: count distinct `family_id`, revoke oldest when `>= max_sessions`
- [ ] Refresh rotation grace window: 30s (`rotated_at`) — outside window → revoke family
- [ ] `POST /api/auth/forgot-password` never leaks whether email exists
- [ ] `POST /api/auth/resend-verification` never leaks whether email exists
- [ ] Invite acceptance: `accepted_at IS NULL` + `expires_at > now()` + email match (case-insensitive) in one TX
- [ ] `jti_blocklist` and `session_version` cached in Redis (30s TTL); Postgres fallback on miss — shared across all Go instances, no per-process gap
- [ ] BYOE org email credentials encrypted at rest (AES-256-GCM) before storing in `org_email_config`
- [ ] BYOE provider only used when `provider_verified = true`; fallback to platform SMTP otherwise
- [ ] `IsSecurity = true` emails always use platform SMTP regardless of org email config

---

## Build Order

Do these in sequence — each step compiles and the app stays in a working state.

```
[ ] 0. Phase 0 complete — Postgres + Redis running, migration applied, default org seeded

[ ] 1. go.mod + dependencies (chi, pgx/v5, golang-jwt/v5, golang.org/x/crypto, go-redis/v9)
[ ] 2. config/config.go — parse + validate all env vars; fatal exit if RedisURL, JWT_SECRET, COOKIE_SECRET, ENCRYPTION_KEY are missing/weak
[ ] 3. db/pool.go — pgxpool connect + ping
[ ] 4. redis/client.go — go-redis client connect + ping; wired into Config
[ ] 5. shared/respond.go — JSON helpers
[ ] 6. auth/password.go — bcrypt hash/compare + dummy compare
[ ] 7. auth/jwt.go — sign/verify + Claims struct
[ ] 8. auth/ratelimit.go — RateLimiter interface; RedisRateLimiter (sliding window via sorted sets); MemoryRateLimiter (tests only)
[ ] 9. auth/blocklist.go — Redis primary (SET with TTL) + Postgres fallback; backfill Redis on miss
[ ] 10. auth/session_version.go — Redis cache (GET/SET, 30s TTL) + Postgres fallback; backfill on miss
[ ] 11. auth/tokens.go — refresh token CRUD (hash, insert, rotate, revoke family)
[ ] 12. email/sender.go — EmailSender interface + PlatformSMTPSender + FallbackSender
[ ] 13. email/sender_smtp.go, sender_sendgrid.go, sender_ses.go — org provider implementations
[ ] 14. email/mailer.go — TemplateData struct, org_email_config lookup (cached 60s in Redis), sender resolution, IsSecurity guard
[ ] 15. auth/handler.go — register, login, verify-email, resend-verification
[ ] 16. auth/handler.go — forgot-password, reset-password
[ ] 17. auth/handler.go — refresh, logout, logout-all, me, sessions, delete-session
[ ] 18. auth/middleware.go — RequireAuth, RequireRole, RequirePlatformRole
[ ] 19. auth/oauth.go — Google + GitHub initiate + callback
[ ] 20. orgs/handler.go — GET/PUT /api/orgs/:id/auth-config, GET/PUT /api/orgs/:id/email-config
[ ] 21. cmd/server/main.go — wire DB + Redis + mailer + router; start server

[ ] 19. Next.js: lib/auth/session.ts — getSession() cookie reader
[ ] 20. Next.js: lib/auth/actions.ts — loginAction, registerAction, logoutAction
[ ] 21. Next.js: middleware.ts — edge route protection
[ ] 22. Next.js: (auth) layout + login page + login-form
[ ] 23. Next.js: register page + register-form
[ ] 24. Next.js: verify-email page
[ ] 25. Next.js: forgot-password + reset-password pages
[ ] 26. Next.js: social-auth-buttons + OAuth route handlers
[ ] 27. Next.js: (app) layout with RequireAuth
[ ] 28. Next.js: dashboard page + role-dashboard component
[ ] 29. Next.js: user-menu + org-switcher
[ ] 30. Next.js: /admin page (super_admin only)
[ ] 31. Next.js: /org/[slug]/settings page (org_admin only)
[ ] 32. Next.js: lib/auth/guards.ts — requireAuth, requireOrgRole, requirePlatformRole
```

---

## Environment Variables

```env
# ── Infrastructure (provisioned by Phase 0 docker-compose) ────────────────────
DATABASE_URL=postgres://mindforge:mindforge@localhost:5432/mindforge
REDIS_URL=redis://localhost:6379          # required — fatal exit if unset
PORT=8080
ENV=development                           # "production" enables Secure cookies + stricter checks

# ── Secrets (fatal exit if missing, empty, default, or under 32 bytes) ────────
JWT_SECRET=                               # min 32 bytes random
COOKIE_SECRET=                            # min 32 bytes random
ENCRYPTION_KEY=                           # exactly 32 bytes (AES-256-GCM for oidc_client_secret + BYOE creds)

# ── Session TTLs ──────────────────────────────────────────────────────────────
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=720h
PASSWORD_RESET_TTL=30m
EMAIL_VERIFICATION_TTL=24h

# ── Tenant ────────────────────────────────────────────────────────────────────
DEFAULT_ORG_ID=00000000-0000-0000-0000-000000000001

# ── Platform OAuth apps (registered once by MindForge — not per-tenant) ──────
# Per-tenant SSO (OIDC/SAML) credentials live in org_auth_config, not here.
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
FRONTEND_URL=http://localhost:3000        # used for OAuth redirect after callback

# ── Platform email (used when org has no verified BYOE config) ────────────────
# Per-org BYOE credentials (SendGrid key, SMTP pass, SES secret) are stored
# AES-256-GCM encrypted in org_email_config, not in env vars.
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
EMAIL_FROM=MindForge <noreply@mindforge.dev>

# ── Optional ──────────────────────────────────────────────────────────────────
MAXMIND_DB_PATH=                          # path to GeoLite2-City.mmdb; enables impossible-travel detection
```

---

## Done Criteria

Phase 1 is complete when:

1. A new user can register with email + password, receive a verification email, verify, and reach `/dashboard`
2. A new user can register via Google or GitHub OAuth and reach `/dashboard`
3. Login with email + password works; wrong credentials return generic 401
4. Refresh token rotates correctly; reuse outside 30s window revokes the family
5. Logout clears cookies and blocks the JTI
6. Password reset flow works end-to-end
7. `super_admin` sees the platform admin nav item and can reach `/admin`
8. `org_admin` sees org settings link and can reach `/org/[slug]/settings`
9. `instructor`, `mentor`, `student` each see their correct dashboard section
10. Unauthed users hitting `/dashboard` are redirected to `/login?next=/dashboard`
11. `pnpm lint:strict` passes (zero warnings) on all frontend files in this phase
