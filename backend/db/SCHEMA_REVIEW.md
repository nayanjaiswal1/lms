# MindForge Database Schema Review

**Principal Database Architect Analysis**  
**Scope:** `backend/db/migrations/001_baseline.sql` (70 tables, PostgreSQL)  
**Date:** 2026-07-10

---

## Executive Summary

- **Total Issues:** 40 (3 Critical, 10 High, 16 Medium, 11 Low)
- **Overall Quality Score:** 5.5 / 10
- **Status:** Production code with significant schema debt

### Key Findings
Solid single-table hygiene and indexing discipline, but plagued by concept-level duplication (two audit tables, two attempt models, three authorization systems), unguarded derived columns, and systemic naming/type drift.

---

## A. Duplicate Models (Schema Fragmentation)

### Issue #1: Two Audit Tables — `audit_log` vs `audit_logs`
- **Severity:** 🔴 CRITICAL
- **Location:** `audit_log(id, tenant_id, actor_id, entity_type, entity_id text, diff)` vs `audit_logs(id, org_id, actor_user_id, target_type, target_id uuid, before_state, after_state, ip_address)`
- **Problem:**
  - Two tables record identical concept with divergent naming (`tenant_id` vs `org_id`, `actor_id` vs `actor_user_id`, `entity_*` vs `target_*`)
  - Divergent payload shapes (`diff jsonb` vs `before_state`/`after_state`)
  - Type drift: `entity_id text` vs `target_id uuid`
  - Audit trails split and unjoinable; every consumer must query both
  - Compliance audits are incomplete by default
- **Recommendation:** Keep `audit_logs` (richer: before/after, IP), migrate `audit_log` rows, drop `audit_log`
- **Migration:**
  ```sql
  -- Archive old audit_log data into audit_logs if needed
  INSERT INTO audit_logs (org_id, actor_user_id, action, target_type, target_id, before_state, after_state, created_at)
  SELECT tenant_id, actor_id, action, entity_type, entity_id::uuid, NULL, diff, created_at FROM audit_log;
  
  DROP TABLE audit_log;
  ```
- **Impact:** High; affects all audit/compliance queries

---

### Issue #2: Three Parallel Authorization Systems — Guaranteed Privilege Drift
- **Severity:** 🔴 CRITICAL
- **Location:** 
  - System 1: `roles(id, tenant_id, name)` + `permissions(id, code)` + `role_permissions(role_id, permission_id)` + `user_roles(user_id, role_id, tenant_id)` (full RBAC)
  - System 2: `org_members.role text enum` (hardcoded: 'owner','admin','instructor','mentor','learner')
  - System 3: `nav_permissions.role text enum` (hardcoded: 'student','instructor','mentor','admin' — **different vocab!**)
  - System 4: `users.platform_role text` (only 'super_admin','user')
- **Problem:**
  - Same question "what can user X do in org Y" answered four different ways
  - `nav_permissions.role` enum uses 'student' but `org_members.role` uses 'learner' — **active bug**
  - No enforcement between systems — guaranteed drift
  - Role additions require schema migration in System 1, enum migration in System 2, hardcoded changes in System 3
  - RBAC tables may be entirely unused (dead code)
- **Recommendation:** 
  - **Option A (if RBAC unused):** Drop `roles`, `permissions`, `user_roles`, `role_permissions`; key everything on `org_members.role`; align nav_permissions enum to `org_members.role` vocab
  - **Option B (if RBAC is used):** Make `org_members(role_id uuid REFERENCES roles(id))` the single source; derive nav_permissions from `role_permissions`
  - **Mandatory:** Standardize role enum everywhere ('admin', 'instructor', 'mentor', 'learner', 'owner')
- **Migration:**
  ```sql
  -- Standardize vocabulary
  ALTER TABLE org_members 
    ALTER COLUMN role TYPE text;
  UPDATE org_members SET role = 'learner' WHERE role = 'student';
  ALTER TABLE org_members 
    ADD CONSTRAINT org_members_role_check CHECK (role = ANY(ARRAY['owner','admin','instructor','mentor','learner']));
  
  -- Align nav_permissions
  UPDATE nav_permissions SET role = 'learner' WHERE role = 'student';
  ALTER TABLE nav_permissions 
    ADD CONSTRAINT nav_permissions_role_check CHECK (role = ANY(ARRAY['admin','instructor','mentor','learner']));
  ```
- **Impact:** Critical; active privilege escalation vector

---

### Issue #3: Feedback Duplication — `feedback` vs `experience_reports`
- **Severity:** 🟠 HIGH
- **Location:** 
  - `feedback(id, org_id, subject_type, subject_id, user_id, rating int, comment, skipped_at, created_at, updated_at)` where `subject_type ∈ ('course','assessment','lab','mentor')`
  - `experience_reports(id, org_id, subject_type, subject_id, user_id, experience text, description, skipped_at, created_at, updated_at)` where `subject_type = 'assessment'` (CHECK constraint)
- **Problem:**
  - Structurally identical "user reacts to subject" model
  - `experience_reports` is a strict subset of `feedback` (only assessments)
  - Both have identical `*_rated_or_skipped` constraints
  - Responses to assessments split between two tables; reporting requires UNION
- **Recommendation:** Merge into `feedback` with optional columns:
  ```sql
  ALTER TABLE feedback ADD COLUMN experience text;
  ALTER TABLE feedback ADD CONSTRAINT feedback_rated_or_skipped_v2 
    CHECK (rating IS NOT NULL OR experience IS NOT NULL OR skipped_at IS NOT NULL);
  
  INSERT INTO feedback (org_id, subject_type, subject_id, user_id, experience, description, skipped_at, created_at, updated_at)
  SELECT org_id, subject_type, subject_id, user_id, experience, description, skipped_at, created_at, updated_at 
  FROM experience_reports;
  
  DROP TABLE experience_reports;
  ```
- **Impact:** Medium; query complexity, incomplete reporting

---

### Issue #4: Two Attempt Models — `assessment_attempts` vs `public_attempts`
- **Severity:** 🟠 HIGH
- **Location:**
  - Authenticated: `assessment_attempts(id, assessment_id, user_id, org_id, score numeric(9,2), max_score numeric(9,2), percentage numeric(5,2), passed boolean, snapshot jsonb, …)` + `attempt_answers(attempt_id, answer jsonb, …)`
  - Anonymous: `public_attempts(id, assessment_id, name, email, session_token, answers jsonb, score numeric, max_score numeric, percentage numeric, passed boolean, …)`
