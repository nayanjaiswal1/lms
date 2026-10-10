-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-04T17:15:14Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: JWT: The Full Story ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('d0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'JWT: The Full Story', 'jwt', 'JSON Web Tokens end to end: structure, signing vs encoding, claims, HS256/RS256/ES256, the validation checklist, access and refresh tokens, rotation and reuse detection, where to store tokens (cookie vs localStorage vs memory), revocation, common attacks, JWKS and key rotation, OAuth2/OIDC, and working FastAPI + PyJWT code. Includes a Hinglish version of the main lesson, switchable on the lesson page.', NULL, 'intermediate', ARRAY['jwt','security','authentication','backend'], 'published', true, true, 1.2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

UPDATE course_sections SET position = position + 100000 WHERE course_id = 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c';
UPDATE course_modules SET position = position + 100000 WHERE course_id = 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c';

-- Section: JWT
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('870c00b2-9d70-5ed4-936a-d3f0127c3d0b', 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c', 'JWT', 1, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3a4b456e-5e54-5c3b-abf0-bcec476ea6ac', 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c', '870c00b2-9d70-5ed4-936a-d3f0127c3d0b', 'JWT, the full story', 'notes', 0, $md$# JWT, the full story

> How to read this: every section builds intuition first, then depth. Lines marked "Interview line" are ready to say word for word in an interview.

---

## 1. What problem does JWT solve?

HTTP is **stateless**. Every request is a fresh request, and the server does not remember that "this is the same person who just logged in". So every request has to carry some proof: "I am Nayan, and I am allowed to do this."

There are two ways to carry that proof:

1. **Session (the classic way):** on login the server creates a random `session_id`, records it in its own store (DB or Redis), and gives it to the browser as a cookie. On every request the server opens its register: "whose session_id is this?"
   - Think of a **railway cloakroom**: you get a token number, but the luggage stays behind the counter. The token is just a number; the real information sits with the counter.
2. **JWT (the self-contained way):** on login the server builds a token that **carries the user's information inside it** (user id, role, expiry) and stamps it with its **signature**. The server stores nothing. On every request it only checks the stamp; if the stamp is genuine, it trusts the information inside.
   - Think of an **office ID card**: your name, department and valid-till date are printed on it, with the company hologram. The security guard at the gate does not phone HR; he checks the hologram and lets you in.

**Main benefit:** no DB or Redis hit on every request. That is why JWT is popular for microservices, mobile apps and horizontally scaled APIs. Any server, any instance, can verify the signature with the key and move on.

**Main drawback (remember this, interviewers always ask):** once you have handed out an ID card, taking it back is hard. Even if the employee resigns, the card still says "valid till December", and the guard will let them in. This is JWT's **revocation problem** (section 9).

> **Interview line:** "JWT is a compact, self-contained, signed token. The server can verify it without a database lookup, which makes it ideal for stateless and distributed systems. The trade-off is that revoking a token before it expires is hard."

---

## 2. Anatomy: `Header.Payload.Signature`

A JWT looks like this (three parts separated by dots):

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzEiLCJyb2xlIjoiYWRtaW4iLCJleHAiOjE3OTk5OTk5OTl9.<signature>
└──────────── header ────────────────┘ └──────────────────────── payload ─────────────────────────────┘ └── sig ──┘
```

### 2.1 Header: how the token was built

```json
{ "alg": "HS256", "typ": "JWT", "kid": "2026-10" }
```

| Field | Meaning |
|---|---|
| `alg` | Algorithm used for the signature (HS256, RS256, ES256, EdDSA) |
| `typ` | Token type, usually `JWT` (you will also see `at+jwt` for access tokens) |
| `kid` | Key ID: which key signed this token. Used for key rotation |

### 2.2 Payload: what the token says (claims)

```json
{ "sub": "user_1", "role": "admin", "exp": 1799999999 }
```

Each key-value pair in the payload is called a **claim**. There are three kinds:

**a) Registered claims** (defined in RFC 7519; all three letters long to keep the token small):

| Claim | Full form | What it is | Who checks it |
|---|---|---|---|
| `iss` | issuer | Who created the token (`https://auth.myapp.com`) | Verifier: must match the expected issuer |
| `sub` | subject | Who the token is about (user id) | App logic |
| `aud` | audience | Who the token is meant for (`orders-api`) | Verifier: "is this token meant for me?" |
| `exp` | expiration | When it expires (Unix seconds) | Verifier: `now < exp` |
| `nbf` | not before | Not valid before this time | Verifier: `now >= nbf` |
| `iat` | issued at | When it was created | Debugging, max-age checks |
| `jti` | JWT ID | Unique ID of the token | Revocation/blocklist, replay prevention |

**b) Public claims:** common names registered with IANA, such as `email`, `name`, `email_verified` (these come from OIDC).

**c) Private/custom claims:** your app's own claims, such as `role`, `tenant_id`, `token_version`. Pick names that will not clash with registered ones.

### 2.3 Signature: the stamp

```text
signature = HMAC_SHA256( base64url(header) + "." + base64url(payload), secret )
```

The signature covers both header and payload. If someone changes `"role":"user"` to `"role":"admin"` in the payload, the signature no longer matches, because producing a new valid signature requires the **secret key**, which only the server has.

### 2.4 The biggest confusion: Base64URL is not encryption

