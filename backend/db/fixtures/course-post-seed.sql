-- Course post-seed: hand-written translations applied AFTER the generated
-- course SQL. Idempotent. Not auto-loaded by SeedDev; run manually.

-- ══ merged from engineering-playbook.post-seed.sql ══

-- Post-seed for The Engineering Playbook course (content/courses/engineering-playbook). Run AFTER the generated
-- course SQL and after migration 049 (module_translations). Idempotent.
-- Hinglish (Hindi in Latin script) version of the main lesson, shown via the
-- lesson language switcher; BCP-47 tag hi-Latn.
INSERT INTO module_translations (module_id, locale, content_body)
SELECT cm.id, 'hi-Latn', $jwt_hi_body$# JWT, poori kahani

> Approach: har section pehle Hinglish mein intuition banata hai. Jahan "Interview line" likha hai, wo formal English mein hai, taaki interview mein seedha bol sako.

---

## 1. Problem kya tha? JWT aaya hi kyun?

HTTP **stateless** hai. Har request ek nayi request hai, server ko yaad nahi rehta ki "ye wahi banda hai jisne abhi login kiya tha". Isliye har request ke saath kuch proof bhejna padta hai ki "main Nayan hoon, aur mujhe ye access hai".

Iske do tareeke hain:

1. **Session (purana desi tareeka):** login pe server ek random `session_id` banata hai, apne paas (DB ya Redis mein) likh leta hai, aur browser ko cookie mein de deta hai. Har request pe server apna register kholta hai: "ye session_id kiska hai?"
   - Socho **railway cloakroom**: tumhe ek token number milta hai, saaman counter ke andar rakha hai. Token sirf number hai, asli info counter ke paas hai.
2. **JWT (self-contained tareeka):** login pe server ek token banata hai jisme user ki info **khud likhi hoti hai** (user id, role, expiry), aur server us pe apna **signature/mohar** laga deta hai. Server ko kuch store nahi karna. Har request pe bas mohar check karo, sahi hai to andar ki info pe bharosa karo.
   - Socho **office ka ID card**: card pe naam, department, valid-till date sab chhapa hai, aur company ka hologram laga hai. Gate wala guard HR ko phone nahi karta, bas hologram dekhta hai aur andar jaane deta hai.

**Main fayda:** server ko har request pe DB/Redis hit nahi karna padta. Isliye ye microservices, mobile apps aur horizontally scaled APIs mein bahut popular hai. Koi bhi server, koi bhi instance, bas key se signature verify karo, ho gaya.

**Main nuksaan (yaad rakhna, interview mein yahi poochenge):** ID card ek baar de diya to wapas lena mushkil hai. Banda resign kar de, phir bhi card pe "valid till Dec" likha hai, to guard andar jaane dega. Yahi JWT ka **revocation problem** hai (section 9).

> **Interview line:** "JWT is a compact, self-contained, signed token. The server can verify it without a database lookup, which makes it ideal for stateless and distributed systems. The trade-off is that revoking a token before it expires is hard."

---

## 2. JWT ki shakal: `Header.Payload.Signature`

Ek JWT aisa dikhta hai (teen hisse, dot se alag):

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzEiLCJyb2xlIjoiYWRtaW4iLCJleHAiOjE3OTk5OTk5OTl9.<signature>
└──────────── header ────────────────┘ └──────────────────────── payload ─────────────────────────────┘ └── sig ──┘
```

### 2.1 Header: "token kaise bana hai"

```json
{ "alg": "HS256", "typ": "JWT", "kid": "2026-10" }
```

| Field | Matlab |
|---|---|
| `alg` | Signature kis algorithm se bana (HS256, RS256, ES256, EdDSA) |
| `typ` | Token type, usually `JWT` (access token ke liye `at+jwt` bhi dekhoge) |
| `kid` | Key ID. Kaunsi key se sign hua, key rotation mein kaam aata hai |

### 2.2 Payload: "token kiske baare mein hai" (claims)

```json
{ "sub": "user_1", "role": "admin", "exp": 1799999999 }
```

Payload ke andar ke har key-value ko **claim** bolte hain. Teen type ke claims hote hain:

**a) Registered claims** (RFC 7519 mein defined, sab short 3-letter names, taaki token chhota rahe):

| Claim | Full form | Kya hai | Check kaun karta hai |
|---|---|---|---|
| `iss` | issuer | Kisne token banaya (`https://auth.myapp.com`) | Verifier: expected issuer se match karo |
| `sub` | subject | Token kiske baare mein hai (user id) | App logic |
| `aud` | audience | Token kiske liye bana (`orders-api`) | Verifier: "kya ye mere liye hai?" |
| `exp` | expiration | Kab expire hoga (Unix seconds) | Verifier: `now < exp` |
| `nbf` | not before | Isse pehle valid nahi | Verifier: `now >= nbf` |
| `iat` | issued at | Kab bana | Debugging, max-age checks |
| `jti` | JWT ID | Token ka unique id | Revocation/blocklist, replay rokna |

**b) Public claims:** IANA registry mein registered common names, jaise `email`, `name`, `email_verified` (ye OIDC se aate hain).

**c) Private/custom claims:** tumhare app ke apne, jaise `role`, `tenant_id`, `token_version`. Naam aise rakho ki registered names se clash na ho.

### 2.3 Signature: "mohar"

```text
signature = HMAC_SHA256( base64url(header) + "." + base64url(payload), secret )
```

Signature header + payload dono ko cover karta hai. Agar kisi ne payload mein `"role":"user"` ko `"role":"admin"` kar diya, to signature match nahi karega, kyunki naya signature banane ke liye **secret key** chahiye jo sirf server ke paas hai.

### 2.4 Sabse bada confusion: Base64URL ≠ Encryption

