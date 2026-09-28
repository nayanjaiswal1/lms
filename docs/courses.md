# Courses

Course structure, lifecycle, and student progress tracking. A course is a tree: **course → sections → modules**. A module is the atomic unit of content — one of five types, each with different content storage.

---

## Module Types

| Type | Content storage | Notes |
|---|---|---|
| `video` | `storage_key` (MinIO object) + `duration_seconds` | Streamed via a signed URL |
| `pdf` | `storage_key` (MinIO object) | Rendered client-side |
| `notes` | `content_body` (markdown, inline in the row) | Rendered via `frontend/lib/courses/markdown.ts` (`marked`, GFM, heading-derived TOC) |
| `assessment` | `assessment_id` → `assessments` table | Quiz/test content lives in the assessment domain, not on the module row |
| `lab` | none of the above — no `content_body`, no `storage_key` | Content comes from the linked `lab_definitions` row via `course_modules.lab_id`, fetched separately via `GET /api/modules/{moduleID}/lab` (see `docs/labs.md`) |

A `lab` module is **never created through `POST /api/sections/{sectionID}/modules`** — `CreateModule` only accepts `video`/`pdf`/`notes`/`assessment`. The only two ways a `lab` module is ever inserted are `library.Service.Attach` ("Add from library" — see below) and the coursegen fixture generator, both of which set `lab_id` in the same insert; `UpdateModule` still recognizes `lab` so an existing lab module's title/position stays editable through the generic course editor, and a dedicated `PATCH /api/modules/{moduleID}/lab-required` toggles its per-placement `lab_is_required`. See `backend/internal/courses/models.go`'s `ModuleTypeLab` constant for the exact wiring note.

---

## Course library ("Add from library")

