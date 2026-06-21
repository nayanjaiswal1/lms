# Auth

Everything about authentication and session management: design, API endpoints, database schema, environment variables, and security rules.

---

## Cookie Model

All auth cookies are set on the **frontend domain** (never directly from the API to the browser). The login server action and all other auth actions fetch the Go API server-to-server, then re-emit the cookies via Next's cookie store. OAuth callbacks, refresh, and logout all go through Next route handlers — never directly browser→API.

This keeps cookies first-party and `SameSite=Lax` working correctly regardless of API host.

All cookies: `httpOnly=true · SameSite=Lax · Secure=true (prod) · Path=/`

---

## Auth Methods

| Method | Controlled by |
|---|---|
| Email + password | Always available unless overridden by org config |
| Google OAuth | `org_auth_config.allow_google` |
| GitHub OAuth | `org_auth_config.allow_github` |
| Microsoft OAuth | `org_auth_config.allow_microsoft` |
| Magic link | `org_auth_config.allow_magic_link` |
| OIDC / SAML (SSO) | `org_auth_config.oidc_*` / `saml_metadata_xml` |

---

## API Endpoints

### Session

```
POST /api/auth/register             body: {email, name, password}
                                    → creates user (email_verified=false), sends verification email
                                    → returns {data: {message: "Check your email"}}

POST /api/auth/login                body: {email, password, org_slug?}
                                    → validates org_auth_config if org_slug provided
                                    → if org require_sso=true → 403 "SSO required"
                                    → rate limited: 5 attempts / 15 min per IP+email
                                    → sets httpOnly cookies: access_token (15m), refresh_token (30d)
                                    → JWT claims include: user_id, org_id, org_role, auth_method
                                    → returns {data: {user, orgs: [{id, slug, name, role}]}}

POST /api/auth/refresh              (no body; reads refresh_token cookie)
                                    → verifies token hash in DB: not revoked, not expired
                                    → checks session_version matches users.session_version
                                    → detects impossible travel (geo check: >1000km in 2h)
                                    → issues new access_token; rotates refresh_token (same family_id)
                                    → if revoked token reused (outside 30s grace window) → revoke entire family → 401
                                    → impossible travel: email alert + step-up auth on next sensitive action (not auto-revoke)

POST /api/auth/logout               → revokes current refresh_token (sets revoked_at)
                                    → adds current jti to jti_blocklist
                                    → clears cookies

POST /api/auth/logout-all           → sets revoked_at on ALL refresh_tokens for user
                                    → bumps users.session_version (invalidates all active JWTs)

GET  /api/auth/me                   → current user + org memberships

GET  /api/auth/sessions             → list active devices (distinct family_ids: device_hint, ip, created_at)

DELETE /api/auth/sessions/:id       → revoke specific session family (adds its JTIs to blocklist)

POST /api/auth/switch-org           body: {org_id}
                                    → user must be member of org
                                    → if target org has require_sso=true and current session auth_method
                                      is not "saml" or "oidc" → 403 "SSO required"
                                    → issues new access_token with org_id + org_role in claims
```

### Email Verification

```
POST /api/auth/verify-email         body: {token}   → marks email_verified=true
POST /api/auth/resend-verification  body: {email}   → rate limited: 3 per email per hour
```

Unverified users can log in but are held on a "/verify-email" holding page. They cannot enroll in paid courses, create content, or hold instructor/mentor roles until verified.

### Password Reset

```
POST /api/auth/forgot-password      body: {email}
                                    → always responds {data: {message: "..."}} (prevents enumeration)
                                    → if email found: sends reset link (30-min token)
                                    → rate limited: 3 per email per hour, 10 per IP per hour
                                    → always runs dummy bcrypt compare to equalize timing

POST /api/auth/reset-password       body: {token, new_password}
                                    → validates token (not used, not expired)
                                    → updates password_hash, marks token used_at
                                    → sets revoked_at on ALL refresh_tokens for user
                                    → bumps session_version (invalidates all active JWTs)
                                    → adds all active JTIs to jti_blocklist
```

