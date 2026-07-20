---
kind: lesson
id_key: interview-prep-45/note-api-protocol-fundamentals
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Password Hashing Algorithms, API Key Lifecycle, REST vs SOAP, HTTPS vs HTTP"
position: 110
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

Day 24 (API Security) shows bcrypt in the JWT login flow and compares JWT/OAuth/API-key *identity models*, but doesn't compare hashing *algorithms* or cover API-key *operational lifecycle*. Neither REST vs SOAP nor HTTPS vs HTTP appears anywhere in the course — both are the kind of "explain the difference" question that opens a networking/API-design round.

## Password hashing algorithm comparison

Day 24 uses bcrypt without explaining why bcrypt over the alternatives — here's the comparison an interviewer expects if they push further.

| Algorithm | Type | Defense mechanism | Notes |
|---|---|---|---|
| MD5 / SHA-256 (alone) | Fast cryptographic hash | None | **Never use for passwords** — designed to be fast, which is exactly wrong here; GPUs compute billions/sec, making brute force trivial |
| PBKDF2 | Key-derivation function | Configurable iteration count (work factor) | Widely supported (FIPS-approved), but no memory cost — still crackable at scale with enough parallel hardware |
| bcrypt | Password hash | Configurable cost factor (`2^cost` rounds) | Industry standard for over a decade; deliberately slow, cost factor tunable as hardware improves; used in this course's Day 24 example |
| scrypt | Password hash | Configurable CPU cost + **memory cost** | Memory-hard: forces attackers to use expensive RAM, not just fast compute, blunting GPU/ASIC parallelism |
| Argon2 | Password hash | Time cost + memory cost + parallelism, independently tunable | Winner of the 2015 Password Hashing Competition; current best-practice recommendation (OWASP), used when starting a new project today |

**The core idea uniting bcrypt/scrypt/Argon2:** they're *intentionally slow* and expose a tunable "cost" parameter, so as hardware gets faster, you raise the cost factor to keep the effective crack time constant — a fast hash (MD5/SHA-256) has no such knob.

**Memory hardness** (scrypt, Argon2) is the newer defense layer beyond bcrypt: bcrypt's cost factor only makes each guess slower on *one* CPU core, but an attacker with thousands of cheap GPU cores can still parallelize guesses cheaply. Memory-hard algorithms force each guess to allocate a meaningful chunk of RAM, which is expensive to replicate thousands of times over — this is why Argon2 is now the recommended default for new systems, with bcrypt remaining an acceptable, battle-tested choice for existing systems.

**Salting** is automatic and built into bcrypt's output format (`$2b$<cost>$<22-char-salt><31-char-hash>` — a single self-contained string), which is why you never see a separate "store the salt" step in the Day 24 example — `bcrypt.checkpw()` extracts the salt from the stored hash itself.

## API key management lifecycle

Day 24's comparison table covers *what* an API key is (identifies a client, no expiry, no claims); this is the *operational* side interviewers ask about once they know you understand the concept:

- **Never in source control.** Load from environment variables or a secrets manager (Vault, AWS Secrets Manager) — never a hardcoded string, never committed even in a "private" repo.
- **Segregate per environment and per service.** A dev key and a prod key should be different values, so a leaked dev key can't touch production data, and revoking one service's key doesn't break every other integration.
- **Rotate on a schedule** (e.g. every 90 days) *and* immediately on suspected leak — rotation should be a routine operation, not a fire drill, which means the system needs to support two valid keys simultaneously during a rotation window (old key still works for a grace period while callers migrate to the new one).
- **Transmit only over HTTPS, in a header** (`Authorization: Bearer <key>` or a custom header), never as a URL query parameter — URLs get logged by proxies, browsers, and web server access logs, silently leaking the key into logs that outlive the request.
- **Monitor usage per key** — track request volume and source IPs per key so an anomaly (sudden spike, requests from an unexpected region) is detectable, and so an unused key can be identified and revoked (reducing attack surface) rather than living forever "just in case."
- **Instant revocation capability** — a key must be disable-able immediately (a DB flag checked on every request, not a cache that takes minutes to propagate) the moment a leak is suspected.