Burn this into memory: **a JWT payload is NOT encrypted, only encoded.** Anyone can read it by pasting it into [jwt.io](https://jwt.io) or with a few lines of code:

> Code: see `jwt_code.md`, section 2.4.

- **Encoding** = changing the format only (anyone can reverse it). Like writing Hindi in Roman script.
- **Signing** = proof that the data was not changed (integrity + authenticity). Everyone can read it; nobody can alter it.
- **Encryption** = hiding the data (confidentiality). Only the key holder can read it.

So **never** put passwords, Aadhaar, PAN, card numbers or any secret in the payload. If the data must be hidden, use **JWE** (section 11).

Why Base64**URL** and not plain Base64? Plain Base64 uses `+`, `/` and `=`, which break URLs and headers. Base64URL uses `-` and `_` instead and drops the `=` padding.

> **Interview line:** "A JWT is encoded and signed, not encrypted. Anyone can read the payload, but nobody can modify it without invalidating the signature. Sensitive data should never go into the payload; if confidentiality is required, use JWE."

---

## 3. Signing algorithms: HS256 vs RS256 vs ES256 vs EdDSA

### Symmetric: HS256 (HMAC + SHA-256)

- **One shared secret** both signs and verifies.
- Simple and fast.
- The catch: whoever can verify can also **sign**. If 10 microservices verify tokens, all 10 hold the secret, and a leak from any one of them lets an attacker forge tokens.
- Think of **a single house key** that both locks and unlocks the door. Every copy you hand out adds risk.
- The secret must be at least **256 bits (32 random bytes)**. A secret like `"secret123"` can be brute-forced offline (with hashcat, see section 10).

### Asymmetric: RS256 / ES256 / EdDSA

- Only the auth server signs, with the **private key**.
- Any service can verify with the **public key**, but cannot sign.
- Think of an **official government stamp**: only the tehsil office holds the stamp (private key), but every bank has a specimen of it (public key) so it can check whether a document is genuine.
- Public keys are published on a **JWKS endpoint** (`/.well-known/jwks.json`), see section 12.

| Algorithm | Type | Key size | When to use |
|---|---|---|---|
| HS256 | Symmetric (HMAC) | ≥ 256-bit secret | One service that both signs and verifies |
| RS256 | RSA + SHA-256 | 2048+ bit | Distributed systems; the most widely supported |
| ES256 | ECDSA P-256 | 256-bit | Same role as RS256, with smaller keys and tokens |
| EdDSA (Ed25519) | Edwards curve | 256-bit | Modern, fast, safe defaults; check library support |
| `none` | No signature | — | **Never.** It is an attack vector |

> **Interview line:** "I use HS256 when a single service both issues and verifies tokens. In a distributed system I use an asymmetric algorithm like RS256 or ES256: the auth server keeps the private key and every other service verifies with the public key from a JWKS endpoint, so a compromised service cannot forge tokens."

---

## 4. The full auth flow, step by step

```text
1. Client  → POST /login {email, password}
2. Server  → verify the password (against a bcrypt/argon2 hash)
3. Server  → create an access token (15 min) + a refresh token (7 days)
4. Server  → access token in the response body, refresh token in an httpOnly cookie
5. Client  → every API call: Authorization: Bearer <access_token>
6. Server  → verify signature + claims → process the request (no DB lookup)
7. After 15 min the access token expires → API returns 401
8. Client  → POST /auth/refresh (the cookie is sent automatically)
9. Server  → verify + rotate the refresh token → new access token (+ new refresh token)
10. Logout → revoke the refresh token, clear the cookie
```

`Bearer` means "whoever holds it owns it". Like a cinema ticket: the usher does not care whose ticket it is; show the ticket and walk in. So a stolen token means a stolen account. **HTTPS** is mandatory everywhere.

---

## 5. Verification checklist (what the server checks on every request)

"The signature is valid" is not enough. The full list:

1. **Format:** three parts, valid Base64URL, valid JSON.
2. **Algorithm allowlist:** **never read `alg` from the token**; pin it on the server (`algorithms=["RS256"]`). Skipping this is the most common bug (section 10).
3. **Signature:** verify with the right key (choose it by `kid`, but only from your own trusted JWKS).
4. **`exp`:** has it expired?
5. **`nbf`:** is it valid yet?
6. **`iss`:** is it from my trusted issuer?
7. **`aud`:** was this token issued **for my** service? (Otherwise a `payments-api` token works on `admin-api`.)
8. **Token type:** has someone sent a refresh token where an access token is expected? (Check a `type` claim or the `typ` header.)
9. **Revocation (if implemented):** is the `jti` on the blocklist? Does `token_version` match the user's current version?
10. **Authorization:** a valid token does not mean the user may access this resource. Check role, scope and ownership separately.

**Clock skew:** server clocks drift a little. Allow 30–60 seconds of `leeway`, or a fresh token will occasionally look "expired" or "not yet valid".

**`decode` vs `verify`:** many libraries offer something like `decode(..., verify=False)`. That only reads the token; it does not verify it. Never use it for auth, only for debugging.

---

## 6. Expiry, access tokens and refresh tokens

### The dilemma

- Long access-token expiry (7 days): a stolen token is usable for 7 days. **Bad security.**
- Short expiry (15 min): the user logs in every 15 minutes. **Bad UX.**

### The fix: two tokens, two jobs

| | Access token | Refresh token |
|---|---|---|
| Job | Authorize API calls | Get a new access token |
| Expiry | Short (5–15 min) | Long (7–30 days) |
| Sent to | Every API request | The cookie rides on every request, but only `/auth/refresh` reads it |
| Stored in | Memory (JS variable) | httpOnly + Secure + SameSite cookie (`__Host-` prefix, `Path=/`) |
| Server-side state | None (stateless) | **Yes**, tracked in DB/Redis |
| Format | JWT | JWT or an opaque random string (both work) |

Think of the **metro**: the access token is a single-journey token (one trip, gone quickly). The refresh token is the metro card (lasts long, but used only at the recharge counter, not at every gate). Lose the card and you can get it blocked, because it is registered in the system.

**Key point:** the refresh token has to be tracked on the server. So "JWT is fully stateless" is only half true. Real systems are **hybrid**: the access token is stateless, the refresh token is stateful. That makes revocation possible, and the DB is hit once every 15 minutes instead of on every request.

### How long should tokens live? (rough guide)

| App type | Access | Refresh |
|---|---|---|
| Banking / payments | 5 min | Short (or re-auth for sensitive actions) |
| Typical SaaS / e-commerce | 15 min | 7–14 days |
| Mobile app (long logins expected) | 15–60 min | 30–90 days, with rotation |

Also set an absolute lifetime: even with rotation, force a fresh login after, say, 90 days.

---

## 7. Refresh token rotation + reuse detection (deep dive)

**Rotation:** on every `/refresh` call, **invalidate** the old refresh token and issue a new one. One refresh token = one use.

**Reuse detection (the real magic):** suppose an attacker steals refresh token RT1.

```text
User     uses RT1 → server issues RT2 (RT1 is now marked "used")
Attacker uses RT1 → server sees: "RT1 has already been used!"
         → this is proof of theft → revoke the whole token FAMILY (RT2 too)
         → both user and attacker are logged out → user logs in again, attacker is locked out
```

The reverse order works the same way: if the attacker uses it first, the user's RT1 shows up as reused, and the family is still revoked.

Implementation idea: store each refresh token in the DB as `{jti, user_id, family_id, used, expires_at}`. Login creates a new `family_id`; every rotation adds a new `jti` to that family.

**Watch out for a race condition:** three API calls on the frontend can get a 401 at the same moment, and all three may call refresh. The first one rotates the token, the other two look like "reuse", and the user is logged out for no reason. There are two fixes; apply both:
- Frontend: keep only **one refresh request** in flight at a time (the Axios code in section 15).
- Backend: allow a short **grace window** (say 10–30 seconds) in which the old token returns the same new token.

> **Interview line:** "I rotate refresh tokens on every use and track them in token families. If an already-used refresh token is presented again, that indicates theft, so I revoke the entire family and force the user to log in again."

---

## 8. Where to store tokens (the XSS vs CSRF game)

First, the two attacks:

- **XSS (Cross-Site Scripting):** the attacker runs their own JavaScript on your site (a script in a comment box, or a compromised npm package). That script can steal anything JavaScript can read.
- **CSRF (Cross-Site Request Forgery):** the attacker's site `evil.com` makes your browser send a request to `bank.com`, and the browser **attaches cookies automatically**. The attacker cannot read the cookie, but can use it.

| Storage | Stolen via XSS? | CSRF risk? | Survives page reload? | Verdict |
|---|---|---|---|---|
| `localStorage` | **Yes**, any script can read it | No | Yes | Avoid for sensitive apps |
| `sessionStorage` | **Yes** | No | Gone when the tab closes | Same problem |
| JS memory (variable) | Hard (lives only with the page) | No | **No**, lost on reload | Best for the access token |
| httpOnly cookie | **No**, JS cannot read it | **Yes**, the browser sends it automatically | Yes | Best for the refresh token (+ CSRF protection) |

**Best-practice combination:**
- **Access token → memory.** Lost on page reload? No problem; silently call `/auth/refresh`.
- **Refresh token → httpOnly cookie** with these flags:

```text
Set-Cookie: __Host-refresh=<token>; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=604800
```

| Flag | What it does |
|---|---|
| `HttpOnly` | JS cannot read it via `document.cookie`, so XSS cannot steal it |
| `Secure` | Sent only over HTTPS |
| `SameSite=Strict` | Not sent on requests coming from another site; the main CSRF defence |
| `SameSite=Lax` | Sent on top-level GET navigation, not on cross-site POST. A good default |
| `Path=/auth/refresh` | Cookie goes only to the refresh endpoint (the `__Host-` prefix requires `Path=/`, so choose one) |
| `__Host-` prefix | Browser enforces Secure, `Path=/`, and no Domain attribute. Protects against subdomain attacks |

**A hard truth:** once XSS happens, httpOnly does not fully save you. The attacker cannot read the token, but can send requests in your name from inside your own site. httpOnly only stops the token from being **carried away**. The real cure is preventing XSS: output escaping, a CSP header, auditing dependencies.

**Mobile apps:** no cookie hassle. Store tokens in the **Keychain (iOS) / Keystore-backed EncryptedSharedPreferences (Android)**, never in plain SharedPreferences.

**BFF pattern (Backend-for-Frontend):** the most secure SPA setup. Tokens never reach the browser. The browser holds only an httpOnly session cookie; the BFF server holds the tokens and forwards API calls. You will see this in banking-grade apps.

> **Interview line:** "I keep the access token in memory and the refresh token in an HttpOnly, Secure, SameSite cookie. That protects the refresh token from XSS theft and SameSite blocks most CSRF. For the highest security in SPAs, I use the BFF pattern so tokens never reach the browser."

---

## 9. Revocation: how do you "cancel" a JWT?

A JWT is stateless, so killing it before `exp` is hard. Options, cheapest first:

| Method | How | Trade-off |
|---|---|---|
| **Short expiry** | Access token 5–15 min | Worst case is a 15-minute window. Enough for most apps |
| **Revoke the refresh token** | Delete it from DB/Redis on logout | No new access token can be issued; the current one lives until `exp` |
| **`jti` blocklist** | On logout put the `jti` in Redis, TTL = token's remaining lifetime | One Redis lookup per request (some statelessness lost) |
| **Per-user `token_version`** | Version in the user table and in the token; bump it on password change | Kills **all** of a user's tokens at once. Needs a DB/cache lookup |
| **Key rotation** | Change the signing key | Kills **everyone's** tokens. Emergencies only (key leak) |

**Which to use when:**
- Normal logout → revoke the refresh token + drop the access token on the frontend.
- "Log out of all devices" / password change → bump `token_version`.
- Account ban / suspicious activity → `jti` blocklist or `token_version`.
- Secret leaked → key rotation (everyone logs out; no way around it).

**Redis + TTL** is the right home for a blocklist. Each entry disappears on its own when the token would have expired, so there is no cleanup. An in-memory `set()` is for local dev only; it does not work across multiple instances.

**Allowlist vs blocklist:** a blocklist says "these tokens are banned" (a short list). An allowlist says "only these tokens are valid" (stores every active token). An allowlist is basically a session store, so at that point ask yourself why you are using JWT at all.

---

## 10. Attacks interviewers ask about (and defences)

### 10.1 `alg: none`
The attacker sets `"alg":"none"` in the header and strips the signature. Some old libraries accepted this as valid.
**Defence:** hardcode `algorithms=["RS256"]` on the server. Never allow `none`.

### 10.2 Algorithm confusion (RS256 → HS256)
The server expects RS256 and verifies with the public key. The attacker labels the token **HS256** and signs it using **the public key as the HMAC secret**. The public key is public; everyone has it. If the library reads `alg` from the token, it treats the public key as an HMAC secret, and the forged token **passes**.
**Defence:** same as above: pin allowed algorithms on the server. Bind key type to algorithm (an RSA key only ever with RS256).

### 10.3 Weak HS256 secret
Secrets like `secret`, `changeme`, `myapp123`. With one valid token, the attacker can **brute-force offline** (hashcat) and the server never notices. Once the secret is found, they can mint any token with any role.
**Defence:** `secrets.token_urlsafe(32)` or longer. Load it from env/a secret manager, never from code.

### 10.4 `kid` injection
The server uses the `kid` header to find a key. If the code does `open(f"keys/{kid}")` or puts `kid` into a SQL query, the attacker can send `kid: "../../dev/null"` (an empty key!) or a SQL injection.
**Defence:** treat `kid` only as a lookup into a trusted key map/JWKS. Never use it in a file path or query.

### 10.5 `jku` / `x5u` header abuse
These headers say "download the public key from here". The attacker puts in their own URL, signs with their own key, and the server verifies with the attacker's key.
**Defence:** ignore these headers. Fix the JWKS URL in server config.

### 10.6 Missing `aud` check (token substitution)
One auth server issues tokens for multiple apps. App A's token works on App B because B never checked `aud`.
**Defence:** always verify `aud` and `iss`.

### 10.7 Token leakage
A token in the URL (`?token=...`) leaks into server logs, browser history and the Referer header. Logging the full `Authorization` header leaks it too.
**Defence:** tokens only in headers/cookies. Mask tokens in logs.

### 10.8 No expiry / very long expiry
A stolen token works forever.
**Defence:** make `exp` mandatory (`options={"require": ["exp"]}`).

### 10.9 Token replay / sidejacking
The attacker uses a stolen token from a different machine.
**Defence (advanced):** **sender-constrained tokens**, where the token is bound to a key only the client holds:
- **DPoP** (OAuth 2.0 Demonstrating Proof of Possession): the client signs a proof with its private key on every request.
- **mTLS-bound tokens:** the token is bound to the client certificate.
Even if the token is stolen, it is useless without the private key.

> **Interview line:** "The most common JWT vulnerabilities are trusting the alg header, which enables alg none and RS256-to-HS256 confusion, using weak HMAC secrets that can be brute-forced offline, and skipping the aud and iss checks. I pin the allowed algorithms on the server, use strong keys from a secret manager, and validate every registered claim."

---

## 11. JWS vs JWE vs JWT (the naming mess)

- **JWT** = the name of the format/standard (RFC 7519): a JSON structure of claims.
- **JWS** (JSON Web Signature) = a **signed** token. The one we use every day, 3 parts. Readable, not modifiable.
- **JWE** (JSON Web Encryption) = an **encrypted** token with **5 parts**: `header.encryptedKey.iv.ciphertext.authTag`. Nobody can read it without the key.
- **Nested JWT** = sign first, then encrypt (sign-then-encrypt). Integrity and confidentiality.

In 90% of cases JWS + HTTPS is enough. Use JWE when the token passes through an untrusted middle party (a third party, the browser) and carries sensitive data.

Related terms: **JWK** = one key represented as JSON. **JWKS** = a set (array) of keys. **JOSE** = the name of this whole family of standards.

---

## 12. JWKS and key rotation

The auth server publishes its **public keys** at a URL:

```text
GET https://auth.myapp.com/.well-known/jwks.json
{ "keys": [
  { "kid": "2026-09", "kty": "RSA", "alg": "RS256", "use": "sig", "n": "...", "e": "AQAB" },
  { "kid": "2026-10", "kty": "RSA", "alg": "RS256", "use": "sig", "n": "...", "e": "AQAB" }
]}
```

The verifier reads `kid` from the token header, finds the matching key in the JWKS, and verifies.

**Zero-downtime rotation:**
1. **Add** the new key (`2026-10`) to the JWKS, but keep signing with the old one.
2. Let verifiers refresh their JWKS cache (say 1 hour).
3. Start **signing** with the new key.
4. Keep the old key in the JWKS until every token it signed has expired (max refresh lifetime if refresh tokens are JWTs; with opaque refresh tokens the access-token lifetime is enough).
5. Remove the old key.

**Caching:** verifiers cache the JWKS (do not fetch it on every request). On an unknown `kid`, re-fetch once, but rate-limit it, or an attacker sending random `kid`s can DoS your auth server.

---

## 13. JWT in microservices and API gateways

```text
Client → API Gateway (verify JWT: sig, exp, iss, aud) → Order Service → Payment Service
```

Common patterns:
- **Verify at the gateway, trust inside:** the gateway verifies and forwards user info in headers (`X-User-Id`). Simple, but the internal network must be trusted (not enough for zero-trust).
- **Every service verifies on its own:** fetch the public key from JWKS and verify locally. Zero-trust friendly. An asymmetric algorithm is required here.
- **Token exchange (RFC 8693):** when Order Service calls Payment Service, it does not forward the user's token. It gets a new token with `aud` = `payments` and a narrower scope, so a token for one service cannot be misused elsewhere.

**Watch token size:** a JWT travels with every request. Stuff in 50 roles and permissions and the token grows to 4–8 KB. Headers have limits (many servers allow ~8 KB) and bandwidth is wasted. Keep **identity and coarse roles** in the token; let each service look up fine-grained permissions from its own cache.

**Stale claims:** the token says `role: admin`, and the admin role is removed in the meantime. Until the token expires, the user is still admin. One more reason to keep access tokens short-lived.

---

## 14. JWT in OAuth 2.0 and OpenID Connect

This confusion is very common, so get it clear:

- **OAuth 2.0** = an **authorization** framework ("let this app read my Google Drive"). The access token can be in any format; it does not have to be a JWT.
- **OpenID Connect (OIDC)** = an **authentication** layer on top of OAuth ("who is this user"). It issues an **ID token**, which is **always a JWT**.

| | ID token | Access token |
|---|---|---|
| Meant for | The client app (who the user is) | The API/resource server |
| Format | Always JWT | JWT or opaque |
| `aud` | Client ID | API identifier |
| Send to APIs? | **No** | Yes |

Golden rule: **never send the ID token to an API, and never derive user identity from the access token on the client.** That is how "Login with Google" works: get a code with the Authorization Code + **PKCE** flow, exchange it for tokens on the backend, verify the ID token, and identify the user.

**Opaque token + introspection:** some systems use a random string as the access token, and the API asks the auth server on every call via `/introspect`: "is this valid?". You get instant revocation at the cost of a network call per request. The exact opposite trade-off to JWT.

---

## 15. Code: FastAPI + PyJWT

> FastAPI's official docs now recommend **PyJWT**. The old `python-jose` recommendation was dropped; do not use it in new projects. `pip install pyjwt` (`pyjwt[crypto]` for RS256).

### 15.1 Creating and verifying tokens

> Code: see `jwt_code.md`, section 15.1.

`except jwt.ExpiredSignatureError` must come first, because it is a subclass of `InvalidTokenError`. Reverse the order and the "expired" message never shows.

Note: use `datetime.now(timezone.utc)` for `iat`/`exp`. `datetime.utcnow()` is deprecated and returns a naive datetime.

### 15.2 Login, refresh (rotation + reuse detection), logout, revoke all sessions

> Code: see `jwt_code.md`, section 15.2.

What this code covers:
- **"Log out of all devices" / password change:** `revoke_all_sessions` sets `tokens_valid_after = now`. Both `get_current_user` and `/refresh` reject any token with an older `iat`, so access **and** refresh tokens die together. (A `token_version` claim works the same way; the timestamp version needs no extra claim.)
- **Grace window:** a token rotated less than 15 seconds ago is accepted once more instead of being treated as theft. This absorbs parallel requests and multiple tabs. The trade-off: a thief who uses the token within those 15 seconds is not caught.
- **CSRF header** on `/refresh` (section 20.3).
- **Logout** needs no valid access token: it revokes the refresh family from the cookie, and blocklists the access `jti` only if that token is still valid.
- `refresh_repo` and `users_repo` are your own DB layer (the `refresh_tokens` table in 19.5). `issue_tokens` writes there too, so a Redis wipe cannot resurrect revoked sessions.
- If the Redis mirror can be lost, fall back to reading `tokens_valid_after` from the DB on a cache miss.

### 15.3 RS256 version (only what changes)

> Code: see `jwt_code.md`, section 15.3.

### 15.4 Frontend: Axios auto-refresh (single-flight, multi-tab safe)

> Code: see `jwt_code.md`, section 15.4.

Things that matter:
- `refreshPromise` is shared, so even 5 parallel 401s trigger **only one** refresh call (the race-condition fix from section 7).
- `navigator.locks` does the same **across tabs** (section 20.2), and `BroadcastChannel` spreads logout to every tab.
- The `isRefreshCall` check stops an infinite loop if refresh itself returns 401.
- The `_retry` flag retries each request only once.
- On app load (after a page reload) memory is empty, so make a silent `/auth/refresh` call first.

---

## 16. Session vs JWT: which one when?

| | Session (opaque ID) | JWT |
|---|---|---|
| Where the data lives | Server (DB/Redis) | Inside the token (with the client) |
| Per request | Store lookup | Signature check only (CPU) |
| Scaling | Needs a shared session store | Any instance can verify |
| Revocation | Instant (delete the row) | Hard (blocklist/short expiry) |
| Size | Small (~32 bytes) | Larger (300 B to a few KB with claims) |
| Cross-domain / mobile / microservices | Awkward (cookies are domain-bound) | Easy (send in a header) |
| Stale data | Never (the store is the source of truth) | Old role/claims until `exp` |
| Best for | Monoliths, server-rendered apps, banking (instant logout) | APIs, SPAs, mobile, microservices, third-party/SSO |

**The honest truth:** JWT is not an "upgrade" over sessions; it is a different trade-off. For a single monolith on a single domain that already has Redis, a session cookie is simpler and more secure. Many teams adopt JWT because it feels "modern", then build a blocklist and end up reinventing sessions.

> **Interview line:** "Sessions give instant revocation and always-fresh data at the cost of a store lookup per request. JWTs give stateless verification that scales across services at the cost of hard revocation and stale claims. For a single web app I prefer server sessions; for APIs, mobile clients and microservices I use short-lived JWT access tokens with server-tracked, rotating refresh tokens."

---

## 17. Best practices checklist

- [ ] HTTPS everywhere. A token is a bearer credential; stolen token = stolen account.
- [ ] Access token 5–15 min; refresh token 7–30 days + an absolute lifetime.
- [ ] Allowed `algorithms` pinned on the server. Never `none`.
- [ ] Always verify `exp`, `iss`, `aud`, `nbf`. `exp` is mandatory. Leeway 30–60 s.
- [ ] HS256 secret ≥ 256-bit random, from env/a secret manager. RS256/ES256 + JWKS in distributed systems.
- [ ] No sensitive data in the payload. Only ids, roles and the claims you need.
- [ ] Access token in memory; refresh token in a `HttpOnly; Secure; SameSite` cookie.
- [ ] Refresh token rotation + reuse detection + token families.
- [ ] On logout, revoke the refresh token + `jti` blocklist (Redis TTL). On password change, bump `token_version`.
- [ ] Check the token type (never mix access and refresh).
- [ ] `kid` is only a lookup into a trusted key map. Ignore `jku`/`x5u`.
- [ ] No tokens in URLs; mask them in logs.
- [ ] Authentication ≠ authorization. Check permissions/ownership even with a valid token.
- [ ] Password change / "log out everywhere" revokes access **and** refresh tokens.
- [ ] Frontend and API on the same site (proxy or custom domain); exact-origin CORS with credentials.
- [ ] Refresh serialised across tabs; logout broadcast to all tabs; CSRF header/Origin check on `/refresh`.
- [ ] WebSockets: check `Origin` on the handshake, or use one-time tickets; close sockets when the token expires.
- [ ] Use a maintained library (PyJWT, `jsonwebtoken`, `jose` for Node). Never write your own JWT parser.

---

## 18. Interview quick-fire

**Q: What is a JWT?**
A compact, URL-safe, signed token made of a header, payload and signature, each Base64URL-encoded. The server can verify it without storing any state.

**Q: Is a JWT encrypted?**
No. A standard JWT (JWS) is encoded and signed, so anyone can read it but nobody can tamper with it. For confidentiality, use JWE.

**Q: How does the server know the token was not modified?**
It recomputes the signature over the header and payload with its key and compares it with the token's signature. Any change to the payload produces a different signature.

**Q: HS256 or RS256?**
HS256 uses one shared secret for signing and verifying, which suits a single service. RS256 uses a private key to sign and a public key to verify, which suits distributed systems because verifying services cannot forge tokens.

**Q: Why do we need refresh tokens?**
Short-lived access tokens limit the damage of theft, but would force frequent logins. A long-lived refresh token, stored securely and tracked on the server, lets the client obtain new access tokens silently.

**Q: How do you log a user out with JWTs?**
Revoke the refresh token on the server, clear the cookie, and optionally add the access token's `jti` to a Redis blocklist with a TTL equal to its remaining lifetime.

**Q: How do you log a user out of all devices?**
Store a `token_version` per user, embed it in tokens, and increment it on password change or "logout everywhere". Tokens carrying an older version are rejected. Also revoke that user's refresh families, or a stolen refresh token mints a fresh access token with the new version.

**Q: The signing secret has leaked. What now?**
Rotate the key immediately. Every existing token becomes invalid, all users must log in again, and you investigate how the leak happened.

**Q: Where should a SPA store tokens?**
Access token in memory, refresh token in an HttpOnly, Secure, SameSite cookie. localStorage is readable by any script, so an XSS bug would leak the token.

**Q: What is the `alg: none` / algorithm confusion attack?**
The attacker changes the `alg` header so a vulnerable library skips verification or uses the RSA public key as an HMAC secret. The fix is to pin the accepted algorithms on the server.

**Q: What is refresh token reuse detection?**
Each refresh token is single-use. If an already-used refresh token appears again, it indicates theft, so the server revokes the whole token family.

**Q: ID token vs access token?**
An ID token is a JWT from OpenID Connect that tells the client who the user is. An access token is sent to APIs to authorize requests. Never use an ID token to call an API.

**Q: What happens if a user's role changes while their token is still valid?**
The token keeps the old role until it expires. Short access-token lifetimes limit this window; for critical changes, use `token_version` or a blocklist.

**Q: Can you put a JWT in the URL?**
Avoid it. URLs end up in server logs, browser history and Referer headers, which leaks the token.

**Terms in one line each:** Bearer token (whoever holds it can use it) · Claim (one key-value in the payload) · JWS (signed) · JWE (encrypted) · JWK (one key as JSON) · JWKS (published set of public keys) · `kid` (key ID for rotation) · `jti` (unique token ID for revocation) · DPoP (binds a token to a client key) · PKCE (protects the OAuth authorization code flow) · Introspection (asking the auth server whether an opaque token is valid).

---

## 19. When things leak: incident playbooks and where everything is stored

### 19.1 The signing secret / private key leaks

**Impact (the worst case in JWT):** the attacker can mint a token for **any user, any role, any expiry**. A `jti` blocklist is useless (they just invent new `jti`s). Even refresh tokens can be forged if they are JWTs. The only real fix is changing the key.

**Playbook:**
1. **Generate a new key and deploy it immediately.** Remove the old key from verifiers **at once** (from the accepted-secrets map for HS256, from the JWKS for RS256). Unlike planned rotation there is **no grace period**, because every token signed with the old key is now untrustworthy.
2. **Everyone gets logged out.** Revoke every refresh token family too (truncate the refresh-token table/Redis keys, or bump a global epoch, see 19.6).
3. **Find the source:** git history, CI logs, an env dump in an error page, a laptop, a third-party service. Rotate whatever credentials exposed it (secret manager access, CI tokens).
4. **Assess damage:** if you log every issued `jti`, any valid-looking token with a `jti` you never issued is proof of forgery. Check audit logs for admin actions in the exposure window.
5. **Notify** users/security team according to policy; force password resets if account data could have been accessed.

**Prevention:**
- Keys live in a **secret manager** (Vault, AWS Secrets Manager, GCP Secret Manager), never in git or `.env` files that get committed.
- Better still, **KMS/HSM signing**: the private key never leaves the HSM; your auth server calls the KMS `Sign` API. Even a fully compromised server cannot copy the key.
- Separate keys per environment (dev/staging/prod). A dev leak must not touch prod.
- **Scheduled rotation** (e.g. every 90 days) so the rotation procedure is practiced, not invented during an incident.

### 19.2 Planned rotation of an HS256 secret

> Code: see `jwt_code.md`, section 19.2.

HS256 has no JWKS, but the same idea works: keep **several secrets keyed by `kid`**, sign with the current one, verify with whichever the token names.

Steps: add the new secret to `KEYS` → deploy everywhere → switch `SIGNING_KID` to the new one → wait for the longest token lifetime (the refresh TTL if refresh tokens are JWTs) → remove the old secret.

### 19.3 A client's access token is stolen

**Impact:** the attacker acts as the user until `exp` (at most 15 minutes if you followed the advice). Without the refresh cookie they cannot get a new one.

**How it gets stolen:** XSS reading localStorage, malware on the device, a token in a URL/log, a proxy logging headers, or a non-HTTPS hop.

**Detection signals (none is perfect):**
- The same `jti` used from two very different IPs/ASNs/user agents at the same time.
- Impossible travel (Mumbai and Frankfurt within 5 minutes).
- A burst of unusual actions (bulk export, password/email change).

**Response:** put the `jti` in the blocklist, or bump the user's `token_version` to kill all their tokens; revoke their refresh families; force re-login and, if needed, a password reset. If XSS was the cause, fix the XSS, or the next token will be stolen too.

**Note:** Binding a token to the IP is usually too brittle (mobile users switch networks all the time); a hashed device fingerprint in the token is a softer signal.

### 19.4 A refresh token is stolen

Rotation + reuse detection (section 7) catches it **only when both parties use the same token**. Its blind spot: if the attacker refreshes first and the real user never comes back (closed the laptop for a week), the attacker keeps rotating and nobody notices.

Extra defences:
- **Absolute lifetime** (e.g. 30–90 days) and an **idle timeout** (e.g. no use in 7 days → dead), so a stolen family dies eventually.
- **Device binding:** store device id / user agent / IP range with the family; a refresh from a totally different device is suspicious → step-up auth (OTP).
- **"Active sessions" screen** (like Google/Netflix): list families with device and location, each with a "log out" button. Users catch theft themselves.
- **Login/new-device alerts** by email or push.
- Rate-limit `/auth/refresh`.

### 19.5 Where everything is stored

| Item | Lives in | Notes |
|---|---|---|
| Signing secret / private key | Secret manager or KMS/HSM, injected at startup | Never in git, DB, logs or the client |
| Public keys | JWKS endpoint; verifiers cache them in memory | Safe to expose |
| Access token | Client memory only | Server stores nothing (that is the point) |
| Refresh token (client side) | `HttpOnly; Secure; SameSite` cookie (web), Keychain/Keystore (mobile) | Never localStorage |
| Refresh token (server side) | DB table (durable source of truth), optionally mirrored in Redis for speed | Store a **SHA-256 hash** of opaque tokens, never the raw value, so a DB leak does not hand out working tokens. For JWT refresh tokens, storing the `jti` is enough |
| Access-token blocklist (`jti`) | **Redis**, key `jwt:block:<jti>`, TTL = remaining token lifetime | Shared by all instances; auto-cleans itself |
| `token_version` / `tokens_valid_after` | `users` table in the DB, cached in Redis | Checked on every request if you use it |
| Audit log of issued `jti`s | Append-only log/DB | Lets you detect forged tokens after a key leak |

A typical refresh-token table:

> Code: see `jwt_code.md`, section 19.5.

**What if Redis is down?** Decide in advance:
- **Fail closed** (reject requests when the blocklist cannot be checked): safer; right for banking/admin APIs.
- **Fail open** (skip the check): more available; acceptable only because access tokens die in 15 minutes anyway.

**What if Redis restarts and loses data?** Revoked access tokens become valid again until their `exp`. With 15-minute tokens that is usually tolerable; otherwise enable Redis persistence (AOF). Refresh-token state must live in the DB precisely so a cache wipe cannot resurrect revoked sessions.

**Performance at scale:** a Redis lookup per request is cheap (sub-millisecond), but at very high traffic the gateway can keep a short local cache or a **Bloom filter** of revoked `jti`s and only hit Redis on a possible match.

### 19.6 The "valid after" trick (revoke without listing tokens)

Instead of storing every revoked token, store **one timestamp**: "tokens issued before this moment are dead".
- Per user: `users.tokens_valid_after`. On password change set it to `now()`; reject any token with `iat < tokens_valid_after`.
- Global: one `global_tokens_valid_after` value. After a key leak or a breach, set it to `now()` and every token in the system dies, even without changing the key.

### 19.7 Edge cases most people miss

1. **Password change must also kill refresh tokens.** Bumping `token_version` only kills access tokens. If the refresh endpoint does not check it too, an attacker holding a stolen refresh token simply mints a fresh access token with the *new* version. On password change: bump the version **and** revoke every refresh family of that user.
2. **Opaque refresh tokens survive a key leak.** If refresh tokens are random strings checked against the DB (not JWTs), forging them is impossible even with the leaked signing key. Only access tokens need cleanup. This is a strong argument for opaque refresh tokens.
3. **SHA-256, not bcrypt, for refresh tokens.** Passwords are low-entropy, so they need a slow hash (bcrypt/argon2) to resist guessing. A refresh token is 256 random bits, which nobody can brute-force, so a fast SHA-256 is enough and keeps `/refresh` fast. Compare hashes with a constant-time function (`hmac.compare_digest`) or look them up by indexed equality.
4. **CORS misconfiguration turns CSRF into token theft.** SameSite and CORS normally stop `evil.com` from *reading* the `/auth/refresh` response. But if the server reflects any `Origin` in `Access-Control-Allow-Origin` together with `Access-Control-Allow-Credentials: true`, the attacker's page can call `/refresh` with the victim's cookie and read the new access token. Allowlist exact origins only.
5. **Multi-region blocklist lag.** Redis replication across regions takes time; a token revoked in Mumbai can still work in Singapore for a few seconds. Usually acceptable; for critical revocation (account takeover), also bump `tokens_valid_after` in the primary DB.
6. **Mass logout causes a thundering herd.** After a key rotation every user hits `/login` and `/refresh` at once. Expect a spike on the auth service and the user DB: scale it up beforehand, keep rate limits sane, and show a friendly "please sign in again" page instead of errors.
7. **Logs and monitoring tools are a leak vector.** APM/error trackers (Sentry, Datadog) and reverse proxies can capture full request headers and cookies. Scrub `Authorization` and `Cookie` before they leave the app.
8. **Catch leaks before they happen.** Run secret scanning in CI and pre-commit hooks (gitleaks, trufflehog, GitHub secret scanning). A secret pushed to a public repo is scraped by bots within minutes, so deleting the commit is not enough: rotate.
9. **Limit the blast radius of a forged or stolen token.** Require step-up auth (password or OTP again) for sensitive actions: changing email or password, adding a payee, large payments. Even a perfectly valid stolen token cannot then do the worst damage.
10. **Logout must work even with an expired access token.** If logout demands a valid access token, a user whose token has just expired cannot log out cleanly. Either refresh first (the Axios interceptor does this) or let `/logout` accept the refresh cookie alone. Also tolerate an expired refresh token and still clear the cookie.

> **Interview line:** "If the signing key leaks, attackers can forge any token, so I rotate the key immediately with no grace period, revoke all refresh tokens, and trace the leak. Keys live in a secret manager or KMS so the application never holds the raw private key. For a stolen access token, short expiry limits the window and I can blocklist its jti in Redis. For stolen refresh tokens, rotation with reuse detection, absolute and idle timeouts, and an active-sessions screen cover the gaps. Refresh tokens are stored hashed in the database, and the blocklist lives in Redis with a TTL equal to each token's remaining lifetime."

---

## 20. Real-world setups and remaining topics

### 20.1 Frontend and API on different sites (the cookie trap)

First, two words people mix up:
- **Origin** = scheme + host + port. `https://app.myapp.com` and `https://api.myapp.com` are **different origins**. CORS works on origins.
- **Site** = scheme + registrable domain (eTLD+1). Both of the above are the **same site** (`myapp.com`). `SameSite` cookies work on sites.

The trap: frontend on `myapp.vercel.app`, API on `myapp-api.onrender.com`. These are **different sites** (and `vercel.app`/`onrender.com` are on the Public Suffix List, so even two subdomains of `vercel.app` are different sites). Result:
- A `SameSite=Strict` or `Lax` refresh cookie is **never sent** with the frontend's fetch to the API. Refresh fails silently and users get logged out after 15 minutes.
- Switching to `SameSite=None; Secure` sends the cookie again, but now it is a **third-party cookie**. Safari and Firefox block those by default and Chrome lets users block them, so it breaks for a large share of users. You also lose SameSite's CSRF protection and must add your own (20.3).

Fixes, best first:
1. **Same origin via a proxy:** the frontend host rewrites `/api/*` to the backend (Vercel/Next.js rewrites, Nginx). The browser only ever talks to `myapp.com`, so there is no CORS and the cookie is first-party. Simplest and most robust.
2. **Same site via a custom domain:** `app.myapp.com` + `api.myapp.com`. The cookie is first-party, `SameSite=Lax/Strict` works, and you still need CORS with credentials and an **exact** allowed origin (`Access-Control-Allow-Origin: https://app.myapp.com` + `Access-Control-Allow-Credentials: true`; a wildcard `*` is not allowed with credentials).
3. **Truly cross-site (only if unavoidable):** `SameSite=None; Secure; Partitioned` (CHIPS) + a CSRF token, and accept that some browsers will still break it. A BFF on the frontend's own domain usually beats this.

### 20.2 Multiple tabs

Every tab has its own JS memory, so every tab holds its own access token, but they all share **one refresh cookie**. Two problems:
- **False theft alarms:** tabs A and B both get a 401 and both call `/refresh` with the same cookie. A rotates it; B's request looks like reuse, and the whole family is revoked. The per-tab `refreshPromise` does not help, because it lives inside one tab.
- **Half-logged-out state:** logging out in tab A leaves tab B with a working access token in memory.

Fixes (both in the 15.4 code):
- `navigator.locks.request("auth-refresh", ...)`: the Web Locks API is shared by all tabs of the origin, so tabs refresh one after another, and each one sends the newest cookie.
- `BroadcastChannel("auth")`: on logout, tell every tab to drop its token and go to the login page.

### 20.3 CSRF protection for `/refresh` beyond SameSite

SameSite is the first line of defence; add one more layer because of older browsers, `SameSite=None` setups and same-site attacks from a compromised subdomain.
- **Required custom header** (`X-Requested-With: XMLHttpRequest`, used in 15.2): an HTML form cannot set custom headers, and a cross-origin `fetch` with a custom header triggers a CORS preflight, which your exact-origin CORS policy rejects. Cheap and effective for JSON APIs.
- **Origin check:** reject state-changing requests whose `Origin` header is not on your allowlist.
- **Double-submit token:** set a random value in a readable (non-httpOnly) cookie; the client copies it into a header; the server checks they match. An attacker's site can make the browser send the cookie but cannot read it to fill the header. Use this when you need classic CSRF tokens (for example with `SameSite=None`).

### 20.4 WebSockets

The browser `WebSocket` API **cannot set custom headers**, so `Authorization: Bearer` is not an option. Choices:
- **Cookie on the handshake:** works when the WebSocket is same-site. WebSockets are **not protected by CORS**, so you must check the `Origin` header on the handshake yourself, or any site can open a socket with the user's cookie (Cross-Site WebSocket Hijacking).
- **One-time ticket:** the client calls `POST /ws-ticket` with its bearer token, gets a random single-use ticket valid for ~30 seconds, and connects to `wss://api/ws?ticket=...`. The ticket is in the URL, but it is useless after one use or 30 seconds.
- **First-message auth:** connect without credentials, send the token as the first message, and the server closes the socket if it does not arrive within a few seconds.

Long-lived connections outlive the token: the server must remember `exp` and close the socket (or demand a fresh token over the socket) when it passes, and also react to revocation.

### 20.5 Service-to-service tokens (no user involved)

A cron job or Order Service calling Payment Service has no user to log in. Use the **OAuth 2.0 Client Credentials flow**:
1. The service authenticates to the auth server with its own credentials (client secret, or better, a signed JWT assertion / mTLS).
2. It gets a short-lived access token with `sub` = the service's client id and only the scopes it needs (`payments:charge`).
3. It caches the token and requests a new one shortly before `exp`. **There is no refresh token** in this flow; the service simply asks again.

Do not let services reuse a user's token for background work, and never share one god-token between all services.

### 20.6 Scopes vs roles

- **Role** = who the user is (`admin`, `support`). Coarse, belongs to the user.
- **Scope** = what **this particular token** may do (`orders:read`, `profile:write`). Fine-grained, belongs to the token.
- They differ when a third-party app acts for you: you may be an admin, but the token you granted to a reporting tool should only carry `reports:read`. Effective permission = what the user is allowed **and** what the token's scopes allow.
- Format: `scope` is a space-separated string (`"orders:read orders:write"`); some providers use an `scp` array. Check scopes in each endpoint, not only at the gateway.

### 20.7 PASETO, the alternative to JWT

PASETO (Platform-Agnostic Security Tokens) was designed to remove JWT's footguns:
- **No `alg` header.** The version and purpose are fixed in the prefix (`v4.public.` = Ed25519 signature, `v4.local.` = symmetric encryption). Algorithm confusion and `alg: none` are impossible by design.
- `local` tokens are **encrypted by default**, so the payload cannot be read.
- Downsides: a smaller ecosystem, and OAuth/OIDC require JWTs, so you cannot use PASETO for ID tokens or with most identity providers.

Good interview answer: "If I control both issuer and verifier and do not need OIDC interoperability, PASETO is safer by design. Otherwise I use JWT with pinned algorithms."

### 20.8 Admin impersonation

Support staff sometimes need to "log in as" a user. Do it explicitly, never by sharing passwords:
- Issue a token with `sub` = the user and an **`act` claim** naming the real actor: `"act": {"sub": "admin_7"}` (RFC 8693).
- Audit logs record both identities, so every action shows "admin_7 acting as user_42".
- Keep the token short-lived and block dangerous actions while impersonating (changing password or email, payouts).

### 20.9 Small validation details

- **`iat` in the future:** a token issued "tomorrow" points to a bad clock or forgery. Reject it beyond the leeway. PyJWT does this when `iat` is present; confirm it for other libraries.
- **"Remember me":** it only changes the refresh token. Unchecked → no `Max-Age` (the cookie dies when the browser closes) and a short refresh lifetime. Checked → a persistent cookie with a long lifetime. The access token stays 15 minutes either way.
- **Absolute session cap:** store the original login time in the family (`auth_time`) and refuse to refresh past it, even with rotation.

### 20.10 Tests to keep

The minimum set that fails if the security logic breaks:

> Code: see `jwt_code.md`, section 20.10.

Also cover, as integration tests against `/auth/refresh`: wrong `aud`/`iss` rejected, refresh-token reuse after the grace window revokes the family, a revoked family cannot refresh, `revoke_all_sessions` kills both token types, and a request without the CSRF header gets 403.

> **Interview line:** "In production the hard parts of JWT are rarely the signature. They are cookie behaviour across sites, refresh races between tabs, CSRF on the refresh endpoint, and authenticating WebSockets. I keep the API on the same site as the frontend, serialise refreshes across tabs, require a custom header on refresh, and use short-lived tickets for WebSockets."

---

## 21. Active recall: answer without scrolling up

1. What are the three parts of a JWT, and which part protects against tampering?
2. Give a one-line difference between "encoded", "signed" and "encrypted".
3. Why must the verifier never read `alg` from the token header? Name both attacks.
4. What can go wrong if you skip the `aud` check? Give a real scenario.
5. Why the access token in memory and the refresh token in an httpOnly cookie? Which attack does each choice defend against?
6. Why is XSS still dangerous even with an httpOnly cookie?
7. Explain refresh token reuse detection step by step. Which frontend race condition can break it, and what is the fix?
8. How do you invalidate all of a user's tokens on password change without rotating the signing key?
9. What TTL do you give a blocklist entry, and why?
10. List the 5 steps of zero-downtime key rotation.
11. Why is sending an ID token to an API wrong?
12. For a single monolith app, would you choose JWT or sessions? Justify it in 3–4 lines of interview-style English.
13. The HS256 secret has leaked. Walk through your first five actions. Why is there no grace period here, unlike planned rotation?
14. How do you rotate an HS256 secret without logging anyone out?
15. What is the blind spot of refresh-token reuse detection, and which three defences cover it?
16. Where do you store the signing key, the refresh token (client and server), the blocklist and `token_version`? Why store refresh tokens hashed?
17. Redis is down: fail open or fail closed? Defend your choice for a banking app and for a blog.
18. Your frontend is on `vercel.app` and your API on `onrender.com`. Why does the refresh cookie stop working, and what are the three fixes in order of preference?
19. Two tabs refresh at the same moment and the user is logged out. Why, and how do you fix it on the frontend and the backend?
20. How do you authenticate a WebSocket connection when the browser cannot send an `Authorization` header? What is Cross-Site WebSocket Hijacking?
21. Scope vs role: explain with a third-party app example.
22. What does PASETO remove compared to JWT, and when can't you use it?
$md$, 60, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6526cfd2-7895-510f-8c24-9abf76612c20', 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c', '870c00b2-9d70-5ed4-936a-d3f0127c3d0b', 'JWT code with FastAPI and PyJWT', 'notes', 1, $md$# JWT code

### 2.4 The biggest confusion: Base64URL is not encryption

```python
import base64, json
part = token.split(".")[1]
print(json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))))
```

### 15.1 Creating and verifying tokens

```python
import uuid
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings  # JWT_SECRET, JWT_ISSUER, JWT_AUDIENCE come from env

ALGORITHM = "HS256"
ACCESS_TTL = timedelta(minutes=15)
REFRESH_TTL = timedelta(days=7)
LEEWAY = timedelta(seconds=30)  # clock skew


def create_token(sub: str, token_type: str, ttl: timedelta, **extra) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "type": token_type,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "iat": now,
        "exp": now + ttl,
        "jti": str(uuid.uuid4()),
        **extra,
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=ALGORITHM)


def decode_token(token: str, expected_type: str) -> dict:
    try:
        claims = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[ALGORITHM],  # never take alg from the token
            audience=settings.JWT_AUDIENCE,
            issuer=settings.JWT_ISSUER,
            leeway=LEEWAY,
            options={"require": ["exp", "iat", "sub", "jti"]},
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    if claims.get("type") != expected_type:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong token type")
    return claims


bearer = HTTPBearer()


def tokens_valid_after(user_id: str) -> int:
    # Redis mirror of users.tokens_valid_after (section 19.6); 0 = never revoked
    return int(redis.get(f"user:valid_after:{user_id}") or 0)


def get_current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> dict:
    claims = decode_token(creds.credentials, "access")
    if redis.exists(f"jwt:block:{claims['jti']}") or claims["iat"] < tokens_valid_after(claims["sub"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token revoked")
    return claims
```

### 15.2 Login, refresh (rotation + reuse detection), logout, revoke all sessions

```python
from fastapi import APIRouter, Cookie, Request, Response

router = APIRouter(prefix="/auth")
REFRESH_COOKIE = "__Host-refresh"
CSRF_HEADER, CSRF_VALUE = "X-Requested-With", "XMLHttpRequest"
GRACE = timedelta(seconds=15)  # parallel requests/tabs may still send the just-rotated token

# One atomic step: consume the token and open the grace window, or report reuse
ROTATE = redis.register_script("""
if redis.call('GETDEL', KEYS[1]) then
  redis.call('SET', KEYS[2], '1', 'EX', ARGV[1])
  return 1
end
return redis.call('EXISTS', KEYS[2])
""")


def issue_tokens(response: Response, user_id: str, family: str) -> dict:
    jti = str(uuid.uuid4())
    refresh = create_token(user_id, "refresh", REFRESH_TTL, jti=jti, fam=family)  # extra overrides the default jti
    redis.setex(f"rt:{jti}", REFRESH_TTL, family)  # "unused" refresh token
    refresh_repo.add(jti=jti, family_id=family, user_id=user_id)  # durable record (section 19.5); Redis is the fast path
    response.set_cookie(
        REFRESH_COOKIE, refresh, httponly=True, secure=True, samesite="strict",
        path="/", max_age=int(REFRESH_TTL.total_seconds()),
    )
    return {"access_token": create_token(user_id, "access", ACCESS_TTL), "token_type": "bearer"}


@router.post("/login")
def login(body: LoginIn, response: Response):
    user = authenticate(body.email, body.password)  # bcrypt/argon2 verify
    return issue_tokens(response, user.id, family=str(uuid.uuid4()))


@router.post("/refresh")
def refresh(request: Request, response: Response, token: str | None = Cookie(None, alias=REFRESH_COOKIE)):
    # A custom header forces a CORS preflight, so a cross-site form/fetch cannot send it (section 20.3)
    if request.headers.get(CSRF_HEADER) != CSRF_VALUE:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Missing CSRF header")
    if not token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "No refresh token")
    claims = decode_token(token, "refresh")
    family = claims["fam"]
    # Password change / "log out everywhere" must kill refresh tokens too, not only access tokens
    if redis.exists(f"fam:revoked:{family}") or claims["iat"] < tokens_valid_after(claims["sub"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session revoked")
    jti = claims["jti"]
    if not ROTATE(keys=[f"rt:{jti}", f"rt:grace:{jti}"], args=[int(GRACE.total_seconds())]):
        redis.setex(f"fam:revoked:{family}", REFRESH_TTL, "1")  # Reuse after the grace window = theft, revoke the whole family
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Refresh token reuse detected")
    return issue_tokens(response, claims["sub"], family)


def revoke_all_sessions(user_id: str) -> None:
    """Call on password change, 'log out of all devices', or account takeover."""
    now = int(datetime.now(timezone.utc).timestamp())
    users_repo.set_tokens_valid_after(user_id, now)  # DB is the source of truth
    redis.set(f"user:valid_after:{user_id}", now)     # fast path read by every request


optional_bearer = HTTPBearer(auto_error=False)


@router.post("/logout")
def logout(response: Response, creds: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
           token: str | None = Cookie(None, alias=REFRESH_COOKIE)):
    # works even if the access token already expired; refresh cookie alone is enough
    now = int(datetime.now(timezone.utc).timestamp())
    for raw, kind in ((creds.credentials if creds else None, "access"), (token, "refresh")):
        if not raw:
            continue
        try:
            claims = decode_token(raw, kind)
        except HTTPException:
            continue  # expired/invalid: nothing left to revoke
        if kind == "access":
            redis.setex(f"jwt:block:{claims['jti']}", max(claims["exp"] - now, 1), "1")  # TTL = token's remaining lifetime
        else:
            redis.setex(f"fam:revoked:{claims['fam']}", REFRESH_TTL, "1")
    response.delete_cookie(REFRESH_COOKIE, path="/", secure=True, httponly=True, samesite="strict")  # attrs must match set_cookie, __Host- needs Secure
    return {"ok": True}
```

### 15.3 RS256 version (only what changes)

```python
private_key = settings.JWT_PRIVATE_KEY_PEM  # auth server only
public_key = settings.JWT_PUBLIC_KEY_PEM    # every service

jwt.encode(payload, private_key, algorithm="RS256", headers={"kid": settings.JWT_KID})
jwt.decode(token, public_key, algorithms=["RS256"], audience=..., issuer=...)

# Fetching the key from JWKS (in other services):
jwks_client = jwt.PyJWKClient(settings.JWKS_URL)  # caches internally
signing_key = jwks_client.get_signing_key_from_jwt(token)
jwt.decode(token, signing_key.key, algorithms=["RS256"], audience=..., issuer=...)
```

### 15.4 Frontend: Axios auto-refresh (single-flight, multi-tab safe)

```js
let accessToken = null;      // in memory, not localStorage
let refreshPromise = null;   // only one refresh at a time in this tab
const CSRF_HEADERS = { "X-Requested-With": "XMLHttpRequest" };
const authChannel = new BroadcastChannel("auth");

authChannel.onmessage = (e) => {
  if (e.data === "logout") { accessToken = null; redirectToLogin(); }   // logout in one tab = logout in all
};

function refreshAccessToken() {
  // Web Locks are shared across tabs: tabs take turns, and each one sends the latest cookie,
  // so two tabs never present the same refresh token (no false "reuse detected")
  return navigator.locks.request("auth-refresh", () =>
    api.post(REFRESH_URL, null, { withCredentials: true, headers: CSRF_HEADERS })
      .then((r) => (accessToken = r.data.access_token)));
}

async function logout() {
  await api.post(LOGOUT_URL, null, { withCredentials: true });
  accessToken = null;
  authChannel.postMessage("logout");
  redirectToLogin();
}

api.interceptors.request.use((config) => {
  if (accessToken) config.headers.Authorization = `Bearer ${accessToken}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  async (error) => {
    const original = error.config;
    const isRefreshCall = original.url === REFRESH_URL;
    if (error.response?.status !== 401 || original._retry || isRefreshCall) {
      return Promise.reject(error);
    }
    original._retry = true;
    refreshPromise ??= refreshAccessToken()
      .catch((e) => { accessToken = null; redirectToLogin(); throw e; })
      .finally(() => { refreshPromise = null; });
    await refreshPromise;
    original.headers.Authorization = `Bearer ${accessToken}`;
    return api(original);
  }
);
```

### 19.2 Planned rotation of an HS256 secret

```python
KEYS = settings.JWT_KEYS              # {"2026-10": "<new>", "2026-07": "<old>"} from the secret manager
SIGNING_KID = settings.JWT_CURRENT_KID