### Social / OAuth

```
GET  /api/auth/google?org=:slug     → checks org_auth_config allow_google; sets state cookie
GET  /api/auth/google/callback      → verifies state cookie (CSRF); exchanges code
                                    → ONLY links/registers if provider asserts email_verified=true
                                    → GitHub: calls GET /user/emails, uses primary+verified only
                                    → if email matches existing user → link accounts (requires verified email)
                                    → if new email → auto-register user
                                    → sets cookies via Next route handler; redirects to /dashboard

GET  /api/auth/github?org=:slug     → same flow as Google
GET  /api/auth/github/callback

GET  /api/auth/microsoft?org=:slug
GET  /api/auth/microsoft/callback
```

### Magic Link

```
POST /api/auth/magic-link           body: {email, org_slug?}
                                    → org must have allow_magic_link=true
                                    → sends 10-min one-time link to email
                                    → always returns {data: {message: "..."}} (no enumeration)

GET  /api/auth/magic-link/verify?token=...
                                    → validates token (not used, not expired)
                                    → marks used_at; issues access+refresh tokens via Next handler
                                    → redirects to dashboard
```

### Org Auth Config

```
GET  /api/orgs/:id/auth-config      (org_admin)
PUT  /api/orgs/:id/auth-config      (org_admin) body: {allow_password, allow_google, ...}
```

### Org Invitations

```
POST   /api/orgs/:id/invites        (org_admin) body: {email, role} → sends invite email (7-day link)
GET    /api/invites/:token          → validates invite (returns org name, role, expiry)
POST   /api/invites/:token/accept   → if logged in: verifies logged-in email matches invite email
                                    → adds org_member row atomically; sets accepted_at
                                    → if not logged in: redirect to /register?invite=:token
                                      (auto-accept on registration completion)
DELETE /api/orgs/:id/invites/:inviteId  (org_admin) → cancel pending invite
```

---

## Database Schema

```sql
-- Refresh tokens (stored as SHA-256 hash; family_id links a rotation chain)
refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  device_hint TEXT,          -- "Chrome / Windows", "iPhone Safari"
  ip          TEXT,          -- first 3 octets only (e.g. "192.168.1.x") — not raw PII
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,   -- NULL = still valid
  rotated_at  TIMESTAMPTZ,   -- set on rotation; accepted within 30s grace window
  family_id   UUID NOT NULL, -- shared across a rotation chain
  created_at  TIMESTAMPTZ DEFAULT now()
)

-- JTI blocklist: revoked access tokens that have not expired yet
jti_blocklist (
  jti        TEXT PRIMARY KEY,
  user_id    UUID NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  reason     TEXT    -- "password_changed" | "force_logout" | "suspicious_activity"
)

-- Social / OAuth identities (one user can link multiple providers)
social_accounts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider     TEXT NOT NULL,   -- "google" | "github" | "microsoft"
  provider_uid TEXT NOT NULL,
  email        TEXT,
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (provider, provider_uid)
)

-- Per-org auth configuration
org_auth_config (
  org_id              UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  allow_password      BOOLEAN DEFAULT true,
  allow_google        BOOLEAN DEFAULT false,
  allow_github        BOOLEAN DEFAULT false,
  allow_microsoft     BOOLEAN DEFAULT false,
  allow_magic_link    BOOLEAN DEFAULT false,
  require_sso         BOOLEAN DEFAULT false,
  oidc_issuer_url     TEXT,
  oidc_client_id      TEXT,
  oidc_client_secret  TEXT,    -- AES-256-GCM encrypted at rest
  saml_metadata_xml   TEXT,
  updated_at          TIMESTAMPTZ DEFAULT now()
)

-- Password reset tokens (one-time use, TTL from env)
password_reset_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ
)

-- Email verification tokens (one-time use, TTL from env)
email_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ
)

-- Magic-link login tokens (one-time use, TTL from env)
magic_link_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ
)

-- Org member invitations (sent by org_admin; accepted via link)
org_invites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  invited_by  UUID NOT NULL REFERENCES users(id),
  email       TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'student',  -- validated against allowed set on accept
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  accepted_at TIMESTAMPTZ,                      -- single-use enforced: reject if not NULL
  created_at  TIMESTAMPTZ DEFAULT now()
)
```