An instructor places an existing lab, quiz, or notes lesson into a course section instead of authoring one from scratch — `backend/internal/library` (a separate package, since `labs` already imports `courses` and a shared module-insert helper can't live in either without a cycle). One shared insert path, `library.Service.Attach`, is used both by the picker UI and (from Phase 1 on) the debug-lab builder's publish step:

1. Lock the target section (`courses.Repo.LockSectionForOrg`, org-scoped — the same "actor can edit this course" boundary `CreateModule` already applies).
2. Check the item is eligible for its kind: a **lab** must be published and visible to the org (own org, or `lab_definitions.library_visibility = 'platform'`); a **quiz** must be `published` and owned by the org; **notes** just needs its source module to be a `notes` module the org can read.
3. Shift every module at/after the insert position down by one (`course_modules_section_id_position_key` is `DEFERRABLE INITIALLY DEFERRED`, so a bulk shift + insert in the same transaction never collides).
4. Insert through `courses.Repo.InsertModuleTx`, reusing `CreateModule`'s column list plus `lab_id`/`lab_is_required`/`copied_from_module_id`.
5. Write an `audit_logs` row and commit.

**Reference vs. copy** (`library.ModeReference` / `library.ModeCopy`): a lab or quiz placement is a **reference** — `course_modules.lab_id`/`assessment_id` point at the same source row, so republishing the source (a lab) reaches every placement, and a quiz's attempts are shared across every course it's placed in. A notes placement is a **copy** — `content_body` is duplicated into the new row with `copied_from_module_id` set, and never re-syncs from the source afterward.

Endpoints (`RequireOrgRole(owner, admin, instructor)`, same guard as the module routes):

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/library?type=lab,quiz,notes&q=&cursor=&limit=` | Cursor-paginated search over the org's (+ platform-shared) labs, quizzes, and notes lessons — no new table, a `UNION ALL` over `lab_definitions`/`assessments`/`course_modules` |
| `GET` | `/api/library/{kind}/{id}/preview` | Student-safe projection: lab task list, quiz questions, or rendered notes body |
| `POST` | `/api/library/{kind}/{id}/try` | Try a lab as a student (`is_test` session — the same path an instructor's own "test my lab" button uses) |
| `POST` | `/api/sections/{sectionID}/library-items` | `Attach` — body `{kind, item_id, position?, title?, is_required?}`; `position` omitted appends at the end of the section |

`library_visibility` (`lab_definitions`, default `'org'`) is `'private'` (reserved), `'org'` (default — placeable within the owning org only), or `'platform'` (placeable by any org; sessions started from that placement count against the *placing* org's caps/usage, not the lab's owner). Cross-org quiz/notes visibility isn't implemented in Phase A — both stay strictly own-org.

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
  disable_code_run BOOLEAN     NOT NULL DEFAULT false, -- locks Run on every lesson code block for this course; added in 028
  created_at      TIMESTAMPTZ  DEFAULT now(),
  updated_at      TIMESTAMPTZ  DEFAULT now(),
  UNIQUE (org_id, slug)
);

CREATE TABLE course_sections (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title      TEXT        NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  position   INT         NOT NULL DEFAULT 0,
  group_title TEXT       CHECK (group_title IS NULL OR length(group_title) BETWEEN 1 AND 200), -- 042: optional; consecutive sections sharing a group_title render nested under one heading
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
  lab_id                UUID    REFERENCES lab_definitions(id) ON DELETE RESTRICT
                                 DEFERRABLE INITIALLY DEFERRED, -- 044: the module<->lab link; resolution goes through THIS, never lab_definitions.module_id
  lab_is_required       BOOLEAN NOT NULL DEFAULT false, -- 044: per-placement — same lab can be required in one course, optional in another
  copied_from_module_id UUID    REFERENCES course_modules(id) ON DELETE SET NULL, -- 044: set on a notes module inserted as a library copy
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  deleted_at        TIMESTAMPTZ, -- soft delete
  UNIQUE (section_id, position) DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT lab_module_has_lab CHECK ((type = 'lab') = (lab_id IS NOT NULL)) -- 044
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

## Bundles

A **bundle** clubs several existing courses together in an order (e.g. "Backend Engineer Path" = Python → Django → FastAPI). It only *references* courses — nothing is copied — so editing a course shows up in every bundle it belongs to. Enrollment, progress and certificates all stay per course; a bundle adds a curated path, an aggregate progress ring, and one **Enroll in all** action. Added in `043_course_bundles.sql`.

```sql
CREATE TABLE course_bundles (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  creator_id  UUID        NOT NULL REFERENCES users(id)         ON DELETE RESTRICT,
  title       TEXT        NOT NULL CHECK (char_length(title) BETWEEN 3 AND 200),
  slug        TEXT        NOT NULL,
  description TEXT        CHECK (description IS NULL OR char_length(description) <= 2000),
  cover_url   TEXT,
  status      TEXT        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, slug)
);

