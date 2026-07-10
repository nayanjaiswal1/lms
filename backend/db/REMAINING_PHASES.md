# Schema Review — Remaining Work (Phases 2-4)

Phase 1 (Critical: #1 audit merge, #2 auth vocab, #39 token hashing) is DONE —
see migrations 002/003/004. This file tracks what's left. Check items off as
migrations land. Each phase = one migration file (or a few), matching the
`00N_description.sql` + `00N_description.down.sql` convention in
`backend/db/migrations/`. No `BEGIN;`/`COMMIT;` inside files — the runner
wraps each file in its own transaction (see `db/migrate.go`).

---

## Phase 2 — Structural (next migration: `005_*`)

- [ ] **#4 — Merge attempt models.** `assessment_attempts` vs `public_attempts`.
      Add nullable `user_id` + `attempt_guests(attempt_id, name, email citext, phone)`
      sub-table to `assessment_attempts`. Rename `public_attempts` →
      `public_attempts_archive`, backfill, update Go call sites in
      `internal/assessment` (repo + handlers) to write/read the unified table.
- [ ] **#5 — Fix lab task versioning.** `lab_tasks` (mutable rows) vs
      `lab_task_versions.tasks jsonb` (immutable snapshot) — completions can
      reference an edited/deleted task. Create `lab_task_version_items`,
      backfill from `lab_tasks` joined through version context, repoint
      `lab_task_completions.task_version_item_id`, drop `lab_tasks`. Update Go
      in lab session/completion code.
- [ ] **#27 — Email → citext everywhere.** `batch_invitations.email`,
      `batch_member_details.email`, `org_invites.email`,
      `calendar_event_invites.email`, `public_attempts.email` →
      `ALTER COLUMN email TYPE citext USING LOWER(email)`. Pure DB-side, no Go
      change needed (citext behaves like text over the wire).
- [ ] **#8 — Derive `percentage`/`passed` on attempts.** Drop
      `percentage`, add `pass_percentage_at_submit` snapshot column,
      make `passed` a generated column. Touches scoring code in
      `internal/assessment` (wherever attempts are scored/submitted) — must
      write `pass_percentage_at_submit` at submit time.

⚠️ #4, #5, #8 all touch `internal/assessment`, which has unrelated in-flight
feature work (batch/excel import). Coordinate or rebase before merging.

---

## Phase 3 — High-priority denormalization (next migration: `006_*`)

- [ ] **#7 — Drop `courses.is_free`.** Compute `price_cents = 0` at query time.
      Grep Go for `is_free` reads first.
- [ ] **#9 — Drop `organizations.active_member_count`.** Replace with
      `COUNT(*) FROM org_members WHERE org_id=? AND status='active'`
      (index `idx_org_members_org_status` already covers it). Check seat-limit
      enforcement code path specifically.
- [ ] **#10 — Trim `user_stats`.** Drop `xp_level_name`, `xp_level`,
      `tests_passed` (all derivable). Needs a rebuild job/query if the read
      model stays.
- [ ] **#11 — Drop `assessments.total_points`.** Compute
      `SUM(assessment_questions.points)` at read time.
- [ ] **#17 — Drop `batches.mentor_id`.** Single source of truth becomes
      `batch_mentors` + new `is_lead boolean` (unique per batch where true).
      Update Go wherever `batches.mentor_id` is read/written.
- [ ] **#20 — Replace unenforced arrays with join tables.**
      `whatnow_tasks.depends_on uuid[]` → `whatnow_task_dependencies`.
      `sheets.source_sheet_ids text[]` → `sheet_sources` (also fixes the
      text-instead-of-uuid type bug). Leave `batch_member_details.locked_fields`,
      `user_profiles.topics_interest`, `organizations.allowed_domains` alone —
      lower value, defer to Phase 4/backlog.
- [ ] **#33 — Refactor `org_auth_config` boolean explosion.** New
      `org_auth_providers(org_id, provider, is_enabled, is_required, config jsonb)`
      child table, drop `org_auth_config`. Also fixes plaintext
      `oidc_client_secret` — move secret into `config` via KMS reference, not
      raw text. Touches auth provider config code — check before dropping.
- [ ] **#35 — Consolidate `user_profiles` duplicate fields.** Drop
      `timeline`, `role_intent`, `learning_goal`, `industry`, `skill_level`,
      `weekly_time_commitment` into a `meta jsonb` archive column; standardize
      on `experience_level`/`career_goal`/`weekly_goal_hrs`. Grep onboarding
      flow in Go before touching — likely the widest blast radius in this repo.

---

## Phase 4 — Consistency + quick wins (next migration: `007_*`)

Quick wins (safe, mostly one-liners):
- [ ] **#23** — `CREATE UNIQUE INDEX ON jobs(idempotency_key) WHERE idempotency_key IS NOT NULL AND deleted_at IS NULL`
- [ ] **#24** — `UNIQUE(user_id, question_id) WHERE question_id IS NOT NULL` on `srs_cards`
- [ ] **#25** — rename `sheet_items.order_index` → `position`, add `UNIQUE(sheet_id, position) DEFERRABLE INITIALLY DEFERRED`
- [ ] **#31** — add `updated_at` to `enrollments`, `srs_cards`, `sheet_items`, `email_verifications`, `user_roles`, `batch_courses`, `batch_mentors`, `calendar_event_attendees`
- [ ] **#32** — `srs_cards.ease_factor` → `numeric(4,2)`
- [ ] **#37** — `highlight_explanations` unique key → `(text_hash, source_type, model_used)`

Needs care (logic or naming touches Go):
- [ ] **#16** — `assessments.status` collapse to `draft/published/archived`; compute scheduled/active/completed from `starts_at`/`ends_at` at read time. Update status checks in Go.
- [ ] **#18** — `mentor_ticket_assignments` drop duplicated `student_id`/`org_id`, join through `mentor_tickets` instead.
- [ ] **#19** — `course_modules.course_id` — drop redundant column, or add composite FK `(section_id, course_id)`. Pick the composite-FK route if Go queries filter by `course_modules.course_id` directly (avoids a join rewrite).
- [ ] **#21** — `user_problem_progress.topic_tag` → FK to `sheet_items.id` (needs surrogate key backfill).
- [ ] **#22** — polymorphic type/id pairs (`assessment_assignments`, etc.) — convert the 2-arity ones (assignee_type student/batch) to exclusive-arc nullable FKs; leave true polymorphism (audit_logs, xp_events) as-is with a reconciliation job.
- [ ] **#26** — composite FK `(assessment_id, org_id)` on attempts/scores tables to guard transitive `org_id`.
- [ ] **#28** — `refresh_tokens.ip` → `inet`, rename to `ip_address`.
- [ ] **#29** — standardize duration columns to `*_seconds`; the two unitless ones (`lab_definitions.max_duration`, `lab_org_config.max_session_duration`) are the actual bugs — rename with unit suffix at minimum even if full seconds-migration is deferred.
- [ ] **#30** — `SET NOT NULL` on the ~10 nullable `created_at` columns; drop `org_members.created_at` (redundant with `joined_at`).
- [ ] **#36** — naming pass: `courses.creator_id` → `created_by`, `audit_log`-style `tenant_id` → `org_id` (already gone with table), unquote `"position"` → `sort_order`. Do last since it touches the most call sites for the least functional value.

Deferred (documented, not migrating now):
- #3 (feedback/experience_reports merge — medium value, do opportunistically)
- #6 (invite table triplication — bigger lift, own migration when touched)
- #12, #13, #14, #15, #34, #38, #40 — low impact or already-acceptable denormalization per the review; revisit only if a bug surfaces in that area

---

## Rules for whoever (human or agent) picks these up

1. One phase = one migration number, with a matching `.down.sql`.
2. No `BEGIN;`/`COMMIT;` in the `.sql` file — runner-managed transaction.
3. Grep Go call sites for every dropped/renamed column before dropping it.
4. `internal/assessment` has unrelated in-flight work — check `git diff` there before editing.
5. No Go toolchain in this environment — migrations are reviewed by hand, not compiled. Flag this in the completion report.