## REST vs SOAP

| | REST | SOAP |
|---|---|---|
| What it is | An architectural style (a set of constraints), not a protocol | A strict messaging protocol with a formal specification |
| Transport | HTTP only (in practice) | Transport-agnostic — HTTP, SMTP, TCP, message queues |
| Data format | Any — JSON is standard, but XML/plain text work | XML only, with a rigid envelope structure |
| Contract | Loose — documented via OpenAPI/Swagger, not enforced by the protocol itself | Strict — WSDL (Web Services Description Language) formally defines every operation, type, and fault |
| Payload weight | Lightweight (JSON is compact) | Heavy (verbose XML envelopes, namespaces) |
| Built-in security/reliability | None — relies on HTTPS, OAuth, etc., layered on top | WS-Security, WS-ReliableMessaging built into the spec |
| Typical use today | Public APIs, mobile backends, microservices — the default for anything new | Legacy enterprise systems, banking/payment gateways, and domains with regulatory requirements for formal contracts |

**The one-sentence interview answer:** REST is a flexible, resource-oriented style that took over because it's simple and maps naturally onto HTTP; SOAP is a rigid, contract-first protocol that's still found in enterprise/financial systems where the formal WSDL contract and built-in security/transaction guarantees outweigh the overhead — you're far more likely to build a REST API today, but you may need to *integrate with* a SOAP-based system (a bank, an airline booking system) that predates REST's dominance.

## HTTPS vs HTTP

**HTTP** sends data in plaintext — anyone on the network path (a public Wi-Fi hotspot, a compromised router, an ISP) can read or modify it in transit. **HTTPS** wraps HTTP in TLS (formerly SSL) encryption.

**The TLS handshake, at a level worth being able to explain:**
1. Client connects and sends supported TLS versions/cipher suites ("ClientHello").
2. Server responds with its chosen cipher suite and its **certificate** (containing its public key, signed by a Certificate Authority).
3. Client verifies the certificate: is it signed by a CA the client trusts, is the domain name correct, has it not expired?
4. Client and server use asymmetric crypto briefly to agree on a shared **symmetric session key** (asymmetric crypto is too slow for bulk data, so it's only used to bootstrap the fast symmetric key).
5. All subsequent traffic is encrypted with that symmetric session key.

This handshake is exactly what defeats a **man-in-the-middle attack**: an attacker intercepting the connection can't decrypt traffic without the session key, and can't forge a valid certificate for a domain they don't own (a browser will flag it as untrusted/invalid).

**Practical details that come up:**
- **Ports:** HTTP defaults to 80, HTTPS to 443.
- **Certificate types:** Domain Validated (DV — just proves you control the domain, automatable via Let's Encrypt), Organization Validated (OV — verifies the requesting organization), Extended Validation (EV — the highest bar, historically shown with a green address bar, now largely deprecated as a visual signal by browsers).
- **Mixed content:** an HTTPS page that loads an HTTP resource (an image, a script) creates a hole an attacker can exploit — modern browsers block "active" mixed content (scripts, stylesheets) outright and warn on "passive" mixed content (images).
- **SEO and trust signals:** browsers mark plain HTTP pages "Not Secure" in the address bar, and search engines factor HTTPS into ranking — there's no remaining reason to serve a production site over plain HTTP.

## Key takeaways

- bcrypt/scrypt/Argon2 are deliberately slow with a tunable cost factor; scrypt and Argon2 add *memory hardness* on top, which is why Argon2 is the current best-practice recommendation for new systems even though bcrypt (used in Day 24) remains acceptable.
- API keys need a full lifecycle: env-var/secrets-manager storage, per-environment segregation, scheduled + emergency rotation with an overlap window, header-only transmission (never in a URL), usage monitoring, and instant revocation.
- REST is a flexible architectural style over HTTP with JSON; SOAP is a strict, contract-first (WSDL) protocol with built-in security/reliability — REST dominates new development, SOAP persists in legacy/regulated enterprise systems.
- HTTPS = HTTP + TLS: the handshake verifies the server's certificate and negotiates a symmetric session key, which is what defeats man-in-the-middle interception — always serve production traffic over HTTPS.