Ye line dil pe likh lo: **JWT ka payload encrypted NAHI hai, sirf encoded hai.** Koi bhi [jwt.io](https://jwt.io) pe paste karke ya kuch lines code se padh sakta hai:

> Code: see `jwt_code.md`, section 2.4.

- **Encoding** = sirf format badalna (koi bhi wapas kar sakta hai). Jaise Hindi ko Roman script mein likhna.
- **Signing** = proof ki data badla nahi gaya (integrity + authenticity). Padh sab sakte hain, badal koi nahi sakta.
- **Encryption** = data chhupana (confidentiality). Sirf key wala padh sakta hai.

Isliye payload mein **kabhi** password, Aadhaar, PAN, card number, ya koi secret mat daalo. Data chhupana hai to **JWE** use karo (section 11).

Base64**URL** kyun, normal Base64 kyun nahi? Kyunki normal Base64 mein `+`, `/`, `=` aate hain jo URL aur headers mein problem karte hain. Base64URL `-` aur `_` use karta hai aur padding `=` hata deta hai.

> **Interview line:** "A JWT is encoded and signed, not encrypted. Anyone can read the payload, but nobody can modify it without invalidating the signature. Sensitive data should never go into the payload; if confidentiality is required, use JWE."

---

## 3. Signing algorithms: HS256 vs RS256 vs ES256 vs EdDSA

### Symmetric: HS256 (HMAC + SHA-256)

- **Ek hi secret** se sign bhi hota hai aur verify bhi.
- Simple aur fast.
- Problem: jo verify kar sakta hai, wo **sign bhi kar sakta hai**. Agar 10 microservices verify karti hain, to sabke paas secret hai, aur ek bhi leak hua to koi bhi fake token bana sakta hai.
- Socho **ghar ki ek hi chaabi** jo lock bhi karti hai aur kholti bhi hai. Jitne logon ko di, utna risk.
- Secret kam se kam **256 bits (32 random bytes)** ka ho. `"secret123"` jaisa secret offline brute-force ho jaata hai (hashcat se, section 10).

### Asymmetric: RS256 / ES256 / EdDSA

- **Private key** se sirf auth server sign karta hai.
- **Public key** se koi bhi service verify kar sakti hai, par sign nahi kar sakti.
- Socho **sarkari mohar**: mohar (private key) sirf tehsil office ke paas hai, par mohar ka sample (public key) har bank ke paas hai taaki wo check kar sake ki document asli hai.
- Public keys **JWKS endpoint** pe publish hoti hain (`/.well-known/jwks.json`), section 12.

| Algo | Type | Key size | Kab use karein |
|---|---|---|---|
| HS256 | Symmetric (HMAC) | ≥ 256-bit secret | Ek hi service jo sign aur verify dono karti hai |
| RS256 | RSA + SHA-256 | 2048+ bit | Distributed systems, sabse widely supported |
| ES256 | ECDSA P-256 | 256-bit | RS256 jaisa hi, par chhoti keys aur chhote tokens |
| EdDSA (Ed25519) | Edwards curve | 256-bit | Modern, fast, safe defaults. Library support check kar lo |
| `none` | Koi signature nahi | — | **Kabhi nahi.** Attack vector hai |

> **Interview line:** "I use HS256 when a single service both issues and verifies tokens. In a distributed system I use an asymmetric algorithm like RS256 or ES256: the auth server keeps the private key and every other service verifies with the public key from a JWKS endpoint, so a compromised service cannot forge tokens."

---

## 4. Poora auth flow, step by step

```text
1. Client  → POST /login {email, password}
2. Server  → password verify karo (bcrypt/argon2 hash se)
3. Server  → access token (15 min) + refresh token (7 din) banao
4. Server  → access token response body mein, refresh token httpOnly cookie mein
5. Client  → har API call: Authorization: Bearer <access_token>
6. Server  → signature + claims verify karo → request process karo (koi DB lookup nahi)
7. 15 min baad access token expire → API 401 deta hai
8. Client  → POST /auth/refresh (cookie apne aap jaati hai)
9. Server  → refresh token verify + rotate → naya access token (+ naya refresh token)
10. Logout → refresh token revoke karo, cookie clear karo
```

`Bearer` ka matlab hai "jiske paas hai, wahi maalik". Jaise cinema ticket: ticket kiske paas hai, guard ko farak nahi padta, ticket dikhao aur andar jao. Isliye token chori hona = account chori hona. Har jagah **HTTPS** zaroori hai.

---

## 5. Verification checklist (server har request pe kya check kare)

Sirf "signature sahi hai" kaafi nahi. Poori list:

1. **Format:** teen parts hain, valid Base64URL, valid JSON.
2. **Algorithm allowlist:** `alg` ko **token se mat padho**, server pe fix rakho (`algorithms=["RS256"]`). Ye check na karna sabse common bug hai (section 10).
3. **Signature:** sahi key se verify karo (`kid` se key choose karo, par sirf apne trusted JWKS se).
4. **`exp`:** expire to nahi hua?
5. **`nbf`:** abhi valid hua ya nahi?
6. **`iss`:** mera trusted issuer hai?
7. **`aud`:** ye token **mere** service ke liye bana hai? (Warna `payments-api` ka token `admin-api` pe chal jayega.)
8. **Token type:** access token ki jagah refresh token to nahi bhej diya? (`type` claim ya `typ` header check karo.)
9. **Revocation (agar lagaya hai):** `jti` blocklist mein to nahi? `token_version` user ke current version se match karta hai?
10. **Authorization:** token valid hai iska matlab ye nahi ki user ko ye resource access karne ka haq hai. Role/scope/ownership alag se check karo.

**Clock skew:** alag-alag servers ki ghadi thodi aage-peeche hoti hai. 30–60 second ka `leeway` do, warna fresh token bhi kabhi-kabhi "expired" ya "not yet valid" ho jayega.

**`decode` vs `verify`:** kai libraries mein `decode(..., verify=False)` jaisa option hota hai. Wo sirf padhta hai, verify nahi karta. Auth ke liye kabhi use mat karo, sirf debugging ke liye.

---

## 6. Expiry, access token aur refresh token

### Dilemma

- Access token ki lambi expiry (7 din): chori hua to 7 din tak misuse. **Security kharab.**
- Chhoti expiry (15 min): har 15 min pe login karo. **UX kharab.**

### Solution: do tokens, do kaam

| | Access token | Refresh token |
|---|---|---|
| Kaam | API calls authorize karna | Naya access token lena |
| Expiry | Chhoti (5–15 min) | Lambi (7–30 din) |
| Kahan jaata hai | Har API request | Har request ke saath cookie jaati hai, par sirf `/auth/refresh` use padhta hai |
| Kahan store | Memory (JS variable) | httpOnly + Secure + SameSite cookie (`__Host-` prefix, `Path=/`) |
| Server pe state | Nahi (stateless) | **Haan**, DB/Redis mein track karo |
| Format | JWT | JWT ya simple opaque random string (dono chalte hain) |

Socho **metro**: access token = single journey ka token (ek trip, jaldi khatam). Refresh token = metro card (lamba chalta hai, par sirf recharge counter pe use hota hai, har gate pe nahi). Card khoya to block karwa sakte ho, kyunki system mein registered hai.

**Important point:** refresh token ko server-side track karna hi padta hai. Isliye "JWT poora stateless hai" adha sach hai. Practical systems **hybrid** hote hain: access token stateless, refresh token stateful. Isse revocation sambhav hota hai, aur DB hit sirf har 15 min mein ek baar hota hai, har request pe nahi.

### Expiry kitni rakhein? (rough guide)

| App type | Access | Refresh |
|---|---|---|
| Banking / payments | 5 min | Chhota (ya re-auth for sensitive actions) |
| Normal SaaS / e-commerce | 15 min | 7–14 din |
| Mobile app (long login chahiye) | 15–60 min | 30–90 din, rotation ke saath |

Absolute lifetime bhi rakho: rotation ke baad bhi, maan lo 90 din baad, dobara login karwao.

---

## 7. Refresh token rotation + reuse detection (deep dive)

**Rotation:** har baar `/refresh` call pe purana refresh token **invalidate** karo aur naya do. Ek refresh token = ek baar use.

**Reuse detection (asli magic):** maan lo hacker ne refresh token RT1 chura liya.

```text
User   uses RT1 → server gives RT2 (RT1 ab "used" mark)
Hacker uses RT1 → server dekhta hai: "RT1 to already use ho chuka hai!"
       → ye chori ka saboot hai → poori token FAMILY revoke (RT2 bhi)
       → user aur hacker dono logout → user dobara login karega, hacker bahar
```

Ulta case bhi same hai: hacker pehle use kare to user ka RT1 reuse dikhega, aur family phir bhi revoke hogi.

Implementation ka idea: har refresh token ko DB mein `{jti, user_id, family_id, used, expires_at}` ke saath store karo. Login pe naya `family_id` banta hai, har rotation usi family mein naya `jti` add karti hai.

**Race condition ka dhyan:** frontend pe 3 API calls ek saath 401 de sakti hain aur teeno refresh call kar sakti hain. Pehli rotate kar degi, baaki do "reuse" lagengi aur user bina wajah logout ho jayega. Do fix hain, aur dono lagao:
- Frontend: ek waqt pe sirf **ek refresh request** in-flight rakho (section 15 ka Axios code).
- Backend: chhota **grace window** (jaise 10–30 sec) rakho jisme purana token same naya token return kare.

> **Interview line:** "I rotate refresh tokens on every use and track them in token families. If an already-used refresh token is presented again, that indicates theft, so I revoke the entire family and force the user to log in again."

---

## 8. Token kahan store karein? (XSS vs CSRF ka khel)

Pehle do attacks samjho:

- **XSS (Cross-Site Scripting):** attacker tumhari site pe apni JavaScript chala deta hai (comment box mein script, ya koi compromised npm package). Wo JS jo bhi JS padh sakti hai, sab chura sakti hai.
- **CSRF (Cross-Site Request Forgery):** attacker ki site `evil.com` tumhare browser se `bank.com` pe request bhejti hai, aur browser **cookies apne aap attach** kar deta hai. Attacker cookie padh nahi sakta, par use kar sakta hai.

| Storage | XSS se token chori? | CSRF risk? | Refresh pe bachta hai? | Verdict |
|---|---|---|---|---|
| `localStorage` | **Haan**, koi bhi JS padh le | Nahi | Haan | Avoid for sensitive apps |
| `sessionStorage` | **Haan** | Nahi | Tab band hote hi gaya | Same problem |
| JS memory (variable) | Mushkil (page ke saath chala jaata hai) | Nahi | **Nahi**, refresh pe gaya | Access token ke liye best |
| httpOnly cookie | **Nahi**, JS padh hi nahi sakti | **Haan**, browser apne aap bhejta hai | Haan | Refresh token ke liye best (+ CSRF protection) |

**Best practice combo:**
- **Access token → memory mein.** Page refresh pe gaya? Koi baat nahi, silently `/auth/refresh` call karo.
- **Refresh token → httpOnly cookie** in flags ke saath:

```text
Set-Cookie: __Host-refresh=<token>; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=604800
```

| Flag | Kya karta hai |
|---|---|
| `HttpOnly` | JS `document.cookie` se padh nahi sakti, XSS se chori nahi hoga |
| `Secure` | Sirf HTTPS pe jaayegi |
| `SameSite=Strict` | Doosri site se aayi request mein cookie nahi jaayegi, CSRF ka main ilaaj |
| `SameSite=Lax` | Top-level GET navigation pe jaati hai, POST pe nahi. Achha default |
| `Path=/auth/refresh` | Cookie sirf refresh endpoint pe jaaye (`__Host-` prefix ke saath `Path=/` zaroori hai, isliye ek choose karo) |
| `__Host-` prefix | Browser force karta hai: Secure ho, Path=/ ho, Domain set na ho. Subdomain wale attacks se bachata hai |

**Ek kadwa sach:** XSS ho gaya to httpOnly bhi tumhe poori tarah nahi bachata. Attacker token padh nahi sakta, par tumhari site ke andar se hi tumhare naam pe requests bhej sakta hai. httpOnly bas token ko **bahar le jaane** se rokta hai. Asli ilaaj XSS rokna hai: output escaping, CSP header, dependencies audit.

**Mobile apps:** cookies ka jhanjhat nahi hai. Tokens ko **Keychain (iOS) / Keystore-backed EncryptedSharedPreferences (Android)** mein rakho, plain SharedPreferences mein nahi.

**BFF pattern (Backend-for-Frontend):** sabse secure SPA setup. Tokens browser tak aate hi nahi. Browser ke paas sirf ek httpOnly session cookie hoti hai, aur BFF server tokens rakhta hai aur API calls forward karta hai. Banking-grade apps mein ye pattern dekhoge.

> **Interview line:** "I keep the access token in memory and the refresh token in an HttpOnly, Secure, SameSite cookie. That protects the refresh token from XSS theft and SameSite blocks most CSRF. For the highest security in SPAs, I use the BFF pattern so tokens never reach the browser."

---

## 9. Revocation: JWT ko "cancel" kaise karein?

JWT stateless hai, to `exp` se pehle use maarna mushkil hai. Options, sasta se mehnga:

| Tareeka | Kaise | Trade-off |
|---|---|---|
| **Short expiry** | Access token 5–15 min | Worst case 15 min ka window. Zyada tar apps ke liye kaafi |
| **Refresh token revoke** | Logout pe DB/Redis se refresh token delete | Naya access token nahi milega. Purana `exp` tak chalega |
| **`jti` blocklist** | Logout pe `jti` Redis mein daalo, TTL = token ki bachi umar | Har request pe ek Redis lookup (stateless-pan thoda gaya) |
| **`token_version` per user** | User table mein version, token mein bhi. Password change pe version++ | User ke **saare** tokens ek saath dead. DB/cache lookup chahiye |
| **Key rotation** | Signing key badal do | **Sabke** tokens dead. Sirf emergency (key leak) mein |

**Kab kya use karein:**
- Normal logout → refresh token revoke + frontend se access token hatao.
- "Logout from all devices" / password change → `token_version` bump.
- Account ban / suspicious activity → `jti` blocklist ya `token_version`.
- Secret leak → key rotation (sab logout, koi chara nahi).

Blocklist ke liye **Redis + TTL** sabse sahi hai. Entry apne aap token ki expiry ke saath gayab ho jaati hai, cleanup ka jhanjhat nahi. In-memory `set()` sirf local dev ke liye hai, multiple instances mein kaam nahi karega.

**Allowlist vs blocklist:** blocklist = "ye tokens band hain" (chhoti list). Allowlist = "sirf ye tokens valid hain" (har active token store). Allowlist basically session hi ban jaata hai, to tab socho ki JWT kyun use kar rahe ho.

---

## 10. Attacks jo interview mein poochte hain (aur bachaav)

### 10.1 `alg: none`
Attacker header mein `"alg":"none"` daal ke signature hata deta hai. Kuch purani libraries isko valid maan leti thi.
**Bachaav:** `algorithms=["RS256"]` server pe hardcode karo. `none` kabhi allow mat karo.

### 10.2 Algorithm confusion (RS256 → HS256)
Server RS256 expect karta hai, public key se verify karta hai. Attacker token ko **HS256** bol ke **public key ko hi HMAC secret** bana ke sign kar deta hai. Public key to public hai, sabke paas hai! Agar library `alg` token se padhti hai, to wo public key ko HMAC secret maan ke verify karegi, aur fake token **pass** ho jayega.
**Bachaav:** wahi baat, allowed algorithms server pe fix rakho. Key type aur algorithm ko bind karo (RSA key sirf RS256 ke saath).

### 10.3 Weak HS256 secret
`secret`, `changeme`, `myapp123` jaise secrets. Attacker ke paas ek valid token hai to wo **offline brute-force** kar sakta hai (hashcat), server ko pata bhi nahi chalega. Secret mila to woh koi bhi token, kisi bhi role ka, bana sakta hai.
**Bachaav:** `secrets.token_urlsafe(32)` ya usse lamba. Env/secret manager se lo, code mein kabhi nahi.

### 10.4 `kid` injection
`kid` header se server key dhoondta hai. Agar code `open(f"keys/{kid}")` ya SQL query mein `kid` daalta hai, to attacker `kid: "../../dev/null"` (empty key!) ya SQL injection kar sakta hai.
**Bachaav:** `kid` ko sirf ek trusted key map/JWKS mein lookup ki tarah use karo. File path ya query mein kabhi nahi.

### 10.5 `jku` / `x5u` header abuse
Ye headers bolte hain "public key yahan se download karo". Attacker apna URL daal deta hai, apni key se sign karta hai, aur server attacker ki key se verify kar deta hai.
**Bachaav:** in headers ko ignore karo. JWKS URL server config mein fix rakho.

### 10.6 Missing `aud` check (token substitution)
Same auth server multiple apps ke tokens deta hai. App A ka token App B pe chal gaya, kyunki B ne `aud` check nahi kiya.
**Bachaav:** `aud` aur `iss` hamesha verify karo.

### 10.7 Token leakage
URL mein token (`?token=...`) server logs, browser history, aur Referer header mein leak hota hai. Logs mein poora `Authorization` header print karna bhi leak hai.
**Bachaav:** token sirf header/cookie mein. Logs mein token mask karo.

### 10.8 No expiry / bahut lambi expiry
Chori hua token hamesha ke liye chalega.
**Bachaav:** `exp` mandatory banao (`options={"require": ["exp"]}`).

### 10.9 Token replay / sidejacking
Chori hua token attacker kisi aur machine se use kar le.
**Bachaav (advanced):** **sender-constrained tokens**, matlab token ek key se bind ho jo sirf client ke paas hai:
- **DPoP** (OAuth 2.0 Demonstrating Proof of Possession): client har request pe apni private key se ek proof sign karta hai.
- **mTLS-bound tokens:** token client certificate se bind hota hai.
Isse token chori ho bhi jaaye to bina private key ke bekaar hai.

> **Interview line:** "The most common JWT vulnerabilities are trusting the alg header, which enables alg none and RS256-to-HS256 confusion, using weak HMAC secrets that can be brute-forced offline, and skipping the aud and iss checks. I pin the allowed algorithms on the server, use strong keys from a secret manager, and validate every registered claim."

---

## 11. JWS vs JWE vs JWT (naam ka jhamela)

- **JWT** = format/standard ka naam (RFC 7519). Claims ka JSON structure.
- **JWS** (JSON Web Signature) = **signed** token. Jo hum roz use karte hain, 3 parts. Padh sakte ho, badal nahi sakte.
- **JWE** (JSON Web Encryption) = **encrypted** token. **5 parts**: `header.encryptedKey.iv.ciphertext.authTag`. Koi padh hi nahi sakta bina key ke.
- **Nested JWT** = pehle sign, phir encrypt (sign-then-encrypt). Integrity bhi, confidentiality bhi.

90% cases mein JWS + HTTPS kaafi hai. JWE tab jab token kisi untrusted beech wale (third party, browser) se guzarta hai aur andar sensitive data hai.

Related: **JWK** = ek key ko JSON mein represent karna. **JWKS** = keys ka set (array). **JOSE** = in sab standards ki family ka naam.

---

## 12. JWKS aur key rotation

Auth server apni **public keys** ek URL pe publish karta hai:

```text
GET https://auth.myapp.com/.well-known/jwks.json
{ "keys": [
  { "kid": "2026-09", "kty": "RSA", "alg": "RS256", "use": "sig", "n": "...", "e": "AQAB" },
  { "kid": "2026-10", "kty": "RSA", "alg": "RS256", "use": "sig", "n": "...", "e": "AQAB" }
]}
```

Verifier token ke header se `kid` padhta hai, JWKS mein matching key dhoondta hai, aur verify karta hai.

**Zero-downtime rotation:**
1. Nayi key (`2026-10`) JWKS mein **add** karo, par sign abhi purani se hi karo.
2. Verifiers ki JWKS cache refresh hone do (jaise 1 ghanta).
3. Ab nayi key se **sign** karna shuru karo.
4. Purani key tab tak JWKS mein rakho jab tak uske saare tokens expire na ho jaayein (max refresh lifetime, agar refresh tokens JWT hain; opaque hain to access-token lifetime kaafi hai).
5. Phir purani key hatao.

**Caching:** verifiers JWKS ko cache karte hain (har request pe fetch mat karo). Unknown `kid` aaye to ek baar re-fetch karo, par rate-limit karke, warna attacker random `kid` bhej ke tumhare auth server pe DoS kar dega.

---

## 13. Microservices aur API gateway mein JWT

```text
Client → API Gateway (JWT verify: sig, exp, iss, aud) → Order Service → Payment Service
```

Common patterns:
- **Gateway pe verify, andar trust:** gateway verify karke user info headers mein forward karta hai (`X-User-Id`). Simple hai, par andar ka network trusted hona chahiye (zero-trust mein ye kaafi nahi).
- **Har service khud verify kare:** JWKS se public key lo, locally verify karo. Zero-trust friendly. Asymmetric algo yahan zaroori hai.
- **Token exchange (RFC 8693):** Order service, Payment service ko call karte waqt user ka token aage na bheje. Naya token le jiska `aud` = `payments` aur scope chhota ho. Isse ek service ka token doosri jagah misuse nahi hoga.

**Token size ka dhyan:** JWT har request mein jaata hai. 50 roles aur permissions daal diye to token 4–8 KB ka ho jayega. Headers ki limit hai (kai servers ~8 KB), aur bandwidth bhi waste hoti hai. Token mein **identity aur coarse roles** rakho, fine-grained permissions service khud cache se dekhe.

**Stale claims:** token mein `role: admin` hai, aur beech mein admin role hata diya. Token expire hone tak wo admin hi rahega. Yahi ek aur wajah hai access token chhota rakhne ki.

---

## 14. OAuth 2.0 aur OpenID Connect mein JWT

Ye confusion bahut common hai, isliye clear kar lo:

- **OAuth 2.0** = **authorization** framework ("is app ko meri Google Drive padhne ki permission do"). Access token kisi bhi format mein ho sakta hai. Zaroori nahi ki JWT ho.
- **OpenID Connect (OIDC)** = OAuth ke upar **authentication** layer ("ye banda kaun hai"). Ye **ID token** deta hai, jo **hamesha JWT** hota hai.

| | ID token | Access token |
|---|---|---|
| Kiske liye | Client app ke liye (user kaun hai) | API/resource server ke liye |
| Format | Hamesha JWT | JWT ya opaque |
| `aud` | Client ID | API identifier |
| API call mein bhejo? | **Nahi** | Haan |

Golden rule: **ID token API pe mat bhejo, access token se user identity mat nikalo.** "Login with Google" ka flow yahi hai: Authorization Code + **PKCE** flow se code lo, backend pe tokens mein exchange karo, ID token verify karke user identify karo.

**Opaque token + introspection:** kuch systems access token ko random string rakhte hain, aur API har baar auth server se `/introspect` karke poochti hai "ye valid hai?". Isse instant revocation milta hai, par har request pe network call lagti hai. JWT ka bilkul ulta trade-off.

---

## 15. Code: FastAPI + PyJWT

> FastAPI ke official docs ab **PyJWT** recommend karte hain. `python-jose` ki purani recommendation hata di gayi hai, naye projects mein mat lo. `pip install pyjwt` (RS256 ke liye `pyjwt[crypto]`).

### 15.1 Token banana aur verify karna

> Code: see `jwt_code.md`, section 15.1.

`except jwt.ExpiredSignatureError` pehle aana chahiye, kyunki wo `InvalidTokenError` ka hi subclass hai. Order ulta kiya to "expired" wala message kabhi nahi dikhega.

Note: `iat`/`exp` mein `datetime.now(timezone.utc)` use karo. `datetime.utcnow()` deprecated hai aur naive datetime deta hai.

### 15.2 Login, refresh (rotation + reuse detection), logout, saare sessions revoke

> Code: see `jwt_code.md`, section 15.2.

Ye code kya cover karta hai:
- **"Sab devices se logout" / password change:** `revoke_all_sessions` `tokens_valid_after = now` set karta hai. `get_current_user` aur `/refresh` dono purane `iat` wale token reject karte hain, to access **aur** refresh tokens saath mein marte hain. (`token_version` claim bhi same kaam karta hai; timestamp wale tareeke mein extra claim nahi chahiye.)
- **Grace window:** 15 second se kam pehle rotate hua token ek baar aur accept hota hai, chori nahi maana jaata. Isse parallel requests aur multiple tabs handle ho jaate hain. Trade-off: chor ne unhi 15 second mein use kiya to pakda nahi jayega.
- `/refresh` pe **CSRF header** (section 20.3).
- **Logout** ko valid access token nahi chahiye: wo cookie se refresh family revoke karta hai, aur access `jti` blocklist mein tabhi daalta hai jab wo token abhi valid ho.
- `refresh_repo` aur `users_repo` tumhari apni DB layer hain (19.5 ki `refresh_tokens` table). `issue_tokens` wahan bhi likhta hai, taaki Redis wipe se revoked sessions zinda na ho jaayein.
- Agar Redis mirror kho sakta hai, to cache miss pe `tokens_valid_after` DB se padho.

### 15.3 RS256 version (sirf jo badalta hai)

> Code: see `jwt_code.md`, section 15.3.

### 15.4 Frontend: Axios auto-refresh (single-flight, multi-tab safe)

> Code: see `jwt_code.md`, section 15.4.

Important baatein:
- `refreshPromise` share hota hai, to 5 parallel 401s pe bhi **sirf ek** refresh call jaayegi (section 7 ka race condition fix).
- `navigator.locks` yahi kaam **tabs ke beech** karta hai (section 20.2), aur `BroadcastChannel` logout ko har tab tak pahunchata hai.
- `isRefreshCall` check: refresh khud 401 de to infinite loop nahi banega.
- `_retry` flag: ek request sirf ek baar retry hogi.
- App load pe (page refresh ke baad) memory khaali hai, to pehle ek silent `/auth/refresh` call karo.

---

## 16. Session vs JWT: kab kya?

| | Session (opaque ID) | JWT |
|---|---|---|
| Data kahan | Server (DB/Redis) | Token ke andar (client ke paas) |
| Har request pe | Store lookup | Sirf signature verify (CPU) |
| Scaling | Shared session store chahiye | Koi bhi instance verify kar le |
| Revocation | Turant (row delete) | Mushkil (blocklist/short expiry) |
| Size | Chhota (~32 bytes) | Bada (claims ke saath, 300 B–kuch KB) |
| Cross-domain / mobile / microservices | Mushkil (cookies domain-bound) | Aasan (header mein bhejo) |
| Stale data | Kabhi nahi (store hi source of truth) | `exp` tak purana role/claim |
| Best for | Monolith, server-rendered apps, banking (instant logout) | APIs, SPAs, mobile, microservices, third-party/SSO |

**Sach ye hai:** JWT session ka "upgrade" nahi hai, alag trade-off hai. Agar ek hi monolith hai, ek hi domain hai, aur Redis already hai, to session cookie zyada simple aur zyada secure hai. Bahut log JWT sirf "modern" lagne ki wajah se lagate hain aur phir blocklist bana ke session hi dobara bana dete hain.

> **Interview line:** "Sessions give instant revocation and always-fresh data at the cost of a store lookup per request. JWTs give stateless verification that scales across services at the cost of hard revocation and stale claims. For a single web app I prefer server sessions; for APIs, mobile clients and microservices I use short-lived JWT access tokens with server-tracked, rotating refresh tokens."

---

## 17. Best practices: ek nazar mein checklist

- [ ] HTTPS everywhere. Token bearer hai, chori = account chori.
- [ ] Access token 5–15 min, refresh token 7–30 din + absolute lifetime.
- [ ] Allowed `algorithms` server pe pinned. `none` kabhi nahi.
- [ ] `exp`, `iss`, `aud`, `nbf` hamesha verify. `exp` mandatory. Leeway 30–60 sec.
- [ ] HS256 secret ≥ 256-bit random, env/secret manager se. Distributed system mein RS256/ES256 + JWKS.
- [ ] Payload mein koi sensitive data nahi. Sirf id, roles, zaroori claims.
- [ ] Access token memory mein, refresh token `HttpOnly; Secure; SameSite` cookie mein.
- [ ] Refresh token rotation + reuse detection + token families.
- [ ] Logout pe refresh revoke + `jti` blocklist (Redis TTL). Password change pe `token_version` bump.
- [ ] Token type check (access vs refresh mix na ho).
- [ ] `kid` sirf trusted key map mein lookup. `jku`/`x5u` ignore.
- [ ] Token URL mein nahi, logs mein masked.
- [ ] Authentication ≠ authorization. Valid token ke baad bhi permission/ownership check karo.
- [ ] Password change / "sab jagah se logout" access **aur** refresh dono tokens revoke kare.
- [ ] Frontend aur API same site pe (proxy ya custom domain); credentials ke saath exact-origin CORS.
- [ ] Refresh tabs ke beech serialised; logout sab tabs tak broadcast; `/refresh` pe CSRF header/Origin check.
- [ ] WebSockets: handshake pe `Origin` check, ya one-time tickets; token expire hone pe socket band.
- [ ] Maintained library use karo (PyJWT, `jsonwebtoken`, `jose` for Node). Khud ka JWT parser kabhi mat likho.

---

## 18. Interview quick-fire (formal English)

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

## 19. Jab kuch leak ho jaaye: incident playbooks aur kaun cheez kahan store hoti hai

### 19.1 Signing secret / private key leak ho gaya

**Impact (JWT ka sabse bura case):** attacker **kisi bhi user, kisi bhi role, kisi bhi expiry** ka token bana sakta hai. `jti` blocklist bekaar hai (wo naye `jti` bana lega). Refresh tokens bhi JWT hain to wo bhi forge ho jaayenge. Asli ilaaj sirf ek hai: key badlo.

Socho **sarkari mohar chori ho gayi**. Ab jo bhi document aayega, asli lagega. Pehle wali mohar ko turant "invalid" declare karna padega, chahe asli documents bhi reject ho jaayein.

**Playbook:**
1. **Nayi key banao aur turant deploy karo.** Purani key verifiers se **usi waqt** hatao (HS256 mein accepted-secrets map se, RS256 mein JWKS se). Planned rotation ki tarah yahan **koi grace period nahi**, kyunki purani key se sign hua har token ab bharose layak nahi hai.
2. **Sab logout ho jaayenge.** Saari refresh token families bhi revoke karo (refresh-token table/Redis keys saaf karo, ya global epoch bump karo, 19.6 dekho).
3. **Source dhoondo:** git history, CI logs, error page mein env dump, kisi ka laptop, third-party service. Jis raaste se leak hua, uske credentials bhi rotate karo (secret manager access, CI tokens).
4. **Damage assess karo:** agar tum har issued `jti` log karte ho, to koi bhi valid-looking token jiska `jti` tumne kabhi issue hi nahi kiya, wo forgery ka saboot hai. Exposure window mein admin actions ke audit logs check karo.
5. Policy ke hisaab se users/security team ko **notify** karo. Account data access hua ho sakta hai to password reset force karo.

**Prevention:**
- Keys **secret manager** mein (Vault, AWS Secrets Manager, GCP Secret Manager). Git ya commit hone wali `.env` files mein kabhi nahi.
- Aur better: **KMS/HSM signing**. Private key HSM se kabhi bahar nikalti hi nahi, auth server KMS ki `Sign` API call karta hai. Server poora hack ho jaaye, tab bhi key copy nahi hogi.
- Har environment ki alag key (dev/staging/prod). Dev leak se prod pe asar nahi hona chahiye.
- **Scheduled rotation** (jaise har 90 din), taaki rotation ka procedure practice mein rahe, incident ke beech pehli baar na sochna pade.

### 19.2 HS256 secret ki planned rotation

> Code: see `jwt_code.md`, section 19.2.

HS256 mein JWKS nahi hota, par idea same hai: **`kid` ke saath multiple secrets** rakho, current wale se sign karo, aur token jis `kid` ka naam le, usse verify karo.

Steps: nayi secret `KEYS` mein add karo → har jagah deploy → `SIGNING_KID` nayi pe switch → sabse lambi token lifetime tak wait (refresh tokens JWT hain to refresh TTL) → purani secret hatao.

### 19.3 Client ka access token chori ho gaya

**Impact:** attacker `exp` tak user ban ke kaam karega (advice follow ki hai to max 15 min). Refresh cookie ke bina naya token nahi le sakta.

**Chori kaise hota hai:** XSS se localStorage padh liya, device pe malware, token URL/log mein, headers log karne wala proxy, ya koi non-HTTPS hop.

**Detection signals (koi bhi perfect nahi):**
- Same `jti` ek hi waqt pe do bilkul alag IPs/ASNs/user agents se.
- Impossible travel (5 minute mein Mumbai aur Frankfurt).
- Achanak unusual actions ka burst (bulk export, password/email change).

**Response:** `jti` blocklist mein daalo, ya user ka `token_version` bump karke uske saare tokens khatam karo. Uski refresh families revoke karo. Re-login force karo, zaroorat ho to password reset bhi. Agar XSS wajah thi to XSS fix karo, warna agla token bhi chori hoga.

**Note:** Token ko IP se bind karna usually bahut brittle hai (mobile users network badalte rehte hain, WiFi se 4G). Token mein hashed device fingerprint ek softer signal hai.

### 19.4 Refresh token chori ho gaya

Rotation + reuse detection (section 7) isko **tabhi** pakadta hai jab dono log same token use karein. Iska blind spot: attacker pehle refresh kar le aur asli user wapas hi na aaye (laptop ek hafte band), to attacker rotate karta rahega aur kisi ko pata nahi chalega.

Extra defences:
- **Absolute lifetime** (jaise 30–90 din) aur **idle timeout** (jaise 7 din use nahi hua → dead), taaki chori hui family kabhi na kabhi mare.
- **Device binding:** family ke saath device id / user agent / IP range store karo. Bilkul alag device se refresh aaye to suspicious → step-up auth (OTP).
- **"Active sessions" screen** (Google/Netflix jaisa): har family device aur location ke saath dikhao, har ek pe "log out" button. User khud chori pakad leta hai.
- Email ya push pe **login/new-device alerts**.
- `/auth/refresh` pe rate-limit.

### 19.5 Kaun cheez kahan store hoti hai

| Cheez | Kahan rehti hai | Notes |
|---|---|---|
| Signing secret / private key | Secret manager ya KMS/HSM, startup pe inject | Git, DB, logs, client mein kabhi nahi |
| Public keys | JWKS endpoint; verifiers memory mein cache karte hain | Expose karna safe hai |
| Access token | Sirf client memory | Server kuch store nahi karta (yahi to point hai) |
| Refresh token (client side) | `HttpOnly; Secure; SameSite` cookie (web), Keychain/Keystore (mobile) | localStorage kabhi nahi |
| Refresh token (server side) | DB table (durable source of truth), speed ke liye optionally Redis mein bhi | Opaque tokens ka **SHA-256 hash** store karo, raw value kabhi nahi, taaki DB leak ho to bhi kaam karne wale tokens na milein. JWT refresh tokens ke liye `jti` store karna kaafi hai |
| Access-token blocklist (`jti`) | **Redis**, key `jwt:block:<jti>`, TTL = token ki bachi umar | Saare instances share karte hain; apne aap saaf hota hai |
| `token_version` / `tokens_valid_after` | DB ki `users` table, Redis mein cached | Use karte ho to har request pe check |
| Issued `jti`s ka audit log | Append-only log/DB | Key leak ke baad forged tokens pakadne mein kaam aata hai |

Hash kyun? Socho bank locker: bank tumhari chaabi ki copy nahi rakhta. Waise hi DB mein token ka hash rakho; DB chori hua to bhi asli token kisi ke haath nahi lagega.

Typical refresh-token table:

> Code: see `jwt_code.md`, section 19.5.

**Redis down ho gaya to?** Pehle se decide karo:
- **Fail closed** (blocklist check nahi ho saka to request reject): zyada safe. Banking/admin APIs ke liye sahi.
- **Fail open** (check skip): zyada available. Sirf isliye chalta hai kyunki access tokens 15 min mein waise bhi mar jaate hain.

**Redis restart hua aur data gaya to?** Revoked access tokens apne `exp` tak phir se valid ho jaayenge. 15-min tokens ke saath ye usually chal jaata hai; warna Redis persistence (AOF) on karo. Refresh-token state DB mein isi liye rakhte hain, taaki cache wipe se revoked sessions zinda na ho jaayein.

**Bade scale pe performance:** har request pe Redis lookup sasta hai (sub-millisecond), par bahut zyada traffic pe gateway ek chhota local cache ya revoked `jti`s ka **Bloom filter** rakh sakta hai, aur Redis sirf possible match pe hit kare.

### 19.6 "Valid after" trick (tokens ki list rakhe bina revoke)

Har revoked token store karne ki jagah **ek timestamp** rakho: "is waqt se pehle issue hue saare tokens dead".
- Per user: `users.tokens_valid_after`. Password change pe isko `now()` set karo; jis token ka `iat < tokens_valid_after`, use reject karo.
- Global: ek `global_tokens_valid_after`. Key leak ya breach ke baad isko `now()` karo, system ka har token mar jayega, key badle bina bhi.

### 19.7 Edge cases jo zyada log miss karte hain

1. **Password change pe refresh tokens bhi maarne padenge.** `token_version` bump sirf access tokens maarta hai. Agar refresh endpoint bhi isko check nahi karta, to chori hua refresh token wala attacker *naye* version ka fresh access token bana lega. Password change pe: version bump **aur** us user ki saari refresh families revoke.
2. **Opaque refresh tokens key leak se bach jaate hain.** Agar refresh tokens random strings hain jo DB se check hote hain (JWT nahi), to leaked signing key se bhi forge nahi ho sakte. Sirf access tokens ki safai karni padti hai. Opaque refresh tokens ke favour mein ye bada argument hai.
3. **Refresh tokens ke liye SHA-256, bcrypt nahi.** Passwords low-entropy hote hain, isliye guessing rokne ke liye slow hash (bcrypt/argon2) chahiye. Refresh token 256 random bits ka hai, koi brute-force nahi kar sakta, to fast SHA-256 kaafi hai aur `/refresh` fast rehta hai. Hash compare constant-time function (`hmac.compare_digest`) se karo ya indexed equality lookup se.
4. **CORS misconfiguration CSRF ko token chori mein badal deta hai.** Normally SameSite aur CORS `evil.com` ko `/auth/refresh` ka response *padhne* se rokte hain. Par agar server koi bhi `Origin` `Access-Control-Allow-Origin` mein reflect kare aur saath mein `Access-Control-Allow-Credentials: true` ho, to attacker ka page victim ki cookie ke saath `/refresh` call karke naya access token padh lega. Sirf exact origins allowlist karo.
5. **Multi-region blocklist lag.** Regions ke beech Redis replication mein time lagta hai; Mumbai mein revoke hua token Singapore mein kuch seconds chal sakta hai. Usually chalta hai; critical revocation (account takeover) mein primary DB mein `tokens_valid_after` bhi bump karo.
6. **Mass logout = thundering herd.** Key rotation ke baad har user ek saath `/login` aur `/refresh` pe aayega. Auth service aur user DB pe spike aayega: pehle se scale karo, rate limits sahi rakho, aur errors ki jagah ek friendly "please sign in again" page dikhao.
7. **Logs aur monitoring tools bhi leak ka raasta hain.** APM/error trackers (Sentry, Datadog) aur reverse proxies poore request headers aur cookies capture kar sakte hain. App se bahar jaane se pehle `Authorization` aur `Cookie` scrub karo.
8. **Leak hone se pehle pakdo.** CI aur pre-commit hooks mein secret scanning chalao (gitleaks, trufflehog, GitHub secret scanning). Public repo pe push hua secret bots minuton mein scrape kar lete hain, to commit delete karna kaafi nahi: rotate karo.
9. **Forged/chori hue token ka blast radius chhota rakho.** Sensitive actions pe step-up auth (dobara password ya OTP) maango: email/password change, payee add karna, bada payment. Tab perfectly valid chori hua token bhi sabse bada nuksaan nahi kar paayega. Jaise bank app UPI PIN maangta hai, chahe tum already logged in ho.
10. **Expired access token ke saath bhi logout kaam karna chahiye.** Agar logout valid access token maangta hai, to jiska token abhi expire hua wo theek se logout nahi kar paayega. Ya to pehle refresh karo (Axios interceptor yahi karta hai) ya `/logout` ko sirf refresh cookie se chalne do. Expired refresh token bhi tolerate karo aur cookie phir bhi clear karo.

> **Interview line:** "If the signing key leaks, attackers can forge any token, so I rotate the key immediately with no grace period, revoke all refresh tokens, and trace the leak. Keys live in a secret manager or KMS so the application never holds the raw private key. For a stolen access token, short expiry limits the window and I can blocklist its jti in Redis. For stolen refresh tokens, rotation with reuse detection, absolute and idle timeouts, and an active-sessions screen cover the gaps. Refresh tokens are stored hashed in the database, and the blocklist lives in Redis with a TTL equal to each token's remaining lifetime."

---

## 20. Real-world setups aur baaki topics

### 20.1 Frontend aur API alag sites pe (cookie ka jaal)

Pehle do shabd jo log mix kar dete hain:
- **Origin** = scheme + host + port. `https://app.myapp.com` aur `https://api.myapp.com` **alag origins** hain. CORS origins pe kaam karta hai.
- **Site** = scheme + registrable domain (eTLD+1). Upar wale dono **same site** hain (`myapp.com`). `SameSite` cookies sites pe kaam karti hain.

Jaal ye hai: frontend `myapp.vercel.app` pe, API `myapp-api.onrender.com` pe. Ye **alag sites** hain (aur `vercel.app`/`onrender.com` Public Suffix List pe hain, to `vercel.app` ke do subdomains bhi alag sites maane jaate hain). Natija:
- `SameSite=Strict` ya `Lax` refresh cookie frontend ke fetch ke saath API tak **kabhi jaati hi nahi**. Refresh chupchaap fail hota hai aur users 15 min baad logout ho jaate hain.
- `SameSite=None; Secure` karoge to cookie phir jaane lagegi, par ab wo **third-party cookie** hai. Safari aur Firefox inhe default mein block karte hain, Chrome users ko block karne deta hai, to kaafi users ke liye toot jayega. SameSite ka CSRF protection bhi gaya, apna lagana padega (20.3).

Fixes, sabse achha pehle:
1. **Proxy se same origin:** frontend host `/api/*` ko backend pe rewrite kare (Vercel/Next.js rewrites, Nginx). Browser sirf `myapp.com` se baat karta hai, to CORS hi nahi, aur cookie first-party hai. Sabse simple aur robust.
2. **Custom domain se same site:** `app.myapp.com` + `api.myapp.com`. Cookie first-party, `SameSite=Lax/Strict` chalta hai. CORS credentials ke saath aur **exact** allowed origin ke saath chahiye (`Access-Control-Allow-Origin: https://app.myapp.com` + `Access-Control-Allow-Credentials: true`; credentials ke saath wildcard `*` allowed nahi hai).
3. **Sach mein cross-site (sirf majboori mein):** `SameSite=None; Secure; Partitioned` (CHIPS) + CSRF token, aur maan ke chalo kuch browsers mein phir bhi tootega. Frontend ke apne domain pe BFF usually isse behtar hai.

Socho **society ka gate pass**: pass sirf apni society (site) ke gate pe chalta hai. Flat number alag ho (origin) to chalega, par doosri society (doosri site) mein le gaye to guard nahi maanega.

### 20.2 Multiple tabs

Har tab ki apni JS memory hai, to har tab ka apna access token hai, par sab **ek hi refresh cookie** share karte hain. Do problems:
- **Galat chori ka alarm:** tab A aur B dono ko 401 mila aur dono ne same cookie se `/refresh` call kiya. A ne rotate kar diya; B ki request reuse lagi, aur poori family revoke. Per-tab `refreshPromise` yahan kaam nahi aata, kyunki wo ek hi tab ke andar rehta hai.
- **Aadha logout:** tab A mein logout kiya, par tab B ki memory mein working access token pada hai.

Fixes (dono 15.4 ke code mein hain):
- `navigator.locks.request("auth-refresh", ...)`: Web Locks API origin ke saare tabs share karte hain, to tabs line mein lag ke refresh karte hain aur har ek sabse nayi cookie bhejta hai.
- `BroadcastChannel("auth")`: logout pe har tab ko bolo ki token hatao aur login page pe jao.

### 20.3 `/refresh` ke liye SameSite ke alawa CSRF protection

SameSite pehli line of defence hai. Ek layer aur lagao, kyunki purane browsers, `SameSite=None` setups, aur compromised subdomain se same-site attacks hote hain.
- **Required custom header** (`X-Requested-With: XMLHttpRequest`, 15.2 mein use hua): HTML form custom headers set nahi kar sakta, aur custom header wala cross-origin `fetch` CORS preflight trigger karta hai, jise tumhari exact-origin CORS policy reject kar degi. JSON APIs ke liye sasta aur effective.
- **Origin check:** state badalne wali requests jinka `Origin` header allowlist mein nahi, reject karo.
- **Double-submit token:** ek random value readable (non-httpOnly) cookie mein set karo; client use header mein copy kare; server dono match kare. Attacker ki site browser se cookie bhejwa sakti hai, par padh nahi sakti, to header nahi bhar sakti. Classic CSRF tokens chahiye ho (jaise `SameSite=None` ke saath) tab ye use karo.

### 20.4 WebSockets

Browser ki `WebSocket` API **custom headers set nahi kar sakti**, to `Authorization: Bearer` ka option hi nahi hai. Choices:
- **Handshake pe cookie:** WebSocket same-site ho to chalta hai. WebSockets **CORS se protected nahi hain**, to handshake pe `Origin` header khud check karo, warna koi bhi site user ki cookie ke saath socket khol legi (Cross-Site WebSocket Hijacking).
- **One-time ticket:** client bearer token ke saath `POST /ws-ticket` call kare, ~30 second valid ek random single-use ticket le, aur `wss://api/ws?ticket=...` pe connect kare. Ticket URL mein hai, par ek use ya 30 second ke baad bekaar hai. Jaise **OTP**: SMS mein dikh bhi jaaye to ek baar aur thodi der hi chalta hai.
- **First-message auth:** bina credentials connect karo, pehle message mein token bhejo; kuch seconds mein na aaye to server socket band kar de.

Lambe connections token se zyada jeete hain: server `exp` yaad rakhe aur time nikalte hi socket band kare (ya socket pe naya token maange), aur revocation pe bhi react kare.

### 20.5 Service-to-service tokens (koi user nahi)

Cron job ya Order Service jab Payment Service ko call karti hai, to login karne wala koi user nahi hai. **OAuth 2.0 Client Credentials flow** use karo:
1. Service apne credentials se auth server pe authenticate kare (client secret, ya better, signed JWT assertion / mTLS).
2. Usse short-lived access token mile jiska `sub` = service ka client id, aur sirf zaroori scopes (`payments:charge`).
3. Token cache kare aur `exp` se thoda pehle naya maang le. Is flow mein **refresh token nahi hota**; service seedha dobara maangti hai.

Background kaam ke liye user ka token reuse mat karo, aur saari services ke beech ek "god-token" kabhi share mat karo.

### 20.6 Scopes vs roles

- **Role** = user kaun hai (`admin`, `support`). Coarse, user ka hai.
- **Scope** = **ye wala token** kya kar sakta hai (`orders:read`, `profile:write`). Fine-grained, token ka hai.
- Fark tab dikhta hai jab third-party app tumhari taraf se kaam kare: tum admin ho sakte ho, par reporting tool ko jo token diya usme sirf `reports:read` hona chahiye. Effective permission = user ko jo allowed hai **aur** token ke scopes jo allow karte hain.
- Socho **power of attorney**: tum ghar ke maalik ho (role), par CA ko sirf tax file karne ka haq diya (scope), ghar bechne ka nahi.
- Format: `scope` space-separated string hai (`"orders:read orders:write"`); kuch providers `scp` array use karte hain. Scopes har endpoint pe check karo, sirf gateway pe nahi.

### 20.7 PASETO, JWT ka alternative

PASETO (Platform-Agnostic Security Tokens) JWT ki galtiyon se bachne ke liye bana:
- **`alg` header hi nahi hai.** Version aur purpose prefix mein fix hai (`v4.public.` = Ed25519 signature, `v4.local.` = symmetric encryption). Algorithm confusion aur `alg: none` design se hi impossible.
- `local` tokens **default encrypted** hain, payload padha hi nahi ja sakta.
- Nuksaan: chhota ecosystem, aur OAuth/OIDC ko JWT chahiye, to ID tokens ya zyada tar identity providers ke saath PASETO nahi chalega.

Achha interview answer: "If I control both issuer and verifier and do not need OIDC interoperability, PASETO is safer by design. Otherwise I use JWT with pinned algorithms."

### 20.8 Admin impersonation

Support staff ko kabhi "user ban ke login" karna padta hai. Explicitly karo, password share karke kabhi nahi:
- Token do jisme `sub` = user aur ek **`act` claim** jo asli karne wale ka naam le: `"act": {"sub": "admin_7"}` (RFC 8693).
- Audit logs dono identities record karte hain, to har action dikhata hai "admin_7 acting as user_42".
- Token short-lived rakho aur impersonation ke dauraan khatarnak actions block karo (password/email change, payouts).

### 20.9 Chhote validation details

- **Future ka `iat`:** "kal" issue hua token matlab ghadi kharab hai ya forgery. Leeway se zyada ho to reject karo. `iat` ho to PyJWT ye karta hai; doosri libraries mein confirm kar lo.
- **"Remember me":** sirf refresh token badalta hai. Unchecked → `Max-Age` nahi (browser band = cookie khatam) aur chhoti refresh lifetime. Checked → lambi lifetime wali persistent cookie. Access token dono case mein 15 min hi.
- **Absolute session cap:** family mein original login time (`auth_time`) store karo aur uske baad refresh mana karo, rotation ke bawajood.

### 20.10 Tests jo rakhne chahiye

Minimum set jo security logic tootne pe fail ho:

> Code: see `jwt_code.md`, section 20.10.

`/auth/refresh` ke against integration tests mein ye bhi cover karo: galat `aud`/`iss` reject, grace window ke baad refresh-token reuse family revoke kare, revoked family refresh na kar sake, `revoke_all_sessions` dono token types maare, aur CSRF header ke bina request ko 403 mile.

> **Interview line:** "In production the hard parts of JWT are rarely the signature. They are cookie behaviour across sites, refresh races between tabs, CSRF on the refresh endpoint, and authenticating WebSockets. I keep the API on the same site as the frontend, serialise refreshes across tabs, require a custom header on refresh, and use short-lived tickets for WebSockets."

---

## 21. Active recall: bina upar dekhe answer karo

1. JWT ke teen parts kya hain, aur kaunsa part tamper hone se bachata hai?
2. "Encoded", "signed" aur "encrypted" mein ek-ek line ka fark batao.
3. Verifier ko `alg` token ke header se kyun nahi padhna chahiye? Dono attacks ke naam batao.
4. `aud` check na karne se kya galat ho sakta hai? Ek real scenario do.
5. Access token memory mein aur refresh token httpOnly cookie mein kyun? Har ek kis attack se bachata hai?
6. httpOnly cookie hone ke baad bhi XSS dangerous kyun hai?
7. Refresh token reuse detection step by step samjhao. Frontend pe kaunsa race condition isko tod sakta hai, aur fix kya hai?
8. Password change pe user ke saare tokens kaise invalidate karoge, bina signing key badle?
9. Blocklist entry ka TTL kitna rakhoge, aur kyun?
10. Zero-downtime key rotation ke 5 steps batao.
11. ID token ko API call mein bhejna galat kyun hai?
12. Ek single monolith app ke liye tum JWT choose karoge ya session? Interview-style formal English mein 3–4 lines mein justify karo.
13. HS256 secret leak ho gaya. Tumhare pehle paanch actions kya honge? Planned rotation ke ulat yahan grace period kyun nahi?
14. Kisi ko logout kiye bina HS256 secret kaise rotate karoge?
15. Refresh-token reuse detection ka blind spot kya hai, aur kaunse teen defences usko cover karte hain?
16. Signing key, refresh token (client aur server), blocklist aur `token_version` kahan store karoge? Refresh tokens hashed kyun store karte hain?
17. Redis down hai: fail open ya fail closed? Banking app aur blog dono ke liye apna choice defend karo.
18. Frontend `vercel.app` pe hai aur API `onrender.com` pe. Refresh cookie kaam karna kyun band kar deti hai, aur teen fixes preference ke order mein kya hain?
19. Do tabs ek saath refresh karte hain aur user logout ho jaata hai. Kyun? Frontend aur backend pe fix kya hai?
20. Browser `Authorization` header nahi bhej sakta to WebSocket ko authenticate kaise karoge? Cross-Site WebSocket Hijacking kya hai?
21. Scope vs role: third-party app ke example se samjhao.
22. PASETO JWT ke comparison mein kya hata deta hai, aur kab use nahi kar sakte?
$jwt_hi_body$
FROM course_modules cm JOIN courses c ON c.id = cm.course_id
WHERE c.slug = 'engineering-playbook' AND cm.title = 'JWT, the full story'
ON CONFLICT (module_id, locale) DO UPDATE SET content_body = EXCLUDED.content_body, updated_at = now();

-- The code samples import FastAPI/PyJWT, which the in-lesson runner can't run.
UPDATE courses SET disable_code_run = true WHERE slug = 'engineering-playbook';


-- ══ merged from jwt.post-seed.sql ══

-- Post-seed for the JWT course (content/courses/jwt). Run AFTER the generated
-- course SQL and after migration 049 (module_translations). Idempotent.
-- Hinglish (Hindi in Latin script) version of the main lesson, shown via the
-- lesson language switcher; BCP-47 tag hi-Latn.
INSERT INTO module_translations (module_id, locale, content_body)
SELECT cm.id, 'hi-Latn', $jwt_hi_body$# JWT, poori kahani

> Approach: har section pehle Hinglish mein intuition banata hai. Jahan "Interview line" likha hai, wo formal English mein hai, taaki interview mein seedha bol sako.

---

## 1. Problem kya tha? JWT aaya hi kyun?

HTTP **stateless** hai. Har request ek nayi request hai, server ko yaad nahi rehta ki "ye wahi banda hai jisne abhi login kiya tha". Isliye har request ke saath kuch proof bhejna padta hai ki "main Nayan hoon, aur mujhe ye access hai".

Iske do tareeke hain:

1. **Session (purana desi tareeka):** login pe server ek random `session_id` banata hai, apne paas (DB ya Redis mein) likh leta hai, aur browser ko cookie mein de deta hai. Har request pe server apna register kholta hai: "ye session_id kiska hai?"
   - Socho **railway cloakroom**: tumhe ek token number milta hai, saaman counter ke andar rakha hai. Token sirf number hai, asli info counter ke paas hai.
2. **JWT (self-contained tareeka):** login pe server ek token banata hai jisme user ki info **khud likhi hoti hai** (user id, role, expiry), aur server us pe apna **signature/mohar** laga deta hai. Server ko kuch store nahi karna. Har request pe bas mohar check karo, sahi hai to andar ki info pe bharosa karo.
   - Socho **office ka ID card**: card pe naam, department, valid-till date sab chhapa hai, aur company ka hologram laga hai. Gate wala guard HR ko phone nahi karta, bas hologram dekhta hai aur andar jaane deta hai.

**Main fayda:** server ko har request pe DB/Redis hit nahi karna padta. Isliye ye microservices, mobile apps aur horizontally scaled APIs mein bahut popular hai. Koi bhi server, koi bhi instance, bas key se signature verify karo, ho gaya.

**Main nuksaan (yaad rakhna, interview mein yahi poochenge):** ID card ek baar de diya to wapas lena mushkil hai. Banda resign kar de, phir bhi card pe "valid till Dec" likha hai, to guard andar jaane dega. Yahi JWT ka **revocation problem** hai (section 9).

> **Interview line:** "JWT is a compact, self-contained, signed token. The server can verify it without a database lookup, which makes it ideal for stateless and distributed systems. The trade-off is that revoking a token before it expires is hard."

---

## 2. JWT ki shakal: `Header.Payload.Signature`

Ek JWT aisa dikhta hai (teen hisse, dot se alag):

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzEiLCJyb2xlIjoiYWRtaW4iLCJleHAiOjE3OTk5OTk5OTl9.<signature>
└──────────── header ────────────────┘ └──────────────────────── payload ─────────────────────────────┘ └── sig ──┘
```

### 2.1 Header: "token kaise bana hai"

```json
{ "alg": "HS256", "typ": "JWT", "kid": "2026-10" }
```

| Field | Matlab |
|---|---|
| `alg` | Signature kis algorithm se bana (HS256, RS256, ES256, EdDSA) |
| `typ` | Token type, usually `JWT` (access token ke liye `at+jwt` bhi dekhoge) |
| `kid` | Key ID. Kaunsi key se sign hua, key rotation mein kaam aata hai |

### 2.2 Payload: "token kiske baare mein hai" (claims)

```json
{ "sub": "user_1", "role": "admin", "exp": 1799999999 }
```

Payload ke andar ke har key-value ko **claim** bolte hain. Teen type ke claims hote hain:

**a) Registered claims** (RFC 7519 mein defined, sab short 3-letter names, taaki token chhota rahe):

| Claim | Full form | Kya hai | Check kaun karta hai |
|---|---|---|---|
| `iss` | issuer | Kisne token banaya (`https://auth.myapp.com`) | Verifier: expected issuer se match karo |
| `sub` | subject | Token kiske baare mein hai (user id) | App logic |
| `aud` | audience | Token kiske liye bana (`orders-api`) | Verifier: "kya ye mere liye hai?" |
| `exp` | expiration | Kab expire hoga (Unix seconds) | Verifier: `now < exp` |
| `nbf` | not before | Isse pehle valid nahi | Verifier: `now >= nbf` |
| `iat` | issued at | Kab bana | Debugging, max-age checks |
| `jti` | JWT ID | Token ka unique id | Revocation/blocklist, replay rokna |

**b) Public claims:** IANA registry mein registered common names, jaise `email`, `name`, `email_verified` (ye OIDC se aate hain).

