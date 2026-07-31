# Schema Review — Status & Remaining Work

Re-audited 2026-07-21 directly against the then-current `001_baseline.sql`
(114 tables). `SCHEMA_REVIEW.md` (the original 40-issue audit this file was
extracted from) has been deleted — its actionable items are folded in below
with verified current status; anything below marked "fixed" or "open" was
checked against the live baseline at that time, not assumed.

**Re-squashed 2026-07-30:** migrations `002`–`027` (accumulated since the
2026-07-21 audit) have been folded into `001_baseline.sql`, which now covers
156 tables. **Next migration is still `002_*`.** None of migrations `002`–`027`
touched the specific columns/tables the line items below call out (they were
additive: cohort groups, final-test certificates, practice/interview-prep
merge, sheet revision settings, lesson notes + MCP connections, self-courses,
highlight notes, interview experiences, GitLab integration, user permission
overrides, AI connector config) — so the statuses below are still accurate,
but they have **not been re-verified** against the new baseline. Re-check
before relying on any specific item.

No `BEGIN;`/`COMMIT;` inside migration files — the runner wraps each file in
its own transaction (see `db/migrate.go`). Each phase = one migration number,
with a matching `.down.sql`.

---

## Fixed (verified in baseline, no action needed)

- **#1 — Audit merge.** `audit_log` is gone; only `audit_logs` remains.
- **#2 — Auth vocab.** `org_members`, `nav_permissions`, and `org_invites` role
  CHECK constraints all use `'learner'` consistently now (the `student`/`learner`
  mismatch is resolved). Note: `roles`/`permissions`/`role_permissions`/`user_roles`
  (the RBAC tables) still exist alongside `org_members.role` — the vocab was
  aligned, the four-systems consolidation was never done and isn't tracked here
  unless a real bug surfaces from it.
- **#23 — `jobs.idempotency_key` uniqueness.** `jobs_idempotency_key_key UNIQUE` exists.
- **#27 — Email → citext.** `batch_invitations`, `batch_member_details`,
  `calendar_event_invites`, `org_invites`, `public_attempts` all use `citext` now.
  Leftover: `social_accounts.email` is still plain `text` — low value, pick up
  opportunistically.
- **#39 (partial) — Token hashing.** `oauth_exchanges` now stores `token_hash`
  with a `UNIQUE` constraint; `refresh_tokens` and `password_reset_tokens` both
  gained `UNIQUE(token_hash)`. **Not fixed:** `assessment_attempts.active_session_token`
  and `public_attempts.session_token` are still stored **plaintext** — see Phase 4.

## Partially fixed / resolved differently than recommended

- **#5 — Lab task versioning.** `lab_task_version_items` was added as recommended,
  but `lab_tasks` was never dropped — both tables coexist. Check what
  `lab_task_completions` actually FKs to in `internal/labs` before finishing the
  drop; may already be safe to remove `lab_tasks`, may still be load-bearing.
- **#9 — `organizations.active_member_count`.** Column was *not* dropped, but a
  trigger (`update_active_member_count()` on `org_members` insert/update/delete)
  now keeps it in sync — the drift risk the review flagged is addressed, just
  not via the recommended denormalization removal. Leave as-is; revisit only if
  the trigger itself becomes a bottleneck.
- **#36 — Naming inconsistencies.** `created_by` is now the standard across
  nearly every table (assessments, calendar_events, lab_definitions, roadmaps,
  sheets, wiki, etc.). `courses.creator_id` is the one remaining holdout.

---

## Phase 2 — Structural (next migration: `002_*`)

- [ ] **#4 — Merge attempt models.** `assessment_attempts` vs `public_attempts`
      still fully duplicated: different column types (`numeric(9,2)` vs bare
      `numeric`), different status enums, separate `score`/`percentage`/`passed`.
      Add nullable `user_id` + `attempt_guests(attempt_id, name, email citext, phone)`
      sub-table to `assessment_attempts`. Rename `public_attempts` →
      `public_attempts_archive`, backfill, update Go call sites in
      `internal/assessment` (repo + handlers).
- [ ] **#6 — Invite table triplication.** `batch_invitations`, `org_invites`,
      `calendar_event_invites` are all still separate, still with inconsistent
      columns (`invited_by` vs `invited_by_user_id`; only `batch_invitations`
      has `resent_at`). Consolidate into one `invitations(target_type, target_id, ...)`
      table per the original design in the (now-deleted) schema review.

⚠️ #4 touches `internal/assessment`, which has unrelated in-flight feature
work. Check `git diff`/current branch state there before editing.

---

## Phase 3 — High-priority denormalization (next migration: `003_*`)

- [ ] **#7 — Drop `courses.is_free`.** Still present (`DEFAULT true NOT NULL`),
      still redundant with `price_cents`. Grep Go for `is_free` reads first.
- [ ] **#8 — Derive `percentage`/`passed` on attempts.** Still stored plain
      columns on `assessment_attempts`. Drop `percentage`, add
      `pass_percentage_at_submit` snapshot column, make `passed` generated.
      Touches scoring code in `internal/assessment`.
- [ ] **#10 — Trim `user_stats`.** `xp_level_name`, `xp_level`, `tests_passed`
      all still present and still derivable. Needs a rebuild job/query if the
      read model stays.
- [ ] **#11 — Drop `assessments.total_points`.** Still a stored column
      (`DEFAULT 0`), still divergeable from `SUM(assessment_questions.points)`.