CREATE TABLE course_bundle_items (
  bundle_id UUID NOT NULL REFERENCES course_bundles(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id)        ON DELETE CASCADE,
  position  INT  NOT NULL CHECK (position >= 0),
  PRIMARY KEY (bundle_id, course_id),
  UNIQUE (bundle_id, position) DEFERRABLE INITIALLY DEFERRED
);
```

Rules:
- **Visibility** — students only see `published` bundles, and only the `published` courses inside them. Instructors see drafts through the `/manage` endpoints.
- **Enroll in all** (`POST /api/bundles/{bundleID}/enroll`) enrolls the student in every published **free** course in one statement (`ON CONFLICT DO NOTHING`, so existing enrollments are untouched). Paid courses are never granted here — they come back in `requires_purchase_course_ids` and the student buys each through its own checkout. There is no bundle price yet; a single bundle checkout would need its own purchase/coupon/refund path.
- **Course list** is replaced wholesale by `PUT /api/bundles/{bundleID}/courses` (`{course_ids: [...]}`, max 50, distinct, all in the caller's org) — one call covers add, remove and reorder.
- **Deleting** a bundle removes only the grouping; courses and student data are unaffected. Deleting a course drops it from every bundle (FK cascade).
- The course detail response (`GET /api/courses/by-slug/{slug}`) includes `bundles` — the published bundles the course is part of — for the "Part of" chip.

Frontend: bundles strip + "New bundle" button on `/courses`, student page `/bundles/[slug]`, editor `/bundles/new` and `/bundles/[slug]/edit` (`components/bundles/`, `lib/server/bundles.ts`, `lib/bundles/actions.ts`).

---

## Lifecycle

```
draft → review → published → archived
```

An instructor authors a course as `draft`, builds out sections/modules, then `POST /api/courses/{courseID}/publish` moves it to `published` (the exact `review` transition, if used, is org-workflow-specific — not enforced by a DB constraint beyond the allowed status set). Students can only enroll in `published` courses. `ForkCourse` clones a published course (`forked_from_id` traces lineage) so an instructor can adapt someone else's course without touching the original.

---

## Fork

`POST /api/courses/{courseID}/fork` deep-copies a course's sections and modules into a new course owned by the caller, with `forked_from_id` set to the source course's id. Lab modules fork as references to the same `lab_definitions` row (labs are not deep-copied) — forking a course with labs does not duplicate lab content, and (since migration 044) `lab_id`/`lab_is_required` are copied onto the new module row so the forked lab module actually resolves. Before 044, `copySectionsAndModules` copied every `course_modules` column except the lab link, so a forked lab module pointed at nothing (`lab_definitions` was keyed by `module_id`, which forking always changes) — 044's backfill relinks courses forked before the fix, matching each still-unlinked lab module back to its source by `(section position, module position)` and reporting any it can't match.

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
| `PATCH` | `/api/modules/{moduleID}/lab-required` | Toggle a lab module's per-placement `lab_is_required` |
| `DELETE` | `/api/modules/{moduleID}` | Delete a module |
| `GET` | `/api/library?...` | Search the course library (labs/quizzes/notes) — see "Course library" above |
| `GET` | `/api/library/{kind}/{id}/preview` | Preview a library item |
| `POST` | `/api/library/{kind}/{id}/try` | Try a library lab as a student |
| `POST` | `/api/sections/{sectionID}/library-items` | Attach a library item into a section |
| `POST` | `/api/upload` | Upload a course asset (video/PDF) |
| `POST` | `/api/upload/course-asset` | Get a signed upload URL |
| `POST` | `/api/courses/generate-outline` | AI-generated course outline draft |
| `POST` | `/api/bundles` | Create a bundle (`draft` by default) |
| `GET` | `/api/bundles/manage` | Every bundle in the org, drafts included |
| `GET` | `/api/bundles/{bundleID}/manage` | Bundle detail for the editor (drafts + unpublished courses included) |
| `PATCH` | `/api/bundles/{bundleID}` | Update title/description/cover/status |
| `DELETE` | `/api/bundles/{bundleID}` | Delete a bundle (courses untouched) |
| `PUT` | `/api/bundles/{bundleID}/courses` | Replace the ordered course list |

### Staff + Mentor

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/courses/{courseID}/progress` | All-students progress overview |

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
| `GET` | `/api/bundles` | Published bundles |
| `GET` | `/api/bundles/by-slug/{slug}` | Published bundle with its courses + my enrollment/progress in each |
| `POST` | `/api/bundles/{bundleID}/enroll` | Enroll in all free courses; lists paid ones still to buy |

---

## Module Completion

`module_progress` tracks per-user, per-module status (`not_started`/`in_progress`/`completed`). For `video`/`pdf`/`notes` modules the student (or the frontend, on scroll/watch-complete) calls `PATCH /api/modules/{moduleID}/progress` directly. For `assessment` and `lab` modules, completion is driven by the owning domain instead — an assessment attempt passing, or a lab session reaching `status='completed'` (see `docs/labs.md`'s "Task Verification" section, `finalizeTaskPass` → `coursesSvc.CompleteModule`) calls into the courses domain to mark the module complete, rather than the student calling the progress endpoint themselves.

`CourseProgressSummary` (`GET /api/courses/{courseID}/progress/me`) aggregates `completed`/`total`/`pct` across every module in the course plus the raw per-module rows, so the frontend can render completion badges and resume-at-the-right-module navigation without a second query.