- **Problem:**
  - Same domain event (attempt a test) modeled two ways
  - Denormalized `answers` in one, normalized in the other
  - Scoring columns have **different numeric types** (`numeric(9,2)` vs bare `numeric`)
  - Analytics queries must UNION and shape-match forever
  - Status enums don't align (`assessment_attempts.status ∈ {created,in_progress,submitted,…}` vs `public_attempts.status ∈ {in_progress,submitted}`)
- **Recommendation:** One `assessment_attempts` table with nullable `user_id` + `guest_identity` sub-table:
  ```sql
  CREATE TABLE attempt_guests (
    attempt_id uuid PRIMARY KEY REFERENCES assessment_attempts(id) ON DELETE CASCADE,
    name text NOT NULL,
    email citext NOT NULL,
    phone text
  );
  
  ALTER TABLE public_attempts 
    RENAME TO public_attempts_archive;  -- preserve historical data
  
  -- Backfill logic: INSERT INTO assessment_attempts (… guest columns …)
  --                SELECT FROM public_attempts_archive
  ```
- **Impact:** High; duplicates test-taking logic, scoring divergence risk

---

### Issue #5: Lab Task Duplication — `lab_tasks` vs `lab_task_versions.tasks jsonb`
- **Severity:** 🟠 HIGH
- **Location:**
  - `lab_tasks(id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)`
  - `lab_task_versions(id, lab_id, version, tasks jsonb NOT NULL, published_by, published_at)` where `tasks` is a blob of all tasks
  - `lab_task_completions(id, session_id, task_id, …)` — FK to `lab_tasks(id)`
- **Problem:**
  - Task definitions stored in two places: relational rows AND published jsonb blob
  - Sessions run against `task_version_id` (immutable snapshot) but completions FK to `lab_tasks(id)` (mutable)
  - A task completion can reference a task definition that has been edited/deleted since the session started — version mismatch bug
  - No way to tell what definition a user actually saw
- **Recommendation:** Version relationally, drop `lab_tasks` relational table:
  ```sql
  CREATE TABLE lab_task_version_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_version_id uuid NOT NULL REFERENCES lab_task_versions(id) ON DELETE CASCADE,
    position integer NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    verification_script text NOT NULL,
    hint_context text,
    explanation_context text,
    points integer DEFAULT 10 NOT NULL,
    is_optional boolean DEFAULT false NOT NULL,
    is_stateful boolean DEFAULT false NOT NULL,
    UNIQUE(task_version_id, position)
  );
  
  ALTER TABLE lab_task_completions 
    ADD COLUMN task_version_item_id uuid REFERENCES lab_task_version_items(id),
    DROP CONSTRAINT lab_task_completions_task_id_fkey;
  -- Backfill: join task_id to lab_tasks, find its version context
  
  DROP TABLE lab_tasks;
  ```
- **Impact:** High; versioning integrity is broken today

---

### Issue #6: Invite Table Triplication — `batch_invitations` vs `org_invites` vs `calendar_event_invites`
- **Severity:** 🟡 MEDIUM
- **Location:**
  - `batch_invitations(id, batch_id, org_id, email, invited_by, token_hash, expires_at, invited_at, accepted_at, declined_at, resent_at)`
  - `org_invites(id, org_id, email, role, invited_by_user_id, token_hash, expires_at, accepted_at, accepted_by_user_id, revoked_at, revoke_reason, created_at, updated_at)`
  - `calendar_event_invites(id, event_id, email, role, token_hash, expires_at, accepted_at, created_at)`
- **Problem:**
  - Same lifecycle (invite → accept/decline/revoke) modeled three times
  - Inconsistent columns: `invited_by` vs `invited_by_user_id`; `invited_at` (nullable) vs `created_at`; only `batch_invitations` has `resent_at`
  - Token expiry, acceptance tracking all duplicated
  - Any auth bug (e.g., token rotation) must be fixed three times
  - Different `role` semantics per table
- **Recommendation:** Single `invitations` table:
  ```sql
  CREATE TABLE invitations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    target_type text NOT NULL CHECK (target_type IN ('batch','org','event')),
    target_id uuid NOT NULL,
    email citext NOT NULL,
    role text,
    invited_by uuid REFERENCES users(id) ON DELETE SET NULL,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamp with time zone NOT NULL,
    accepted_at timestamp with time zone,
    accepted_by_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    declined_at timestamp with time zone,
    revoked_at timestamp with time zone,
    revoke_reason text,
    resent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE(target_type, target_id, email) WHERE accepted_at IS NULL AND declined_at IS NULL AND revoked_at IS NULL
  );
  ```
- **Impact:** Medium; maintenance multiplier, token auth bugs

---

## B. Derived & Redundant Fields (Maintainability Debt)

### Issue #7: `courses.is_free` Redundant with `price_cents`
- **Severity:** 🟠 HIGH
- **Location:** `courses(price_cents integer DEFAULT 0, is_free boolean DEFAULT true)`
- **Problem:**
  - `is_free ⇔ price_cents = 0` — textbook redundancy
  - No CHECK constraint tying them: `is_free=true, price_cents=5000` is storable
  - Every update must touch both columns or they diverge
  - Queries must check both or get wrong results
- **Recommendation:** Drop `is_free`; compute in queries or use a generated column:
  ```sql
  -- Option 1: Immediate cleanup (query-time)
  ALTER TABLE courses DROP COLUMN is_free;
  -- Queries: SELECT *, (price_cents = 0) AS is_free FROM courses
  
  -- Option 2: Preserve column as computed (if app requires it)
  ALTER TABLE courses ADD COLUMN is_free boolean GENERATED ALWAYS AS (price_cents = 0) STORED;
  ```
- **Impact:** Low; data quality issue

---

### Issue #8: Stored `percentage` & `passed` on Attempts (Derivable)
- **Severity:** 🟠 HIGH
- **Location:** `assessment_attempts(score numeric(9,2), max_score numeric(9,2), percentage numeric(5,2), passed boolean)` + `public_attempts(score, max_score, percentage, passed)`
- **Problem:**
  - `percentage = score / max_score * 100` — pure math, not state
  - `passed = percentage >= assessments.pass_percentage` — policy-derived, not state
  - Storing both creates divergence: re-evaluation updates `score` but not `percentage` → stale reports
  - Historical `passed` flag may be wrong if pass_percentage is updated globally