- [ ] **#17 — Drop `batches.mentor_id`.** Still present with its own FK + index
      (`idx_batches_mentor`), still duplicated by `batch_mentors`. Single source
      of truth becomes `batch_mentors` + `is_lead boolean`.
- [ ] **#20 — Replace unenforced arrays with join tables.**
      `whatnow_tasks.depends_on uuid[]` and `sheets.source_sheet_ids text[]`
      both still raw arrays, no FK enforcement. Leave `batch_member_details.locked_fields`,
      `user_profiles.topics_interest`, `organizations.allowed_domains` alone —
      still lower value, still deferred.
- [ ] **#33 — Refactor `org_auth_config` boolean explosion.** Still one row per
      org with a provider boolean per column; no `org_auth_providers` child
      table exists. Also still no encryption on `oidc_client_secret` — plaintext.
- [ ] **#35 — Consolidate `user_profiles` duplicate fields.** All four
      duplicate-answer pairs are still present verbatim: `experience_level` /
      `skill_level`, `role_intent` / `job_title` (verify) / `current_role` (verify),
      `learning_goal` / `career_goal`, `weekly_time_commitment` / `weekly_goal_hrs`.
      This is still the widest-blast-radius item — grep the onboarding flow
      before touching.

---

## Phase 4 — Consistency + quick wins (next migration: `004_*`)

Quick wins (safe, mostly one-liners):
- [ ] **#24** — `UNIQUE(user_id, question_id) WHERE question_id IS NOT NULL` on
      `srs_cards` — still missing.
- [ ] **#25** — rename `sheet_items.order_index` → `position`, add
      `UNIQUE(sheet_id, position) DEFERRABLE INITIALLY DEFERRED` — still only a
      plain (non-unique) index exists (`idx_sheet_items_sheet_order`).
- [ ] **#28** — `refresh_tokens.ip` → `inet`, rename to `ip_address` — still `text`.
- [ ] **#29** — standardize duration columns to `*_seconds`; `lab_definitions.max_duration`
      and `lab_org_config.max_session_duration` are still unitless integers — rename
      with a unit suffix at minimum.
- [ ] **#32** — `srs_cards.ease_factor` → `numeric(4,2)` — still `double precision`.
- [ ] **#37** — `highlight_explanations` unique key → `(text_hash, source_type, model_used)`
      — still `UNIQUE(text_hash)` alone.
- [ ] **#39 (remainder)** — Hash `assessment_attempts.active_session_token` and
      `public_attempts.session_token`. Both are still plaintext bearer tokens —
      this is the one still-open **critical**-severity item from the original audit.

Needs care (logic or naming touches Go):
- [ ] **#3** — `feedback` vs `experience_reports` still fully duplicated —
      merge, low urgency (medium value per original review).
- [ ] **#13** — `interview_evaluations.composite_score` still a plain stored
      column, not generated from the seven `score_*` fields.
- [ ] **#16** — `assessments.status` still the full 6-value enum
      (`draft/published/scheduled/active/completed/archived`); collapse to
      `draft/published/archived` and compute temporal phase at read time.
- [ ] **#18** — `mentor_ticket_assignments` still duplicates `student_id` AND
      `org_id` from `mentor_tickets`. Drop both, join through `ticket_id`.
- [ ] **#19** — `course_modules.course_id` still present despite `section_id`
      already determining it — drop, or add composite FK if Go filters by it directly.
- [ ] **#21** — `user_problem_progress` still PKs on `(user_id, topic_tag)` with
      no FK to `sheet_items` — needs surrogate key backfill.
- [ ] **#22** — polymorphic type/id pairs (`assessment_assignments.assignee_type/id`,
      etc.) still unenforced — convert 2-arity ones to exclusive-arc nullable FKs;
      leave true polymorphism (`audit_logs`, `xp_events`) as-is.
- [ ] **#36 (remainder)** — `courses.creator_id` → `created_by`, to match every
      other table. Do last, touches the most call sites for least functional value.
- [ ] **#40** — `enrollments.batch_id` still present alongside `batch_members` +
      `batch_courses` — three tables can still disagree on batch membership.

Deferred (documented, not migrating now — unchanged from original review, not reverified this pass):
- #12 (`coding_submissions` dual test counts — defensible denormalization)
- #14 (`users.email_verified` vs `email_verifications.verified_at` — acceptable with discipline)
- #15 (`batch_member_details.status` vs `batch_invitations` timestamps)
- #26 (transitive `org_id` on attempts/scores — needed for RLS/partitioning)
- #30, #31 (`created_at` nullability chaos, missing `updated_at` — low impact)
- #34 (`user_profiles.show_*` / assessment toggle booleans — tolerable today)
- #38 (event/log tables not partition-ready — matters at 10M+ rows, not yet)

---

## Rules for whoever (human or agent) picks these up

1. One phase = one migration number, with a matching `.down.sql`.
2. No `BEGIN;`/`COMMIT;` in the `.sql` file — runner-managed transaction.
3. Grep Go call sites for every dropped/renamed column before dropping it.
4. `internal/assessment` may have unrelated in-flight work — check `git diff`
   / `git status` there before editing.
5. Re-verify against `001_baseline.sql` before starting — this file reflects a
   point-in-time audit (2026-07-21, table statuses unchanged by the 2026-07-30
   re-squash), not a live query.
