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

This course covers JWT/OAuth/API keys, rate limiting, refresh rotation, and CSRF in depth elsewhere, along with frontend-side XSS, CORS, and CSP. This note is the remaining backend-security ground those two don't touch: SQL injection, secrets management practice, and a named checklist (the OWASP API Top 10) for tying the pieces together in an interview answer.

## SQL injection and parameterized queries

Injection happens when user input is concatenated directly into a query string instead of passed as a bound parameter:

```python
# VULNERABLE — user input becomes part of the SQL itself
query = f"SELECT * FROM users WHERE email = '{email}'"
cursor.execute(query)
# email = "' OR '1'='1" returns every row
```

The vulnerable version fails because the string `' OR '1'='1` doesn't stay data. Once it's spliced into the query text, the database parses it as SQL, and `WHERE email = '' OR '1'='1'` is always true, so the query returns every row in the table regardless of what email was actually being searched for.

```python
# SAFE — parameterized: the driver sends value and query separately,
# the DB never interprets the value as SQL syntax
cursor.execute("SELECT * FROM users WHERE email = %s", [email])
```

In the safe version, the query text (`"SELECT * FROM users WHERE email = %s"`) and the value (`email`) travel to the database as two separate things. The database compiles the query shape once, with a placeholder, and then substitutes the value in afterward purely as data. No matter what characters `email` contains, the database never re-parses it as part of the SQL grammar, so there's no way for it to change what the query does.

Django's ORM (`Model.objects.filter(email=email)`) parameterizes automatically. This is why raw `.raw()` queries or SQL built with `str.format()` are the actual risk surface in a Django codebase, not the ORM itself. The interview framing: the ORM's safety comes from consistently doing parameterization for you, not from any special magic, and the risk reappears the moment someone drops to raw SQL for a "quick" query and string-formats it instead of using a bound parameter.

## Secrets management

Never hardcode secrets in code or commit them in `.env` files. A secret that reaches git history is compromised even if the commit is later reverted, since the history still persists and remains fetchable. Standard practice:

- Use a managed secrets store (Vault, AWS Secrets Manager, GCP Secret Manager) rather than environment files checked into a repo, so the app fetches secrets at startup/runtime instead of reading them from a committed file.
- Rotate keys on a schedule, and immediately on suspected breach. A secret that can't be rotated without a full deploy is a design flaw, not just an inconvenience.
- Use `.gitignore` plus a pre-commit secret-scanning hook (tools like detect-secrets or gitleaks) to catch a leak before it's pushed, rather than after.
- Mask sensitive fields in logs. Tokens, passwords, and PII should never appear in plaintext log output, since logs are often retained and searched with less access control than the primary datastore.

## OWASP API Security Top 10 as an interview checklist

This is a named list to reach for when asked "how would you secure this API." Two items on it, BOLA and Mass Assignment, are the ones most likely to come up as a live code-review exercise ("here's an endpoint, what's wrong with it"), because both fail from authorization being checked at the wrong granularity rather than being missing outright.

1. **Broken Object Level Authorization (BOLA).** Not fixed by authentication alone. Every object-fetching endpoint must check that the *authenticated user* owns or can access *this specific* object ID, not just that they're logged in as someone. The classic bug: `/orders/{id}` returns any order to anyone who's logged in, regardless of whose order it actually is.
2. **Broken Authentication.** Covered by the JWT/OAuth/session correctness and refresh-token-rotation material elsewhere in this course.
3. **Excessive Data Exposure.** Serializers that return a full model object instead of an explicit field allowlist. The fix to say out loud: allowlist fields in the serializer, and don't rely on the client to politely ignore extra fields it receives.
4. **Lack of Resources & Rate Limiting.** Covered by the Redis-backed rate limiter material elsewhere in this course.
5. **Broken Function Level Authorization.** A role check on the *action* being performed, not just a resource-level ownership check. An admin-only endpoint must reject a non-admin token even when the object-level check would otherwise pass, because the user does technically own the object they're trying to act on.
6. **Mass Assignment.** Accepting a full JSON body into a model or serializer without an explicit allowed-fields list. A request body containing `{"is_admin": true}` can silently escalate privilege if the endpoint blindly deserializes the whole body into the model.
7. **Security Misconfiguration.** Default credentials left in place, verbose error messages that leak stack traces, or debug mode accidentally left on in production.
8. **Injection.** SQL injection, as above, plus the general principle: never let unsanitized input reach an interpreter, whether that's SQL, a shell command, or a template engine.
9. **Improper Assets Management.** Old or undocumented API versions still live and unpatched. A `/v1/` endpoint nobody remembers exists is still just as attackable as the current one.
10. **Insufficient Logging & Monitoring.** Log auth failures, rate-limit hits, and unusual access patterns. Alerting on a spike in 401/403 responses is often how a credential-stuffing attack actually gets caught in practice.