- **Recommendation:** Compute at read time; if you need historical freeze, snapshot the rule used:
  ```sql
  ALTER TABLE assessment_attempts 
    DROP COLUMN percentage,
    ADD COLUMN pass_percentage_at_submit numeric(5,2),  -- snapshot
    ADD COLUMN passed boolean GENERATED ALWAYS AS (
      CASE WHEN max_score > 0 THEN (score/max_score*100) >= COALESCE(pass_percentage_at_submit, 40) ELSE NULL END
    ) STORED;
  ```
- **Impact:** Medium; report corruption risk on re-evaluation

---

### Issue #9: `organizations.active_member_count` Denormalized Counter
- **Severity:** 🟠 HIGH
- **Location:** `organizations.active_member_count integer DEFAULT 0 NOT NULL`
- **Problem:**
  - Counter over `org_members WHERE status='active'`
  - No trigger visible in schema (or missing) — counter drifts
  - Used for `seat_limit` enforcement → divergence = billing bug
  - Hard to reconcile without a job
- **Recommendation:** Drop; rely on indexes:
  ```sql
  ALTER TABLE organizations DROP COLUMN active_member_count;
  
  -- Queries: SELECT COUNT(*) FROM org_members WHERE org_id=? AND status='active'
  -- Index exists: idx_org_members_org_status (org_id, status)
  
  -- Optional reconciliation job:
  UPDATE organizations SET active_member_count = (
    SELECT COUNT(*) FROM org_members WHERE org_id=organizations.id AND status='active'
  ) WHERE true;
  ```
- **Impact:** Medium; seat limit enforcement bug vector

---

### Issue #10: `user_stats` Table of Derivables
- **Severity:** 🟡 MEDIUM
- **Location:** `user_stats(courses_enrolled, courses_completed, tests_attempted, tests_passed, problems_solved, certificates_earned, current_streak_days, learning_hours, roadmaps_completed, total_xp, xp_level, xp_level_name, updated_at)`
- **Problem:**
  - Every column is an aggregate of another table
  - Contains *second-order* derivations: `xp_level = f(total_xp)`, `xp_level_name = levels[xp_level]`
  - `xp_level_name text` is a display string stored per-user → goes stale when level names change
  - No mechanism to rebuild atomically
- **Recommendation:** If read-model is necessary, rebuild it idempotently; at minimum:
  ```sql
  ALTER TABLE user_stats 
    DROP COLUMN xp_level_name,
    DROP COLUMN tests_passed,  -- already derivable from assessment_attempts
    DROP COLUMN xp_level;      -- derivable from total_xp
  
  -- Add job to rebuild user_stats daily/weekly
  -- SELECT user_id, 
  --        COUNT(DISTINCT course_id) courses_enrolled,
  --        COUNT(DISTINCT CASE WHEN completed_at IS NOT NULL THEN course_id END) courses_completed,
  --        ...
  ```
- **Impact:** Medium; performance read-model but inconsistency risk

---

### Issue #11: `assessments.total_points` Redundant with Question Summing
- **Severity:** 🟡 MEDIUM
- **Location:** `assessments.total_points numeric(9,2)` vs `SUM(assessment_questions.points)`
- **Problem:**
  - `total_points = SUM(assessment_questions.points WHERE assessment_id=?)`
  - Editing a question's points → `total_points` becomes stale
  - No trigger visible in schema
- **Recommendation:** Make computed or remove:
  ```sql
  -- Option 1: Drop and compute
  ALTER TABLE assessments DROP COLUMN total_points;
  
  -- Queries: SELECT SUM(points) FROM assessment_questions WHERE assessment_id=?
  
  -- Option 2: Or add auto-update trigger (complex; not recommended)
  ```
- **Impact:** Low; scoring inconsistency risk

---

### Issue #12: `coding_submissions` — Test Results Stored Twice
- **Severity:** 🟢 LOW
- **Location:** `coding_submissions(tests_total, tests_passed, result jsonb)`
- **Problem:**
  - Test counts extracted from `result` and also stored as scalars
  - Two sources of truth; scalars may not match `result`
- **Recommendation:** Keep scalars (queryable), treat `result` as the authoritative raw log:
  ```sql
  -- Add CHECK to enforce consistency
  ALTER TABLE coding_submissions 
    ADD CONSTRAINT coding_submissions_tests_check 
      CHECK ((result::jsonb->>'total_tests')::int = tests_total OR result::jsonb->>'total_tests' IS NULL);
  ```
- **Impact:** Low; defensible denormalization for query speed

---

### Issue #13: `interview_evaluations` — Composite Score Derivable
- **Severity:** 🟢 LOW
- **Location:** `interview_evaluations(score_technical_accuracy, score_completeness, score_communication, score_clarity, score_structure, score_confidence, score_seniority_alignment, composite_score, injection_detected, injection_score)`
- **Problem:**
  - `composite_score` is a weighted average of seven `score_*` columns
  - `injection_detected = injection_score >= THRESHOLD` (boolean should be boolean)
- **Recommendation:** Compute; refactor score explosion into jsonb if rubric changes:
  ```sql
  ALTER TABLE interview_evaluations 
    ADD COLUMN scores jsonb,  -- {technical_accuracy: 4.5, completeness: 3.8, ...}
    DROP COLUMN score_technical_accuracy, score_completeness, ...
    ADD COLUMN composite_score numeric(5,2) GENERATED ALWAYS AS (/* weighted avg from scores */) STORED,
    ADD COLUMN injection_detected boolean GENERATED ALWAYS AS (injection_score >= 5) STORED;
  ```
- **Impact:** Low; extensibility issue

---

### Issue #14: `users.email_verified` vs `email_verifications.verified_at`
- **Severity:** 🟢 LOW
- **Location:** `users.email_verified boolean` + `email_verifications.verified_at timestamp`
- **Problem:**
  - Verification state stored twice
  - No mechanism keeping them consistent
  - Defensible denormalization (hot auth path), but undocumented
- **Recommendation:** Document that `email_verifications` is ephemeral token storage; `users.email_verified` is the canonical state. Add a check:
  ```sql
  -- Optional: Enforce consistency
  CREATE CONSTRAINT TRIGGER email_verified_check AFTER DELETE ON email_verifications
    FOR EACH ROW EXECUTE FUNCTION check_email_verified_state();
  ```
- **Impact:** Low; acceptable with discipline

---

