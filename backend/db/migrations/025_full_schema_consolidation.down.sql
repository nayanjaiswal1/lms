-- Migration 025 (DOWN) — full_schema_consolidation
-- ═════════════════════════════════════════════════════════════════════════
-- Best-effort structural reversal. Recreates the pre-025 table shapes and
-- backfills what it can from the consolidated tables. Data fidelity is NOT
-- guaranteed for anything that went through a JSONB merge (roadmap
-- structure, gitlab_objects, org_settings) — those reversals recreate
-- columns but some fields (e.g. comment threading parent_id, mistake_entry
-- id continuity) are approximate. Treat this as an emergency rollback path,
-- not a routine toggle.
-- ═════════════════════════════════════════════════════════════════════════

-- ── Phase 5 comments ──
COMMENT ON TABLE public.attempt_events IS NULL;
COMMENT ON TABLE public.audit_logs IS NULL;
COMMENT ON TABLE public.xp_events IS NULL;
COMMENT ON TABLE public.notifications IS NULL;
COMMENT ON TABLE public.lab_usage_events IS NULL;
COMMENT ON TABLE public.srs_reviews IS NULL;
COMMENT ON TABLE public.gitlab_webhook_events IS NULL;
COMMENT ON TABLE public.job_runs IS NULL;
COMMENT ON TABLE public.idempotency_keys IS NULL;

-- ── Phase 4 ──
CREATE TABLE public.project_handoffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  team_id uuid NOT NULL REFERENCES public.project_teams(id) ON DELETE CASCADE,
  mode text, target_namespace text, status text, error text,
  requested_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
INSERT INTO public.project_handoffs (org_id, team_id, mode, target_namespace, status, requested_at)
SELECT org_id, (payload->>'team_id')::uuid, payload->>'mode', payload->>'target_namespace', status, created_at
FROM public.jobs WHERE handler = 'project_handoff';
DELETE FROM public.jobs WHERE handler = 'project_handoff';

CREATE TABLE public.gitlab_mr_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merge_request_id uuid NOT NULL REFERENCES public.gitlab_merge_requests(id) ON DELETE CASCADE,
  reviewer_id uuid, state text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.gitlab_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL, team_id uuid, gitlab_issue_id bigint,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.gitlab_pipelines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL, team_id uuid, gitlab_pipeline_id bigint,
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.gitlab_issues (org_id, team_id, gitlab_issue_id, updated_at)
SELECT org_id, team_id, gitlab_id, updated_at FROM public.gitlab_objects WHERE object_type = 'issue';
INSERT INTO public.gitlab_pipelines (org_id, team_id, gitlab_pipeline_id, updated_at)
SELECT org_id, team_id, gitlab_id, updated_at FROM public.gitlab_objects WHERE object_type = 'pipeline';
DROP TABLE public.gitlab_objects;
ALTER TABLE public.gitlab_merge_requests DROP COLUMN IF EXISTS reviews;

