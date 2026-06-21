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
Instructor creates test → toggles "Public / Anonymous allowed"
  └─ System generates unique URL: /t/{short-code}
  └─ Anyone with the link can take the test

Anonymous user visits link
  └─ Optionally enters name + email (configurable: required or optional)
  └─ Takes the test (quiz / coding challenge / mixed)
  └─ Gets result page immediately on submit
  └─ Receives shareable result link: /t/{short-code}/result/{attempt-uuid}
  └─ Can optionally create account to save history

Instructor sees all attempts (anonymous + registered)
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
GET  /t/:code                        public test info (title, time limit, instructions) — no auth
POST /t/:code/start                  body: {name?, email?} → {attempt_id, questions}
POST /t/:code/submit/:attemptId      body: {answers} → {score, total, result_url}
GET  /t/:code/result/:attemptId      public result page — no auth
```

---

## Database Schema

```sql
public_tests (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id                  UUID REFERENCES quizzes(id) ON DELETE CASCADE,
  final_test_id            UUID REFERENCES final_tests(id) ON DELETE CASCADE,
  created_by               UUID NOT NULL REFERENCES users(id),
  short_code               TEXT NOT NULL UNIQUE,
  title                    TEXT NOT NULL,
  requires_name            BOOLEAN NOT NULL DEFAULT false,
  requires_email           BOOLEAN NOT NULL DEFAULT false,
  allow_anonymous          BOOLEAN NOT NULL DEFAULT true,
  starts_at                TIMESTAMPTZ,    -- NULL = always open
  ends_at                  TIMESTAMPTZ,
  max_attempts_per_ip      INT NOT NULL DEFAULT 3,
  show_result_immediately  BOOLEAN NOT NULL DEFAULT true,
  created_at               TIMESTAMPTZ DEFAULT now()
)

anonymous_attempts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_test_id  UUID NOT NULL REFERENCES public_tests(id) ON DELETE CASCADE,
  name            TEXT,
  email           TEXT,
  ip_hash         TEXT NOT NULL,   -- hashed for rate limiting; raw IP never stored
  answers         JSONB NOT NULL,
  score           INT NOT NULL,
  total           INT NOT NULL,
  started_at      TIMESTAMPTZ DEFAULT now(),
  completed_at    TIMESTAMPTZ
)
```