### Issue #15: `batch_member_details.status` vs `batch_invitations` Timestamps
- **Severity:** 🟡 MEDIUM
- **Location:** `batch_member_details.status IN ('pending','invited','resent','enrolled_existing','failed','skipped')` vs `batch_invitations(invited_at, accepted_at, declined_at, resent_at)`
- **Problem:**
  - Invitation lifecycle represented as enum in one table, timestamps in another
  - For the same (batch_id, email), `batch_member_details.status='invited'` may disagree with `batch_invitations.invited_at NOT NULL`
  - Partial failure scenarios → state divergence
- **Recommendation:** Make `batch_invitations` the sole source of truth:
  ```sql
  ALTER TABLE batch_member_details 
    DROP COLUMN status,
    ADD CONSTRAINT batch_member_details_batch_email_fkey 
      FOREIGN KEY (batch_id, email) REFERENCES batch_invitations(batch_id, email);
  
  -- Queries derive status: CASE WHEN accepted_at IS NOT NULL THEN 'enrolled' WHEN declined_at IS NOT NULL THEN 'declined' ...
  ```
- **Impact:** Medium; data consistency

---

## C. Relationships & Foreign Keys (Integrity)

### Issue #16: `assessments.status` Mixes Lifecycle with Time-Derived States
- **Severity:** 🟡 MEDIUM
- **Location:** `assessments.status IN ('draft','published','scheduled','active','completed','archived')` with `starts_at`, `ends_at`, `published_at`
- **Problem:**
  - `scheduled`, `active`, `completed` are pure functions of `now()` vs `starts_at`/`ends_at`
  - Storing them requires a cron to flip rows; status is wrong between cron runs
  - `published` duplicates `published_at IS NOT NULL`
- **Recommendation:** Reduce to `draft | published | archived`; compute temporal phase:
  ```sql
  ALTER TABLE assessments 
    ADD CONSTRAINT assessments_status_check_v2 CHECK (status IN ('draft','published','archived'));
  
  -- Queries: CASE WHEN status != 'published' THEN 'draft'
  --               WHEN now() < starts_at THEN 'scheduled'
  --               WHEN now() BETWEEN starts_at AND ends_at THEN 'active'
  --               ELSE 'completed'
  --          END
  ```
- **Impact:** Medium; time-based state bugs

---

### Issue #17: `batches.mentor_id` vs `batch_mentors` Join Table
- **Severity:** 🟠 HIGH
- **Location:** `batches.mentor_id uuid FK` + `batch_mentors(batch_id, user_id) PK` (N:M)
- **Problem:**
  - Batch↔Mentor relationship modeled both 1:N (column) and N:M (join table)
  - A mentor can exist in one but not the other → "who mentors this batch" has two answers
  - Foreign key references are split: some queries use the column, some the table
- **Recommendation:** Drop `batches.mentor_id`; if a "lead" mentor is needed, use:
  ```sql
  ALTER TABLE batches DROP COLUMN mentor_id;
  
  ALTER TABLE batch_mentors 
    ADD COLUMN is_lead boolean DEFAULT false,
    ADD CONSTRAINT batch_mentors_lead_uniq UNIQUE (batch_id) 
      WHERE is_lead = true;
  ```
- **Impact:** High; relationship integrity bug

---

### Issue #18: `mentor_tickets` Dual Assignment Tracking
- **Severity:** 🟡 MEDIUM
- **Location:** `mentor_tickets(assigned_mentor_id, assigned_by, assigned_at)` + `mentor_ticket_assignments(ticket_id, mentor_id, student_id, assigned_at)`
- **Problem:**
  - Assignment stored twice
  - `mentor_ticket_assignments.student_id` duplicates `mentor_tickets.student_id` (transitive)
  - `mentor_ticket_assignments.org_id` also duplicated
  - Update anomalies if ticket's student is corrected
- **Recommendation:** Treat `mentor_ticket_assignments` as audit/history only:
  ```sql
  ALTER TABLE mentor_ticket_assignments 
    DROP COLUMN student_id,
    DROP COLUMN org_id,
    ADD CONSTRAINT mentor_ticket_assignments_ticket_fkey 
      FOREIGN KEY (ticket_id) REFERENCES mentor_tickets(id);
  
  -- Queries join through ticket to get student
  ```
- **Impact:** Medium; data anomalies

---

### Issue #19: Transitive `course_id` on Course Content (3NF)
- **Severity:** 🟡 MEDIUM
- **Location:** `course_modules(course_id, section_id)` where `section_id → course_id` already; `module_progress(course_id, module_id)`
- **Problem:**
  - `section_id` determines `course_id` via FK
  - Nothing prevents a module where its `course_id` disagrees with its section's course
  - 3NF violation (transitive dependency)
- **Recommendation:** Either drop redundant column or enforce composite FK:
  ```sql
  -- Option 1: Drop redundant column
  ALTER TABLE course_modules DROP COLUMN course_id;
  
  -- Option 2: Safe with composite FK
  ALTER TABLE course_sections ADD UNIQUE (id, course_id);
  ALTER TABLE course_modules ADD CONSTRAINT course_modules_section_course_fkey 
    FOREIGN KEY (section_id, course_id) REFERENCES course_sections(id, course_id);
  ```
- **Impact:** Medium; query safety (composite FK preferred for perf)

---

### Issue #20: Array-Based Relationships Without Integrity (SYSTEMIC)
- **Severity:** 🟠 HIGH
- **Location:** 
  - `whatnow_tasks.depends_on uuid[]` (array of task IDs)
  - `sheets.source_sheet_ids text[]` (array of sheet IDs, stored as TEXT not UUID)
  - `batch_member_details.locked_fields text[]`
  - `user_profiles.topics_interest text[]`
  - `organizations.allowed_domains text[]`
- **Problem:**
  - No FK enforcement → orphaned IDs accumulate
  - No cascade on delete
  - No index without GIN (slow joins)
  - `source_sheet_ids` stores UUIDs as text (type confusion)
  - Hard to partition/query
- **Recommendation:** Replace with join tables:
  ```sql
  -- whatnow_tasks
  CREATE TABLE whatnow_task_dependencies (
    task_id uuid NOT NULL REFERENCES whatnow_tasks(id) ON DELETE CASCADE,
    depends_on_task_id uuid NOT NULL REFERENCES whatnow_tasks(id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, depends_on_task_id),
    CONSTRAINT no_self_deps CHECK (task_id != depends_on_task_id)
  );
  ALTER TABLE whatnow_tasks DROP COLUMN depends_on;
  
  -- sheets
  CREATE TABLE sheet_sources (
    sheet_id uuid NOT NULL REFERENCES sheets(id) ON DELETE CASCADE,
    source_sheet_id uuid NOT NULL REFERENCES sheets(id) ON DELETE CASCADE,
    PRIMARY KEY (sheet_id, source_sheet_id)
  );
  ALTER TABLE sheets DROP COLUMN source_sheet_ids;
  ```
