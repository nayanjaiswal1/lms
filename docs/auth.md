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
| Magic link | **planned (not built)** — no endpoint exists; `org_auth_config.allow_magic_link` is an unused column |
| OIDC / SAML (SSO) | **planned (not built)** — the columns exist, no login flow does; `require_sso` therefore cannot be satisfied by any session |
| Passkey (WebAuthn) | Additive — always available once a password/OAuth account exists; enrolled from Settings → Security, never a standalone signup path |

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

GET  /api/auth/sessions             → list live devices (one per refresh-token family_id):
                                      [{id, device_hint, ip (truncated), started_at, last_active_at, current}]

DELETE /api/auth/sessions/:id       → revokes that family's refresh tokens (404 if not the caller's or already revoked)
                                    → emits auth_event session_revoked
                                    → the device keeps its access token until it expires (access tokens carry no
                                      family_id, so they cannot be blocklisted per device) but can no longer refresh
                                    → revoking the CURRENT device also blocklists its jti and clears cookies
                                      (response {revoked_current: true}; the UI redirects to /login)

Org switching is not an /api/auth endpoint: it ships as POST /api/orgs/switch (see docs/orgs.md).
```

### Email Verification

```
POST /api/auth/verify-email         body: {token}   → marks email_verified=true
POST /api/auth/resend-verification  body: {email}   → rate limited: 3 per email per hour
```

Unverified users can log in but are held on a "/verify-email" holding page. They cannot enroll in paid courses, create content, or hold instructor/mentor roles until verified.

### CAPTCHA (Cloudflare Turnstile)

`/api/auth/register`, `/login` and `/forgot-password` sit behind `middleware.RequireCaptcha`: the browser widget's token is sent as `X-Captcha-Token` and verified against Turnstile siteverify (SSRF-guarded client, 5s timeout, remote IP included). Missing/rejected token -> 400; verifier unreachable -> 503 (fails closed). `TURNSTILE_SECRET_KEY` is mandatory when `ENV` is not `development`; unset in dev disables the check. The Next.js server's own calls (demo login, admin password reset) send `X-Captcha-Bypass` = `CAPTCHA_BYPASS_SECRET`. MFA verify is not gated: it requires a prior password success and is already rate limited.

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

> **Planned (not built).** None of the endpoints below are registered; the section is the intended design only.

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

### Passkeys (WebAuthn)

```
POST /api/auth/webauthn/login/begin     body: {email?}
                                        → email known + has passkeys: scoped challenge (webauthn.BeginLogin)
                                        → email absent/unknown/no passkeys: discoverable challenge
                                          (webauthn.BeginDiscoverableLogin) — never reveals account existence
                                        → rate limited (same /api/auth group as login)
                                        → returns {data: {handle, options}}

POST /api/auth/webauthn/login/finish    body: {handle, response}
                                        → verifies the authenticator response; mints the same
                                          access/refresh/CSRF cookies as password login
                                        → JWT auth_method: "passkey"
                                        → returns {data: {user, orgs, onboarding_completed}}

POST /api/auth/webauthn/register/begin   (authenticated) → excludes already-registered credentials
                                        → requires a discoverable (resident-key) credential
                                        → returns {data: {handle, options}}

POST /api/auth/webauthn/register/finish  (authenticated) body: {handle, nickname, response}
                                        → verifies + stores the new credential
                                        → returns {data: {credential: {id, nickname, created_at}}}

GET    /api/auth/webauthn/credentials         (authenticated) → list the user's passkeys
PATCH  /api/auth/webauthn/credentials/:id     (authenticated) body: {nickname} → rename
DELETE /api/auth/webauthn/credentials/:id     (authenticated)
                                        → 409 if this is the account's last sign-in method
                                          (no password_hash, no social_accounts, no other passkey)
```

### MFA (TOTP)

Authenticated (session) endpoints: `GET /api/auth/mfa` (status), `POST /api/auth/mfa/setup` (returns `secret` + `otpauth://` `uri`), `POST /api/auth/mfa/enable` (`{code}` -> `recovery_codes`), `POST /api/auth/mfa/disable` (`{code}`; refused for privileged roles), `POST /api/auth/mfa/recovery-codes` (`{code}` -> new `recovery_codes`).

