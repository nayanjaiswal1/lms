# Schema Refactor — Decisions Record

Architectural review (2026-08-04) found ~181 tables with heavy overlap — the same concept
(comments, messages, tickets, config, attempts) reimplemented per-domain. This document is the
permanent record of what was merged, why, and what was explicitly decided instead of a full
migration. The working checklists used to execute it (`schema-refactor-plan.md`,
`schema-refactor-execute.md`, `schema-refactor-agent-instructions.md`) are gone now that the work
they tracked is done — this file is what's worth keeping.

**Migration history:** the change shipped as one migration, `025_full_schema_consolidation.sql`,
then that file (plus all of `001`–`024` before it) was squashed into a new
`backend/db/migrations/001_baseline.sql` — same squash-to-baseline pattern this repo already used
twice before. The old numbered files are gone from the working tree; every version is still in
`git log` if the literal SQL is ever needed again.

---

## Table consolidations (data mapping)

| New/surviving shape | Absorbed | Discriminator |
|---|---|---|
| `user_profiles` | `user_social_links`, `user_skills`, `whatnow_user_state` | columns: `linkedin_url`/`github_url`/`portfolio_url`/`skills` (jsonb), `whatnow_energy` |
| `user_sheets` | `user_sheet_settings` | columns: `base_revision_days`, `growth_scheme` |
| `courses` | `certificate_rules` | column: `certificate_threshold_percent` |
| `mentor_sessions` | `mentor_session_notes` | columns: `notes`, `notes_visible_to_student` |
| `org_settings` | `org_auth_config`, `org_ai_connector_config`, `org_job_quotas`, `gitlab_org_config`, `lab_org_config`, `org_session_booking_config` | namespaced JSONB, one namespace per former table |
| `user_permission_overrides` | `feature_grants` | folded in as-is |
| `auth_tokens` | `email_verifications`, `password_reset_tokens`, `oauth_exchanges`, `calendar_feed_tokens`, `mcp_auth_codes`, `mcp_access_tokens`, `gitlab_oauth_states`, `calendar_event_invites` | `purpose` discriminator + `payload` jsonb (`refresh_tokens` stays separate — different lifecycle/rotation rules) |
| `messages` | `mentor_chat_messages`, `mentor_direct_messages`, `support_ticket_messages` | `thread_type` filter |
| `comments` | `wiki_comments`, `interview_exp_comments` | `subject_type` filter |
| `content_reactions` | `batch_message_reactions`, `interview_exp_votes` | `target_type` filter |
| `content_versions` | `question_versions`, `wiki_page_versions` | `content_type` filter |
| `wiki_pages` | `wiki_templates` | `is_template = true`, `space_id IS NULL` |
| `content_reports` | `mentor_reports` | extended `content_type` CHECK to include `mentor`/`user` |
| `change_requests` | `mentor_change_requests`, `course_content_proposals` | `kind` filter |
| `feedback` | `course_reviews`, `experience_reports`, `mentor_session_feedback` | `kind` filter |
| `audit_logs` | `mcp_action_log` | `source = 'mcp'` |
| `conversations` | `mentor_tickets`, `support_tickets`, `mentor_conversations` | `kind` filter; **old row `id`s were carried over** so `messages.thread_id` still resolves |
| `assessments` / `assessment_attempts` / `attempt_answers` | `final_tests`/`final_test_attempts`, `public_attempts`, `offline_test_scores`, `practice_sessions`/`practice_items`, `lesson_check_attempts` | `type` discriminator: `final_test` / `offline` / `practice` / `knowledge_check`; anonymous attempts keep nullable `user_id` + `anonymous_identity` jsonb |
| `purchases` | `session_pack_purchases`, `course_purchases` (renamed) | `product_type` discriminator + `granted` jsonb |
| `content_assignments` | `batch_courses`, `assessment_assignments` | polymorphic `content_type` + audience |
| `roadmaps.structure` (jsonb) + `roadmap_module_progress` | `roadmap_phases`, `roadmap_milestones`, `roadmap_modules` | flattened; per-module completion moved to the new small table |
| `calendar_event_attendees` | `calendar_event_invites` | merged, `user_id`/`email` both nullable |
| `learning_annotations` | `lesson_notes`, `lesson_reflections`, `mistake_entries`, `highlights` | `annotation_type` filter (`highlight_explanations` was kept separate — not a duplicate) |
| `gitlab_objects` | `gitlab_issues`, `gitlab_pipelines` | `object_type` filter |
| `gitlab_merge_requests.reviews` (jsonb) | `gitlab_mr_reviews` | folded into the parent row |
| `jobs` | `project_handoffs` | `project_handoff` job type, payload `{team_id, mode, target_namespace}` |
| `batch_members` (+`role`) | `batch_mentors` | folded in, `batches.mentor_id` dropped |
| `roles`/`user_roles`/`user_permission_overrides` | — | `tenant_id` column renamed to `org_id` everywhere (naming fix, not a merge) |