- **Impact:** High; data quality, cascading deletes

---

### Issue #21: String-Coupled Relationship — `user_problem_progress.topic_tag`
- **Severity:** 🟡 MEDIUM
- **Location:** `user_problem_progress(user_id, topic_tag text, status)` PK vs `sheet_items(topic_tag text NOT NULL)` (no UNIQUE, no FK)
- **Problem:**
  - Progress keyed by free-text tag, not a PK
  - Tag is not unique in `sheet_items`; same tag can appear many times
  - No FK from `user_problem_progress` to `sheet_items`
  - Renaming a tag orphans all progress silently
- **Recommendation:** Use sheet_item IDs:
  ```sql
  -- Add surrogate key to sheet_items if missing
  ALTER TABLE user_problem_progress 
    DROP CONSTRAINT user_problem_progress_pkey,
    ADD COLUMN sheet_item_id uuid,
    ADD CONSTRAINT user_problem_progress_sheet_item_fkey 
      FOREIGN KEY (sheet_item_id) REFERENCES sheet_items(id) ON DELETE CASCADE,
    ADD PRIMARY KEY (user_id, sheet_item_id);
  
  -- Backfill: JOIN topic_tag to sheet_items
  UPDATE user_problem_progress SET sheet_item_id = (
    SELECT id FROM sheet_items WHERE topic_tag = user_problem_progress.topic_tag LIMIT 1
  ) WHERE sheet_item_id IS NULL;
  ```
- **Impact:** Medium; data loss risk on tag edits

---

### Issue #22: Polymorphic References Without Enforcement (SYSTEMIC)
- **Severity:** 🟡 MEDIUM
- **Location:** 7+ tables use polymorphic pairs:
  - `assessment_assignments(assignee_type ∈ {'student','batch'}, assignee_id)`
  - `assessments(parent_type ∈ {'standalone','course','module','roadmap','batch','bootcamp'}, parent_id)`
  - `calendar_events(entity_type, entity_id)`
  - `feedback(subject_type)`, `experience_reports(subject_type)`
  - `highlights(source_type)`, `xp_events(reference_type)`
  - `audit_logs(target_type)`
  - `batch_courses(batch_id)` — FK missing
- **Problem:**
  - Zero referential integrity per FK — orphaned rows accumulate silently
  - `highlights.source_orphaned boolean` flag exists **because** the FK doesn't
  - `assessments.parent_type` allows 'roadmap','bootcamp' but no such tables exist (dead enum values)
  - Queries must check `type + id` in app logic (not at DB)
  - Deleting a parent doesn't cascade
- **Recommendation:** 
  - For low-arity polymorphism (2-3 types), use exclusive-arc nullable FKs:
    ```sql
    ALTER TABLE assessment_assignments 
      ADD COLUMN student_id uuid REFERENCES users(id) ON DELETE CASCADE,
      ADD COLUMN batch_id uuid REFERENCES batches(id) ON DELETE CASCADE,
      DROP COLUMN assignee_type, assignee_id,
      ADD CONSTRAINT assignment_type_check CHECK (num_nonnulls(student_id, batch_id) = 1);
    ```
  - For true polymorphism (logs), keep type+id but add reconciliation jobs
- **Impact:** Medium; data quality, cascade bugs

---

### Issue #23: `jobs.idempotency_key` Not Unique
- **Severity:** 🟡 MEDIUM
- **Location:** `jobs.idempotency_key text` (no UNIQUE constraint in dump)
- **Problem:**
  - An idempotency key that isn't unique doesn't idempotify
  - Duplicate enqueues are not prevented at DB layer
- **Recommendation:**
  ```sql
  CREATE UNIQUE INDEX ON jobs(idempotency_key) 
    WHERE idempotency_key IS NOT NULL AND deleted_at IS NULL;
  
  ALTER TABLE jobs 
    ADD CONSTRAINT jobs_idempotency_key_unique UNIQUE (idempotency_key) 
      WHERE idempotency_key IS NOT NULL AND deleted_at IS NULL;
  ```
- **Impact:** Low; enqueue safety

---

### Issue #24: `srs_cards` Missing Dedup Constraint
- **Severity:** 🟡 MEDIUM
- **Location:** `srs_cards(user_id, question_id, front, back)` — PK on `id` only
- **Problem:**
  - Nothing prevents duplicate cards for same user+question
  - Other user-content tables enforce `UNIQUE(user_id, ...)` — inconsistent rigor
  - `question_id` is nullable, so partial uniqueness needed
- **Recommendation:**
  ```sql
  ALTER TABLE srs_cards 
    ADD CONSTRAINT srs_cards_user_question_unique UNIQUE (user_id, question_id) 
      WHERE question_id IS NOT NULL;
  ```
- **Impact:** Low; data duplication

---

### Issue #25: `sheet_items` — Missing Ordering Constraint
- **Severity:** 🟢 LOW
- **Location:** `sheet_items(sheet_id, order_index integer)` — only PK(id)
- **Problem:**
  - Sibling ordering tables enforce `UNIQUE(parent, position)` (`lab_tasks`, `course_modules`, `course_sections`, `practice_items`)
  - `sheet_items` doesn't — duplicate `order_index` per sheet is storable
  - Uses `order_index` while standards use `position` (naming drift)
- **Recommendation:**
  ```sql
  ALTER TABLE sheet_items 
    RENAME COLUMN order_index TO position;
  
  ALTER TABLE sheet_items 
    ADD CONSTRAINT sheet_items_sheet_position_unique UNIQUE (sheet_id, position) 
      DEFERRABLE INITIALLY DEFERRED;
  ```
- **Impact:** Low; ordering bugs

---

### Issue #26: Transitive `org_id` Denormalization on Attempts/Scores
- **Severity:** 🟢 LOW
- **Location:** `assessment_attempts.org_id`, `interview_skill_scores.org_id`, `mentor_chat_messages.org_id`, etc.
- **Problem:**
  - `org_id` is derivable via parent FK (assessment_id → assessments.org_id)
  - Unguarded — row can carry the wrong org
  - Justified for RLS/partitioning, but requires enforcement