CREATE TABLE public.learning_annotations_backup_unused (id uuid); -- placeholder to keep old name free
DROP TABLE public.learning_annotations_backup_unused;
CREATE TABLE public.lesson_notes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid, user_id uuid NOT NULL, module_id uuid, content text, source text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.lesson_reflections (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid, user_id uuid NOT NULL, module_id uuid, response text, source text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.mistake_entries (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, category text, original_text text, corrected_text text, source_module_id uuid, resolved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.highlights (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, source_type text, source_id uuid, selected_text text, note text, saved_for_revision boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now());
INSERT INTO public.lesson_notes (org_id, user_id, module_id, content, source, created_at)
SELECT org_id, user_id, source_id, text, meta->>'source', created_at FROM public.learning_annotations WHERE annotation_type = 'note';
INSERT INTO public.lesson_reflections (org_id, user_id, module_id, response, source, created_at)
SELECT org_id, user_id, source_id, text, meta->>'source', created_at FROM public.learning_annotations WHERE annotation_type = 'reflection';
INSERT INTO public.mistake_entries (user_id, category, original_text, corrected_text, source_module_id, resolved_at, created_at)
SELECT user_id, meta->>'category', text, meta->>'corrected_text', source_id, resolved_at, created_at FROM public.learning_annotations WHERE annotation_type = 'mistake';
INSERT INTO public.highlights (id, user_id, source_type, source_id, selected_text, note, saved_for_revision, created_at)
SELECT id, user_id, source_type, source_id, text, meta->>'note', saved_for_revision, created_at FROM public.learning_annotations WHERE annotation_type = 'highlight';
ALTER TABLE public.srs_cards DROP COLUMN IF EXISTS annotation_id;
DROP TABLE public.learning_annotations;

CREATE TABLE public.calendar_event_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_id uuid NOT NULL, email text NOT NULL,
  role text, token_hash text, expires_at timestamptz, accepted_at timestamptz
);
INSERT INTO public.calendar_event_invites (event_id, email, role, accepted_at)
SELECT event_id, email, role, CASE WHEN rsvp_status = 'accepted' THEN now() ELSE NULL END
FROM public.calendar_event_attendees WHERE email IS NOT NULL;
DELETE FROM public.calendar_event_attendees WHERE email IS NOT NULL;
ALTER TABLE public.calendar_event_attendees DROP CONSTRAINT IF EXISTS calendar_event_attendees_subject_chk;
ALTER TABLE public.calendar_event_attendees DROP COLUMN IF EXISTS email;
ALTER TABLE public.calendar_event_attendees ALTER COLUMN user_id SET NOT NULL;

CREATE TABLE public.roadmap_phases (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), roadmap_id uuid NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE, title text, description text, position integer, estimated_weeks integer);
CREATE TABLE public.roadmap_milestones (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), phase_id uuid NOT NULL REFERENCES public.roadmap_phases(id) ON DELETE CASCADE, title text, description text, position integer, estimated_hours integer);
CREATE TABLE public.roadmap_modules (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), milestone_id uuid NOT NULL REFERENCES public.roadmap_milestones(id) ON DELETE CASCADE, title text, module_type text, position integer, resource_type text, resource_id uuid, completed_at timestamptz);
-- Rehydration from structure JSONB back into three tables is a data-loss
-- risk if new fields were added post-flatten; left as an application-level
-- backfill script rather than blind SQL against unknown JSON shape drift.
DROP TABLE public.roadmap_module_progress;
ALTER TABLE public.roadmaps DROP COLUMN IF EXISTS structure;

DROP TABLE public.content_assignments;
CREATE TABLE public.batch_courses (batch_id uuid NOT NULL, course_id uuid NOT NULL, assigned_by uuid, assigned_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (batch_id, course_id));
CREATE TABLE public.assessment_assignments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), assessment_id uuid NOT NULL, assignee_type text, assignee_id uuid, due_at timestamptz, assigned_by uuid, assigned_at timestamptz NOT NULL DEFAULT now());

-- ── Phase 3 ──
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS course_id_restore uuid;
CREATE TABLE public.session_pack_purchases (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid, user_id uuid, pack_id uuid, amount_cents bigint, currency text, provider text, provider_ref text, payment_ref text, status text, created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz);
INSERT INTO public.session_pack_purchases (org_id, user_id, pack_id, amount_cents, currency, provider, provider_ref, payment_ref, status, created_at, completed_at)
SELECT org_id, user_id, pack_id, amount_cents, currency, provider, provider_ref, payment_ref, status, created_at, completed_at
FROM public.purchases WHERE product_type = 'session_pack';
DELETE FROM public.purchases WHERE product_type = 'session_pack';
ALTER TABLE public.purchases DROP COLUMN IF EXISTS course_id_restore;
ALTER TABLE public.purchases DROP COLUMN IF EXISTS granted;
ALTER TABLE public.purchases DROP COLUMN IF EXISTS pack_id;
ALTER TABLE public.purchases DROP COLUMN IF EXISTS product_type;
ALTER TABLE public.purchases ALTER COLUMN course_id SET NOT NULL;
DROP INDEX IF EXISTS idx_purchases_user_course_completed;
CREATE UNIQUE INDEX idx_course_purchases_user_course_completed ON public.purchases (user_id, course_id) WHERE status = 'completed';
ALTER TABLE public.purchases RENAME TO course_purchases;

