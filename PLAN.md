# MindForge — Phases 5–8 Implementation Plan

> **Status:** Pending confirmation. Do not implement until user runs `/confirm`.
> **Supersedes:** `docs/courses.md` (schema replaced here). `phase0.md` and `phase1.md` remain as historical records.
> **Next free migration:** `007`

---

## 1. ANALYSIS

### Explicit Requirements (from user brief)
| # | Requirement |
|---|---|
| R1 | Instructors create courses with nested modules (video / test / pdf / notes) |
| R2 | Modules support nesting (sections → modules) |
| R3 | Assign courses to users; users can start and track progress |
| R4 | Batches/cohorts: create, add courses, group users, assign mentors |
| R5 | Bulk user invite into a batch (CSV / email list); invite accept flow |
| R6 | Instructor/mentor can chat with candidates in a batch context |
| R7 | Mentor sees all queries, FAQs surfaced to reduce overload |
| R8 | Mentor views progress, assigns tests, tracks per-student metrics |
| R9 | Course designer with video/image support; full course authoring |
| R10 | AI-assisted course creation flow |
| R11 | AI Interview Prep: user creates tech practice sessions, AI (Gemini/Anthropic) reviews answers, flags gaps, suggests corrections |

### Implicit Requirements
- **Tenant isolation**: every resource is scoped to `org_id` — no cross-org data leakage
- **Role enforcement**: instructors author; mentors guide and view; students consume
- **File storage**: videos and PDFs go to MinIO (already wired), not the DB
- **Pre-signed URLs**: course video/PDF served via time-limited MinIO URLs (not public)
- **Enrollment gate**: module content only accessible after enrollment (or `is_free_preview`)
- **Progress aggregation**: course `progress_pct` computed from `module_progress`, not stored redundantly
- **AI cost control**: generate-outline and interview review are rate-limited; results cached in DB (never re-call LLM for the same result)
- **Soft delete for messages**: batch messages deleted by the sender or mentor, body replaced with `[deleted]`, never hard-deleted (audit trail)
- **FAQ dedup**: mentors can promote a batch message to course FAQ; AI can suggest FAQ from clusters of similar questions
- **user_stats triggers**: the existing `user_stats` table is a stub — needs DB-level UPDATE whenever enrollments, completions, or test passes change

### Edge Cases and Failure Scenarios
| Scenario | Handling |
|---|---|
| Instructor deletes a module that has in-progress student progress | Soft-delete: `deleted_at` on module; progress row kept, module excluded from active view |
| Assessment assigned to module is deleted | `assessment_id` FK → `ON DELETE SET NULL`; module shows "assessment removed" in UI |
| Batch course assigned; new member joins batch later | Enrollment trigger on `batch_members INSERT` auto-enrolls in all `batch_courses` |
| Video upload to MinIO fails mid-way | Presigned URL flow: module stays `content_url = NULL` (draft) until upload confirmed |
| AI provider down during course generation | Return 503 with `retry_after`; never persist partial outline |
| Invitation token reuse | `accepted_at IS NOT NULL` check prevents double-accept |
| User invited to batch but not an org member | Invitation acceptance auto-creates `org_members` row as `student` |
| Student submits interview answer, AI review times out | Store answer, mark `feedback_at = NULL`; async review job retries up to 3× |
| Course forked; original deleted | `forked_from_id → ON DELETE SET NULL`; fork is independent |
| Mentor removed from batch; their messages remain | `sender_id → ON DELETE CASCADE` would delete messages — use RESTRICT + deactivation pattern |

### Security Risks
- IDOR on `/api/modules/:id`: must verify user is enrolled OR instructor of that course
- SSRF via cover_url / content_url: validate MinIO domain only; no external URL stored directly
- Prompt injection in AI course generation: sanitize user topic input before sending to LLM
- Invitation token enumeration: token must be random 32-byte hex, hashed in DB (same pattern as reset tokens)
- Bulk invite CSV: validate email format, max 500 emails per request, strip BOM
- File upload: validate MIME type via magic bytes (not extension), cap at 2 GB for video, 50 MB for PDF

### Scalability Concerns
- Course viewer N+1: single query loads full course tree (sections + modules) in one CTE, not N queries
- Module progress aggregation: computed per-request from `module_progress` — cache in Redis if > 1000 enrollments per course
- Batch message pagination: cursor-based (`created_at`, `id`), not offset — offsets break on concurrent inserts
- AI calls: idempotent — check DB before calling LLM; store result immediately after

---

## 2. ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Next.js 16 Frontend                          │
│  /courses          /instructor/courses     /practice                │
│  /courses/[slug]/learn  /mentor/batches    /mentor/batches/[id]/chat│
└──────────────────────────────┬──────────────────────────────────────┘
                               │ Server Actions / fetch (server-side)