- **Recommendation:** Keep for performance/partitioning, but enforce via composite FK:
  ```sql
  -- Make assessments uniquely keyed on (id, org_id)
  ALTER TABLE assessments 
    ADD UNIQUE (id, org_id);
  
  -- Repoint child FKs
  ALTER TABLE assessment_attempts 
    ADD CONSTRAINT assessment_attempts_composite_fkey 
      FOREIGN KEY (assessment_id, org_id) REFERENCES assessments(id, org_id);
  ```
- **Impact:** Low; data integrity guarantee

---

## D. Data Types & Nullability

### Issue #27: Email Type Inconsistency (Systemic)
- **Severity:** 🟡 MEDIUM
- **Location:** 
  - Correct: `users.email citext UNIQUE`
  - Wrong (text): `batch_invitations.email`, `batch_member_details.email`, `org_invites.email`, `calendar_event_invites.email`, `public_attempts.email`, `social_accounts.email` (partially)
- **Problem:**
  - Case-sensitive `text` means `John@X.com` invite never matches `john@x.com` user
  - `UNIQUE(batch_id, email text)` allows case duplicates ('test@x.com', 'TEST@x.com')
  - Invite-to-user joins silently fail on case mismatch
- **Recommendation:**
  ```sql
  -- Convert all email columns to citext
  ALTER TABLE batch_invitations ALTER COLUMN email TYPE citext USING LOWER(email);
  ALTER TABLE batch_member_details ALTER COLUMN email TYPE citext USING LOWER(email);
  ALTER TABLE org_invites ALTER COLUMN email TYPE citext USING LOWER(email);
  ALTER TABLE calendar_event_invites ALTER COLUMN email TYPE citext USING LOWER(email);
  ALTER TABLE public_attempts ALTER COLUMN email TYPE citext USING LOWER(email);
  ```
- **Impact:** Medium; authentication/matching bugs

---

### Issue #28: IP & ID Type Drift
- **Severity:** 🟢 LOW
- **Location:** 
  - IP: `refresh_tokens.ip text` vs `audit_logs.ip_address inet`
  - ID: `audit_log.entity_id text` vs `audit_logs.target_id uuid`
- **Problem:**
  - Same semantics, different types and names
  - Prevents joins and shared validation
- **Recommendation:**
  ```sql
  ALTER TABLE refresh_tokens ALTER COLUMN ip TYPE inet USING ip::inet;
  RENAME COLUMN ip TO ip_address;
  ```
- **Impact:** Low; query consistency

---

### Issue #29: Duration Unit Chaos (SYSTEMIC)
- **Severity:** 🟡 MEDIUM
- **Location:** 
  - `*_seconds`: `assessment_attempts.duration_seconds`, `lab_sessions.paused_seconds`, `lab_definitions.max_duration seconds?`, `attempt_answers.time_spent_seconds`, `module_progress.last_position_seconds`, `lab_usage_events.container_seconds`
  - `*_sec`: `public_attempts.duration_sec`, `lab_sessions.expires_at` (derived)
  - `*_ms`: `job_runs.duration_ms`, `jobs.timeout_ms`, `coding_submissions.runtime_ms`
  - `*_min`: `whatnow_tasks.duration_min`, `lab_definitions.max_duration (NO UNIT!)`
  - `*_minutes`: `assessments.duration_minutes`, `lab_org_config.max_session_duration (NO UNIT!)`
  - `*_hours`: `courses.estimated_hours`, `user_profiles.weekly_goal_hrs`
- **Problem:**
  - Nine spellings, two with **no unit** (`max_duration`, `max_session_duration`)
  - Guaranteed source of ×60 bugs
  - Mixing units in single table
- **Recommendation:**
  ```sql
  -- Standardize everything to seconds
  ALTER TABLE assessments 
    ADD COLUMN duration_seconds integer,
    RENAME COLUMN duration_minutes TO duration_minutes_old;
  UPDATE assessments SET duration_seconds = duration_minutes_old * 60;
  ALTER TABLE assessments DROP COLUMN duration_minutes_old;
  
  ALTER TABLE lab_definitions 
    RENAME COLUMN max_duration TO max_duration_minutes,
    ALTER COLUMN max_duration_minutes SET DATA TYPE integer;
  
  ALTER TABLE lab_org_config 
    RENAME COLUMN max_session_duration TO max_session_duration_minutes;
  
  -- Rename for consistency: estimated_hours, weekly_goal_hrs stay as-is (interval type cleaner)
  ```
- **Impact:** Medium; calculations, migrations

---

### Issue #30: `created_at` Nullability Chaos (SYSTEMIC)
- **Severity:** 🟡 MEDIUM
- **Location:** `created_at` is nullable (default now()) on ~10 tables but `NOT NULL` on ~50 others:
  - Nullable: `users`, `courses`, `organizations`, `enrollments`, `org_members.created_at`, `batch_courses.assigned_at`, `course_faqs`, `course_sections`, `social_accounts`, `refresh_tokens`, `practice_sessions`
  - Consistent `NOT NULL`: most others
- **Problem:**
  - Same audit column, randomly nullable
  - Queries need `COALESCE`; sorting semantics differ
  - `org_members` has **both** `joined_at NOT NULL` and `created_at NULL` (redundant pair)
- **Recommendation:**
  ```sql
  -- Set NOT NULL across the board
  ALTER TABLE users ALTER COLUMN created_at SET NOT NULL;
  ALTER TABLE courses ALTER COLUMN created_at SET NOT NULL;
  -- ... (repeating pattern)
  
  -- Remove duplicate created_at where joined_at exists
  ALTER TABLE org_members DROP COLUMN created_at;
  ```
- **Impact:** Low; consistency, sorting

---

### Issue #31: Missing `updated_at` on Mutable Tables
- **Severity:** 🟢 LOW
- **Location:** Mutable tables without `updated_at`: `enrollments`, `srs_cards`, `lab_tasks`, `sheet_items`, `email_verifications`, `user_roles`, `batch_courses`, `batch_mentors`, `calendar_event_attendees`
- **Problem:**
  - Mutable rows without modification timestamps — undebuggable, unsyncable
  - Can't audit when something changed
- **Recommendation:**
  ```sql
  ALTER TABLE srs_cards ADD COLUMN updated_at timestamp with time zone DEFAULT now() NOT NULL;
  -- Add trigger: UPDATE org_members SET updated_at = now() ON UPDATE
  ```