def encode(payload: dict) -> str:
    return jwt.encode(payload, KEYS[SIGNING_KID], algorithm="HS256", headers={"kid": SIGNING_KID})


def decode(token: str) -> dict:
    kid = jwt.get_unverified_header(token).get("kid")  # kid is only a lookup key, never trusted for anything else
    key = KEYS.get(kid)
    if key is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Unknown signing key")
    return jwt.decode(token, key, algorithms=["HS256"], audience=..., issuer=...)
```

### 19.5 Where everything is stored

```sql
CREATE TABLE refresh_tokens (
    jti          UUID PRIMARY KEY,
    family_id    UUID NOT NULL,
    user_id      BIGINT NOT NULL REFERENCES users(id),
    token_hash   CHAR(64),                  -- only if refresh tokens are opaque (sha256); JWT refresh tokens are identified by jti
    device_info  TEXT,
    ip           INET,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    used_at      TIMESTAMPTZ,               -- set on rotation; non-null + reused = theft
    revoked_at   TIMESTAMPTZ,
    expires_at   TIMESTAMPTZ NOT NULL
);
CREATE INDEX ON refresh_tokens (family_id);
CREATE INDEX ON refresh_tokens (user_id);
```

### 20.10 Tests to keep

```python
import base64, json
from datetime import timedelta

