# Courses

Course structure, lifecycle, and student progress tracking. A course is a tree: **course → sections → modules**. A module is the atomic unit of content — one of five types, each with different content storage.

---

## Kind: org vs. self

Every course has a `kind`:

| Kind | Owner | Visibility | Who can write its modules |
|---|---|---|---|
| `org` (default) | the org — authored by an instructor/admin | listed in the org browse catalog (and `is_public` ones in the anonymous catalog) | instructor/admin only, via the authoring API above |
| `self` | one student (`owner_id`) | **never** listed anywhere — only its owner can see it (`GetCourseTree` returns 404, not 403, to anyone else, same rationale as `docs/roadmap.md`'s ownership check) | only the owner — including their connected MCP client (see `docs/ai-connector.md`), with **no review gate** |

A self-course is created either from scratch (`POST /api/self-courses`) or by forking a published org course (`POST /api/self-courses/fork`) — the owner is auto-enrolled in the same transaction, so every existing enrollment/progress/module code path (module completion, XP, `GetModuleContent`'s enrollment check) treats it exactly like any other course with no self-course special-casing needed there. Its modules are always `notes` (markdown) — created/edited via `POST /api/self-courses/{courseID}/modules` and `PATCH /api/self-course-modules/{moduleID}`, both ownership-gated rather than role-gated (any student may call them for a course they own; `RequireOrgRole` doesn't apply).

### Contributing self-course content back into an org course

A self-course write never touches a shared org course directly. Instead, `POST /api/courses/{courseID}/proposals` queues a `course_content_proposals` row (`status='pending'`) with a snapshot of the proposed title/content — the target course's instructor/admin reviews it at `GET /api/courses/{courseID}/proposals` and either:
- **Approves** (`POST /api/proposals/{id}/approve`) — inside one transaction, inserts a real `course_modules` row from the snapshot (into `target_section_id`, or the course's first section if none was given) and marks the proposal `approved` with the resulting module id.
- **Rejects** (`POST /api/proposals/{id}/reject`) — marks it `rejected`, nothing is created.

Both actions require the same instructor/admin role as authoring the course directly — approving a proposal *is* authoring the course, just sourced from a student's own work.

---

## Module Types

| Type | Content storage | Notes |
|---|---|---|
| `video` | `storage_key` (MinIO object) + `duration_seconds` | Streamed via a signed URL |
| `pdf` | `storage_key` (MinIO object) | Rendered client-side |
| `notes` | `content_body` (markdown, inline in the row) | Rendered via `frontend/lib/courses/markdown.ts` (`marked`, GFM, heading-derived TOC) |
| `assessment` | `assessment_id` → `assessments` table | Quiz/test content lives in the assessment domain, not on the module row |
| `lab` | none of the above — no `content_body`, no `storage_key` | Content comes from the linked `lab_definitions` row, fetched separately via `GET /api/modules/{moduleID}/lab` (see `docs/labs.md`) |

A `lab` module is **never created through `POST /api/sections/{sectionID}/modules`** — `CreateModule` only accepts `video`/`pdf`/`notes`/`assessment`. Lab modules are inserted directly (by the labs domain's fixture generator or, in the live product, its own instructor-authoring flow) with `type='lab'` and no `content_body`/`storage_key`; `UpdateModule` still recognizes `lab` so an existing lab module's title/position stays editable through the generic course editor. See `backend/internal/courses/models.go`'s `ModuleTypeLab` constant for the exact wiring note.

---

## Database Schema

```sql
CREATE TABLE courses (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          UUID         NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  creator_id      UUID         NOT NULL REFERENCES users(id)         ON DELETE RESTRICT,
  title           TEXT         NOT NULL CHECK (length(title) BETWEEN 3 AND 200),
  slug            TEXT         NOT NULL,
  description     TEXT         CHECK (length(description) <= 2000),
  cover_url       TEXT,
  difficulty      TEXT         NOT NULL DEFAULT 'beginner'
                               CHECK (difficulty IN ('beginner', 'intermediate', 'advanced', 'expert')), -- 'expert' added in 009
  tags            TEXT[]       NOT NULL DEFAULT '{}',
  status          TEXT         NOT NULL DEFAULT 'draft'
                               CHECK (status IN ('draft', 'review', 'published', 'archived')),
  forked_from_id  UUID         REFERENCES courses(id) ON DELETE SET NULL,
  price_cents     INT          NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
  is_free         BOOLEAN      NOT NULL DEFAULT true,
  estimated_hours NUMERIC(5,1) CHECK (estimated_hours > 0),
  kind            TEXT         NOT NULL DEFAULT 'org' CHECK (kind IN ('org', 'self')), -- added in 016
  owner_id        UUID         REFERENCES users(id) ON DELETE CASCADE, -- set only when kind='self'; added in 016
  created_at      TIMESTAMPTZ  DEFAULT now(),
  updated_at      TIMESTAMPTZ  DEFAULT now(),
  UNIQUE (org_id, slug),
  CHECK (kind = 'org' OR owner_id IS NOT NULL)
);

CREATE TABLE course_content_proposals ( -- added in 016
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id             UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  proposer_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_course_id   UUID        REFERENCES courses(id) ON DELETE SET NULL,
  source_module_id   UUID        REFERENCES course_modules(id) ON DELETE SET NULL,
  target_course_id   UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  target_section_id  UUID        REFERENCES course_sections(id) ON DELETE SET NULL,
  title              TEXT        NOT NULL,
  type               TEXT        NOT NULL CHECK (type IN ('notes', 'assessment')), -- text-only: the proposer is always an MCP tool call, no file-upload transport
  content_body       TEXT        NOT NULL,
  status             TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  review_note        TEXT,
  reviewed_by        UUID        REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at        TIMESTAMPTZ,
  created_module_id  UUID        REFERENCES course_modules(id) ON DELETE SET NULL, -- set on approve
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE course_sections (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title      TEXT        NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  position   INT         NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (course_id, position) DEFERRABLE INITIALLY DEFERRED -- lets a full reorder batch-insert without a temporary collision
);

CREATE TABLE course_modules (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id         UUID        NOT NULL REFERENCES courses(id)         ON DELETE CASCADE,
  section_id        UUID        NOT NULL REFERENCES course_sections(id) ON DELETE CASCADE,
  title             TEXT        NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  type              TEXT        NOT NULL
                                CHECK (type IN ('video', 'pdf', 'notes', 'assessment', 'lab')), -- 'lab' added in 009
  position          INT         NOT NULL DEFAULT 0,
  is_free_preview   BOOLEAN     NOT NULL DEFAULT false,
  storage_key       TEXT,
  duration_seconds  INT         CHECK (duration_seconds > 0),
  content_body      TEXT,
  assessment_id     UUID        REFERENCES assessments(id) ON DELETE SET NULL,
  estimated_minutes INT         CHECK (estimated_minutes > 0),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  deleted_at        TIMESTAMPTZ, -- soft delete
  UNIQUE (section_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE enrollments (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  course_id    UUID        NOT NULL REFERENCES courses(id)  ON DELETE CASCADE,
  batch_id     UUID        REFERENCES batches(id)           ON DELETE SET NULL,
  enrolled_by  UUID        REFERENCES users(id)             ON DELETE SET NULL,
  enrolled_at  TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  UNIQUE (user_id, course_id)
);

CREATE TABLE module_progress (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  module_id             UUID        NOT NULL REFERENCES course_modules(id) ON DELETE CASCADE,
  course_id             UUID        NOT NULL REFERENCES courses(id)        ON DELETE CASCADE,
  status                TEXT        NOT NULL DEFAULT 'not_started'
                                    CHECK (status IN ('not_started', 'in_progress', 'completed')),
  last_position_seconds INT         DEFAULT 0, -- video/PDF scroll resume position
  completed_at          TIMESTAMPTZ,
  updated_at            TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, module_id)
);

CREATE TABLE course_reviews (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  rating     INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (course_id, user_id) -- one review per user per course; resubmitting updates it
);

-- Purchases & coupons — added in 004_payments_coupons.sql. A row starts
-- 'pending' at checkout-creation and only ever transitions to 'completed' or
-- 'failed' via a confirmed gateway webhook (see "Purchases & Coupons" below).
CREATE TABLE course_purchases (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id         UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id        UUID        NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
  course_id      UUID        NOT NULL REFERENCES courses(id)       ON DELETE CASCADE,
  amount_cents   INT         NOT NULL CHECK (amount_cents >= 0), -- final, post-discount, in the currency's SMALLEST unit (paise for INR)
  discount_cents INT         NOT NULL DEFAULT 0 CHECK (discount_cents >= 0),
  currency       TEXT        NOT NULL, -- always supplied from PAYMENTS_CURRENCY (default INR); no column default, so a missing value fails loudly instead of stamping the wrong currency (010_purchase_currency_no_default.sql)
  provider       TEXT        NOT NULL DEFAULT 'stub' CHECK (provider IN ('stub', 'stripe', 'razorpay')),
  provider_ref   TEXT        NOT NULL, -- the gateway's session/order id; "checkout_<uuid>" placeholder until CreateCheckout returns
  payment_ref    TEXT,                 -- the underlying charge/payment id (refund handle)
  coupon_id      UUID        REFERENCES coupons(id) ON DELETE SET NULL,
  status         TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  purchased_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_ref) -- webhook lookup key
  -- plus a partial UNIQUE (user_id, course_id) WHERE status = 'completed' —
  -- only one completed purchase per user+course may ever exist, but a
  -- pending/failed attempt must not block retrying a new checkout
);

CREATE TABLE coupons (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  code             TEXT        NOT NULL, -- matched case-insensitively; UNIQUE (org_id, upper(code))
  description      TEXT        NOT NULL DEFAULT '',
  discount_type    TEXT        NOT NULL CHECK (discount_type IN ('percent', 'fixed')),
  discount_value   INT         NOT NULL, -- percent 1-100, or fixed minor units
  max_discount_cents INT,               -- caps the absolute discount a percent-off coupon can give; NULL = uncapped; no-op for fixed-type (added in 005)
  max_redemptions  INT,                  -- NULL = unlimited
  redeemed_count   INT         NOT NULL DEFAULT 0 CHECK (redeemed_count <= max_redemptions OR max_redemptions IS NULL),
  starts_at        TIMESTAMPTZ,
  expires_at       TIMESTAMPTZ,
  is_active        BOOLEAN     NOT NULL DEFAULT true, -- deactivated, never hard-deleted once redeemed
  created_by       UUID        REFERENCES users(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Course scope — zero rows for a coupon_id = valid for any paid course in
-- the org (the default); one or more rows = restricted to exactly those
-- courses. Replaces a single nullable coupons.course_id (added in 005).
CREATE TABLE coupon_courses (
  coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  PRIMARY KEY (coupon_id, course_id)
);

CREATE TABLE coupon_redemptions (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id      UUID        NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id        UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  purchase_id    UUID        NOT NULL REFERENCES course_purchases(id) ON DELETE CASCADE,
  discount_cents INT         NOT NULL CHECK (discount_cents >= 0),
  redeemed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (coupon_id, user_id), -- one redemption per user per coupon, enforced by Postgres
  UNIQUE (purchase_id)
);

-- Webhook delivery dedup + audit trail — a duplicate delivery of the same
-- gateway event id (Stripe retries up to 72h) is a no-op, not an error.
CREATE TABLE payment_events (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  provider     TEXT        NOT NULL CHECK (provider IN ('stub', 'stripe', 'razorpay')),
  event_id     TEXT        NOT NULL,
  event_type   TEXT        NOT NULL,
  provider_ref TEXT,
  purchase_id  UUID        REFERENCES course_purchases(id) ON DELETE SET NULL,
  payload      JSONB       NOT NULL,
  received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  error        TEXT,
  UNIQUE (provider, event_id)
);
```

---

## Purchases & Coupons

A paid course (`is_free=false`, `price_cents > 0`) is purchased through `backend/internal/mentoring` (checkout/webhook orchestration) + `backend/internal/payments` (the Stripe/Razorpay/stub provider seam) + `backend/internal/coupons` (discount codes) — `courses` itself only defines the `CoursePurchaser` interface these packages implement, to avoid an import cycle.

**Flow:**
1. `POST /api/courses/{courseID}/checkout` (optionally with `provider` and `coupon_code`) — validates the course and coupon, inserts a `pending` `course_purchases` row, and asks the gateway to start a real checkout. Returns a `redirect_url` (Stripe hosted Checkout) or `client_params` (Razorpay Checkout.js modal). **Grants no access** — a real gateway confirms asynchronously (3DS, bank debit clearing), so this call only starts that process.
2. The student completes payment on the gateway's own UI, then lands back on the frontend's checkout return page, which polls `GET /api/courses/{courseID}/purchase-status` — the redirect itself never grants access, only a webhook-confirmed `"completed"` status does, which may arrive slightly after the redirect.
3. The gateway calls `POST /api/payments/webhooks/{provider}` (public, authenticated by the gateway's own signature scheme). After de-duplicating the event (`payment_events.(provider, event_id)` UNIQUE) and cross-checking its amount/currency against what was stored at checkout-creation, one transaction: marks the purchase `completed`, atomically consumes the coupon redemption (if any), enrolls the student (`courses.Repo.CreateEnrollmentTx` — identical to the free-course enrollment path), and opens a mentor ticket unless the student already has one.

A coupon's redemption is only ever consumed at step 3 (payment confirmed), never at step 1 — an abandoned or failed checkout never burns a redemption slot. Redemption caps and per-user reuse are enforced by Postgres (`coupons.redeemed_count` guarded `UPDATE ... RETURNING`, `coupon_redemptions` `UNIQUE(coupon_id, user_id)`), not application-level check-then-write, since that has a race under concurrent redemption attempts.

Coupon management (`POST/GET/PATCH/DELETE /api/coupons`) is gated by the `payments.manage_coupons` permission (see [rbac.md](rbac.md)) — granted to `tenant_admin` by default.

---

## Lifecycle

```
draft → review → published → archived
```

An instructor authors a course as `draft`, builds out sections/modules, then `POST /api/courses/{courseID}/publish` moves it to `published` (the exact `review` transition, if used, is org-workflow-specific — not enforced by a DB constraint beyond the allowed status set). Students can only enroll in `published` courses. `ForkCourse` clones a published course (`forked_from_id` traces lineage) so an instructor can adapt someone else's course without touching the original.

---

## Fork

`POST /api/courses/{courseID}/fork` deep-copies a course's sections and modules into a new course owned by the caller, with `forked_from_id` set to the source course's id. Lab modules fork as references to the same `lab_definitions` row (labs are not deep-copied) — forking a course with labs does not duplicate lab content.

---

## API

### Instructor (requires `admin` or `instructor` org role)

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/courses` | Create a course (`draft` status) |
| `PATCH` | `/api/courses/{courseID}` | Update course metadata |
| `POST` | `/api/courses/{courseID}/publish` | Publish |
| `DELETE` | `/api/courses/{courseID}` | Delete |
| `POST` | `/api/courses/{courseID}/fork` | Fork a course |
| `POST` | `/api/courses/{courseID}/sections` | Add a section |
| `PUT` | `/api/courses/{courseID}/sections/order` | Reorder sections |
| `PATCH` | `/api/sections/{sectionID}` | Update a section |
| `DELETE` | `/api/sections/{sectionID}` | Delete a section |
| `POST` | `/api/sections/{sectionID}/modules` | Add a module — `video`/`pdf`/`notes`/`assessment` only, never `lab` |
| `PUT` | `/api/sections/{sectionID}/modules/order` | Reorder modules within a section |
| `PATCH` | `/api/modules/{moduleID}` | Update a module (works for `lab` modules too — title/position only, not content) |
| `DELETE` | `/api/modules/{moduleID}` | Delete a module |
| `POST` | `/api/upload` | Upload a course asset (video/PDF) |
| `POST` | `/api/upload/course-asset` | Get a signed upload URL |
| `POST` | `/api/courses/generate-outline` | AI-generated course outline draft |

### Staff + Mentor

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/courses/{courseID}/progress` | All-students progress overview |

### Instructor: content-proposal review queue

Same `admin`/`instructor` role gate as authoring the target course directly.

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/courses/{courseID}/proposals` | List proposals for this course (`?status=` filters, defaults to `pending`) |
| `POST` | `/api/proposals/{proposalID}/approve` | Merge a pending proposal into the course as a real module (body: `{review_note?}`) |
| `POST` | `/api/proposals/{proposalID}/reject` | Reject a pending proposal, no module created (body: `{review_note?}`) |

### All authenticated users: self-courses

No `RequireOrgRole` gate — ownership (not org role) is what these enforce.

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/self-courses` | Create a private course from scratch (body: `{title, description?, difficulty?, tags?}`) |
| `POST` | `/api/self-courses/fork` | Fork a published org course into a private copy (body: `{course_id, title}`) |
| `POST` | `/api/self-courses/{courseID}/modules` | Add a notes module to a self-course you own (body: `{section_id?, title, content_body}`) |
| `PATCH` | `/api/self-course-modules/{moduleID}` | Replace a self-course module's title/content (body: `{title, content_body}`) |
| `POST` | `/api/courses/{courseID}/proposals` | Propose a contribution to a shared org course (body: `{target_section_id?, source_module_id?, title?, content_body?}` — either `source_module_id` from one of your own self-courses, or both `title` and `content_body`) |

### All authenticated users

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/courses` | List/browse courses |
| `GET` | `/api/courses/random-topic` | "Surprise me" — one published course not yet enrolled in, weighted toward `topics_interest` |
| `GET` | `/api/courses/{courseID}` | Course detail (tree of sections + modules) |
| `POST` | `/api/courses/{courseID}/enroll` | Enroll in a free course (402 if the course is paid) |
| `POST` | `/api/courses/{courseID}/checkout` | Start a paid-course checkout — see "Purchases & Coupons" below |
| `GET` | `/api/courses/{courseID}/purchase-status` | Poll purchase status after a gateway redirect |
| `POST` | `/api/courses/{courseID}/coupon/preview` | Validate a coupon code and preview its discount |
| `GET` | `/api/enrollments/me` | My enrollments |
| `POST` | `/api/courses/{courseID}/reviews` | Submit/update my star rating |
| `GET` | `/api/courses/{courseID}/reviews/me` | My review for this course |
| `GET` | `/api/modules/{moduleID}` | Module content (for `lab` modules, use `GET /api/modules/{moduleID}/lab` instead — see `docs/labs.md`) |
| `PATCH` | `/api/modules/{moduleID}/progress` | Update my progress on a module (video position, mark complete) |
| `GET` | `/api/courses/{courseID}/progress/me` | My aggregate + per-module progress |

---

## Module Completion

`module_progress` tracks per-user, per-module status (`not_started`/`in_progress`/`completed`). For `video`/`pdf`/`notes` modules the student (or the frontend, on scroll/watch-complete) calls `PATCH /api/modules/{moduleID}/progress` directly. For `assessment` and `lab` modules, completion is driven by the owning domain instead — an assessment attempt passing, or a lab session reaching `status='completed'` (see `docs/labs.md`'s "Task Verification" section, `finalizeTaskPass` → `coursesSvc.CompleteModule`) calls into the courses domain to mark the module complete, rather than the student calling the progress endpoint themselves.

`CourseProgressSummary` (`GET /api/courses/{courseID}/progress/me`) aggregates `completed`/`total`/`pct` across every module in the course plus the raw per-module rows, so the frontend can render completion badges and resume-at-the-right-module navigation without a second query.