- **Impact:** Low; debuggability

---

### Issue #32: `srs_cards.ease_factor` Stored as `double precision`
- **Severity:** 🟢 LOW
- **Location:** `srs_cards.ease_factor double precision DEFAULT 2.5`
- **Problem:**
  - Only float in an otherwise `numeric(n,m)` schema
  - SM-2 algorithm tolerates floats, but drifts with rounding
  - Inconsistent with schema discipline
- **Recommendation:**
  ```sql
  ALTER TABLE srs_cards ALTER COLUMN ease_factor TYPE numeric(4,2);
  ```
- **Impact:** Low; consistency

---

## E. Boolean Explosion & Enum Misuse

### Issue #33: `org_auth_config` — Boolean Explosion
- **Severity:** 🟠 HIGH
- **Location:** `org_auth_config(allow_password, allow_google, allow_github, allow_microsoft, allow_magic_link, require_sso, sso_enabled, sso_provider text, oidc_client_secret text)`
- **Problem:**
  - 6 provider booleans + sso state (2 columns, `sso_enabled` vs `require_sso`) = overlapping representations
  - Contradictory combinations storable: `sso_enabled=true, sso_provider=NULL`
  - Adding a new provider = DDL migration (not DML)
  - `oidc_client_secret` stored in plaintext (no encryption at rest, no KMS reference)
  - DDL migration required for each new auth method (GitHub, Apple, etc.)
- **Recommendation:** Use a child table:
  ```sql
  CREATE TABLE org_auth_providers (
    org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    provider text NOT NULL CHECK (provider IN ('password','google','github','microsoft','magic_link','oidc','saml')),
    is_enabled boolean DEFAULT false NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    config jsonb DEFAULT '{}' NOT NULL,  -- {client_id, client_secret_kms_key, ...}
    PRIMARY KEY (org_id, provider)
  );
  
  DROP TABLE org_auth_config;
  ```
- **Impact:** High; extensibility, security

---

### Issue #34: `user_profiles.show_*` Privacy Booleans + Assessment Feature Flags
- **Severity:** 🟢 LOW
- **Location:** `user_profiles(show_skills, show_achievements, show_certificates, show_activity)`; `assessments(shuffle_questions, shuffle_options, allow_backtrack, show_results, mock_mode)`
- **Problem:**
  - Growing families of feature booleans; each new toggle is a migration
  - Tolerable now but not scalable
- **Recommendation:** Acceptable for now; fold into `jsonb` if > 5 flags:
  ```sql
  ALTER TABLE assessments 
    ADD COLUMN settings jsonb DEFAULT '{"shuffle_questions":false,"shuffle_options":false,"allow_backtrack":true,"show_results":true,"mock_mode":false}';
  ```
- **Impact:** Low; extensibility

---

## F. God-Object / Field Sprawl

### Issue #35: `user_profiles` — Duplicate Fields (Onboarding Debt)
- **Severity:** 🟠 HIGH
- **Location:** `user_profiles(timeline, experience_level, role_intent, learning_goal, job_title, weekly_time_commitment, skill_level, industry, career_goal, current_role, years_of_experience, weekly_goal_hrs, preferred_learning_style, topics_interest, …)`
- **Problem:**
  - At least four duplicate answer-pairs (one question asked multiple ways):
    1. `experience_level text` vs `skill_level text` vs `years_of_experience smallint` (all express expertise)
    2. `role_intent text` vs `job_title text` vs `"current_role" text` (career intent)
    3. `learning_goal text` vs `career_goal text` (goals)
    4. `weekly_time_commitment text` vs `weekly_goal_hrs smallint` (availability)
  - This is onboarding-question archaeology: each survey iteration added columns instead of replacing
  - Columns lack CHECK constraints (free text, no validation)
  - `topics_interest text[]` overlaps `user_skills.skill_name`
  - No `updated_at` to track survey iterations
- **Recommendation:** Consolidate; move dead fields to `meta jsonb`:
  ```sql
  ALTER TABLE user_profiles 
    DROP COLUMN timeline, role_intent, learning_goal, industry,  -- archive to meta
    DROP COLUMN skill_level,  -- use user_skills instead
    DROP COLUMN weekly_time_commitment,  -- standardize on weekly_goal_hrs
    ADD COLUMN meta jsonb DEFAULT '{}' NOT NULL,  -- archive survey history
    ADD CONSTRAINT weekly_goal_hrs_check CHECK (weekly_goal_hrs BETWEEN 1 AND 100);
  
  -- Create lookup table for enum values
  CREATE TABLE career_goals (goal text PRIMARY KEY);
  ALTER TABLE user_profiles 
    ADD CONSTRAINT user_profiles_career_goal_fkey 
      FOREIGN KEY (career_goal) REFERENCES career_goals(goal) ON DELETE SET NULL;
  ```
- **Impact:** High; data quality, query complexity

---

### Issue #36: Naming Inconsistencies (SYSTEMIC)
- **Severity:** 🟡 MEDIUM
- **Location:** Multiple consistency breaks:
  - `courses.creator_id` vs `created_by` everywhere else
  - `tenant_id` vs `org_id`
  - `actor_id` vs `actor_user_id`
  - `invited_by` vs `invited_by_user_id`
  - `"position"` (quoted) vs `order_index` vs `item_order`/`section_order` vs `plan_position`
  - Table `audit_log` (singular) vs `audit_logs` (plural)
  - `purchased_at`/`invited_at`/`joined_at` as creation timestamps (inconsistent naming)
- **Problem:**
  - Every inconsistency is a place where generated code fails, ORM conventions break, and humans forget
  - Quoting `"position"` forever is annoying
  - Singular vs plural table names create cognitive load
- **Recommendation:** Convention doc + multi-step migration:
  ```sql
  -- Step 1: Rename all *_id creator/author columns to created_by
  ALTER TABLE courses RENAME COLUMN creator_id TO created_by;
  
  -- Step 2: Standardize on org_id
  ALTER TABLE audit_log RENAME COLUMN tenant_id TO org_id;
  
  -- Step 3: Unquote position (requires dropping constraints)
  ALTER TABLE course_modules RENAME COLUMN "position" TO sort_order;
  
  -- Step 4: Audit timestamp naming (optional, lower priority)
  ```
- **Impact:** Medium; maintenance multiplier

---