import pytest
from fastapi import HTTPException


def b64(data: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(data).encode()).rstrip(b"=").decode()


def test_rejects_alg_none():
    token = f'{b64({"alg": "none", "typ": "JWT"})}.{b64({"sub": "user_1", "type": "access"})}.'
    with pytest.raises(HTTPException):
        decode_token(token, "access")


def test_rejects_tampered_payload():
    header, _, signature = create_token("user_1", "access", ACCESS_TTL).split(".")
    with pytest.raises(HTTPException):
        decode_token(f'{header}.{b64({"sub": "admin", "type": "access"})}.{signature}', "access")


def test_rejects_expired_token():
    with pytest.raises(HTTPException, match="expired"):
        decode_token(create_token("user_1", "access", timedelta(minutes=-5)), "access")


def test_rejects_refresh_token_used_as_access():
    with pytest.raises(HTTPException, match="Wrong token type"):
        decode_token(create_token("user_1", "refresh", REFRESH_TTL), "access")
```
$md$, 15, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('b815406f-7919-5387-89a4-6576e674d99b', '00000000-0000-0000-0000-000000000014', 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c' AND id NOT IN ('3a4b456e-5e54-5c3b-abf0-bcec476ea6ac', '6526cfd2-7895-510f-8c24-9abf76612c20');
DELETE FROM course_sections WHERE course_id = 'd0bebd66-bcfb-5c6a-b6a0-1043ab07ae0c' AND id NOT IN ('870c00b2-9d70-5ed4-936a-d3f0127c3d0b');