CREATE TABLE public.practice_sessions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, org_id uuid, technology text, difficulty text, question_count integer, status text, ai_model text, created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz);
CREATE TABLE public.practice_items (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), session_id uuid NOT NULL REFERENCES public.practice_sessions(id) ON DELETE CASCADE, position integer, question_text text, user_answer text, ai_feedback jsonb, answered_at timestamptz, feedback_at timestamptz);
DELETE FROM public.assessments WHERE type = 'practice';

DELETE FROM public.assessment_attempts WHERE assessment_id IN (SELECT id FROM public.assessments WHERE type = 'offline');
DELETE FROM public.assessments WHERE type = 'offline';
CREATE TABLE public.offline_test_scores (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid, batch_id uuid, user_id uuid, test_id uuid, test_name text, test_date timestamptz, max_score numeric, score numeric, entered_by uuid);

DELETE FROM public.assessment_attempts WHERE user_id IS NULL;
ALTER TABLE public.assessment_attempts DROP COLUMN IF EXISTS anonymous_identity;
ALTER TABLE public.assessment_attempts ALTER COLUMN user_id SET NOT NULL;
CREATE TABLE public.public_attempts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), assessment_id uuid NOT NULL, name text, email text, phone text, status text, score numeric, max_score numeric, percentage numeric, passed boolean, started_at timestamptz, submitted_at timestamptz, active_session_token text, overridden_by uuid, override_note text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());

ALTER TABLE public.certificates DROP COLUMN IF EXISTS assessment_attempt_id;
DELETE FROM public.assessment_attempts WHERE assessment_id IN (SELECT id FROM public.assessments WHERE type = 'final_test');
CREATE TABLE public.final_tests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), course_id uuid NOT NULL, questions jsonb, time_limit_minutes integer, passing_score_percent numeric, max_attempts integer, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.final_test_attempts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), final_test_id uuid NOT NULL REFERENCES public.final_tests(id) ON DELETE CASCADE, user_id uuid NOT NULL, status text, score numeric, answers jsonb, started_at timestamptz, submitted_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
DELETE FROM public.assessments WHERE type = 'final_test';

-- ── Phase 2 ──
CREATE TABLE public.mentor_conversations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, student_id uuid NOT NULL, mentor_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (org_id, student_id, mentor_id));
CREATE TABLE public.support_tickets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, user_id uuid NOT NULL, subject text, category text, priority text, status text, assigned_to uuid, resolved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.mentor_tickets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, student_id uuid NOT NULL, course_id uuid, purchase_id uuid, status text, assigned_mentor_id uuid, assigned_by uuid, assigned_at timestamptz, escalation_level integer NOT NULL DEFAULT 0, closed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.mentor_ticket_assignments (ticket_id uuid NOT NULL, mentor_id uuid NOT NULL, student_id uuid, assigned_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (ticket_id, mentor_id, assigned_at));
INSERT INTO public.mentor_tickets (id, org_id, student_id, course_id, purchase_id, status, assigned_mentor_id, escalation_level, closed_at, created_at)
SELECT id, org_id, requester_id, course_id, purchase_id, status, counterpart_id, escalation_level, closed_at, created_at FROM public.conversations WHERE kind = 'mentorship';
INSERT INTO public.support_tickets (id, org_id, user_id, subject, category, priority, status, assigned_to, resolved_at, created_at)
SELECT id, org_id, requester_id, subject, category, priority, status, assigned_to, resolved_at, created_at FROM public.conversations WHERE kind = 'support';
INSERT INTO public.mentor_conversations (id, org_id, student_id, mentor_id, created_at)
SELECT id, org_id, requester_id, counterpart_id, created_at FROM public.conversations WHERE kind = 'direct';
DROP TABLE public.conversations;