---

## Users Table (auth-relevant columns)

```sql
users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email            CITEXT NOT NULL UNIQUE,  -- citext: case-insensitive, always normalized
  name             TEXT NOT NULL,
  password_hash    TEXT,                    -- NULL for social-only accounts
  avatar_url       TEXT,
  platform_role    TEXT NOT NULL DEFAULT 'user',  -- 'super_admin' | 'user'
  email_verified   BOOLEAN NOT NULL DEFAULT false,
  session_version  INT NOT NULL DEFAULT 1,   -- bump to instantly invalidate all tokens
  max_sessions     INT NOT NULL DEFAULT 2,   -- concurrent device cap (plan-driven); counted by distinct family_id
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
)
```

---

## Environment Variables

```env
JWT_SECRET=                         # min 32 bytes random; app exits on startup if unset or default
COOKIE_SECRET=                      # for signing OAuth state cookies; same requirement
ENCRYPTION_KEY=                     # AES-256-GCM for oidc_client_secret at rest; 32 bytes exactly

ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=720h              # 30 days
PASSWORD_RESET_TTL=30m
EMAIL_VERIFICATION_TTL=24h
MAGIC_LINK_TTL=10m
INVITE_TTL=168h                     # 7 days

GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
MICROSOFT_CLIENT_ID=
MICROSOFT_CLIENT_SECRET=

MAXMIND_DB_PATH=./GeoLite2-City.mmdb    # optional; enables impossible-travel detection
```

---

## Security Rules (enforced at middleware level)

- Startup: if `JWT_SECRET`, `COOKIE_SECRET`, or `ENCRYPTION_KEY` is unset, empty, matches the `change-me` default, or is under 32 bytes → **fatal exit**. Never run with default secrets.
- JWT algorithm pinned to `HS256` in both sign and verify. Algorithm from token header is ignored.
- Every protected request: JWT signature → `jti_blocklist` lookup → `session_version` match against DB.
- `jti_blocklist` and `session_version` are cached in-process (30s TTL) to avoid two DB reads per request.
- bcrypt cost: 12 minimum. Never lower.
- Password length: 8–72 chars enforced at registration. bcrypt silently truncates at 72; reject above that at the API level.
- Login with null `password_hash` (social-only account): return generic 401 — do not reveal the account is social-only.
- Login timing: always run bcrypt compare even when user is not found (dummy hash), to equalize response time.
- OAuth state param: CSRF token stored in `httpOnly + SameSite=Lax + Secure` cookie; verified with constant-time compare on callback.
- OAuth email linking: only when provider asserts `email_verified=true`. GitHub: use `GET /user/emails` primary+verified field. Never use the top-level `/user` email field.
- Session cap: count distinct `family_id` (not individual rows). On login, if `COUNT(DISTINCT family_id) >= max_sessions` → revoke the oldest family.
- Refresh rotation grace: accept a "rotated" token up to 30 seconds after it was rotated (`rotated_at` within 30s). Reuse outside that window → revoke entire family.
- Impossible travel (`>1000km in 2h` between refresh IPs): send email alert + require step-up auth on next sensitive action. Do NOT auto-revoke the family (high false-positive rate with VPNs/mobile).
- `switch-org`: if target org has `require_sso=true`, only accept sessions where `auth_method` in JWT is `"saml"` or `"oidc"`.
- Invite acceptance: verify `accepted_at IS NULL` (single-use) + `expires_at > now()` + logged-in user email matches `org_invites.email` (case-insensitive). Set `accepted_at` and insert `org_members` in one transaction.
- `org_members`: `UNIQUE(org_id, user_id)` to prevent duplicate memberships.
- Cookie forwarding (`forwardSetCookies`): strip the `Domain` attribute from backend `Set-Cookie` headers before re-emitting. Assert `access_token` cookie was set before redirecting.
