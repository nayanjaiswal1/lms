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

This course's API security material shows bcrypt in a JWT login flow and compares JWT/OAuth/API-key identity models, but doesn't compare hashing algorithms against each other or cover an API key's operational lifecycle. Neither REST vs SOAP nor HTTPS vs HTTP appears elsewhere in the course; both are the kind of "explain the difference" question that opens a networking or API-design round.

## Password hashing algorithm comparison

Bcrypt gets used without explaining why bcrypt over the alternatives elsewhere in this course. Here's the comparison an interviewer expects if they push further.

| Algorithm | Type | Defense mechanism |
|---|---|---|
| MD5 / SHA-256 (alone) | Fast cryptographic hash | None |
| PBKDF2 | Key-derivation function | Configurable iteration count (work factor) |
| bcrypt | Password hash | Configurable cost factor (`2^cost` rounds) |
| scrypt | Password hash | Configurable CPU cost plus **memory cost** |
| Argon2 | Password hash | Time cost, memory cost, and parallelism, independently tunable |

Plain MD5 or SHA-256 must never be used for passwords. They're designed to be fast, which is exactly the wrong property here: modern GPUs compute billions of hashes per second, which makes brute-forcing every likely password against a stolen hash trivial.

PBKDF2 fixes that by adding a configurable iteration count, so each guess costs more CPU time. It's widely supported and FIPS-approved, but it has no memory cost, so it's still crackable at scale by an attacker with enough parallel hardware.

Bcrypt has been the industry standard for over a decade. It's deliberately slow, with a cost factor you can raise as hardware gets faster to keep the effective crack time roughly constant. It's the algorithm used in this course's JWT login example.

Scrypt and Argon2 add **memory hardness** on top of bcrypt's approach. Bcrypt's cost factor only makes each guess slower on one CPU core, but an attacker with thousands of cheap GPU cores can still parallelize guesses cheaply. Memory-hard algorithms force each guess to allocate a meaningful chunk of RAM, which is expensive to replicate thousands of times over, blunting that GPU/ASIC parallelism advantage. Argon2 (winner of the 2015 Password Hashing Competition) is the current OWASP best-practice recommendation for a new project, with bcrypt remaining an acceptable, battle-tested choice for existing systems that already use it.

The core idea uniting bcrypt, scrypt, and Argon2 is that they're intentionally slow and expose a tunable "cost" parameter, so as hardware gets faster, you raise the cost factor to keep the effective crack time constant. A fast hash like MD5 or SHA-256 has no such knob to turn.

**Salting** is automatic and built into bcrypt's output format: a single self-contained string shaped like `$2b$<cost>$<22-char-salt><31-char-hash>`. This is why you never see a separate "store the salt" step when using bcrypt; `bcrypt.checkpw()` extracts the salt from the stored hash itself before checking a candidate password against it.

## API key management lifecycle

The comparison elsewhere in this course covers *what* an API key is (it identifies a client, has no expiry, and carries no claims). Here's the *operational* side interviewers ask about once they know you understand the concept:

- **Never in source control.** Load from environment variables or a secrets manager (Vault, AWS Secrets Manager), never a hardcoded string, and never committed even in a "private" repo.
- **Segregate per environment and per service.** A dev key and a prod key should be different values, so a leaked dev key can't touch production data, and revoking one service's key doesn't break every other integration.
- **Rotate on a schedule** (for example, every 90 days) and immediately on suspected leak. Rotation should be a routine operation, not a fire drill, which means the system needs to support two valid keys simultaneously during a rotation window, with the old key still working for a grace period while callers migrate to the new one.
- **Transmit only over HTTPS, in a header** (`Authorization: Bearer <key>` or a custom header), never as a URL query parameter. URLs get logged by proxies, browsers, and web server access logs, silently leaking the key into logs that outlive the request itself.
- **Monitor usage per key.** Track request volume and source IPs per key so an anomaly (a sudden spike, requests from an unexpected region) is detectable, and so an unused key can be identified and revoked, reducing attack surface, rather than living forever "just in case."
- **Support instant revocation.** A key must be disable-able immediately, via a DB flag checked on every request rather than a cache that takes minutes to propagate, the moment a leak is suspected.

## REST vs SOAP

| | REST | SOAP |
|---|---|---|
| What it is | An architectural style (a set of constraints), not a protocol | A strict messaging protocol with a formal specification |
| Transport | HTTP only, in practice | Transport-agnostic: HTTP, SMTP, TCP, message queues |
| Data format | Any; JSON is standard, but XML/plain text work | XML only, with a rigid envelope structure |
| Contract | Loose, documented via OpenAPI/Swagger, not enforced by the protocol itself | Strict; WSDL (Web Services Description Language) formally defines every operation, type, and fault |
| Payload weight | Lightweight (JSON is compact) | Heavy (verbose XML envelopes, namespaces) |
| Built-in security/reliability | None; relies on HTTPS, OAuth, etc. layered on top | WS-Security, WS-ReliableMessaging built into the spec |
| Typical use today | Public APIs, mobile backends, microservices; the default for anything new | Legacy enterprise systems, banking/payment gateways, domains with regulatory requirements for formal contracts |

The one-sentence interview answer: REST is a flexible, resource-oriented style that took over because it's simple and maps naturally onto HTTP, while SOAP is a rigid, contract-first protocol that's still found in enterprise and financial systems where the formal WSDL contract and built-in security/transaction guarantees outweigh the overhead. You're far more likely to build a REST API today, but you may still need to integrate with a SOAP-based system, like a bank or an airline booking system, that predates REST's dominance.

## HTTPS vs HTTP

HTTP sends data in plaintext, so anyone on the network path (a public Wi-Fi hotspot, a compromised router, an ISP) can read or modify it in transit. HTTPS wraps HTTP in TLS (formerly SSL) encryption.

The TLS handshake, at a level worth being able to explain:

1. The client connects and sends its supported TLS versions and cipher suites ("ClientHello").
2. The server responds with its chosen cipher suite and its certificate, containing its public key, signed by a Certificate Authority.
3. The client verifies the certificate: is it signed by a CA the client trusts, is the domain name correct, and has it not expired?
4. The client and server use asymmetric crypto briefly to agree on a shared symmetric session key. Asymmetric crypto is too slow for bulk data, so it's only used to bootstrap the fast symmetric key.
5. All subsequent traffic is encrypted with that symmetric session key.

This handshake is exactly what defeats a man-in-the-middle attack: an attacker intercepting the connection can't decrypt traffic without the session key, and can't forge a valid certificate for a domain they don't own, since a browser will flag a forged one as untrusted or invalid.

Practical details that come up:

- **Ports.** HTTP defaults to 80, HTTPS to 443.
- **Certificate types.** Domain Validated (DV) just proves you control the domain and is automatable via Let's Encrypt. Organization Validated (OV) verifies the requesting organization. Extended Validation (EV) is the highest bar, historically shown with a green address bar, though that visual signal has now been largely deprecated by browsers.
- **Mixed content.** An HTTPS page that loads an HTTP resource, like an image or a script, creates a hole an attacker can exploit. Modern browsers block "active" mixed content (scripts, stylesheets) outright and warn on "passive" mixed content (images).
- **SEO and trust signals.** Browsers mark plain HTTP pages "Not Secure" in the address bar, and search engines factor HTTPS into ranking. There's no remaining reason to serve a production site over plain HTTP.