ALTER TABLE public.audit_logs DROP COLUMN IF EXISTS source;
ALTER TABLE public.audit_logs DROP COLUMN IF EXISTS connection_id;
ALTER TABLE public.audit_logs DROP COLUMN IF EXISTS revertible;
ALTER TABLE public.audit_logs DROP COLUMN IF EXISTS reverted_at;
ALTER TABLE public.audit_logs DROP COLUMN IF EXISTS reverted_by;
CREATE TABLE public.mcp_action_log (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, org_id uuid, user_id uuid, tool_name text, connection_id uuid, args jsonb, target_type text, target_id uuid, before_state jsonb, after_state jsonb, revertible boolean, reverted_at timestamptz, reverted_by uuid, created_at timestamptz NOT NULL DEFAULT now());

ALTER TABLE public.feedback DROP COLUMN IF EXISTS kind;
CREATE TABLE public.course_reviews (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), course_id uuid NOT NULL, user_id uuid NOT NULL, rating numeric, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.experience_reports (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid, subject_type text, subject_id uuid, user_id uuid, experience text, description text, skipped_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.mentor_session_feedback (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), session_id uuid NOT NULL, author_id uuid NOT NULL, author_role text, rating numeric, comment text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (session_id, author_id));

DROP TABLE public.change_requests;
CREATE TABLE public.mentor_change_requests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, student_id uuid NOT NULL, ticket_id uuid, reason text, status text, review_note text, reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.course_content_proposals (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, proposer_id uuid NOT NULL, target_course_id uuid, title text, content_type text, body text, status text, review_note text, reviewed_by uuid, reviewed_at timestamptz, created_module_id uuid, created_at timestamptz NOT NULL DEFAULT now());

DELETE FROM public.content_reports WHERE content_type = 'mentor';
CREATE TABLE public.mentor_reports (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, reporter_id uuid NOT NULL, mentor_id uuid NOT NULL, reason text, description text, status text, resolution_note text, resolved_by uuid, resolved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.content_reports DROP CONSTRAINT IF EXISTS content_reports_content_type_check;
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_content_type_check CHECK (content_type IN ('wiki_page', 'course_module'));

CREATE TABLE public.wiki_templates (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid, name text, description text, content jsonb, created_by uuid, created_at timestamptz NOT NULL DEFAULT now());
INSERT INTO public.wiki_templates (org_id, name, content, created_by, created_at)
SELECT NULL, title, content, created_by, created_at FROM public.wiki_pages WHERE is_template;
DELETE FROM public.wiki_pages WHERE is_template;
ALTER TABLE public.wiki_pages DROP COLUMN IF EXISTS is_template;

ALTER TABLE public.assessment_questions DROP COLUMN IF EXISTS content_version_id;
CREATE TABLE public.wiki_page_versions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), page_id uuid NOT NULL, version integer, title text, content jsonb, saved_by uuid, saved_at timestamptz NOT NULL DEFAULT now());
INSERT INTO public.wiki_page_versions (page_id, version, title, content, saved_by, saved_at)
SELECT content_id, version, title, content, created_by, created_at FROM public.content_versions WHERE content_type = 'wiki_page';
DELETE FROM public.content_versions WHERE content_type = 'wiki_page';

DROP TABLE public.content_reactions;
CREATE TABLE public.batch_message_reactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), message_id uuid NOT NULL, user_id uuid NOT NULL, emoji text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.interview_exp_votes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, qna_id uuid NOT NULL, value smallint, created_at timestamptz NOT NULL DEFAULT now());

DROP TABLE public.comments;
CREATE TABLE public.wiki_comments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), page_id uuid NOT NULL, parent_id uuid, author_id uuid, content text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz);
CREATE TABLE public.interview_exp_comments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), qna_id uuid NOT NULL, parent_id uuid, author_id uuid, content text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz);