┌──────────────────────────────▼──────────────────────────────────────┐
│                        Go Chi Router (port 8080)                    │
│                                                                     │
│  /api/courses/*       → internal/courses/                           │
│  /api/sections/*      → internal/courses/                           │
│  /api/modules/*       → internal/courses/                           │
│  /api/enrollments/*   → internal/courses/                           │
│  /api/batches/*       → internal/assessment/ (extended)             │
│  /api/invitations/*   → internal/assessment/ (extended)             │
│  /api/messages/*      → internal/messaging/                         │
│  /api/faqs/*          → internal/messaging/                         │
│  /api/practice/*      → internal/practice/                          │
│  /api/upload/*        → internal/storage/ (presigned URL)           │
│  /api/ai/*            → internal/ai/ (LLM interface)                │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
        ┌──────────────────────┼────────────────────┐
        ▼                      ▼                    ▼
   PostgreSQL              Redis               MinIO (S3)
   (primary store)    (rate-limit cache)   (video / PDF / images)
        │
   ┌────┴──────────────────────────────┐
   │          internal/ai/             │
   │  LLMProvider interface            │
   │  ├── AnthropicProvider            │
   │  ├── GeminiProvider (OpenAI-compat│
   │  │   via generativelanguage API)  │
   │  └── NoOpProvider (disabled)      │
   └───────────────────────────────────┘
```

### Package Map (backend — new)
| Package | Responsibility |
|---|---|
| `internal/courses/` | CRUD for courses, sections, modules; enrollment; progress; fork; AI outline |
| `internal/messaging/` | Batch messages, reactions, FAQ CRUD |
| `internal/practice/` | Interview prep sessions, AI review, question generation |
| `internal/ai/` | LLMProvider interface + Anthropic + Gemini (OpenAI-compat) + NoOp implementations |
| `internal/storage/` | Already exists — extend with `PresignedUploadURL(key, mimeType)` and `PresignedGetURL(key, ttl)` |

### Data Flow — Course Content Delivery
```
Student → GET /api/modules/:id → check enrollment in DB → if enrolled:
  → if type=video: generate MinIO presigned GET URL (TTL=1h) → return URL
  → if type=pdf:   generate MinIO presigned GET URL (TTL=1h) → return URL
  → if type=notes: return content_body directly in response
  → if type=assessment: return assessment_id (frontend navigates to /assessments/:id)
```

### Data Flow — AI Course Generation
```
Instructor → POST /api/courses/generate-outline {topic, level, module_count}
  → rate-limit check (5/hour per user)
  → sanitize topic (strip HTML, trim, max 200 chars)
  → call ai.Provider.Complete(systemPrompt, userPrompt, JSONMode=true)
  → parse response → validate structure
  → return {sections:[{title, modules:[{title, type, description}]}]}
  (does NOT auto-create DB rows — instructor reviews and confirms first)
```

### Data Flow — Interview Prep AI Review
```
User → POST /api/practice/sessions/:id/items/:pos/answer {answer_text}
  → store answer in practice_items.user_answer
  → enqueue AI review (inline, not async — simpler; if AI > 15s → timeout → store NULL)
  → call ai.Provider.Complete(reviewPrompt, userAnswer) → parse JSONB feedback
  → store in practice_items.ai_feedback
  → return {item with feedback}
```

---

## 3. DATABASE CHANGES

### Migration 007 — Course System

```sql
-- 001_schema.sql (courses section)

CREATE TABLE courses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          UUID REFERENCES organizations(id) ON DELETE CASCADE,
  creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  title           TEXT NOT NULL CHECK (length(title) BETWEEN 3 AND 200),
  slug            TEXT NOT NULL,
  description     TEXT CHECK (length(description) <= 2000),
  cover_url       TEXT,
  difficulty      TEXT NOT NULL DEFAULT 'beginner'
                  CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  tags            TEXT[] NOT NULL DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft', 'review', 'published', 'archived')),
  forked_from_id  UUID REFERENCES courses(id) ON DELETE SET NULL,
  price_cents     INT NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
  is_free         BOOLEAN NOT NULL DEFAULT true,
  estimated_hours NUMERIC(5,1) CHECK (estimated_hours > 0),
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (org_id, slug)
);
CREATE INDEX ON courses (org_id, status);
CREATE INDEX ON courses USING GIN (tags);
CREATE INDEX ON courses (creator_id);

CREATE TABLE course_sections (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title      TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  position   INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (course_id, position) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ON course_sections (course_id, position);

-- Each module IS a content item within a section
CREATE TABLE course_modules (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id         UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  section_id        UUID NOT NULL REFERENCES course_sections(id) ON DELETE CASCADE,
  title             TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  type              TEXT NOT NULL
                    CHECK (type IN ('video', 'pdf', 'notes', 'assessment')),
  position          INT NOT NULL DEFAULT 0,
  is_free_preview   BOOLEAN NOT NULL DEFAULT false,
  -- video/pdf: MinIO object key (NOT a full URL — presigned on request)
  storage_key       TEXT,
  -- video only
  duration_seconds  INT CHECK (duration_seconds > 0),
  -- notes only (Markdown)
  content_body      TEXT,
  -- assessment only
  assessment_id     UUID REFERENCES assessments(id) ON DELETE SET NULL,
  estimated_minutes INT CHECK (estimated_minutes > 0),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  deleted_at        TIMESTAMPTZ,
  UNIQUE (section_id, position) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ON course_modules (course_id) WHERE deleted_at IS NULL;
CREATE INDEX ON course_modules (section_id, position) WHERE deleted_at IS NULL;
CREATE INDEX ON course_modules (assessment_id) WHERE assessment_id IS NOT NULL;

CREATE TABLE enrollments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id   UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  batch_id    UUID REFERENCES batches(id) ON DELETE SET NULL,
  enrolled_by UUID REFERENCES users(id) ON DELETE SET NULL,
  enrolled_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  UNIQUE (user_id, course_id)
);
CREATE INDEX ON enrollments (user_id);
CREATE INDEX ON enrollments (course_id);
CREATE INDEX ON enrollments (batch_id) WHERE batch_id IS NOT NULL;

CREATE TABLE module_progress (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  module_id             UUID NOT NULL REFERENCES course_modules(id) ON DELETE CASCADE,
  course_id             UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  status                TEXT NOT NULL DEFAULT 'not_started'
                        CHECK (status IN ('not_started', 'in_progress', 'completed')),
  last_position_seconds INT DEFAULT 0,
  completed_at          TIMESTAMPTZ,
  updated_at            TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, module_id)
);
CREATE INDEX ON module_progress (user_id, course_id);
CREATE INDEX ON module_progress (module_id);

-- Trigger: update user_stats.courses_enrolled on enrollment
CREATE OR REPLACE FUNCTION update_user_stats_enrollment() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_stats (user_id, courses_enrolled, updated_at)
    VALUES (NEW.user_id, 1, now())
  ON CONFLICT (user_id) DO UPDATE
    SET courses_enrolled = user_stats.courses_enrolled + 1,
        updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enrollment_stats
  AFTER INSERT ON enrollments
  FOR EACH ROW EXECUTE FUNCTION update_user_stats_enrollment();

-- Trigger: update user_stats.courses_completed on course completion
CREATE OR REPLACE FUNCTION update_user_stats_completion() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL THEN
    INSERT INTO user_stats (user_id, courses_completed, updated_at)
      VALUES (NEW.user_id, 1, now())
    ON CONFLICT (user_id) DO UPDATE
      SET courses_completed = user_stats.courses_completed + 1,
          updated_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_completion_stats
  AFTER UPDATE OF completed_at ON enrollments
  FOR EACH ROW EXECUTE FUNCTION update_user_stats_completion();
```

### Migration 008 — Batch Enhancements

```sql
-- 001_schema.sql (batch enhancements section)

-- Multiple mentors per batch (existing batches.mentor_id stays as primary contact)
CREATE TABLE batch_mentors (
  id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  user_id  UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  added_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  added_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (batch_id, user_id)
);
CREATE INDEX ON batch_mentors (batch_id);
CREATE INDEX ON batch_mentors (user_id);

-- Assign courses to batches; triggers bulk enrollment of all members
CREATE TABLE batch_courses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id    UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  course_id   UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (batch_id, course_id)
);
CREATE INDEX ON batch_courses (batch_id);
CREATE INDEX ON batch_courses (course_id);

-- Email-based batch invitations
CREATE TABLE batch_invitations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id    UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  org_id      UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email       CITEXT NOT NULL,
  invited_by  UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  invited_at  TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  resent_at   TIMESTAMPTZ,
  UNIQUE (batch_id, email)
);
CREATE INDEX ON batch_invitations (batch_id, accepted_at, declined_at);
CREATE INDEX ON batch_invitations (expires_at) WHERE accepted_at IS NULL AND declined_at IS NULL;
CREATE INDEX ON batch_invitations (email, accepted_at);

-- When a batch_course is assigned: auto-enroll all current batch members
CREATE OR REPLACE FUNCTION enroll_batch_members_in_course() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO enrollments (user_id, course_id, batch_id, enrolled_by)
  SELECT bm.user_id, NEW.course_id, NEW.batch_id, NEW.assigned_by
  FROM batch_members bm
  WHERE bm.batch_id = NEW.batch_id
  ON CONFLICT (user_id, course_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_batch_course_enroll
  AFTER INSERT ON batch_courses
  FOR EACH ROW EXECUTE FUNCTION enroll_batch_members_in_course();

-- When a user joins a batch: auto-enroll in all batch courses
CREATE OR REPLACE FUNCTION enroll_new_member_in_batch_courses() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO enrollments (user_id, course_id, batch_id, enrolled_by)
  SELECT NEW.user_id, bc.course_id, NEW.batch_id, NEW.user_id
  FROM batch_courses bc
  WHERE bc.batch_id = NEW.batch_id
  ON CONFLICT (user_id, course_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_member_join_enroll
  AFTER INSERT ON batch_members
  FOR EACH ROW EXECUTE FUNCTION enroll_new_member_in_batch_courses();
```

### Migration 009 — Messaging & FAQ

```sql
-- 001_schema.sql (messaging section)

CREATE TABLE batch_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id    UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  sender_id   UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  parent_id   UUID REFERENCES batch_messages(id) ON DELETE CASCADE,
  body        TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 5000),
  type        TEXT NOT NULL DEFAULT 'question'
              CHECK (type IN ('question', 'answer', 'announcement', 'resource')),
  is_pinned   BOOLEAN NOT NULL DEFAULT false,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  edited_at   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now(),
  deleted_at  TIMESTAMPTZ
);
-- Cursor pagination: (batch_id, created_at, id)
CREATE INDEX ON batch_messages (batch_id, created_at DESC, id) WHERE deleted_at IS NULL;
CREATE INDEX ON batch_messages (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX ON batch_messages (batch_id, is_pinned) WHERE is_pinned = true AND deleted_at IS NULL;
CREATE INDEX ON batch_messages (batch_id, is_resolved) WHERE is_resolved = false AND deleted_at IS NULL;

CREATE TABLE batch_message_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES batch_messages(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction   TEXT NOT NULL CHECK (reaction IN ('upvote', 'helpful')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (message_id, user_id, reaction)
);
CREATE INDEX ON batch_message_reactions (message_id);

CREATE TABLE course_faqs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id         UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  org_id            UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  question          TEXT NOT NULL CHECK (length(question) BETWEEN 10 AND 500),
  answer            TEXT NOT NULL CHECK (length(answer) BETWEEN 10 AND 5000),
  ai_generated      BOOLEAN NOT NULL DEFAULT false,
  source_message_id UUID REFERENCES batch_messages(id) ON DELETE SET NULL,
  created_by        UUID REFERENCES users(id) ON DELETE SET NULL,
  position          INT NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX ON course_faqs (course_id, position);
CREATE INDEX ON course_faqs (org_id);
```

### Migration 010 — AI Feature Support

```sql
-- 001_schema.sql (AI features section)

-- Add AI feedback to assessment attempt answers (interview_prep grading)
ALTER TABLE attempt_answers
  ADD COLUMN IF NOT EXISTS ai_feedback JSONB;

-- Extend question type to include interview_prep
ALTER TABLE questions
  DROP CONSTRAINT questions_type_check;
ALTER TABLE questions
  ADD CONSTRAINT questions_type_check
  CHECK (type IN ('mcq', 'coding', 'interview_prep'));

-- Self-directed interview prep practice sessions (NOT backed by the assessment table)
CREATE TABLE practice_sessions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id         UUID REFERENCES organizations(id) ON DELETE CASCADE,
  technology     TEXT NOT NULL CHECK (length(technology) BETWEEN 1 AND 100),
  difficulty     TEXT NOT NULL DEFAULT 'intermediate'
                 CHECK (difficulty IN ('beginner', 'intermediate', 'advanced', 'expert')),
  question_count INT NOT NULL DEFAULT 5 CHECK (question_count BETWEEN 1 AND 20),
  status         TEXT NOT NULL DEFAULT 'active'
                 CHECK (status IN ('active', 'completed', 'abandoned')),
  ai_model       TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  completed_at   TIMESTAMPTZ
);
CREATE INDEX ON practice_sessions (user_id, created_at DESC);
CREATE INDEX ON practice_sessions (user_id, status);

CREATE TABLE practice_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID NOT NULL REFERENCES practice_sessions(id) ON DELETE CASCADE,
  position      INT NOT NULL DEFAULT 0,
  question_text TEXT NOT NULL,
  user_answer   TEXT,
  -- ai_feedback shape: {score:int, max_score:int, strengths:[], gaps:[], 
  --   suggested_answer:string, follow_up_resources:[], model:string}
  ai_feedback   JSONB,
  answered_at   TIMESTAMPTZ,
  feedback_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (session_id, position)
);
CREATE INDEX ON practice_items (session_id, position);
```

### Index Strategy Notes
- All course content queries filter on `org_id` + `status` — composite index covers both
- Course tree loaded via single CTE (no per-section queries)
- `batch_messages` uses cursor pagination, not offset — index on `(batch_id, created_at DESC, id)`
- `module_progress` indexed on `(user_id, course_id)` for progress aggregation query
- `enrollments` has index on `batch_id` — used by `enroll_batch_members_in_course` trigger

---

## 4. API CHANGES

### New Routes Summary

#### Course Routes (`/api/courses/*`)
```
GET    /api/courses                          Browse (filter: org, status, tag, difficulty, q)
POST   /api/courses                          [instructor+] Create course
GET    /api/courses/:courseID                Course detail + sections + modules (tree)
PATCH  /api/courses/:courseID                [instructor - own] Update metadata
POST   /api/courses/:courseID/publish        [instructor/admin] Draft → published
DELETE /api/courses/:courseID                [instructor/admin] Soft-archive
POST   /api/courses/:courseID/fork           [instructor] Fork course

POST   /api/courses/:courseID/sections       [instructor] Add section
PATCH  /api/sections/:sectionID              [instructor] Update section title/position
DELETE /api/sections/:sectionID              [instructor] Delete section + cascade modules
PUT    /api/courses/:courseID/sections/order [instructor] Reorder: {section_ids:[...]}

POST   /api/sections/:sectionID/modules      [instructor] Add module (type + content)
GET    /api/modules/:moduleID                [enrolled student | instructor] Get content + presigned URL
PATCH  /api/modules/:moduleID                [instructor] Update module
DELETE /api/modules/:moduleID                [instructor] Soft-delete
PUT    /api/sections/:sectionID/modules/order [instructor] Reorder: {module_ids:[...]}

POST   /api/courses/:courseID/enroll         [student] Direct enrollment (free courses)
GET    /api/enrollments/me                   [student] My enrolled courses + progress
PATCH  /api/modules/:moduleID/progress       [student] {status, last_position_seconds}
GET    /api/courses/:courseID/progress/me    [student] Full progress summary
GET    /api/courses/:courseID/progress       [instructor/mentor] All student progress

POST   /api/courses/generate-outline         [instructor] AI outline: {topic, level, module_count}
POST   /api/upload/course-asset              [instructor] Get presigned PUT URL for MinIO
```

#### Batch Enhancement Routes (extend `/api/batches/*`)
```
POST   /api/batches/:batchID/mentors         [admin/instructor] Add mentor
DELETE /api/batches/:batchID/mentors/:userID [admin/instructor] Remove mentor
GET    /api/batches/:batchID/mentors         [admin/instructor] List mentors

POST   /api/batches/:batchID/courses         [admin/instructor] Assign course (triggers bulk enroll)
DELETE /api/batches/:batchID/courses/:courseID [admin/instructor] Unassign
GET    /api/batches/:batchID/courses         [mentor+] List assigned courses

POST   /api/batches/:batchID/invite          [admin/instructor] Bulk invite {emails:[...], message?}
GET    /api/batches/:batchID/invitations     [admin/instructor] List invitations (with status)
DELETE /api/batches/:batchID/invitations/:invID [admin/instructor] Revoke invite
POST   /api/batches/:batchID/invitations/:invID/resend [admin/instructor] Resend email

POST   /api/invitations/accept               [public] Accept: {token}
POST   /api/invitations/decline              [public] Decline: {token}
GET    /api/invitations/preview/:token       [public] Preview invite details before accepting

GET    /api/batches/:batchID/progress        [mentor/instructor] All members, all courses, all assessments
```

#### Messaging Routes (`/api/batches/:batchID/messages/*`)
```
GET    /api/batches/:batchID/messages        Paginated (cursor: ?before=id, ?limit=20)
                                             Filters: ?type=question&unresolved=true&pinned=true
POST   /api/batches/:batchID/messages        {body, type, parent_id?}
PATCH  /api/messages/:msgID                  [sender - within 15min] {body}
DELETE /api/messages/:msgID                  [sender | mentor | admin] Soft-delete

POST   /api/messages/:msgID/reactions        [member] {reaction}
DELETE /api/messages/:msgID/reactions/:reaction [member] Remove own reaction
POST   /api/messages/:msgID/resolve          [mentor/instructor] Mark thread resolved
POST   /api/messages/:msgID/pin             [mentor/instructor] Pin message
POST   /api/messages/:msgID/promote-faq      [mentor/instructor] Promote to course FAQ

GET    /api/courses/:courseID/faqs           [enrolled student] Course FAQ list
POST   /api/courses/:courseID/faqs           [mentor/instructor] Create FAQ
PATCH  /api/faqs/:faqID                      [creator | mentor | instructor] Update
DELETE /api/faqs/:faqID                      [mentor/instructor] Delete
PUT    /api/courses/:courseID/faqs/order     [mentor/instructor] Reorder
```

#### Practice / AI Interview Prep Routes
```
GET    /api/practice/sessions                [student] My practice sessions
POST   /api/practice/sessions                [student] Create: {technology, difficulty, question_count}
GET    /api/practice/sessions/:sessionID     [student] Session + all items + feedback
PATCH  /api/practice/sessions/:sessionID     [student] {status: "completed"|"abandoned"}

POST   /api/practice/sessions/:sessionID/items/:position/answer
                                             [student] Submit answer: {answer_text}
                                             → triggers AI review inline, returns item with feedback

GET    /api/practice/technologies            [student] Suggested technology topics (static list)
```

### Consistent API Contract
All endpoints follow the existing `response.go` envelope:
```json
{ "data": {...}, "meta": {"page": 1, "limit": 20, "total": 150} }
{ "error": {"code": "NOT_FOUND", "message": "..."} }
```

Pagination: cursor-based for messages (`?before=<uuid>&limit=20`), offset for courses (`?page=1&limit=20`).

### Rate Limits
| Endpoint | Limit |
|---|---|
| `POST /api/courses/generate-outline` | 5 / hour per user |
| `POST /api/practice/sessions` | 10 / hour per user |
| `POST /api/practice/sessions/:id/items/:pos/answer` | 50 / hour per user |
| `POST /api/batches/:id/invite` | 3 / hour per instructor |

---

## 5. BACKEND CHANGES

### New Package: `internal/ai/`
```
internal/ai/
  provider.go      — LLMProvider interface + CompletionRequest/Response structs
  anthropic.go     — AnthropicProvider (calls Anthropic Messages API directly via http.Client)
  gemini.go        — GeminiProvider (OpenAI-compat endpoint: generativelanguage.googleapis.com/v1beta/openai/)
  noop.go          — NoOpProvider (returns ErrAIDisabled when LLM_PROVIDER=disabled)
  prompts.go       — all prompt templates as typed constants (no inline string literals in handlers)
  sanitize.go      — sanitize user input before LLM call (strip HTML, length cap)
```

LLMProvider interface:
```go
type LLMProvider interface {
  Available() bool
  Complete(ctx context.Context, req CompletionRequest) (CompletionResponse, error)
}

type CompletionRequest struct {
  SystemPrompt string
  UserPrompt   string
  MaxTokens    int
  Temperature  float32
  JSONMode     bool   // if true, provider is instructed to return valid JSON
}

type CompletionResponse struct {
  Content string
  Model   string
  Usage   struct{ InputTokens, OutputTokens int }
}
```

Provider selection at startup (in `config.go`):
```go
LLMProvider string  // "anthropic" | "gemini" | "disabled"
LLMAPIKey   string
LLMModel    string  // e.g. "claude-sonnet-4-6" or "gemini-2.0-flash"
LLMBaseURL  string  // for gemini compat: https://generativelanguage.googleapis.com/v1beta/openai/
```

### New Package: `internal/courses/`
```
internal/courses/
  models.go         — Course, Section, Module, Enrollment, ModuleProgress structs
  repo.go           — DB queries (GetCourseTree, CreateCourse, UpdateModule, etc.)
  service.go        — business logic: fork, publish, progress aggregation
  handler.go        — HTTP handlers (course CRUD, section/module CRUD)
  handler_student.go — enroll, get-module-content, update-progress
  handler_ai.go     — generate-outline handler (calls ai.LLMProvider)
  routes.go         — RegisterRoutes(r chi.Router, pool, cfg, storage, ai)
```

Key service methods:
- `GetCourseTree(ctx, courseID, orgID)` — single CTE query: course + sections + modules
- `GetModuleContent(ctx, moduleID, userID, orgID)` — verify enrollment + return content or presigned URL
- `ForkCourse(ctx, courseID, instructorID, orgID)` — copy sections + modules, set forked_from_id
- `AggregateCourseProgress(ctx, userID, courseID)` — COUNT completed / total modules WHERE not deleted

### Extend: `internal/storage/`
Add two methods to the existing `StorageClient` interface:
```go
PresignedPutURL(ctx context.Context, key string, mimeType string, maxBytes int64) (url string, err error)
PresignedGetURL(ctx context.Context, key string, ttl time.Duration) (url string, err error)
```
Implement for MinIO (using `minio-go` presigned methods). `NoopStorage` returns `ErrStorageUnavailable`.

### Extend: `internal/assessment/` (batch enhancements)
Add to `repo_batch.go`:
- `AddBatchMentor`, `RemoveBatchMentor`, `ListBatchMentors`
- `AssignBatchCourse`, `UnassignBatchCourse`, `ListBatchCourses`
- `CreateBatchInvitation`, `ListBatchInvitations`, `RevokeInvitation`, `AcceptInvitation`
- `GetBatchProgress` (joins batch_members + enrollments + module_progress + assessment_attempts)

Add to `handler.go` or new `handler_batch_ext.go` — new HTTP handlers for the above.

### New Package: `internal/messaging/`
```
internal/messaging/
  models.go    — BatchMessage, Reaction, CourseFAQ structs
  repo.go      — paginated message fetch, CRUD, reaction toggle, FAQ CRUD
  service.go   — soft-delete logic, edit window check (15 min), promote-to-FAQ
  handler.go   — HTTP handlers
  routes.go    — RegisterRoutes
```

### New Package: `internal/practice/`
```
internal/practice/
  models.go    — PracticeSession, PracticeItem structs
  repo.go      — create session, save answer, save feedback
  service.go   — generate questions (calls ai.Provider), review answer (calls ai.Provider)
  handler.go   — HTTP handlers
  routes.go    — RegisterRoutes
```

AI prompts (in `internal/ai/prompts.go`):
```go
const CourseOutlineSystemPrompt = `You are a curriculum designer...`
const InterviewQuestionSystemPrompt = `You are a senior technical interviewer...`
const InterviewReviewSystemPrompt = `You are a technical evaluator reviewing an interview answer...`
```

Review response schema (JSON mode):
```json
{
  "score": 7,
  "max_score": 10,
  "strengths": ["Clear explanation of mutex", "Correct locking semantics"],
  "gaps": ["Did not mention semaphore signaling", "No example given"],
  "suggested_answer": "A mutex is...",
  "follow_up_resources": ["OS concepts - mutex vs semaphore"]
}
```

### New Env Vars (`config.go` additions)
```
LLM_PROVIDER=anthropic          # "anthropic" | "gemini" | "disabled"
LLM_API_KEY=                    # fatal if LLM_PROVIDER != "disabled" and key is empty
LLM_MODEL=claude-sonnet-4-6     # model identifier
LLM_BASE_URL=                   # only for gemini/openai-compat (Gemini: https://generativelanguage.googleapis.com/v1beta/openai/)
LLM_TIMEOUT=30s                 # per-request timeout for AI calls
```

---

## 6. FRONTEND CHANGES

### New Pages

#### Student
| Route | File | Notes |
|---|---|---|
| `/courses` | `app/courses/page.tsx` | Server component; browse + filter by difficulty/tag; `<CourseGrid>` |
| `/courses/[slug]` | `app/courses/[slug]/page.tsx` | Course detail; enroll CTA; section/module tree preview |
| `/courses/[slug]/learn` | `app/courses/[slug]/learn/page.tsx` | Redirect to first incomplete module |
| `/courses/[slug]/learn/[moduleId]` | `app/courses/[slug]/learn/[moduleId]/page.tsx` | Content viewer + sidebar tree |
| `/practice` | `app/practice/page.tsx` | List past sessions; "New Session" CTA |
| `/practice/new` | `app/practice/new/page.tsx` | Topic + difficulty + count form |
| `/practice/[sessionId]` | `app/practice/[sessionId]/page.tsx` | Q&A flow + AI feedback panel |

#### Instructor
| Route | File | Notes |
|---|---|---|
| `/instructor/courses` | `app/instructor/courses/page.tsx` | My courses list (extends existing `/instructor/` pattern) |
| `/instructor/courses/new` | `app/instructor/courses/new/page.tsx` | Create form; AI outline button |
| `/instructor/courses/[id]` | `app/instructor/courses/[id]/page.tsx` | Course builder (section/module tree + content editor) |
| `/instructor/courses/[id]/analytics` | `app/instructor/courses/[id]/analytics/page.tsx` | Enrollment + completion + per-module drop-off |

#### Mentor
| Route | File | Notes |
|---|---|---|
| `/mentor/batches` | `app/mentor/batches/page.tsx` | My assigned batches |
| `/mentor/batches/[id]` | `app/mentor/batches/[id]/page.tsx` | Members list + progress table |
| `/mentor/batches/[id]/chat` | `app/mentor/batches/[id]/chat/page.tsx` | Message thread; resolve/pin controls |

### New Components

#### Course Viewer (`components/courses/`)
- `course-sidebar.tsx` — Section/module tree; completion checkmarks; current module highlight
- `module-video.tsx` — `"use client"` — HTML5 video player with presigned URL; progress reporting
- `module-pdf.tsx` — `"use client"` — PDF embed via `<iframe>` with presigned URL
- `module-notes.tsx` — Markdown renderer (server component; uses `prose-content` class)
- `module-assessment.tsx` — Redirect button to existing `/assessments/:id`

#### Course Builder (`components/instructor/`)
- `course-builder.tsx` — `"use client"` — drag-and-drop section/module tree (using browser-native drag, not an uninstalled lib)
- `module-editor.tsx` — `"use client"` — tabbed content editor: type selector + content form
- `ai-outline-panel.tsx` — `"use client"` — AI generation form; shows loading skeleton; outputs editable tree

#### Practice / Interview Prep (`components/practice/`)
- `practice-question.tsx` — Question display + textarea for answer
- `ai-feedback-card.tsx` — `ai-surface` class; score badge; strengths/gaps lists; suggested answer
- `session-progress.tsx` — Question N of M progress indicator

#### Batch Enhancements (`components/instructor/batches/`)
- `bulk-invite-form.tsx` — Textarea for email list (one per line or comma-separated); CSV upload button
- `invitation-list.tsx` — Table of pending/accepted/declined invitations with resend/revoke actions
- `batch-progress-table.tsx` — Per-member rows; columns: courses progress %, assessments passed, last active

#### Messaging (`components/messaging/`)
- `message-list.tsx` — `"use client"` — scroll container; cursor-paginated; renders `<MessageItem>`
- `message-item.tsx` — Message bubble; reply thread; reaction buttons; mentor controls (resolve/pin)
- `message-compose.tsx` — Textarea + type selector (question/resource); reply context display
- `faq-panel.tsx` — Course FAQ accordion; "Promote to FAQ" button on messages (mentor only)

### Route & Constants Updates

`lib/routes.ts` additions:
```ts
COURSES: '/courses',
COURSE(slug: string) { return `/courses/${slug}` },
COURSE_LEARN(slug: string, moduleId: string) { return `/courses/${slug}/learn/${moduleId}` },
INSTRUCTOR_COURSES: '/instructor/courses',
INSTRUCTOR_COURSE(id: string) { return `/instructor/courses/${id}` },
INSTRUCTOR_COURSE_ANALYTICS(id: string) { return `/instructor/courses/${id}/analytics` },
MENTOR_BATCH(id: string) { return `/mentor/batches/${id}` },
MENTOR_BATCH_CHAT(id: string) { return `/mentor/batches/${id}/chat` },
PRACTICE: '/practice',
PRACTICE_NEW: '/practice/new',
PRACTICE_SESSION(id: string) { return `/practice/${id}` },
```

`lib/features.ts` additions:
```ts
COURSES: 'courses',
PRACTICE_AI: 'practice_ai',
BATCH_CHAT: 'batch_chat',
```

`lib/nav.ts` additions (instructor group):
```ts
{ label: 'Courses', href: ROUTES.INSTRUCTOR_COURSES, icon: BookOpen },
```
(student group):
```ts
{ label: 'My Courses', href: ROUTES.COURSES, icon: GraduationCap },
{ label: 'Practice', href: ROUTES.PRACTICE, icon: Brain, feature: FEATURES.PRACTICE_AI, mode: 'badge' },
```

### Server Data Fetchers (`lib/server/`)
- `courses.ts` — `getCourses()`, `getCourseTree()`, `getEnrollments()`, `getCourseProgress()`
- `messaging.ts` — `getBatchMessages()`, `getCourseFAQs()`
- `practice.ts` — `getPracticeSessions()`, `getPracticeSession()`

### Server Actions (new)
- `lib/courses/actions.ts` — `createCourseAction`, `enrollAction`, `updateProgressAction`, `generateOutlineAction`
- `lib/batches/actions.ts` — `inviteMembersAction`, `acceptInvitationAction`, `assignCourseAction`
- `lib/messaging/actions.ts` — `postMessageAction`, `resolveMessageAction`, `promoteFAQAction`
- `lib/practice/actions.ts` — `createSessionAction`, `submitAnswerAction`

### Frontend Constraints (from `frontend/CLAUDE.md`)
- Max 300 lines/file — split large builders into sub-components
- Max 2 `useState` — course builder state goes into a custom hook `useCourseBuilder`
- No `useEffect` — video progress reported via `onTimeUpdate` event callback to server action
- Video player is `"use client"` — page remains server component
- All colors: semantic tokens only (`bg-primary`, `text-ai`, `bg-muted`)
- AI feedback panels use `.ai-surface` class (cyan-tinted, from `globals.css`)
- Message compose uses `nuqs` for `?type=question` URL state

---

## 7. SECURITY REVIEW

### IDOR Prevention
- `GET /api/modules/:id` — query must `JOIN course_modules ON course_id IN (SELECT id FROM courses WHERE org_id=$orgID)` AND `(is_free_preview = true OR EXISTS(SELECT 1 FROM enrollments WHERE user_id=$userID AND course_id=...))`
- `GET /api/practice/sessions/:id` — must verify `sessions.user_id = $jwtUserID`
- `GET /api/batches/:id/messages` — must verify user is `batch_members` OR mentor/instructor of that batch
- Every course/batch/message query includes `org_id = $jwtOrgID` in WHERE clause — no exception

### Invitation Token Security
- Token: `crypto.rand.Read(32 bytes)` → hex encode → hash with SHA-256 → store hash
- Same pattern as `password_reset_tokens` — reuse `internal/auth`'s `tokens.go` helpers
- Constant-time compare on accept/decline
- Expiry: 7 days; single-use (`accepted_at IS NULL AND declined_at IS NULL AND expires_at > now()`)
- Rate limit `POST /api/batches/:id/invite`: 3 calls/hour; max 500 emails per call
- Email validation: RFC 5321 pattern match; reject known disposable domains (configurable list)

### File Upload Security
- Presigned PUT URL: key format `orgs/{orgID}/courses/{courseID}/modules/{moduleID}/{uuid}.{ext}`
- MIME type: client declares MIME in `POST /api/upload/course-asset`; MinIO enforces `Content-Type` on the PUT
- After upload: fetch object metadata from MinIO to verify actual MIME matches declared (`HEAD /{key}`)
- Max sizes enforced by MinIO presigned policy: video ≤ 2 GB, PDF ≤ 50 MB, image ≤ 10 MB
- Presigned PUT URL TTL: 30 minutes (enough for large video upload)
- Keys are opaque UUIDs — no user-controlled path segments

### AI Prompt Injection
- `sanitize.go` in `internal/ai/`: strip HTML tags, replace newlines with spaces, cap at 200 chars for topic input
- System prompt enforces JSON output schema — malicious content in `user_answer` cannot escape the JSON structure
- Never echo raw LLM output to other users without sanitization (FAQ answers: strip HTML before storing)

### OWASP Top 10 Coverage
| Risk | Mitigation |
|---|---|
| A01 Broken Access Control | org_id scope on all queries; enrollment check on module access; batch membership check on messages |
| A02 Cryptographic Failures | Invitation tokens: random 32 bytes + SHA-256 hash (same as reset tokens); presigned URLs: time-limited |
| A03 Injection | pgx parameterized queries everywhere; no string concatenation in SQL |
| A04 Insecure Design | Soft-delete for messages (audit trail); enrollment triggers in DB (not app logic) |
| A07 Auth Failures | JWT middleware on all routes; role middleware on instructor/mentor endpoints |
| A08 Integrity Failures | `forked_from_id` is informational only; fork is fully independent |
| A10 SSRF | Module `storage_key` is a MinIO object key, not a user URL; presigned URLs generated server-side |

---

## 8. PERFORMANCE REVIEW

### Query Strategy

#### Course Tree (single CTE, not N queries)
```sql
WITH sections AS (
  SELECT * FROM course_sections WHERE course_id = $1 ORDER BY position
), modules AS (
  SELECT * FROM course_modules WHERE course_id = $1 AND deleted_at IS NULL ORDER BY section_id, position
)
SELECT
  c.*,
  COALESCE(json_agg(DISTINCT jsonb_build_object(
    'section', s,
    'modules', (SELECT json_agg(m ORDER BY m.position) FROM modules m WHERE m.section_id = s.id)
  ) ORDER BY s.position), '[]') AS sections
FROM courses c
JOIN sections s ON s.course_id = c.id
WHERE c.id = $1 AND c.org_id = $2
GROUP BY c.id;
```

#### Progress Aggregation (no stored redundancy)
```sql
SELECT
  COUNT(*) FILTER (WHERE mp.status = 'completed') AS completed,
  COUNT(*) AS total,
  ROUND(100.0 * COUNT(*) FILTER (WHERE mp.status = 'completed') / NULLIF(COUNT(*), 0), 1) AS pct
FROM course_modules cm
LEFT JOIN module_progress mp ON mp.module_id = cm.id AND mp.user_id = $userID
WHERE cm.course_id = $courseID AND cm.deleted_at IS NULL;
```
Cache result in Redis at key `prog:{userID}:{courseID}` with 30s TTL; invalidate on `module_progress` update.

#### Batch Progress Dashboard (one query, not N per member)
```sql
SELECT
  u.id, u.name, u.email,
  COUNT(DISTINCT e.course_id) AS courses_enrolled,
  COUNT(DISTINCT e.completed_at) AS courses_completed,
  COUNT(DISTINCT aa.id) FILTER (WHERE aa.passed = true) AS tests_passed
FROM batch_members bm
JOIN users u ON u.id = bm.user_id
LEFT JOIN enrollments e ON e.user_id = u.id AND e.batch_id = $batchID
LEFT JOIN assessment_attempts aa ON aa.user_id = u.id AND aa.status = 'evaluated'
WHERE bm.batch_id = $batchID
GROUP BY u.id, u.name, u.email;
```

### Caching Strategy
| Data | Cache Key | TTL | Invalidate On |
|---|---|---|---|
| Course tree | `course:{courseID}` | 5 min | Course/section/module update |
| Progress pct | `prog:{userID}:{courseID}` | 30 s | module_progress update |
| FAQ list | `faq:{courseID}` | 60 s | FAQ CRUD |
| Practice session | none (small, user-specific) | — | — |

### AI Call Optimization
- Course outline: check if a similar outline was generated in the last 24h (hash of `topic+level+count` as cache key); return cached if exists
- Interview review: check `practice_items.ai_feedback IS NOT NULL` before calling LLM — idempotent
- LLM calls use context with 30s timeout (`LLM_TIMEOUT` env var)

### Bundle Size
- Video player: native HTML5 `<video>` — no React player library
- PDF viewer: native `<iframe>` — no PDF.js (avoids 200 KB bundle addition)
- Course builder drag-and-drop: browser-native `draggable` API — no sortable library
- AI feedback rendering: plain Tailwind — no Markdown parser needed (AI returns structured JSON, not Markdown)

---

## 9. TEST PLAN

### Backend Unit Tests

#### `internal/courses/`
- `service_test.go`: `TestForkCourse` (sections + modules copied, forked_from_id set), `TestAggregateCourseProgress` (0%, 50%, 100% cases), `TestPublishCourse` (draft → published state machine)
- `repo_test.go`: `TestGetCourseTree` (N sections, M modules — assert single query via pgx trace), `TestModuleContentAccess` (enrolled vs not enrolled vs free_preview)

#### `internal/ai/`
- `anthropic_test.go`: mock HTTP round-tripper; test JSON mode response parsing; test timeout handling; test error propagation
- `gemini_test.go`: same pattern, OpenAI-compat envelope
- `noop_test.go`: `Available()` returns false; `Complete()` returns `ErrAIDisabled`
- `sanitize_test.go`: HTML stripping, length capping, newline collapsing

#### `internal/practice/`
- `service_test.go`: `TestGenerateQuestions` (mocked AI provider), `TestReviewAnswer` (mocked AI provider — verify JSON feedback stored correctly), `TestAITimeout` (provider times out → feedback remains NULL)

#### `internal/messaging/`
- `service_test.go`: `TestEditWindow` (edit within 15 min → OK; after → 403), `TestSoftDelete` (body replaced, not removed), `TestPromoteToFAQ` (creates course_faqs row)

#### `internal/assessment/` (batch extensions)
- `repo_batch_test.go`: `TestBulkInvite` (500 emails → 500 rows), `TestAcceptInvitation` (token hash match, expired token rejected, already-accepted rejected), `TestBatchCourseAssignment` (trigger enrolls existing members)

### Integration Tests (Docker + real Postgres)
- Course create → section → module → enroll student → get module content (presigned URL) → update progress → 100% complete → enrollment.completed_at set
- Batch create → assign course → add member → assert enrollment row created (trigger)
- Bulk invite → accept → assert org_members row created
- Post message → reply → react → resolve → promote to FAQ

### API Tests (httptest)
- `GET /api/modules/:id` with non-enrolled user → 403
- `GET /api/modules/:id` with free-preview module, non-enrolled → 200
- `PATCH /api/modules/:id` by student → 403 (role guard)
- `POST /api/courses/generate-outline` with rate limit exceeded → 429
- `POST /api/invitations/accept` with expired token → 400
- `POST /api/invitations/accept` with already-accepted token → 409

### Frontend Tests (Playwright E2E — if/when configured)
- Instructor creates course → adds section → adds video module → publishes
- Student enrolls → views module → reports progress → sees 100% on course card
- Mentor sends announcement in batch chat → student sees it
- Student creates practice session → answers question → receives AI feedback

---

## 10. REFACTORING PLAN

### Remove/Update Conflicts

| Item | Action |
|---|---|
| `docs/courses.md` | **Superseded by this plan.** Update file to say "See PLAN.md" — do not delete (history) |
| `user_stats` table (exists, no handlers) | **Wire up via DB triggers** in migrations 007 and 010; remove any stub comments |
| `assessment/repo_batch.go` | **Keep and extend** — do not move; add new batch mentor/invite/course methods here |
| `lib/routes.ts` | **Extend, never duplicate** — all new routes added to existing constant object |
| `lib/features.ts` | **Extend** — add `COURSES`, `PRACTICE_AI`, `BATCH_CHAT` |
| `lib/nav.ts` | **Extend** — add course and practice nav items to correct role groups |
| `lib/constants.ts` | **Extend** — add practice technology options, difficulty options (no hardcoded arrays in components) |

### No Code Moves
Existing `assessment/repo_batch.go` stays where it is — extending is safer than moving during active development. The batch package grows to encompass both assessment-batch and course-batch logic within the assessment package.

### Dead Code Audit (do before implementing)
- `app/demo/` and `app/demo/tour/` — assess if still needed or can be removed
- `user_stats` table columns with zero-update paths (pre-trigger) — will be activated by migration 007 triggers
- Any `// TODO` comments found during implementation — must be resolved, not left

---

## 11. IMPLEMENTATION ORDER

### Prerequisites (do first, unblocks everything)
```
[P0] Migration 007 (courses schema)
[P0] internal/ai/ package (LLMProvider interface + Anthropic + NoOp)
[P0] Config additions (LLM_PROVIDER, LLM_API_KEY, LLM_MODEL, LLM_BASE_URL, LLM_TIMEOUT)
[P0] storage.PresignedPutURL + PresignedGetURL (extend existing StorageClient)
```

### Phase 5 — Course System (parallel after P0)
```
[P5-A] internal/courses/ backend (models → repo → service → handler → routes)
[P5-B] Frontend: instructor course builder pages + components
[P5-C] Frontend: student course viewer pages + components

P5-A must complete before P5-B and P5-C can wire API calls.
P5-B and P5-C are parallel once P5-A is done.
```

### Phase 6 — Batch Enhancements (after P5 migration is live)
```
[P6] Migration 008 (batch_mentors, batch_courses, batch_invitations + triggers)
[P6-A] internal/assessment/ batch extension (mentors, courses, invitations)
[P6-B] Frontend: bulk-invite-form, invitation-list, batch-progress-table
[P6-C] Frontend: mentor batch pages (/mentor/batches/*)
```

### Phase 7 — Messaging (parallel with P6)
```
[P7] Migration 009 (batch_messages, reactions, course_faqs)
[P7-A] internal/messaging/ package
[P7-B] Frontend: message-list, message-item, message-compose, faq-panel
```

### Phase 8 — AI Features (after P0 AI package, parallel with P5+)
```
[P8] Migration 010 (ai_feedback column, interview_prep type, practice_sessions, practice_items)
[P8-A] internal/practice/ package (generate questions + review answer service)
[P8-A-ext] Gemini provider in internal/ai/ (if GEMINI needed)
[P8-B] Frontend: practice pages + components
[P8-C] handler_ai.go in courses package (generate-outline endpoint)
[P8-D] Frontend: ai-outline-panel in course builder
```

### Wall-clock estimate
With parallel subagents (P5-A + P7 + P8-A can run simultaneously):
- Backend migrations + AI package: ~30 min
- Course backend: ~60 min
- Batch backend + frontend: ~45 min
- Messaging backend + frontend: ~45 min
- Practice backend + frontend: ~45 min
- Course frontend: ~60 min
**Total sequential critical path: ~3h. With parallelism: ~1.5h.**

---

## 12. FINAL VALIDATION CHECKLIST

Before any subagent marks work complete:

### Code Quality
- [ ] Zero `// TODO`, `// FIXME`, `// HACK` in any new file
- [ ] No stub functions (`return nil, nil` with no logic)
- [ ] No hardcoded strings — all from constants or env vars
- [ ] All SQL uses parameterized queries (pgx `$1`, `$2` — never string format)
- [ ] `go build ./...` passes with zero errors
- [ ] `go vet ./...` passes with zero warnings
- [ ] `pnpm tsc --noEmit` passes with zero errors
- [ ] `pnpm lint:strict` passes with zero warnings

### Database
- [ ] All foreign keys have explicit `ON DELETE` behavior
- [ ] All `UNIQUE` constraints defined
- [ ] All high-traffic query columns have indexes
- [ ] Triggers verified: enrollment on batch_course assign, enrollment on member join
- [ ] `user_stats` updated by triggers (not application code)
- [ ] Down migrations exist for every up migration

### Security
- [ ] Every new endpoint has correct role middleware (`RequireOrgRole(...)`)
- [ ] Every query includes `org_id` filter from JWT claims
- [ ] Module content endpoint verifies enrollment OR free_preview
- [ ] Batch message endpoint verifies batch membership
- [ ] Invitation token comparison is constant-time
- [ ] MinIO object keys are opaque UUIDs (no user-controlled path components)
- [ ] AI input sanitized before LLM call

### Performance
- [ ] Course tree loaded in single CTE (no N+1)
- [ ] Progress aggregation cached in Redis (30s TTL)
- [ ] Batch progress dashboard uses single GROUP BY query
- [ ] AI calls are idempotent (check DB before calling LLM)
- [ ] Presigned URLs served on-demand, not stored in DB

### Frontend
- [ ] All new components: max 300 lines, max 2 useState
- [ ] No `useEffect` except one justified exception in video player (with eslint-disable + reason comment)
- [ ] No raw color classes — semantic tokens only
- [ ] No `dark:` prefix in any component file
- [ ] All new routes added to `lib/routes.ts`
- [ ] All new nav items use `feature` field for gating
- [ ] Mobile-first: every new page works at 375px width

### No Duplicate Code
- [ ] No second copy of `response.go` helpers
- [ ] No second copy of role middleware
- [ ] No second copy of token generation (reuse `auth`'s token helpers)
- [ ] No second copy of pagination logic
- [ ] No two components that render the same UI pattern

### Tenant Isolation
- [ ] No query returns data from a different `org_id` than the JWT's `org_id`
- [ ] No cross-batch data leakage in message or progress queries
- [ ] Practice sessions are user-private (no org sharing, just `user_id` scope)

---

## Appendix — Files to Create (Backend)

```
backend/db/migrations/001_schema.sql
backend/db/migrations/001_schema.down.sql
backend/internal/ai/provider.go
backend/internal/ai/anthropic.go
backend/internal/ai/gemini.go
backend/internal/ai/noop.go
backend/internal/ai/prompts.go
backend/internal/ai/sanitize.go
backend/internal/courses/models.go
backend/internal/courses/repo.go
backend/internal/courses/service.go
backend/internal/courses/handler.go
backend/internal/courses/handler_student.go
backend/internal/courses/handler_ai.go
backend/internal/courses/routes.go
backend/internal/messaging/models.go
backend/internal/messaging/repo.go
backend/internal/messaging/service.go
backend/internal/messaging/handler.go
backend/internal/messaging/routes.go
backend/internal/practice/models.go
backend/internal/practice/repo.go
backend/internal/practice/service.go
backend/internal/practice/handler.go
backend/internal/practice/routes.go
```

## Appendix — Files to Create (Frontend)

```
frontend/app/courses/page.tsx
frontend/app/courses/[slug]/page.tsx
frontend/app/courses/[slug]/learn/page.tsx
frontend/app/courses/[slug]/learn/[moduleId]/page.tsx
frontend/app/instructor/courses/page.tsx
frontend/app/instructor/courses/new/page.tsx
frontend/app/instructor/courses/[id]/page.tsx
frontend/app/instructor/courses/[id]/analytics/page.tsx
frontend/app/mentor/batches/page.tsx
frontend/app/mentor/batches/[id]/page.tsx
frontend/app/mentor/batches/[id]/chat/page.tsx
frontend/app/practice/page.tsx
frontend/app/practice/new/page.tsx
frontend/app/practice/[sessionId]/page.tsx
frontend/components/courses/course-sidebar.tsx
frontend/components/courses/module-video.tsx
frontend/components/courses/module-pdf.tsx
frontend/components/courses/module-notes.tsx
frontend/components/courses/module-assessment.tsx
frontend/components/courses/course-card.tsx
frontend/components/instructor/course-builder.tsx
frontend/components/instructor/module-editor.tsx
frontend/components/instructor/ai-outline-panel.tsx
frontend/components/instructor/batches/bulk-invite-form.tsx
frontend/components/instructor/batches/invitation-list.tsx
frontend/components/instructor/batches/batch-progress-table.tsx
frontend/components/messaging/message-list.tsx
frontend/components/messaging/message-item.tsx
frontend/components/messaging/message-compose.tsx
frontend/components/messaging/faq-panel.tsx
frontend/components/practice/practice-question.tsx
frontend/components/practice/ai-feedback-card.tsx
frontend/components/practice/session-progress.tsx
frontend/lib/server/courses.ts
frontend/lib/server/messaging.ts
frontend/lib/server/practice.ts
frontend/lib/courses/actions.ts
frontend/lib/batches/actions.ts
frontend/lib/messaging/actions.ts
frontend/lib/practice/actions.ts
```

## Appendix — Files to Modify

```
backend/internal/config/config.go          — add LLM env vars
backend/internal/api/router.go             — register courses, messaging, practice routes
backend/internal/assessment/repo_batch.go  — add mentors, courses, invitations methods
backend/internal/assessment/handler.go     — add new batch HTTP handlers
backend/internal/assessment/routes.go      — register new batch routes
backend/internal/storage/storage.go        — add PresignedPutURL, PresignedGetURL to interface
backend/internal/storage/minio.go          — implement presigned methods
backend/internal/storage/noop.go           — implement presigned stubs (return ErrUnavailable)
frontend/lib/routes.ts                     — add course, practice, mentor routes
frontend/lib/features.ts                   — add COURSES, PRACTICE_AI, BATCH_CHAT
frontend/lib/nav.ts                        — add course + practice nav items
frontend/lib/constants.ts                  — add practice tech options, course difficulty options
frontend/components/layout/sidebar.tsx     — ensure new nav items render
docs/courses.md                            — add header: "Superseded by PLAN.md"
```