**c) Private/custom claims:** tumhare app ke apne, jaise `role`, `tenant_id`, `token_version`. Naam aise rakho ki registered names se clash na ho.

### 2.3 Signature: "mohar"

```text
signature = HMAC_SHA256( base64url(header) + "." + base64url(payload), secret )
```

Signature header + payload dono ko cover karta hai. Agar kisi ne payload mein `"role":"user"` ko `"role":"admin"` kar diya, to signature match nahi karega, kyunki naya signature banane ke liye **secret key** chahiye jo sirf server ke paas hai.

### 2.4 Sabse bada confusion: Base64URL ≠ Encryption

Ye line dil pe likh lo: **JWT ka payload encrypted NAHI hai, sirf encoded hai.** Koi bhi [jwt.io](https://jwt.io) pe paste karke ya kuch lines code se padh sakta hai:

> Code: see `jwt_code.md`, section 2.4.

- **Encoding** = sirf format badalna (koi bhi wapas kar sakta hai). Jaise Hindi ko Roman script mein likhna.
- **Signing** = proof ki data badla nahi gaya (integrity + authenticity). Padh sab sakte hain, badal koi nahi sakta.
- **Encryption** = data chhupana (confidentiality). Sirf key wala padh sakta hai.

Isliye payload mein **kabhi** password, Aadhaar, PAN, card number, ya koi secret mat daalo. Data chhupana hai to **JWE** use karo (section 11).

Base64**URL** kyun, normal Base64 kyun nahi? Kyunki normal Base64 mein `+`, `/`, `=` aate hain jo URL aur headers mein problem karte hain. Base64URL `-` aur `_` use karta hai aur padding `=` hata deta hai.

> **Interview line:** "A JWT is encoded and signed, not encrypted. Anyone can read the payload, but nobody can modify it without invalidating the signature. Sensitive data should never go into the payload; if confidentiality is required, use JWE."

---

## 3. Signing algorithms: HS256 vs RS256 vs ES256 vs EdDSA

### Symmetric: HS256 (HMAC + SHA-256)

- **Ek hi secret** se sign bhi hota hai aur verify bhi.
- Simple aur fast.
- Problem: jo verify kar sakta hai, wo **sign bhi kar sakta hai**. Agar 10 microservices verify karti hain, to sabke paas secret hai, aur ek bhi leak hua to koi bhi fake token bana sakta hai.
- Socho **ghar ki ek hi chaabi** jo lock bhi karti hai aur kholti bhi hai. Jitne logon ko di, utna risk.
- Secret kam se kam **256 bits (32 random bytes)** ka ho. `"secret123"` jaisa secret offline brute-force ho jaata hai (hashcat se, section 10).

### Asymmetric: RS256 / ES256 / EdDSA

- **Private key** se sirf auth server sign karta hai.
- **Public key** se koi bhi service verify kar sakti hai, par sign nahi kar sakti.
- Socho **sarkari mohar**: mohar (private key) sirf tehsil office ke paas hai, par mohar ka sample (public key) har bank ke paas hai taaki wo check kar sake ki document asli hai.
- Public keys **JWKS endpoint** pe publish hoti hain (`/.well-known/jwks.json`), section 12.

| Algo | Type | Key size | Kab use karein |
|---|---|---|---|
| HS256 | Symmetric (HMAC) | ≥ 256-bit secret | Ek hi service jo sign aur verify dono karti hai |
| RS256 | RSA + SHA-256 | 2048+ bit | Distributed systems, sabse widely supported |
| ES256 | ECDSA P-256 | 256-bit | RS256 jaisa hi, par chhoti keys aur chhote tokens |
| EdDSA (Ed25519) | Edwards curve | 256-bit | Modern, fast, safe defaults. Library support check kar lo |
| `none` | Koi signature nahi | — | **Kabhi nahi.** Attack vector hai |

> **Interview line:** "I use HS256 when a single service both issues and verifies tokens. In a distributed system I use an asymmetric algorithm like RS256 or ES256: the auth server keeps the private key and every other service verifies with the public key from a JWKS endpoint, so a compromised service cannot forge tokens."

---

## 4. Poora auth flow, step by step

```text
1. Client  → POST /login {email, password}
2. Server  → password verify karo (bcrypt/argon2 hash se)
3. Server  → access token (15 min) + refresh token (7 din) banao
4. Server  → access token response body mein, refresh token httpOnly cookie mein
5. Client  → har API call: Authorization: Bearer <access_token>
6. Server  → signature + claims verify karo → request process karo (koi DB lookup nahi)
7. 15 min baad access token expire → API 401 deta hai
8. Client  → POST /auth/refresh (cookie apne aap jaati hai)
9. Server  → refresh token verify + rotate → naya access token (+ naya refresh token)
10. Logout → refresh token revoke karo, cookie clear karo
```

`Bearer` ka matlab hai "jiske paas hai, wahi maalik". Jaise cinema ticket: ticket kiske paas hai, guard ko farak nahi padta, ticket dikhao aur andar jao. Isliye token chori hona = account chori hona. Har jagah **HTTPS** zaroori hai.

---

## 5. Verification checklist (server har request pe kya check kare)

Sirf "signature sahi hai" kaafi nahi. Poori list:

1. **Format:** teen parts hain, valid Base64URL, valid JSON.
2. **Algorithm allowlist:** `alg` ko **token se mat padho**, server pe fix rakho (`algorithms=["RS256"]`). Ye check na karna sabse common bug hai (section 10).
3. **Signature:** sahi key se verify karo (`kid` se key choose karo, par sirf apne trusted JWKS se).
4. **`exp`:** expire to nahi hua?
5. **`nbf`:** abhi valid hua ya nahi?
6. **`iss`:** mera trusted issuer hai?
7. **`aud`:** ye token **mere** service ke liye bana hai? (Warna `payments-api` ka token `admin-api` pe chal jayega.)
8. **Token type:** access token ki jagah refresh token to nahi bhej diya? (`type` claim ya `typ` header check karo.)
9. **Revocation (agar lagaya hai):** `jti` blocklist mein to nahi? `token_version` user ke current version se match karta hai?
10. **Authorization:** token valid hai iska matlab ye nahi ki user ko ye resource access karne ka haq hai. Role/scope/ownership alag se check karo.

**Clock skew:** alag-alag servers ki ghadi thodi aage-peeche hoti hai. 30–60 second ka `leeway` do, warna fresh token bhi kabhi-kabhi "expired" ya "not yet valid" ho jayega.

**`decode` vs `verify`:** kai libraries mein `decode(..., verify=False)` jaisa option hota hai. Wo sirf padhta hai, verify nahi karta. Auth ke liye kabhi use mat karo, sirf debugging ke liye.

---

## 6. Expiry, access token aur refresh token

### Dilemma

- Access token ki lambi expiry (7 din): chori hua to 7 din tak misuse. **Security kharab.**
- Chhoti expiry (15 min): har 15 min pe login karo. **UX kharab.**

### Solution: do tokens, do kaam

| | Access token | Refresh token |
|---|---|---|
| Kaam | API calls authorize karna | Naya access token lena |
| Expiry | Chhoti (5–15 min) | Lambi (7–30 din) |
| Kahan jaata hai | Har API request | Har request ke saath cookie jaati hai, par sirf `/auth/refresh` use padhta hai |
| Kahan store | Memory (JS variable) | httpOnly + Secure + SameSite cookie (`__Host-` prefix, `Path=/`) |
| Server pe state | Nahi (stateless) | **Haan**, DB/Redis mein track karo |
| Format | JWT | JWT ya simple opaque random string (dono chalte hain) |

Socho **metro**: access token = single journey ka token (ek trip, jaldi khatam). Refresh token = metro card (lamba chalta hai, par sirf recharge counter pe use hota hai, har gate pe nahi). Card khoya to block karwa sakte ho, kyunki system mein registered hai.

**Important point:** refresh token ko server-side track karna hi padta hai. Isliye "JWT poora stateless hai" adha sach hai. Practical systems **hybrid** hote hain: access token stateless, refresh token stateful. Isse revocation sambhav hota hai, aur DB hit sirf har 15 min mein ek baar hota hai, har request pe nahi.

### Expiry kitni rakhein? (rough guide)

| App type | Access | Refresh |
|---|---|---|
| Banking / payments | 5 min | Chhota (ya re-auth for sensitive actions) |
| Normal SaaS / e-commerce | 15 min | 7–14 din |
| Mobile app (long login chahiye) | 15–60 min | 30–90 din, rotation ke saath |

Absolute lifetime bhi rakho: rotation ke baad bhi, maan lo 90 din baad, dobara login karwao.

---

## 7. Refresh token rotation + reuse detection (deep dive)

**Rotation:** har baar `/refresh` call pe purana refresh token **invalidate** karo aur naya do. Ek refresh token = ek baar use.

**Reuse detection (asli magic):** maan lo hacker ne refresh token RT1 chura liya.

```text
User   uses RT1 → server gives RT2 (RT1 ab "used" mark)
Hacker uses RT1 → server dekhta hai: "RT1 to already use ho chuka hai!"
       → ye chori ka saboot hai → poori token FAMILY revoke (RT2 bhi)
       → user aur hacker dono logout → user dobara login karega, hacker bahar
```

Ulta case bhi same hai: hacker pehle use kare to user ka RT1 reuse dikhega, aur family phir bhi revoke hogi.

Implementation ka idea: har refresh token ko DB mein `{jti, user_id, family_id, used, expires_at}` ke saath store karo. Login pe naya `family_id` banta hai, har rotation usi family mein naya `jti` add karti hai.

**Race condition ka dhyan:** frontend pe 3 API calls ek saath 401 de sakti hain aur teeno refresh call kar sakti hain. Pehli rotate kar degi, baaki do "reuse" lagengi aur user bina wajah logout ho jayega. Do fix hain, aur dono lagao:
- Frontend: ek waqt pe sirf **ek refresh request** in-flight rakho (section 15 ka Axios code).
- Backend: chhota **grace window** (jaise 10–30 sec) rakho jisme purana token same naya token return kare.

> **Interview line:** "I rotate refresh tokens on every use and track them in token families. If an already-used refresh token is presented again, that indicates theft, so I revoke the entire family and force the user to log in again."

---

## 8. Token kahan store karein? (XSS vs CSRF ka khel)

Pehle do attacks samjho:

- **XSS (Cross-Site Scripting):** attacker tumhari site pe apni JavaScript chala deta hai (comment box mein script, ya koi compromised npm package). Wo JS jo bhi JS padh sakti hai, sab chura sakti hai.
- **CSRF (Cross-Site Request Forgery):** attacker ki site `evil.com` tumhare browser se `bank.com` pe request bhejti hai, aur browser **cookies apne aap attach** kar deta hai. Attacker cookie padh nahi sakta, par use kar sakta hai.

| Storage | XSS se token chori? | CSRF risk? | Refresh pe bachta hai? | Verdict |
|---|---|---|---|---|
| `localStorage` | **Haan**, koi bhi JS padh le | Nahi | Haan | Avoid for sensitive apps |
| `sessionStorage` | **Haan** | Nahi | Tab band hote hi gaya | Same problem |
| JS memory (variable) | Mushkil (page ke saath chala jaata hai) | Nahi | **Nahi**, refresh pe gaya | Access token ke liye best |
| httpOnly cookie | **Nahi**, JS padh hi nahi sakti | **Haan**, browser apne aap bhejta hai | Haan | Refresh token ke liye best (+ CSRF protection) |

**Best practice combo:**
- **Access token → memory mein.** Page refresh pe gaya? Koi baat nahi, silently `/auth/refresh` call karo.
- **Refresh token → httpOnly cookie** in flags ke saath:

```text
Set-Cookie: __Host-refresh=<token>; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=604800
```

| Flag | Kya karta hai |
|---|---|
| `HttpOnly` | JS `document.cookie` se padh nahi sakti, XSS se chori nahi hoga |
| `Secure` | Sirf HTTPS pe jaayegi |
| `SameSite=Strict` | Doosri site se aayi request mein cookie nahi jaayegi, CSRF ka main ilaaj |
| `SameSite=Lax` | Top-level GET navigation pe jaati hai, POST pe nahi. Achha default |
| `Path=/auth/refresh` | Cookie sirf refresh endpoint pe jaaye (`__Host-` prefix ke saath `Path=/` zaroori hai, isliye ek choose karo) |
| `__Host-` prefix | Browser force karta hai: Secure ho, Path=/ ho, Domain set na ho. Subdomain wale attacks se bachata hai |

**Ek kadwa sach:** XSS ho gaya to httpOnly bhi tumhe poori tarah nahi bachata. Attacker token padh nahi sakta, par tumhari site ke andar se hi tumhare naam pe requests bhej sakta hai. httpOnly bas token ko **bahar le jaane** se rokta hai. Asli ilaaj XSS rokna hai: output escaping, CSP header, dependencies audit.

**Mobile apps:** cookies ka jhanjhat nahi hai. Tokens ko **Keychain (iOS) / Keystore-backed EncryptedSharedPreferences (Android)** mein rakho, plain SharedPreferences mein nahi.

**BFF pattern (Backend-for-Frontend):** sabse secure SPA setup. Tokens browser tak aate hi nahi. Browser ke paas sirf ek httpOnly session cookie hoti hai, aur BFF server tokens rakhta hai aur API calls forward karta hai. Banking-grade apps mein ye pattern dekhoge.

> **Interview line:** "I keep the access token in memory and the refresh token in an HttpOnly, Secure, SameSite cookie. That protects the refresh token from XSS theft and SameSite blocks most CSRF. For the highest security in SPAs, I use the BFF pattern so tokens never reach the browser."

---

## 9. Revocation: JWT ko "cancel" kaise karein?

JWT stateless hai, to `exp` se pehle use maarna mushkil hai. Options, sasta se mehnga:

| Tareeka | Kaise | Trade-off |
|---|---|---|
| **Short expiry** | Access token 5–15 min | Worst case 15 min ka window. Zyada tar apps ke liye kaafi |
| **Refresh token revoke** | Logout pe DB/Redis se refresh token delete | Naya access token nahi milega. Purana `exp` tak chalega |
| **`jti` blocklist** | Logout pe `jti` Redis mein daalo, TTL = token ki bachi umar | Har request pe ek Redis lookup (stateless-pan thoda gaya) |
| **`token_version` per user** | User table mein version, token mein bhi. Password change pe version++ | User ke **saare** tokens ek saath dead. DB/cache lookup chahiye |
| **Key rotation** | Signing key badal do | **Sabke** tokens dead. Sirf emergency (key leak) mein |

**Kab kya use karein:**
- Normal logout → refresh token revoke + frontend se access token hatao.
- "Logout from all devices" / password change → `token_version` bump.
- Account ban / suspicious activity → `jti` blocklist ya `token_version`.
- Secret leak → key rotation (sab logout, koi chara nahi).

Blocklist ke liye **Redis + TTL** sabse sahi hai. Entry apne aap token ki expiry ke saath gayab ho jaati hai, cleanup ka jhanjhat nahi. In-memory `set()` sirf local dev ke liye hai, multiple instances mein kaam nahi karega.

**Allowlist vs blocklist:** blocklist = "ye tokens band hain" (chhoti list). Allowlist = "sirf ye tokens valid hain" (har active token store). Allowlist basically session hi ban jaata hai, to tab socho ki JWT kyun use kar rahe ho.

---

## 10. Attacks jo interview mein poochte hain (aur bachaav)

### 10.1 `alg: none`
Attacker header mein `"alg":"none"` daal ke signature hata deta hai. Kuch purani libraries isko valid maan leti thi.
**Bachaav:** `algorithms=["RS256"]` server pe hardcode karo. `none` kabhi allow mat karo.

### 10.2 Algorithm confusion (RS256 → HS256)
Server RS256 expect karta hai, public key se verify karta hai. Attacker token ko **HS256** bol ke **public key ko hi HMAC secret** bana ke sign kar deta hai. Public key to public hai, sabke paas hai! Agar library `alg` token se padhti hai, to wo public key ko HMAC secret maan ke verify karegi, aur fake token **pass** ho jayega.
**Bachaav:** wahi baat, allowed algorithms server pe fix rakho. Key type aur algorithm ko bind karo (RSA key sirf RS256 ke saath).

### 10.3 Weak HS256 secret
`secret`, `changeme`, `myapp123` jaise secrets. Attacker ke paas ek valid token hai to wo **offline brute-force** kar sakta hai (hashcat), server ko pata bhi nahi chalega. Secret mila to woh koi bhi token, kisi bhi role ka, bana sakta hai.
**Bachaav:** `secrets.token_urlsafe(32)` ya usse lamba. Env/secret manager se lo, code mein kabhi nahi.

### 10.4 `kid` injection
`kid` header se server key dhoondta hai. Agar code `open(f"keys/{kid}")` ya SQL query mein `kid` daalta hai, to attacker `kid: "../../dev/null"` (empty key!) ya SQL injection kar sakta hai.
**Bachaav:** `kid` ko sirf ek trusted key map/JWKS mein lookup ki tarah use karo. File path ya query mein kabhi nahi.

### 10.5 `jku` / `x5u` header abuse
Ye headers bolte hain "public key yahan se download karo". Attacker apna URL daal deta hai, apni key se sign karta hai, aur server attacker ki key se verify kar deta hai.
**Bachaav:** in headers ko ignore karo. JWKS URL server config mein fix rakho.

### 10.6 Missing `aud` check (token substitution)
Same auth server multiple apps ke tokens deta hai. App A ka token App B pe chal gaya, kyunki B ne `aud` check nahi kiya.
**Bachaav:** `aud` aur `iss` hamesha verify karo.

### 10.7 Token leakage
URL mein token (`?token=...`) server logs, browser history, aur Referer header mein leak hota hai. Logs mein poora `Authorization` header print karna bhi leak hai.
**Bachaav:** token sirf header/cookie mein. Logs mein token mask karo.

### 10.8 No expiry / bahut lambi expiry
Chori hua token hamesha ke liye chalega.
**Bachaav:** `exp` mandatory banao (`options={"require": ["exp"]}`).

### 10.9 Token replay / sidejacking
Chori hua token attacker kisi aur machine se use kar le.
**Bachaav (advanced):** **sender-constrained tokens**, matlab token ek key se bind ho jo sirf client ke paas hai:
- **DPoP** (OAuth 2.0 Demonstrating Proof of Possession): client har request pe apni private key se ek proof sign karta hai.
- **mTLS-bound tokens:** token client certificate se bind hota hai.
Isse token chori ho bhi jaaye to bina private key ke bekaar hai.

> **Interview line:** "The most common JWT vulnerabilities are trusting the alg header, which enables alg none and RS256-to-HS256 confusion, using weak HMAC secrets that can be brute-forced offline, and skipping the aud and iss checks. I pin the allowed algorithms on the server, use strong keys from a secret manager, and validate every registered claim."

---

## 11. JWS vs JWE vs JWT (naam ka jhamela)

- **JWT** = format/standard ka naam (RFC 7519). Claims ka JSON structure.
- **JWS** (JSON Web Signature) = **signed** token. Jo hum roz use karte hain, 3 parts. Padh sakte ho, badal nahi sakte.
- **JWE** (JSON Web Encryption) = **encrypted** token. **5 parts**: `header.encryptedKey.iv.ciphertext.authTag`. Koi padh hi nahi sakta bina key ke.
- **Nested JWT** = pehle sign, phir encrypt (sign-then-encrypt). Integrity bhi, confidentiality bhi.

90% cases mein JWS + HTTPS kaafi hai. JWE tab jab token kisi untrusted beech wale (third party, browser) se guzarta hai aur andar sensitive data hai.

Related: **JWK** = ek key ko JSON mein represent karna. **JWKS** = keys ka set (array). **JOSE** = in sab standards ki family ka naam.

---

## 12. JWKS aur key rotation

Auth server apni **public keys** ek URL pe publish karta hai:

```text
GET https://auth.myapp.com/.well-known/jwks.json
{ "keys": [
  { "kid": "2026-09", "kty": "RSA", "alg": "RS256", "use": "sig", "n": "...", "e": "AQAB" },
  { "kid": "2026-10", "kty": "RSA", "alg": "RS256", "use": "sig", "n": "...", "e": "AQAB" }
]}
```

Verifier token ke header se `kid` padhta hai, JWKS mein matching key dhoondta hai, aur verify karta hai.

**Zero-downtime rotation:**
1. Nayi key (`2026-10`) JWKS mein **add** karo, par sign abhi purani se hi karo.
2. Verifiers ki JWKS cache refresh hone do (jaise 1 ghanta).
3. Ab nayi key se **sign** karna shuru karo.
4. Purani key tab tak JWKS mein rakho jab tak uske saare tokens expire na ho jaayein (max refresh lifetime, agar refresh tokens JWT hain; opaque hain to access-token lifetime kaafi hai).
5. Phir purani key hatao.

**Caching:** verifiers JWKS ko cache karte hain (har request pe fetch mat karo). Unknown `kid` aaye to ek baar re-fetch karo, par rate-limit karke, warna attacker random `kid` bhej ke tumhare auth server pe DoS kar dega.

---

## 13. Microservices aur API gateway mein JWT

```text
Client → API Gateway (JWT verify: sig, exp, iss, aud) → Order Service → Payment Service
```

Common patterns:
- **Gateway pe verify, andar trust:** gateway verify karke user info headers mein forward karta hai (`X-User-Id`). Simple hai, par andar ka network trusted hona chahiye (zero-trust mein ye kaafi nahi).
- **Har service khud verify kare:** JWKS se public key lo, locally verify karo. Zero-trust friendly. Asymmetric algo yahan zaroori hai.
- **Token exchange (RFC 8693):** Order service, Payment service ko call karte waqt user ka token aage na bheje. Naya token le jiska `aud` = `payments` aur scope chhota ho. Isse ek service ka token doosri jagah misuse nahi hoga.

**Token size ka dhyan:** JWT har request mein jaata hai. 50 roles aur permissions daal diye to token 4–8 KB ka ho jayega. Headers ki limit hai (kai servers ~8 KB), aur bandwidth bhi waste hoti hai. Token mein **identity aur coarse roles** rakho, fine-grained permissions service khud cache se dekhe.

**Stale claims:** token mein `role: admin` hai, aur beech mein admin role hata diya. Token expire hone tak wo admin hi rahega. Yahi ek aur wajah hai access token chhota rakhne ki.

---

## 14. OAuth 2.0 aur OpenID Connect mein JWT

Ye confusion bahut common hai, isliye clear kar lo:

- **OAuth 2.0** = **authorization** framework ("is app ko meri Google Drive padhne ki permission do"). Access token kisi bhi format mein ho sakta hai. Zaroori nahi ki JWT ho.
- **OpenID Connect (OIDC)** = OAuth ke upar **authentication** layer ("ye banda kaun hai"). Ye **ID token** deta hai, jo **hamesha JWT** hota hai.

| | ID token | Access token |
|---|---|---|
| Kiske liye | Client app ke liye (user kaun hai) | API/resource server ke liye |
| Format | Hamesha JWT | JWT ya opaque |
| `aud` | Client ID | API identifier |
| API call mein bhejo? | **Nahi** | Haan |

Golden rule: **ID token API pe mat bhejo, access token se user identity mat nikalo.** "Login with Google" ka flow yahi hai: Authorization Code + **PKCE** flow se code lo, backend pe tokens mein exchange karo, ID token verify karke user identify karo.

**Opaque token + introspection:** kuch systems access token ko random string rakhte hain, aur API har baar auth server se `/introspect` karke poochti hai "ye valid hai?". Isse instant revocation milta hai, par har request pe network call lagti hai. JWT ka bilkul ulta trade-off.

---

## 15. Code: FastAPI + PyJWT

> FastAPI ke official docs ab **PyJWT** recommend karte hain. `python-jose` ki purani recommendation hata di gayi hai, naye projects mein mat lo. `pip install pyjwt` (RS256 ke liye `pyjwt[crypto]`).

### 15.1 Token banana aur verify karna

> Code: see `jwt_code.md`, section 15.1.

`except jwt.ExpiredSignatureError` pehle aana chahiye, kyunki wo `InvalidTokenError` ka hi subclass hai. Order ulta kiya to "expired" wala message kabhi nahi dikhega.

Note: `iat`/`exp` mein `datetime.now(timezone.utc)` use karo. `datetime.utcnow()` deprecated hai aur naive datetime deta hai.

### 15.2 Login, refresh (rotation + reuse detection), logout, saare sessions revoke

> Code: see `jwt_code.md`, section 15.2.

Ye code kya cover karta hai:
- **"Sab devices se logout" / password change:** `revoke_all_sessions` `tokens_valid_after = now` set karta hai. `get_current_user` aur `/refresh` dono purane `iat` wale token reject karte hain, to access **aur** refresh tokens saath mein marte hain. (`token_version` claim bhi same kaam karta hai; timestamp wale tareeke mein extra claim nahi chahiye.)
- **Grace window:** 15 second se kam pehle rotate hua token ek baar aur accept hota hai, chori nahi maana jaata. Isse parallel requests aur multiple tabs handle ho jaate hain. Trade-off: chor ne unhi 15 second mein use kiya to pakda nahi jayega.
- `/refresh` pe **CSRF header** (section 20.3).
- **Logout** ko valid access token nahi chahiye: wo cookie se refresh family revoke karta hai, aur access `jti` blocklist mein tabhi daalta hai jab wo token abhi valid ho.
- `refresh_repo` aur `users_repo` tumhari apni DB layer hain (19.5 ki `refresh_tokens` table). `issue_tokens` wahan bhi likhta hai, taaki Redis wipe se revoked sessions zinda na ho jaayein.
- Agar Redis mirror kho sakta hai, to cache miss pe `tokens_valid_after` DB se padho.

### 15.3 RS256 version (sirf jo badalta hai)

> Code: see `jwt_code.md`, section 15.3.

### 15.4 Frontend: Axios auto-refresh (single-flight, multi-tab safe)

> Code: see `jwt_code.md`, section 15.4.

Important baatein:
- `refreshPromise` share hota hai, to 5 parallel 401s pe bhi **sirf ek** refresh call jaayegi (section 7 ka race condition fix).
- `navigator.locks` yahi kaam **tabs ke beech** karta hai (section 20.2), aur `BroadcastChannel` logout ko har tab tak pahunchata hai.
- `isRefreshCall` check: refresh khud 401 de to infinite loop nahi banega.
- `_retry` flag: ek request sirf ek baar retry hogi.
- App load pe (page refresh ke baad) memory khaali hai, to pehle ek silent `/auth/refresh` call karo.

---

## 16. Session vs JWT: kab kya?

| | Session (opaque ID) | JWT |
|---|---|---|
| Data kahan | Server (DB/Redis) | Token ke andar (client ke paas) |
| Har request pe | Store lookup | Sirf signature verify (CPU) |
| Scaling | Shared session store chahiye | Koi bhi instance verify kar le |
| Revocation | Turant (row delete) | Mushkil (blocklist/short expiry) |
| Size | Chhota (~32 bytes) | Bada (claims ke saath, 300 B–kuch KB) |
| Cross-domain / mobile / microservices | Mushkil (cookies domain-bound) | Aasan (header mein bhejo) |
| Stale data | Kabhi nahi (store hi source of truth) | `exp` tak purana role/claim |
| Best for | Monolith, server-rendered apps, banking (instant logout) | APIs, SPAs, mobile, microservices, third-party/SSO |

**Sach ye hai:** JWT session ka "upgrade" nahi hai, alag trade-off hai. Agar ek hi monolith hai, ek hi domain hai, aur Redis already hai, to session cookie zyada simple aur zyada secure hai. Bahut log JWT sirf "modern" lagne ki wajah se lagate hain aur phir blocklist bana ke session hi dobara bana dete hain.

> **Interview line:** "Sessions give instant revocation and always-fresh data at the cost of a store lookup per request. JWTs give stateless verification that scales across services at the cost of hard revocation and stale claims. For a single web app I prefer server sessions; for APIs, mobile clients and microservices I use short-lived JWT access tokens with server-tracked, rotating refresh tokens."

---

## 17. Best practices: ek nazar mein checklist

- [ ] HTTPS everywhere. Token bearer hai, chori = account chori.
- [ ] Access token 5–15 min, refresh token 7–30 din + absolute lifetime.
- [ ] Allowed `algorithms` server pe pinned. `none` kabhi nahi.
- [ ] `exp`, `iss`, `aud`, `nbf` hamesha verify. `exp` mandatory. Leeway 30–60 sec.
- [ ] HS256 secret ≥ 256-bit random, env/secret manager se. Distributed system mein RS256/ES256 + JWKS.
- [ ] Payload mein koi sensitive data nahi. Sirf id, roles, zaroori claims.
- [ ] Access token memory mein, refresh token `HttpOnly; Secure; SameSite` cookie mein.
- [ ] Refresh token rotation + reuse detection + token families.
- [ ] Logout pe refresh revoke + `jti` blocklist (Redis TTL). Password change pe `token_version` bump.
- [ ] Token type check (access vs refresh mix na ho).
- [ ] `kid` sirf trusted key map mein lookup. `jku`/`x5u` ignore.
- [ ] Token URL mein nahi, logs mein masked.
- [ ] Authentication ≠ authorization. Valid token ke baad bhi permission/ownership check karo.
- [ ] Password change / "sab jagah se logout" access **aur** refresh dono tokens revoke kare.
- [ ] Frontend aur API same site pe (proxy ya custom domain); credentials ke saath exact-origin CORS.
- [ ] Refresh tabs ke beech serialised; logout sab tabs tak broadcast; `/refresh` pe CSRF header/Origin check.
- [ ] WebSockets: handshake pe `Origin` check, ya one-time tickets; token expire hone pe socket band.
- [ ] Maintained library use karo (PyJWT, `jsonwebtoken`, `jose` for Node). Khud ka JWT parser kabhi mat likho.

---

## 18. Interview quick-fire (formal English)

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

## 19. Jab kuch leak ho jaaye: incident playbooks aur kaun cheez kahan store hoti hai

### 19.1 Signing secret / private key leak ho gaya

**Impact (JWT ka sabse bura case):** attacker **kisi bhi user, kisi bhi role, kisi bhi expiry** ka token bana sakta hai. `jti` blocklist bekaar hai (wo naye `jti` bana lega). Refresh tokens bhi JWT hain to wo bhi forge ho jaayenge. Asli ilaaj sirf ek hai: key badlo.

Socho **sarkari mohar chori ho gayi**. Ab jo bhi document aayega, asli lagega. Pehle wali mohar ko turant "invalid" declare karna padega, chahe asli documents bhi reject ho jaayein.

**Playbook:**
1. **Nayi key banao aur turant deploy karo.** Purani key verifiers se **usi waqt** hatao (HS256 mein accepted-secrets map se, RS256 mein JWKS se). Planned rotation ki tarah yahan **koi grace period nahi**, kyunki purani key se sign hua har token ab bharose layak nahi hai.
2. **Sab logout ho jaayenge.** Saari refresh token families bhi revoke karo (refresh-token table/Redis keys saaf karo, ya global epoch bump karo, 19.6 dekho).
3. **Source dhoondo:** git history, CI logs, error page mein env dump, kisi ka laptop, third-party service. Jis raaste se leak hua, uske credentials bhi rotate karo (secret manager access, CI tokens).
4. **Damage assess karo:** agar tum har issued `jti` log karte ho, to koi bhi valid-looking token jiska `jti` tumne kabhi issue hi nahi kiya, wo forgery ka saboot hai. Exposure window mein admin actions ke audit logs check karo.
5. Policy ke hisaab se users/security team ko **notify** karo. Account data access hua ho sakta hai to password reset force karo.

**Prevention:**
- Keys **secret manager** mein (Vault, AWS Secrets Manager, GCP Secret Manager). Git ya commit hone wali `.env` files mein kabhi nahi.
- Aur better: **KMS/HSM signing**. Private key HSM se kabhi bahar nikalti hi nahi, auth server KMS ki `Sign` API call karta hai. Server poora hack ho jaaye, tab bhi key copy nahi hogi.
- Har environment ki alag key (dev/staging/prod). Dev leak se prod pe asar nahi hona chahiye.
- **Scheduled rotation** (jaise har 90 din), taaki rotation ka procedure practice mein rahe, incident ke beech pehli baar na sochna pade.

### 19.2 HS256 secret ki planned rotation

> Code: see `jwt_code.md`, section 19.2.

HS256 mein JWKS nahi hota, par idea same hai: **`kid` ke saath multiple secrets** rakho, current wale se sign karo, aur token jis `kid` ka naam le, usse verify karo.

Steps: nayi secret `KEYS` mein add karo → har jagah deploy → `SIGNING_KID` nayi pe switch → sabse lambi token lifetime tak wait (refresh tokens JWT hain to refresh TTL) → purani secret hatao.

### 19.3 Client ka access token chori ho gaya

**Impact:** attacker `exp` tak user ban ke kaam karega (advice follow ki hai to max 15 min). Refresh cookie ke bina naya token nahi le sakta.

**Chori kaise hota hai:** XSS se localStorage padh liya, device pe malware, token URL/log mein, headers log karne wala proxy, ya koi non-HTTPS hop.

**Detection signals (koi bhi perfect nahi):**
- Same `jti` ek hi waqt pe do bilkul alag IPs/ASNs/user agents se.
- Impossible travel (5 minute mein Mumbai aur Frankfurt).
- Achanak unusual actions ka burst (bulk export, password/email change).

**Response:** `jti` blocklist mein daalo, ya user ka `token_version` bump karke uske saare tokens khatam karo. Uski refresh families revoke karo. Re-login force karo, zaroorat ho to password reset bhi. Agar XSS wajah thi to XSS fix karo, warna agla token bhi chori hoga.

**Note:** Token ko IP se bind karna usually bahut brittle hai (mobile users network badalte rehte hain, WiFi se 4G). Token mein hashed device fingerprint ek softer signal hai.

### 19.4 Refresh token chori ho gaya

Rotation + reuse detection (section 7) isko **tabhi** pakadta hai jab dono log same token use karein. Iska blind spot: attacker pehle refresh kar le aur asli user wapas hi na aaye (laptop ek hafte band), to attacker rotate karta rahega aur kisi ko pata nahi chalega.

Extra defences:
- **Absolute lifetime** (jaise 30–90 din) aur **idle timeout** (jaise 7 din use nahi hua → dead), taaki chori hui family kabhi na kabhi mare.
- **Device binding:** family ke saath device id / user agent / IP range store karo. Bilkul alag device se refresh aaye to suspicious → step-up auth (OTP).
- **"Active sessions" screen** (Google/Netflix jaisa): har family device aur location ke saath dikhao, har ek pe "log out" button. User khud chori pakad leta hai.
- Email ya push pe **login/new-device alerts**.
- `/auth/refresh` pe rate-limit.

### 19.5 Kaun cheez kahan store hoti hai

| Cheez | Kahan rehti hai | Notes |
|---|---|---|
| Signing secret / private key | Secret manager ya KMS/HSM, startup pe inject | Git, DB, logs, client mein kabhi nahi |
| Public keys | JWKS endpoint; verifiers memory mein cache karte hain | Expose karna safe hai |
| Access token | Sirf client memory | Server kuch store nahi karta (yahi to point hai) |
| Refresh token (client side) | `HttpOnly; Secure; SameSite` cookie (web), Keychain/Keystore (mobile) | localStorage kabhi nahi |
| Refresh token (server side) | DB table (durable source of truth), speed ke liye optionally Redis mein bhi | Opaque tokens ka **SHA-256 hash** store karo, raw value kabhi nahi, taaki DB leak ho to bhi kaam karne wale tokens na milein. JWT refresh tokens ke liye `jti` store karna kaafi hai |
| Access-token blocklist (`jti`) | **Redis**, key `jwt:block:<jti>`, TTL = token ki bachi umar | Saare instances share karte hain; apne aap saaf hota hai |
| `token_version` / `tokens_valid_after` | DB ki `users` table, Redis mein cached | Use karte ho to har request pe check |
| Issued `jti`s ka audit log | Append-only log/DB | Key leak ke baad forged tokens pakadne mein kaam aata hai |

Hash kyun? Socho bank locker: bank tumhari chaabi ki copy nahi rakhta. Waise hi DB mein token ka hash rakho; DB chori hua to bhi asli token kisi ke haath nahi lagega.

Typical refresh-token table:

> Code: see `jwt_code.md`, section 19.5.

**Redis down ho gaya to?** Pehle se decide karo:
- **Fail closed** (blocklist check nahi ho saka to request reject): zyada safe. Banking/admin APIs ke liye sahi.
- **Fail open** (check skip): zyada available. Sirf isliye chalta hai kyunki access tokens 15 min mein waise bhi mar jaate hain.

**Redis restart hua aur data gaya to?** Revoked access tokens apne `exp` tak phir se valid ho jaayenge. 15-min tokens ke saath ye usually chal jaata hai; warna Redis persistence (AOF) on karo. Refresh-token state DB mein isi liye rakhte hain, taaki cache wipe se revoked sessions zinda na ho jaayein.

**Bade scale pe performance:** har request pe Redis lookup sasta hai (sub-millisecond), par bahut zyada traffic pe gateway ek chhota local cache ya revoked `jti`s ka **Bloom filter** rakh sakta hai, aur Redis sirf possible match pe hit kare.

### 19.6 "Valid after" trick (tokens ki list rakhe bina revoke)

Har revoked token store karne ki jagah **ek timestamp** rakho: "is waqt se pehle issue hue saare tokens dead".
- Per user: `users.tokens_valid_after`. Password change pe isko `now()` set karo; jis token ka `iat < tokens_valid_after`, use reject karo.
- Global: ek `global_tokens_valid_after`. Key leak ya breach ke baad isko `now()` karo, system ka har token mar jayega, key badle bina bhi.

### 19.7 Edge cases jo zyada log miss karte hain

1. **Password change pe refresh tokens bhi maarne padenge.** `token_version` bump sirf access tokens maarta hai. Agar refresh endpoint bhi isko check nahi karta, to chori hua refresh token wala attacker *naye* version ka fresh access token bana lega. Password change pe: version bump **aur** us user ki saari refresh families revoke.
2. **Opaque refresh tokens key leak se bach jaate hain.** Agar refresh tokens random strings hain jo DB se check hote hain (JWT nahi), to leaked signing key se bhi forge nahi ho sakte. Sirf access tokens ki safai karni padti hai. Opaque refresh tokens ke favour mein ye bada argument hai.
3. **Refresh tokens ke liye SHA-256, bcrypt nahi.** Passwords low-entropy hote hain, isliye guessing rokne ke liye slow hash (bcrypt/argon2) chahiye. Refresh token 256 random bits ka hai, koi brute-force nahi kar sakta, to fast SHA-256 kaafi hai aur `/refresh` fast rehta hai. Hash compare constant-time function (`hmac.compare_digest`) se karo ya indexed equality lookup se.
4. **CORS misconfiguration CSRF ko token chori mein badal deta hai.** Normally SameSite aur CORS `evil.com` ko `/auth/refresh` ka response *padhne* se rokte hain. Par agar server koi bhi `Origin` `Access-Control-Allow-Origin` mein reflect kare aur saath mein `Access-Control-Allow-Credentials: true` ho, to attacker ka page victim ki cookie ke saath `/refresh` call karke naya access token padh lega. Sirf exact origins allowlist karo.
5. **Multi-region blocklist lag.** Regions ke beech Redis replication mein time lagta hai; Mumbai mein revoke hua token Singapore mein kuch seconds chal sakta hai. Usually chalta hai; critical revocation (account takeover) mein primary DB mein `tokens_valid_after` bhi bump karo.
6. **Mass logout = thundering herd.** Key rotation ke baad har user ek saath `/login` aur `/refresh` pe aayega. Auth service aur user DB pe spike aayega: pehle se scale karo, rate limits sahi rakho, aur errors ki jagah ek friendly "please sign in again" page dikhao.
7. **Logs aur monitoring tools bhi leak ka raasta hain.** APM/error trackers (Sentry, Datadog) aur reverse proxies poore request headers aur cookies capture kar sakte hain. App se bahar jaane se pehle `Authorization` aur `Cookie` scrub karo.
8. **Leak hone se pehle pakdo.** CI aur pre-commit hooks mein secret scanning chalao (gitleaks, trufflehog, GitHub secret scanning). Public repo pe push hua secret bots minuton mein scrape kar lete hain, to commit delete karna kaafi nahi: rotate karo.
9. **Forged/chori hue token ka blast radius chhota rakho.** Sensitive actions pe step-up auth (dobara password ya OTP) maango: email/password change, payee add karna, bada payment. Tab perfectly valid chori hua token bhi sabse bada nuksaan nahi kar paayega. Jaise bank app UPI PIN maangta hai, chahe tum already logged in ho.
10. **Expired access token ke saath bhi logout kaam karna chahiye.** Agar logout valid access token maangta hai, to jiska token abhi expire hua wo theek se logout nahi kar paayega. Ya to pehle refresh karo (Axios interceptor yahi karta hai) ya `/logout` ko sirf refresh cookie se chalne do. Expired refresh token bhi tolerate karo aur cookie phir bhi clear karo.

> **Interview line:** "If the signing key leaks, attackers can forge any token, so I rotate the key immediately with no grace period, revoke all refresh tokens, and trace the leak. Keys live in a secret manager or KMS so the application never holds the raw private key. For a stolen access token, short expiry limits the window and I can blocklist its jti in Redis. For stolen refresh tokens, rotation with reuse detection, absolute and idle timeouts, and an active-sessions screen cover the gaps. Refresh tokens are stored hashed in the database, and the blocklist lives in Redis with a TTL equal to each token's remaining lifetime."

---

## 20. Real-world setups aur baaki topics

### 20.1 Frontend aur API alag sites pe (cookie ka jaal)

Pehle do shabd jo log mix kar dete hain:
- **Origin** = scheme + host + port. `https://app.myapp.com` aur `https://api.myapp.com` **alag origins** hain. CORS origins pe kaam karta hai.
- **Site** = scheme + registrable domain (eTLD+1). Upar wale dono **same site** hain (`myapp.com`). `SameSite` cookies sites pe kaam karti hain.

Jaal ye hai: frontend `myapp.vercel.app` pe, API `myapp-api.onrender.com` pe. Ye **alag sites** hain (aur `vercel.app`/`onrender.com` Public Suffix List pe hain, to `vercel.app` ke do subdomains bhi alag sites maane jaate hain). Natija:
- `SameSite=Strict` ya `Lax` refresh cookie frontend ke fetch ke saath API tak **kabhi jaati hi nahi**. Refresh chupchaap fail hota hai aur users 15 min baad logout ho jaate hain.
- `SameSite=None; Secure` karoge to cookie phir jaane lagegi, par ab wo **third-party cookie** hai. Safari aur Firefox inhe default mein block karte hain, Chrome users ko block karne deta hai, to kaafi users ke liye toot jayega. SameSite ka CSRF protection bhi gaya, apna lagana padega (20.3).

Fixes, sabse achha pehle:
1. **Proxy se same origin:** frontend host `/api/*` ko backend pe rewrite kare (Vercel/Next.js rewrites, Nginx). Browser sirf `myapp.com` se baat karta hai, to CORS hi nahi, aur cookie first-party hai. Sabse simple aur robust.
2. **Custom domain se same site:** `app.myapp.com` + `api.myapp.com`. Cookie first-party, `SameSite=Lax/Strict` chalta hai. CORS credentials ke saath aur **exact** allowed origin ke saath chahiye (`Access-Control-Allow-Origin: https://app.myapp.com` + `Access-Control-Allow-Credentials: true`; credentials ke saath wildcard `*` allowed nahi hai).
3. **Sach mein cross-site (sirf majboori mein):** `SameSite=None; Secure; Partitioned` (CHIPS) + CSRF token, aur maan ke chalo kuch browsers mein phir bhi tootega. Frontend ke apne domain pe BFF usually isse behtar hai.

Socho **society ka gate pass**: pass sirf apni society (site) ke gate pe chalta hai. Flat number alag ho (origin) to chalega, par doosri society (doosri site) mein le gaye to guard nahi maanega.

### 20.2 Multiple tabs

Har tab ki apni JS memory hai, to har tab ka apna access token hai, par sab **ek hi refresh cookie** share karte hain. Do problems:
- **Galat chori ka alarm:** tab A aur B dono ko 401 mila aur dono ne same cookie se `/refresh` call kiya. A ne rotate kar diya; B ki request reuse lagi, aur poori family revoke. Per-tab `refreshPromise` yahan kaam nahi aata, kyunki wo ek hi tab ke andar rehta hai.
- **Aadha logout:** tab A mein logout kiya, par tab B ki memory mein working access token pada hai.

Fixes (dono 15.4 ke code mein hain):
- `navigator.locks.request("auth-refresh", ...)`: Web Locks API origin ke saare tabs share karte hain, to tabs line mein lag ke refresh karte hain aur har ek sabse nayi cookie bhejta hai.
- `BroadcastChannel("auth")`: logout pe har tab ko bolo ki token hatao aur login page pe jao.

### 20.3 `/refresh` ke liye SameSite ke alawa CSRF protection

SameSite pehli line of defence hai. Ek layer aur lagao, kyunki purane browsers, `SameSite=None` setups, aur compromised subdomain se same-site attacks hote hain.
- **Required custom header** (`X-Requested-With: XMLHttpRequest`, 15.2 mein use hua): HTML form custom headers set nahi kar sakta, aur custom header wala cross-origin `fetch` CORS preflight trigger karta hai, jise tumhari exact-origin CORS policy reject kar degi. JSON APIs ke liye sasta aur effective.
- **Origin check:** state badalne wali requests jinka `Origin` header allowlist mein nahi, reject karo.
- **Double-submit token:** ek random value readable (non-httpOnly) cookie mein set karo; client use header mein copy kare; server dono match kare. Attacker ki site browser se cookie bhejwa sakti hai, par padh nahi sakti, to header nahi bhar sakti. Classic CSRF tokens chahiye ho (jaise `SameSite=None` ke saath) tab ye use karo.

### 20.4 WebSockets

Browser ki `WebSocket` API **custom headers set nahi kar sakti**, to `Authorization: Bearer` ka option hi nahi hai. Choices:
- **Handshake pe cookie:** WebSocket same-site ho to chalta hai. WebSockets **CORS se protected nahi hain**, to handshake pe `Origin` header khud check karo, warna koi bhi site user ki cookie ke saath socket khol legi (Cross-Site WebSocket Hijacking).
- **One-time ticket:** client bearer token ke saath `POST /ws-ticket` call kare, ~30 second valid ek random single-use ticket le, aur `wss://api/ws?ticket=...` pe connect kare. Ticket URL mein hai, par ek use ya 30 second ke baad bekaar hai. Jaise **OTP**: SMS mein dikh bhi jaaye to ek baar aur thodi der hi chalta hai.
- **First-message auth:** bina credentials connect karo, pehle message mein token bhejo; kuch seconds mein na aaye to server socket band kar de.

Lambe connections token se zyada jeete hain: server `exp` yaad rakhe aur time nikalte hi socket band kare (ya socket pe naya token maange), aur revocation pe bhi react kare.

### 20.5 Service-to-service tokens (koi user nahi)

Cron job ya Order Service jab Payment Service ko call karti hai, to login karne wala koi user nahi hai. **OAuth 2.0 Client Credentials flow** use karo:
1. Service apne credentials se auth server pe authenticate kare (client secret, ya better, signed JWT assertion / mTLS).
2. Usse short-lived access token mile jiska `sub` = service ka client id, aur sirf zaroori scopes (`payments:charge`).
3. Token cache kare aur `exp` se thoda pehle naya maang le. Is flow mein **refresh token nahi hota**; service seedha dobara maangti hai.

Background kaam ke liye user ka token reuse mat karo, aur saari services ke beech ek "god-token" kabhi share mat karo.

### 20.6 Scopes vs roles

- **Role** = user kaun hai (`admin`, `support`). Coarse, user ka hai.
- **Scope** = **ye wala token** kya kar sakta hai (`orders:read`, `profile:write`). Fine-grained, token ka hai.
- Fark tab dikhta hai jab third-party app tumhari taraf se kaam kare: tum admin ho sakte ho, par reporting tool ko jo token diya usme sirf `reports:read` hona chahiye. Effective permission = user ko jo allowed hai **aur** token ke scopes jo allow karte hain.
- Socho **power of attorney**: tum ghar ke maalik ho (role), par CA ko sirf tax file karne ka haq diya (scope), ghar bechne ka nahi.
- Format: `scope` space-separated string hai (`"orders:read orders:write"`); kuch providers `scp` array use karte hain. Scopes har endpoint pe check karo, sirf gateway pe nahi.

### 20.7 PASETO, JWT ka alternative

PASETO (Platform-Agnostic Security Tokens) JWT ki galtiyon se bachne ke liye bana:
- **`alg` header hi nahi hai.** Version aur purpose prefix mein fix hai (`v4.public.` = Ed25519 signature, `v4.local.` = symmetric encryption). Algorithm confusion aur `alg: none` design se hi impossible.
- `local` tokens **default encrypted** hain, payload padha hi nahi ja sakta.
- Nuksaan: chhota ecosystem, aur OAuth/OIDC ko JWT chahiye, to ID tokens ya zyada tar identity providers ke saath PASETO nahi chalega.

Achha interview answer: "If I control both issuer and verifier and do not need OIDC interoperability, PASETO is safer by design. Otherwise I use JWT with pinned algorithms."

### 20.8 Admin impersonation

Support staff ko kabhi "user ban ke login" karna padta hai. Explicitly karo, password share karke kabhi nahi:
- Token do jisme `sub` = user aur ek **`act` claim** jo asli karne wale ka naam le: `"act": {"sub": "admin_7"}` (RFC 8693).
- Audit logs dono identities record karte hain, to har action dikhata hai "admin_7 acting as user_42".
- Token short-lived rakho aur impersonation ke dauraan khatarnak actions block karo (password/email change, payouts).

### 20.9 Chhote validation details

- **Future ka `iat`:** "kal" issue hua token matlab ghadi kharab hai ya forgery. Leeway se zyada ho to reject karo. `iat` ho to PyJWT ye karta hai; doosri libraries mein confirm kar lo.
- **"Remember me":** sirf refresh token badalta hai. Unchecked → `Max-Age` nahi (browser band = cookie khatam) aur chhoti refresh lifetime. Checked → lambi lifetime wali persistent cookie. Access token dono case mein 15 min hi.
- **Absolute session cap:** family mein original login time (`auth_time`) store karo aur uske baad refresh mana karo, rotation ke bawajood.

### 20.10 Tests jo rakhne chahiye

Minimum set jo security logic tootne pe fail ho:

> Code: see `jwt_code.md`, section 20.10.

`/auth/refresh` ke against integration tests mein ye bhi cover karo: galat `aud`/`iss` reject, grace window ke baad refresh-token reuse family revoke kare, revoked family refresh na kar sake, `revoke_all_sessions` dono token types maare, aur CSRF header ke bina request ko 403 mile.

> **Interview line:** "In production the hard parts of JWT are rarely the signature. They are cookie behaviour across sites, refresh races between tabs, CSRF on the refresh endpoint, and authenticating WebSockets. I keep the API on the same site as the frontend, serialise refreshes across tabs, require a custom header on refresh, and use short-lived tickets for WebSockets."

---

## 21. Active recall: bina upar dekhe answer karo

1. JWT ke teen parts kya hain, aur kaunsa part tamper hone se bachata hai?
2. "Encoded", "signed" aur "encrypted" mein ek-ek line ka fark batao.
3. Verifier ko `alg` token ke header se kyun nahi padhna chahiye? Dono attacks ke naam batao.
4. `aud` check na karne se kya galat ho sakta hai? Ek real scenario do.
5. Access token memory mein aur refresh token httpOnly cookie mein kyun? Har ek kis attack se bachata hai?
6. httpOnly cookie hone ke baad bhi XSS dangerous kyun hai?
7. Refresh token reuse detection step by step samjhao. Frontend pe kaunsa race condition isko tod sakta hai, aur fix kya hai?
8. Password change pe user ke saare tokens kaise invalidate karoge, bina signing key badle?
9. Blocklist entry ka TTL kitna rakhoge, aur kyun?
10. Zero-downtime key rotation ke 5 steps batao.
11. ID token ko API call mein bhejna galat kyun hai?
12. Ek single monolith app ke liye tum JWT choose karoge ya session? Interview-style formal English mein 3–4 lines mein justify karo.
13. HS256 secret leak ho gaya. Tumhare pehle paanch actions kya honge? Planned rotation ke ulat yahan grace period kyun nahi?
14. Kisi ko logout kiye bina HS256 secret kaise rotate karoge?
15. Refresh-token reuse detection ka blind spot kya hai, aur kaunse teen defences usko cover karte hain?
16. Signing key, refresh token (client aur server), blocklist aur `token_version` kahan store karoge? Refresh tokens hashed kyun store karte hain?
17. Redis down hai: fail open ya fail closed? Banking app aur blog dono ke liye apna choice defend karo.
18. Frontend `vercel.app` pe hai aur API `onrender.com` pe. Refresh cookie kaam karna kyun band kar deti hai, aur teen fixes preference ke order mein kya hain?
19. Do tabs ek saath refresh karte hain aur user logout ho jaata hai. Kyun? Frontend aur backend pe fix kya hai?
20. Browser `Authorization` header nahi bhej sakta to WebSocket ko authenticate kaise karoge? Cross-Site WebSocket Hijacking kya hai?
21. Scope vs role: third-party app ke example se samjhao.
22. PASETO JWT ke comparison mein kya hata deta hai, aur kab use nahi kar sakte?
$jwt_hi_body$
FROM course_modules cm JOIN courses c ON c.id = cm.course_id
WHERE c.slug = 'jwt' AND cm.title = 'JWT, the full story'
ON CONFLICT (module_id, locale) DO UPDATE SET content_body = EXCLUDED.content_body, updated_at = now();

-- The code samples import FastAPI/PyJWT, which the in-lesson runner can't run.
UPDATE courses SET disable_code_run = true WHERE slug = 'jwt';