DROP TABLE public.messages;
CREATE TABLE public.mentor_chat_messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, ticket_id uuid NOT NULL, sender_id uuid NOT NULL, body text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.mentor_direct_messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, conversation_id uuid NOT NULL, sender_id uuid NOT NULL, body text CHECK (char_length(body) BETWEEN 1 AND 4000), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.support_ticket_messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, ticket_id uuid NOT NULL, sender_id uuid NOT NULL, body text CHECK (char_length(body) BETWEEN 1 AND 4000), created_at timestamptz NOT NULL DEFAULT now());

DROP TABLE public.auth_tokens;
CREATE TABLE public.email_verifications (token_hash text PRIMARY KEY, user_id uuid NOT NULL, expires_at timestamptz, consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.password_reset_tokens (token_hash text PRIMARY KEY, user_id uuid NOT NULL, expires_at timestamptz, consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.oauth_exchanges (token_hash text PRIMARY KEY, user_id uuid NOT NULL, onboarding_completed boolean, expires_at timestamptz, consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.calendar_feed_tokens (user_id uuid NOT NULL, org_id uuid NOT NULL, token_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, org_id));
CREATE TABLE public.mcp_auth_codes (code_hash text PRIMARY KEY, client_id uuid, scopes text[], code_challenge text, redirect_uri text, expires_at timestamptz, consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.mcp_access_tokens (token_hash text PRIMARY KEY, connection_id uuid, expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.gitlab_oauth_states (state_hash text PRIMARY KEY, org_id uuid, code_verifier text, redirect_to text, expires_at timestamptz, consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());

-- ── Phase 1 ──
CREATE TABLE public.feature_grants (user_id uuid NOT NULL, feature_key text NOT NULL, granted_by uuid, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, feature_key));

CREATE TABLE public.org_ai_connector_config (org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE, enabled boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.org_job_quotas (org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.gitlab_org_config (org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE, allow_project_override boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.lab_org_config (org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE, max_concurrent_sessions integer, max_session_duration integer, allowed_images text[], egress_proxy_enabled boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.org_session_booking_config (org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE, updated_at timestamptz NOT NULL DEFAULT now());
INSERT INTO public.org_ai_connector_config (org_id, enabled, updated_at) SELECT org_id, COALESCE((ai_connector->>'enabled')::boolean, false), updated_at FROM public.org_settings;
INSERT INTO public.gitlab_org_config (org_id, allow_project_override, updated_at) SELECT org_id, COALESCE((gitlab->>'allow_project_override')::boolean, false), updated_at FROM public.org_settings;
INSERT INTO public.lab_org_config (org_id, max_concurrent_sessions, max_session_duration, egress_proxy_enabled, updated_at)
SELECT org_id, (labs->>'max_concurrent_sessions')::integer, (labs->>'max_session_duration')::integer, COALESCE((labs->>'egress_proxy_enabled')::boolean, false), updated_at FROM public.org_settings;
DROP TABLE public.org_settings;

ALTER TABLE public.roles RENAME COLUMN org_id TO tenant_id;
ALTER TABLE public.user_roles RENAME COLUMN org_id TO tenant_id;
ALTER TABLE public.user_permission_overrides RENAME COLUMN org_id TO tenant_id;

ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS mentor_id uuid;
CREATE TABLE public.batch_mentors (batch_id uuid NOT NULL, user_id uuid NOT NULL, added_by uuid, added_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (batch_id, user_id));
INSERT INTO public.batch_mentors (batch_id, user_id, added_by, added_at)
SELECT batch_id, user_id, added_by, added_at FROM public.batch_members WHERE role = 'mentor';
DELETE FROM public.batch_members WHERE role = 'mentor';
ALTER TABLE public.batch_members DROP COLUMN IF EXISTS role;
ALTER TABLE public.batch_members DROP COLUMN IF EXISTS added_by;

CREATE TABLE public.focus_wall_categories (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, name text NOT NULL);

CREATE TABLE public.mentor_session_notes (session_id uuid PRIMARY KEY, body text, visible_to_student boolean NOT NULL DEFAULT false);
INSERT INTO public.mentor_session_notes (session_id, body, visible_to_student)
SELECT id, notes, notes_visible_to_student FROM public.mentor_sessions WHERE notes IS NOT NULL;
ALTER TABLE public.mentor_sessions DROP COLUMN IF EXISTS notes;
ALTER TABLE public.mentor_sessions DROP COLUMN IF EXISTS notes_visible_to_student;

CREATE TABLE public.certificate_rules (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), course_id uuid NOT NULL, threshold_percent numeric, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
INSERT INTO public.certificate_rules (course_id, threshold_percent)
SELECT id, certificate_threshold_percent FROM public.courses WHERE certificate_threshold_percent IS NOT NULL;
ALTER TABLE public.courses DROP COLUMN IF EXISTS certificate_threshold_percent;

CREATE TABLE public.user_sheet_settings (user_id uuid NOT NULL, sheet_id uuid NOT NULL, base_revision_days integer, growth_scheme text, updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, sheet_id));
INSERT INTO public.user_sheet_settings (user_id, sheet_id, base_revision_days, growth_scheme)
SELECT user_id, sheet_id, base_revision_days, growth_scheme FROM public.user_sheets WHERE base_revision_days IS NOT NULL OR growth_scheme IS NOT NULL;
ALTER TABLE public.user_sheets DROP COLUMN IF EXISTS base_revision_days;
ALTER TABLE public.user_sheets DROP COLUMN IF EXISTS growth_scheme;

CREATE TABLE public.user_social_links (user_id uuid PRIMARY KEY, linkedin text, github text, portfolio text);
CREATE TABLE public.whatnow_user_state (user_id uuid PRIMARY KEY, energy text, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.user_skills (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, skill_name text, skill_level text);
INSERT INTO public.user_social_links (user_id, linkedin, github, portfolio)
SELECT user_id, linkedin_url, github_url, portfolio_url FROM public.user_profiles WHERE linkedin_url IS NOT NULL OR github_url IS NOT NULL OR portfolio_url IS NOT NULL;
INSERT INTO public.whatnow_user_state (user_id, energy)
SELECT user_id, whatnow_energy FROM public.user_profiles WHERE whatnow_energy IS NOT NULL;
INSERT INTO public.user_skills (user_id, skill_name, skill_level)
SELECT user_id, s->>'name', s->>'level' FROM public.user_profiles, jsonb_array_elements(skills) s WHERE jsonb_array_length(skills) > 0;
DROP INDEX IF EXISTS idx_user_profiles_skills_gin;
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS linkedin_url;
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS github_url;
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS portfolio_url;
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS whatnow_energy;
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS skills;

-- ── lesson_check_attempts + course_modules.knowledge_check restoration ──
ALTER TABLE public.course_modules ADD COLUMN IF NOT EXISTS knowledge_check jsonb DEFAULT '[]'::jsonb NOT NULL;

CREATE TABLE public.lesson_check_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, user_id uuid NOT NULL, module_id uuid NOT NULL,
  question_id text NOT NULL, question_type text NOT NULL, answer jsonb DEFAULT '{}'::jsonb NOT NULL,
  is_correct boolean NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lesson_check_attempts_question_type_check CHECK (question_type = ANY (ARRAY['mcq'::text, 'sql'::text]))
);

INSERT INTO public.lesson_check_attempts (org_id, user_id, module_id, question_id, question_type, answer, is_correct, created_at)
SELECT aa.org_id, aa.user_id, a.parent_id, qv.content ->> 'id', qv.content ->> 'type', ans.answer, ans.is_correct, ans.evaluated_at
FROM public.attempt_answers ans
JOIN public.assessment_attempts aa ON aa.id = ans.attempt_id
JOIN public.assessments a ON a.id = aa.assessment_id AND a.type = 'knowledge_check'
JOIN public.assessment_questions aq ON aq.id = ans.assessment_question_id
JOIN public.question_versions qv ON qv.id = aq.version_id
WHERE aa.user_id IS NOT NULL;

UPDATE public.course_modules cm SET knowledge_check = agg.items
FROM (
  SELECT a.parent_id AS module_id,
         jsonb_agg(jsonb_build_object('id', qv.content ->> 'id', 'type', qv.content ->> 'type', 'correct', qv.content ->> 'correct') ORDER BY aq."position") AS items
  FROM public.assessment_questions aq
  JOIN public.question_versions qv ON qv.id = aq.version_id
  JOIN public.assessments a ON a.id = aq.assessment_id AND a.type = 'knowledge_check'
  GROUP BY a.parent_id
) agg
WHERE cm.id = agg.module_id;

CREATE TEMP TABLE _kc_cleanup_ids AS
SELECT aq.question_id, aq.version_id
FROM public.assessment_questions aq
JOIN public.assessments a ON a.id = aq.assessment_id
WHERE a.type = 'knowledge_check';

DELETE FROM public.assessment_attempts WHERE assessment_id IN (SELECT id FROM public.assessments WHERE type = 'knowledge_check');
DELETE FROM public.assessment_questions WHERE assessment_id IN (SELECT id FROM public.assessments WHERE type = 'knowledge_check');
DELETE FROM public.assessments WHERE type = 'knowledge_check';
DELETE FROM public.question_versions WHERE id IN (SELECT version_id FROM _kc_cleanup_ids);
DELETE FROM public.questions WHERE id IN (SELECT question_id FROM _kc_cleanup_ids);
DROP TABLE _kc_cleanup_ids;

-- narrows back to pre-migration values; safe here since Phase 3's down
-- section (which runs before this, in reverse order) already deleted the
-- final_test/offline/practice rows, and knowledge_check rows are gone above.
ALTER TABLE public.assessments DROP CONSTRAINT assessments_type_check;
ALTER TABLE public.assessments ADD CONSTRAINT assessments_type_check
  CHECK (type = ANY (ARRAY['mcq'::text, 'coding'::text, 'mixed'::text]));

-- ── Phase 0 ──
ALTER TABLE public.org_auth_config DROP COLUMN IF EXISTS oidc_client_secret_enc;
COMMENT ON COLUMN public.org_auth_config.oidc_client_secret IS NULL;

DROP INDEX IF EXISTS idx_sheets_category;
DROP INDEX IF EXISTS idx_project_handoffs_team;
DROP INDEX IF EXISTS idx_project_originality_reports_assignment;
DROP INDEX IF EXISTS idx_gitlab_mr_reviews_mr;
DROP INDEX IF EXISTS idx_gitlab_merge_requests_team;
DROP INDEX IF EXISTS idx_lab_task_version_items_version_position;
DROP INDEX IF EXISTS idx_lab_task_versions_lab;
DROP INDEX IF EXISTS idx_lab_tasks_lab_position;
DROP INDEX IF EXISTS idx_revision_plan_topics_plan;
DROP INDEX IF EXISTS idx_project_checkpoints_assignment;
DROP INDEX IF EXISTS idx_final_tests_course;
DROP INDEX IF EXISTS idx_notifications_user_unread;
DROP INDEX IF EXISTS idx_srs_reviews_user_reviewed;

-- FK ON DELETE reverts to NO ACTION (original state) intentionally omitted —
-- these were correctness fixes, not toggleable behavior; reverting them
-- reintroduces the undeleteable-tenant bug. Leave as-is even on rollback.

ALTER TABLE public.lab_task_versions ADD COLUMN IF NOT EXISTS tasks jsonb;
CREATE TABLE IF NOT EXISTS public.nav_permissions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), role text, section_label text, section_order integer, item_key text, item_order integer, in_bottom_nav boolean);
CREATE TABLE IF NOT EXISTS public.lab_analytics (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), lab_id uuid, sessions_started integer, sessions_completed integer, avg_duration_sec numeric, avg_score numeric, per_task_pass_rate jsonb, computed_at timestamptz);
CREATE TABLE IF NOT EXISTS public.lab_egress_rules (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), lab_id uuid, host text, port integer, protocol text, reason text);