Dropped outright (confirmed zero references in `.go`/`.sql`/`.ts`/`.tsx` at review time):
`lab_analytics`, `nav_permissions`, `lab_egress_rules`, `lab_task_versions.tasks` (dead JSONB
duplicate of `lab_task_version_items`).

---

## Explicitly resolved decisions (not full merges)

- **`lesson_check_attempts`** — promoted to real `assessments`/`assessment_questions`/
  `attempt_answers` rows (`type='knowledge_check'`, `parent_type='module'`), same shape as the
  `final_tests` migration block. `course_modules.knowledge_check` JSONB and the old table were
  dropped in the same migration — low traffic, no dual-read period needed.
- **`system_design_attempts`** — left untouched. Confirmed ungraded practice (no attempt-limit
  enforcement in `systemdesign` package), so it stays outside the assessment engine.
- **`mentor_ticket_assignments`** — dropped with no history table. No product surface displays
  "who was this ticket assigned to before," so reassignment history wasn't worth preserving.
- **`feature_grants` → `user_permission_overrides`** — shipped as-is. The migration reproduces a
  pre-existing bug (a grant applies in every org the user belongs to, not just the intended one).
  Documented as a known, accepted limitation rather than a blocker — fixing the underlying grant
  scope was out of scope for a schema migration.
- **`conversations` id continuity** — the three source tables' primary keys were carried into the
  new `conversations.id` (not regenerated), so `messages.thread_id` — already written assuming old
  ids survive — resolves correctly without a remap pass.
- **`comments` parent threading** — `wiki_comments`/`interview_exp_comments` got new
  `gen_random_uuid()` ids on migration, so `parent_id` was resolved via a two-pass insert (temp
  `(old_id, new_id)` mapping table, then a second pass that rewrites `parent_id` through it) rather
  than trying to preserve old ids across a merge of two previously-separate id spaces.
- **`certificates.assessment_attempt_id`** — backfilled from `final_test_attempts` via an exact
  `(user_id, assessment_id, started_at)` match against the newly-inserted `assessment_attempts`
  rows; the migration raises an exception if any certificate's match comes back NULL rather than
  silently shipping a broken certificate reference.

---

## Deferred, not part of this migration

- **Partitioning** (`attempt_events`, `audit_logs`, `xp_events`, `notifications`,
  `lab_usage_events`, `srs_reviews`) — separate runbook, triggered by real row-count/growth data,
  not bundled into the consolidation. Retention numbers are recorded as `COMMENT ON TABLE` on the
  relevant tables in `001_baseline.sql` (30d `gitlab_webhook_events`, 90d `job_runs`, 24–48h
  `idempotency_keys`).
- **`org_auth_config.oidc_client_secret` encryption backfill** — the column now has an `_enc`
  counterpart; the plaintext column stays readable until the backfill job finishes, then gets
  dropped in a follow-up migration.

---

## Docs

`docs/erd.md`, `docs/learning.md`, `docs/anonymous.md`, `docs/orgs.md`, `docs/sheets.md`,
`docs/design.md`, `docs/rbac.md`, `docs/session-booking.md`, `docs/activity.md` were all rewritten
to describe the post-consolidation shape — no more references to the merged-away tables.
