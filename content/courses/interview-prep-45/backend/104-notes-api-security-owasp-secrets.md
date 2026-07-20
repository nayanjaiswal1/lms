---
kind: lesson
id_key: interview-prep-45/note-api-security-owasp-secrets
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: SQL Injection, Secrets Management, and the OWASP API Top 10"
position: 104
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Day 24 already covers JWT/OAuth/API keys, rate limiting, refresh rotation, and CSRF in depth; Day 15 (frontend) covers XSS, CORS, and CSP. This note is the remaining backend-security ground those two don't touch: SQL injection, secrets management practice, and a named checklist (OWASP API Top 10) for tying the pieces together in an interview answer.

## SQL injection and parameterized queries

Injection happens when user input is concatenated directly into a query string instead of passed as a bound parameter:

```python
# VULNERABLE — user input becomes part of the SQL itself
query = f"SELECT * FROM users WHERE email = '{email}'"
cursor.execute(query)
# email = "' OR '1'='1" returns every row

# SAFE — parameterized: the driver sends value and query separately,
# the DB never interprets the value as SQL syntax
cursor.execute("SELECT * FROM users WHERE email = %s", [email])
```

Django's ORM (`Model.objects.filter(email=email)`) parameterizes automatically — this is *why* raw `.raw()` queries or `str.format()`-built SQL are the actual risk surface in a Django codebase, not the ORM itself. The interview framing: "the ORM isn't magic, it's just consistently doing parameterization for you — the risk reappears the moment someone drops to raw SQL for a 'quick' query and string-formats it."

## Secrets management

Never hardcode secrets in code or commit them in `.env` files — a secret that reaches git history is compromised even if the commit is later reverted, since history persists. Standard practice:

- Use a managed secrets store (Vault, AWS Secrets Manager, GCP Secret Manager) rather than environment files checked into a repo — the app fetches secrets at startup/runtime, not from a committed file.
- Rotate keys on a schedule and immediately on suspected breach — a secret that can't be rotated without a deploy is a design flaw, not just an inconvenience.
- Use `.gitignore` plus a pre-commit secret-scanning hook (e.g., detect-secrets, gitleaks) to catch a leak before it's pushed, not after.
- Mask sensitive fields in logs — tokens, passwords, PII should never appear in plaintext log output, since logs are often retained and searched with less access control than the primary datastore.

## OWASP API Security Top 10 — as an interview checklist

A named list to reach for when asked "how would you secure this API," each mapped to material already covered in this course where applicable:

| # | Risk | Where it's covered / how to say it |
|---|---|---|
| 1 | Broken Object Level Authorization (BOLA) | Not fixed by authentication alone — every object-fetching endpoint must check the *authenticated user* owns/can-access *this specific* object ID, not just that they're logged in. The classic bug: `/orders/{id}` returns any order if you're logged in as anyone. |
| 2 | Broken Authentication | Day 24 — JWT/OAuth/session correctness, refresh rotation |
| 3 | Excessive Data Exposure | Serializers returning full model objects instead of an explicit field allowlist — say "allowlist fields in the serializer, don't rely on the client to ignore extra fields" |
| 4 | Lack of Resources & Rate Limiting | Day 24 — Redis-backed rate limiter |
| 5 | Broken Function Level Authorization | Day 24/RBAC docs — role checks on the *action*, not just resource-level checks; an admin-only endpoint must reject a non-admin token even if the object-level check would otherwise pass |
| 6 | Mass Assignment | Accepting a full JSON body into a model/serializer without an explicit allowed-fields list — a request body with `{"is_admin": true}` silently escalating privilege if the endpoint blindly deserializes into the model |
| 7 | Security Misconfiguration | Default credentials, verbose error messages leaking stack traces, debug mode left on in production |
| 8 | Injection | SQL injection (above), plus the general principle: never let unsanitized input reach an interpreter (SQL, shell, template engine) |
| 9 | Improper Assets Management | Old/undocumented API versions still live and unpatched — a `/v1/` endpoint nobody remembers exists is still attackable |
| 10 | Insufficient Logging & Monitoring | Log auth failures, rate-limit hits, and unusual access patterns; alerting on a spike in 401/403s is often how a credential-stuffing attack is actually caught |

Mass Assignment and BOLA are the two most likely to come up as a live code-review exercise ("here's an endpoint, what's wrong with it") — both are about *authorization scoped to the specific object/field*, not just "is this request authenticated."

## Key takeaways

- Parameterized queries (or the ORM, which parameterizes for you) are the fix for SQL injection — the risk reappears specifically where raw SQL is string-built by hand.
- Secrets live in a managed store (Vault/Secrets Manager) with rotation and pre-commit scanning, never in a committed `.env`.
- BOLA and Mass Assignment are the two OWASP API risks most likely to appear as a "spot the bug in this endpoint" exercise — both fail because authorization was checked at the wrong granularity (user-is-logged-in instead of user-owns-this-object; request-is-valid-JSON instead of request-only-sets-allowed-fields).