### Issue #37: `highlight_explanations` Cache Key Too Narrow
- **Severity:** 🟢 LOW
- **Location:** `highlight_explanations(text_hash UNIQUE, source_type, model_used, …)`
- **Problem:**
  - `UNIQUE(text_hash)` alone: same highlighted text from different source types (or newer model) can't get its own explanation
  - `model_used` becomes misleading after model upgrades
- **Recommendation:**
  ```sql
  DROP INDEX highlight_explanations_text_hash_key;
  ALTER TABLE highlight_explanations 
    ADD UNIQUE (text_hash, source_type, model_used);
  ```
- **Impact:** Low; cache invalidation

---

### Issue #38: Event/Log Tables Not Partition-Ready
- **Severity:** 🟢 LOW
- **Location:** `attempt_events`, `xp_events`, `lab_usage_events`, `audit_logs`, `idempotency_keys`, `job_runs` — unbounded append-only with bigint identity
- **Problem:**
  - At scale (10M+ rows), no partitioning strategy
  - `idempotency_keys` stores full `response_body text` forever with only `created_at` index — grows fastest
  - No retention/TTL cleanup mechanism
- **Recommendation:** Add partitioning & retention:
  ```sql
  -- Enable time-based partitioning
  CREATE TABLE idempotency_keys_archive (LIKE idempotency_keys);
  
  -- Cron job: DELETE FROM idempotency_keys WHERE created_at < now() - INTERVAL '30 days';
  ```
- **Impact:** Low (today), Medium (at scale)

---

### Issue #39: Token Security Inconsistency (CRITICAL)
- **Severity:** 🔴 CRITICAL
- **Location:**
  - Hashed (correct): `refresh_tokens.token_hash`, `password_reset_tokens.token_hash`, `email_verifications.token_hash`, all invite tables
  - Plaintext (wrong): `oauth_exchanges.token text UNIQUE`, `assessment_attempts.active_session_token text`, `public_attempts.session_token text`
- **Problem:**
  - Three tables store bearable tokens in plaintext
  - DB breach replays them immediately
  - `refresh_tokens.token_hash` and `password_reset_tokens.token_hash` lack UNIQUE constraints (lookup by hash without uniqueness is unsafe)
- **Recommendation:**
  ```sql
  -- Hash existing plaintext tokens (one-way, irreversible)
  -- Archive old oauth_exchanges, start hashing
  ALTER TABLE oauth_exchanges 
    RENAME COLUMN token TO token_plaintext;
  ALTER TABLE oauth_exchanges 
    ADD COLUMN token_hash text UNIQUE NOT NULL DEFAULT '',
    DROP COLUMN token_plaintext;
  
  -- Add uniqueness to hashed columns
  ALTER TABLE refresh_tokens 
    ADD CONSTRAINT refresh_tokens_token_hash_unique UNIQUE (token_hash);
  ALTER TABLE password_reset_tokens 
    ADD CONSTRAINT password_reset_tokens_token_hash_unique UNIQUE (token_hash);
  
  -- Migrate session tokens
  CREATE TABLE assessment_session_tokens (
    token_hash text PRIMARY KEY,
    attempt_id uuid NOT NULL REFERENCES assessment_attempts(id) ON DELETE CASCADE,
    issued_at timestamp with time zone DEFAULT now() NOT NULL
  );
  ```
- **Impact:** Critical; data leak on DB breach

---

### Issue #40: `enrollments.batch_id` Creates Triangle Ambiguity
- **Severity:** 🟡 MEDIUM
- **Location:** `enrollments(user_id, course_id, batch_id NULL)` + `batch_members(batch_id, user_id)` + `batch_courses(batch_id, course_id)`
- **Problem:**
  - Batch membership representable two ways: `batch_members` (direct) or via enrollment
  - Nothing forces an `enrollments.batch_id` user to also be in `batch_members`, nor the course to be in `batch_courses`
  - Three tables can tell three different stories about the same batch+user+course relationship
  - Queries must check all three or miss users
- **Recommendation:** Treat `batch_members` + `batch_courses` as source of truth; remove `batch_id` from enrollments:
  ```sql
  ALTER TABLE enrollments DROP COLUMN batch_id;
  
  -- Queries derive batch context:
  -- SELECT e.*, bm.batch_id FROM enrollments e
  -- LEFT JOIN batch_members bm ON bm.user_id = e.user_id
  -- WHERE e.course_id IN (SELECT course_id FROM batch_courses WHERE batch_id = bm.batch_id)
  ```
- **Impact:** Medium; query correctness

---

## Summary & Recommendations

### Critical Issues (Fix First)
1. **#1: Audit table merge** — compliance, data traceability
2. **#2: Unify auth systems** — active privilege bug (student/learner mismatch)
3. **#39: Token hashing** — security breach vector
4. **#4: Merge attempts** — scoring divergence risk
5. **#5: Lab task versioning** — version integrity broken

### High-Priority Issues (Next Sprint)
- **#7:** Drop `courses.is_free`
- **#8:** Compute attempt `percentage` and `passed`
- **#9:** Drop `organizations.active_member_count`
- **#10:** Rebuild `user_stats` idempotently
- **#17:** Drop `batches.mentor_id`
- **#20:** Replace arrays with join tables
- **#27:** Convert all `email text` → `citext`
- **#33:** Refactor `org_auth_config` to child table

### Quick Wins (One-Line Migrations)
- Add `UNIQUE INDEX` on `jobs(idempotency_key)` (#23)
- Add `UNIQUE(sheet_id, position)` on `sheet_items` (#25)
- `SET NOT NULL` on nullable `created_at` columns (#30)
- Rename duration columns with units (#29)
- Add missing `updated_at` to mutable tables (#31)

### Overall Schema Health
- **Today:** 5.5 / 10 (good hygiene, significant debt)
- **After critical fixes:** 7.0 / 10 (acceptable production state)
- **After high-priority:** 8.5+ / 10 (clean, scalable)

### Implementation Roadmap
1. **Phase 1 (Weeks 1-2):** Merge audits (#1), unify auth (#2), hash tokens (#39)
2. **Phase 2 (Weeks 3-4):** Merge attempts (#4), fix lab versioning (#5)
3. **Phase 3 (Weeks 5-6):** Denormalization cleanup (#7-10, #17, #20)
4. **Phase 4 (Weeks 7-8):** Type/naming consistency (#27-29, #33, #36)

---

**Report Generated:** 2026-07-10  
**Reviewed By:** Principal Database Architect  
**Reviewed For:** MindForge Production Deployment
