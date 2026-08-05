# Anonymous Tests

Everything about public tests accessible without an account: use cases, flow, constraints, API, and database schema.

---

## Overview

Organizations and instructors can publish tests via a unique link — no login, no account required.

**Use cases:**
- College entrance exam shared with applicants
- Practice quiz shared on social media
- Public coding challenge / hackathon
- Recruiter skill-screening test

---

## Flow

```
Instructor creates assessment → toggles "Make public for anonymous access"
  └─ System marks assessment `is_public = true`
  └─ Public endpoint available: /api/assessments/:id/public
  └─ Anyone with the link can take the assessment

Anonymous user visits public assessment link
  └─ Optionally enters name + email (configurable: required or optional)
  └─ POST /api/assessments/:id/attempt/start → captures metadata
  └─ Takes the assessment (MCQ / coding challenge / mixed)
  └─ Gets result page immediately on submit
  └─ Receives shareable result link: /api/assessments/attempt/:attemptId/result
  └─ Can optionally create account to save attempt history

Instructor sees all attempts (anonymous + registered)
  └─ `assessment_attempts` rows with `user_id IS NULL` = anonymous
  └─ Filters: registered vs anonymous, score range, date
  └─ Export results as CSV
```

---

## Constraints

- Rate limit by IP: max attempts per IP per test (configurable per test)
- No AI calls for anonymous attempts (cost control)
- Result page: public but only via direct UUID link — not indexed
- Instructor can disable anonymous access at any time; existing attempts are preserved

---

## API Endpoints

```
GET  /api/assessments/:assessmentId/public  public assessment info (title, time limit, instructions) — no auth
POST /api/assessments/:assessmentId/attempt/start  body: {name?, email?, ip_address?} → {attempt_id, questions}
POST /api/assessments/:attemptId/submit          body: {answers} → {score, total}
GET  /api/assessments/attempt/:attemptId/result  public result page — no auth
```

---

## Database Schema

Anonymous attempts are stored in the same `assessment_attempts` table as authenticated attempts, with `user_id = NULL`. Assessments may be marked as `is_public = true` to enable anonymous access.

```sql
assessments (
  -- Core fields; see docs/learning.md for full schema
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id                UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title                 TEXT NOT NULL,
  is_public             BOOLEAN DEFAULT false,  -- enables /public endpoint and anonymous attempts
  requires_name         BOOLEAN DEFAULT false,
  requires_email        BOOLEAN DEFAULT false,
  max_attempts_per_ip   INT DEFAULT 3,
  starts_at             TIMESTAMPTZ,
  ends_at               TIMESTAMPTZ,
  -- ... other fields
)

assessment_attempts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id   UUID NOT NULL REFERENCES assessments(id) ON DELETE CASCADE,
  user_id         UUID,  -- NULL for anonymous attempts
  org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Anonymous metadata
  anon_name       TEXT,  -- captured from {name?} in /start
  anon_email      TEXT,  -- captured from {email?} in /start
  ip_hash         TEXT,  -- hashed for rate limiting; raw IP never stored
  
  started_at      TIMESTAMPTZ DEFAULT now(),
  submitted_at    TIMESTAMPTZ,
  percentage      INT,
  passed          BOOLEAN,
  time_spent_ms   INT
)
```

**Key design:** No separate `public_tests` or `anonymous_attempts` tables. Assessments are polymorphic — the same data model handles both authenticated and anonymous taking. Rate limiting by IP uses `ip_hash`; email/name are optional capture fields.