- Setup UI renders the `uri` as a QR code client-side (`qrcode` package, data URL); the secret is never sent to a third party.
- Recovery-code regeneration requires a current TOTP code (a recovery code is not accepted), shares the per-account `rl:mfa:<user>` limit (5 per 5 min) with every other code-checking MFA endpoint, deletes all old codes (used or not) and inserts the new set in one transaction, emits `mfa_recovery_regenerated` (failed attempts emit `mfa_failed`) and sends a security notice email. Codes are stored hashed and shown once.
- TOTP codes are single-use (`last_step` replay guard).
- DB tests: `internal/auth/mfa_db_test.go` (enrol/verify/replay, recovery regen, change-password transaction).

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

-- Passkey (WebAuthn) credentials — one row per registered authenticator
webauthn_credentials (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  credential_id    BYTEA NOT NULL UNIQUE,   -- raw WebAuthn credential ID
  public_key       BYTEA NOT NULL,          -- COSE public key
  attestation_type TEXT NOT NULL DEFAULT 'none',
  transports       TEXT[] NOT NULL DEFAULT '{}',
  aaguid           BYTEA NOT NULL DEFAULT '\x',
  sign_count       BIGINT NOT NULL DEFAULT 0,   -- clone-detection counter
  clone_warning    BOOLEAN NOT NULL DEFAULT false,
  backup_eligible  BOOLEAN NOT NULL DEFAULT false,
  backup_state     BOOLEAN NOT NULL DEFAULT false,
  nickname         TEXT NOT NULL DEFAULT 'Passkey',   -- user-facing label
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at     TIMESTAMPTZ
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

GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

WEBAUTHN_RP_DISPLAY_NAME=MindForge      # optional, defaults to "MindForge"
                                         # RPID/RPOrigin are NOT separate env vars — derived from FRONTEND_URL
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
- Refresh rotation grace: accept a "rotated" token up to `REFRESH_REUSE_GRACE` (30s) after it was rotated. The successor is derived as `HMAC-SHA256(COOKIE_SECRET, parent)`, so an in-grace replay re-emits the exact successor already issued (idempotent — racing responses all set the same cookie); if that successor is no longer live the replay gets 401 without revoking. Reuse outside the window → revoke entire family.
- Next proxy (`frontend/proxy.ts`) must append the backend's Set-Cookie headers *after* any `response.cookies.set()` — `NextResponse.cookies.set()` rebuilds the Set-Cookie list and drops headers appended earlier (this lost rotated refresh tokens and caused the E2E logout, F8/C8).
- Impossible travel (`>1000km in 2h` between refresh IPs): send email alert + require step-up auth on next sensitive action. Do NOT auto-revoke the family (high false-positive rate with VPNs/mobile).
- `switch-org` [planned (not built)]: if target org has `require_sso=true`, only accept sessions where `auth_method` in JWT is `"saml"` or `"oidc"`.
- Invite acceptance: verify `accepted_at IS NULL` (single-use) + `expires_at > now()` + logged-in user email matches `org_invites.email` (case-insensitive). Set `accepted_at` and insert `org_members` in one transaction.
- `org_members`: `UNIQUE(org_id, user_id)` to prevent duplicate memberships.
- Cookie forwarding (`forwardSetCookies`): strip the `Domain` attribute from backend `Set-Cookie` headers before re-emitting. Assert `access_token` cookie was set before redirecting.
- Passkey RPID/RPOrigin are pinned to `FRONTEND_URL` (parsed at config load) — never accepted from a request. Passkey registration requires a discoverable (resident-key) credential so login/begin can always fall back to a usernameless challenge.
- Passkey in-flight challenges (`SessionData`) live in Redis only, keyed by a random handle, 5-minute TTL, consumed exactly once (`GETDEL`) — never persisted to Postgres, never trusted from the client.
- Passkey sign-counter regression (`clone_warning`) is advisory, not a block: the login is allowed to complete, the credential is flagged, and an alert email is sent — mirrors the impossible-travel posture, since synced/cloud-backed passkeys often report a static or zero counter and would otherwise false-positive constantly.
- Deleting a passkey is blocked with `409` when it is the account's last remaining sign-in method (`password_hash IS NULL` and no `social_accounts` and no other `webauthn_credentials` row) — prevents an irrecoverable lockout.

---

## Registration: age declaration and legal acceptance

`POST /api/auth/register` requires `accept_terms: true` and `age_declared: true` (DPDP s.9: users must be 18+). A missing declaration is a `422` field error on `age_declared`. The moment of declaration is stored in `users.age_declared_at` (migration 057); the terms/privacy acceptance (version + truncated IP) goes to `legal_acceptances`, which erasure retains as proof of consent.

## Security event trail (`auth_events`)

Append-only table (migration 056) written only through `authevents.Emit`, which truncates the IP (IPv4 to /24, IPv6 to /48) and stores a hash of the User-Agent, never the raw value. A DB trigger rejects every UPDATE and DELETE; only the retention job may delete, by setting `mindforge.purge_auth_events=on` for its own transaction. `user_id` has no foreign key on purpose, so the trail survives account erasure.

Events: `login`, `login_failed`, `password_reset`, `password_changed`, `passkey_added`, `passkey_removed`, `logout_all`, `mcp_connected`, `mcp_revoked`, `data_export`, `account_deletion`, `mfa_enabled`, `mfa_disabled`, `mfa_verified`, `mfa_failed`, `mfa_recovery_used`, `mfa_recovery_regenerated`. Retention: `RETENTION_AUTH_EVENTS_DAYS` (default 365).

## Privacy settings (AI consent and nominee)

Per-user row in `user_privacy_settings` (migration 055), served by `internal/privacy`:

```
GET /api/privacy/settings      -> {ai_consent, ai_consent_at, nominee}
PUT /api/privacy/ai-consent    body: {consent: bool}   opt in / withdraw AI processing of your own content
PUT /api/privacy/nominee       body: {nominee: {name, relationship, contact} | null} (all three or none; null clears; <=200 chars each)
POST /api/privacy/export       body: {password, code} step-up; full data bundle (JSON); emits auth event data_export
POST /api/privacy/delete-account  body: {password, code} step-up; emits account_deletion
                                  step-up (auth.VerifyStepUp): password required when the account has one, TOTP/recovery
                                  code when MFA is enabled; 403 on failure, shares the per-account MFA rate limit
```

AI consent is default off. Features that send the user's own text or files to a third-party model (captures, diary AI analysis and Fix English) return `403` with an explanatory message until consent exists; withdrawing consent takes effect on the next request. The nominee is the person who may exercise the user's rights on their behalf (DPDP s.14); it is stored but exercised through the grievance officer, there is no nominee login.

## Erasure and export semantics

- **Export** returns the curated sections plus every table with an `ON DELETE CASCADE` foreign key to `users`, read from the live catalog so new tables are included automatically. Credential material (token hashes, passkeys, social links, MCP connections, GitLab connections, idempotency keys) is deliberately left out.
- **Erasure** (`privacy.AnonymizeAndDeletePII`, one transaction): deletes every cascade child of `users` except the allowlist `retainedUserTables`, deletes MCP action logs, removes stored capture blobs from object storage before commit (a storage failure rolls everything back and the request can be retried), anonymizes the `users` row (never hard-deleted because content it authored is `ON DELETE RESTRICT` elsewhere), then deactivates the account and revokes all sessions.
- **Retained, disassociated from identity:** payment and ledger records, coupon redemptions, consent records, certificates, assessment and enrolment records, org rosters, other people's conversations, moderation records, shared interview content. A new user-FK table is erased by default; it must be added to `retainedUserTables` with a reason to be kept.

## Domain verification

An org proves an email domain by publishing a DNS TXT record `_mindforge-verification.<domain>` with value `mindforge-verification=<token>`; `Verify` does the lookup (5 s timeout) and never trusts the caller. A verified domain belongs to exactly one org (partial unique index, migration 054); auto-join is only possible on verified domains. Rows self-attested before the fix were reset to unverified.
