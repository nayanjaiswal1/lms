-- Migration 025 — full_schema_consolidation
-- ═════════════════════════════════════════════════════════════════════════
-- Implements docs/schema-refactor-plan.md end to end in one migration.
-- Source: the full architectural review (2026-08-04). ~181 tables -> ~143.
--
-- DRAFT: written in one pass from the review's findings, not re-verified
-- table-by-table against live application code. Run against a staging copy
-- and `go build ./...` + full test suite BEFORE this touches production —
-- this migration drops columns and tables; several steps are not reversible
-- once old columns are dropped (the .down.sql recreates structure, not
-- guaranteed-lossless data).
--
-- Ordering matters: sections are additive-then-destructive within
-- themselves (add new table/column, backfill, drop old) so the app can be
-- deployed mid-migration without a hard outage window, but the whole file
-- is intended to run as one transaction-per-section unit.
-- ═════════════════════════════════════════════════════════════════════════


-- ═════════════════════════════════════════════════════════════════════════
-- PHASE 0 — dead tables, FK/index audit, secret encryption
-- ═════════════════════════════════════════════════════════════════════════

-- Confirmed zero references anywhere in backend/frontend (grepped .go/.sql/.ts/.tsx).
DROP TABLE IF EXISTS public.lab_analytics;
DROP TABLE IF EXISTS public.nav_permissions;

-- lab_egress_rules: zero DB reads found, but a LabEgressRule Go struct and
-- ProtocolHTTP/ProtocolHTTPS constants exist in labs/models.go with no
-- repo.go query touching the table — the model was scaffolded but the
-- egress proxy does not consult it. Dropping; if egress restriction is
-- actually needed, it should be re-added wired to a real reader.
DROP TABLE IF EXISTS public.lab_egress_rules;

-- Duplicated JSONB snapshot — labs/repo.go reads lab_task_version_items rows,
-- not this column. Dead weight, doubles storage of every published version.
ALTER TABLE public.lab_task_versions DROP COLUMN IF EXISTS tasks;

-- lab_warm_pool_configs was already dropped by 013_warm_pool_by_image.sql;
-- nothing to do here except note backend/db/fixtures/warm_pool_seed.sql
-- must be deleted/updated separately (not a migration concern).

-- ── FK delete-behavior audit ────────────────────────────────────────────
-- Classification: compositional (child meaningless without parent) -> CASCADE
--                 referential (actor/reference column)              -> SET NULL
--                 protective (financial/legal record)               -> RESTRICT
-- Labs (compositional except actor columns):
ALTER TABLE public.lab_sessions
  DROP CONSTRAINT IF EXISTS lab_sessions_org_id_fkey,
  ADD CONSTRAINT lab_sessions_org_id_fkey
    FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.lab_sessions
  DROP CONSTRAINT IF EXISTS lab_sessions_user_id_fkey,
  ADD CONSTRAINT lab_sessions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
ALTER TABLE public.lab_definitions
  DROP CONSTRAINT IF EXISTS lab_definitions_org_id_fkey,
  ADD CONSTRAINT lab_definitions_org_id_fkey
    FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.lab_definitions
  DROP CONSTRAINT IF EXISTS lab_definitions_course_id_fkey,
  ADD CONSTRAINT lab_definitions_course_id_fkey
    FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE SET NULL;
ALTER TABLE public.lab_usage_events
  DROP CONSTRAINT IF EXISTS lab_usage_events_org_id_fkey,
  ADD CONSTRAINT lab_usage_events_org_id_fkey
    FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;
-- Wiki (compositional):
ALTER TABLE public.wiki_pages
  DROP CONSTRAINT IF EXISTS wiki_pages_created_by_fkey,
  ADD CONSTRAINT wiki_pages_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.wiki_spaces
  DROP CONSTRAINT IF EXISTS wiki_spaces_created_by_fkey,
  ADD CONSTRAINT wiki_spaces_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.wiki_comments
  DROP CONSTRAINT IF EXISTS wiki_comments_author_id_fkey,
  ADD CONSTRAINT wiki_comments_author_id_fkey
    FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;
-- Interview prep (compositional):
ALTER TABLE public.interview_prep_plans
  DROP CONSTRAINT IF EXISTS interview_prep_plans_org_id_fkey,
  ADD CONSTRAINT interview_prep_plans_org_id_fkey
    FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.interview_skill_scores
  DROP CONSTRAINT IF EXISTS interview_skill_scores_user_id_fkey,
  ADD CONSTRAINT interview_skill_scores_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- Protective (retain on delete, anonymize instead):
ALTER TABLE public.audit_logs
  DROP CONSTRAINT IF EXISTS audit_logs_actor_user_id_fkey,
  ADD CONSTRAINT audit_logs_actor_user_id_fkey
    FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.idempotency_keys
  DROP CONSTRAINT IF EXISTS idempotency_keys_user_id_fkey,
  ADD CONSTRAINT idempotency_keys_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ── Missing hot-path indexes ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_srs_reviews_user_reviewed
  ON public.srs_reviews (user_id, reviewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, read_at, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_final_tests_course
  ON public.final_tests (course_id);
CREATE INDEX IF NOT EXISTS idx_project_checkpoints_assignment
  ON public.project_checkpoints (assignment_id);
CREATE INDEX IF NOT EXISTS idx_revision_plan_topics_plan
  ON public.revision_plan_topics (revision_plan_id);
CREATE INDEX IF NOT EXISTS idx_lab_tasks_lab_position
  ON public.lab_tasks (lab_id, position);
CREATE INDEX IF NOT EXISTS idx_lab_task_versions_lab
  ON public.lab_task_versions (lab_id);
CREATE INDEX IF NOT EXISTS idx_lab_task_version_items_version_position
  ON public.lab_task_version_items (task_version_id, position);
CREATE INDEX IF NOT EXISTS idx_gitlab_merge_requests_team
  ON public.gitlab_merge_requests (team_id);
CREATE INDEX IF NOT EXISTS idx_gitlab_mr_reviews_mr
  ON public.gitlab_mr_reviews (merge_request_id);
CREATE INDEX IF NOT EXISTS idx_project_originality_reports_assignment
  ON public.project_originality_reports (assignment_id);
CREATE INDEX IF NOT EXISTS idx_project_handoffs_team
  ON public.project_handoffs (team_id);
-- sheets has no is_public/visibility column (see docs/sheets.md — visibility
-- is a not-yet-built field); indexing what actually exists.
CREATE INDEX IF NOT EXISTS idx_sheets_category
  ON public.sheets (category);

-- ── Secret encryption ────────────────────────────────────────────────────
-- Bring org_auth_config in line with gitlab_installations' encrypted-bytea
-- convention. Column renamed so the app layer can tell old plaintext rows
-- apart during the backfill (application code must decrypt-on-read with a
-- fallback to plaintext until the backfill job finishes, then this comment
-- and the plaintext column should be dropped in a follow-up migration).
ALTER TABLE public.org_auth_config ADD COLUMN IF NOT EXISTS oidc_client_secret_enc bytea;
COMMENT ON COLUMN public.org_auth_config.oidc_client_secret IS
  'DEPRECATED — plaintext. Encrypt into oidc_client_secret_enc via the secrets package, then drop this column in a follow-up migration.';


-- ═════════════════════════════════════════════════════════════════════════
-- PHASE 1 — mechanical 1:1 folds, org_settings, RBAC org_id rename
-- ═════════════════════════════════════════════════════════════════════════

-- Widen assessments.type to cover the types this migration populates below
-- and in Phase 3 (final_test, offline, practice, knowledge_check) — app-side
-- handling added in the assessment/practice/certificates package changes.
ALTER TABLE public.assessments DROP CONSTRAINT assessments_type_check;
ALTER TABLE public.assessments ADD CONSTRAINT assessments_type_check
  CHECK (type = ANY (ARRAY['mcq'::text, 'coding'::text, 'mixed'::text, 'final_test'::text, 'offline'::text, 'practice'::text, 'knowledge_check'::text]));

-- ── lesson_check_attempts + course_modules.knowledge_check retire into assessments (type='knowledge_check') ──
-- knowledge_check jsonb only ever carried the grading key (id, type,
-- correct-if-mcq) — question text/options live in the lesson's content_body
-- markdown, not in the DB — so the `questions`/`question_versions` rows
-- created here are grading-key shells, not full question bank entries.
CREATE TEMP TABLE _kc_assessment_map (module_id uuid PRIMARY KEY, assessment_id uuid NOT NULL DEFAULT gen_random_uuid());

INSERT INTO _kc_assessment_map (module_id)
SELECT cm.id FROM public.course_modules cm WHERE jsonb_array_length(cm.knowledge_check) > 0;

INSERT INTO public.assessments (id, org_id, title, slug, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, created_by, created_at, updated_at)
SELECT m.assessment_id, c.org_id, cm.title || ' — Knowledge Check', 'kc-' || cm.id, 'knowledge_check', 'published', 'module', cm.id,
       30, 40, 100, jsonb_array_length(cm.knowledge_check), c.creator_id, cm.created_at, cm.updated_at
FROM _kc_assessment_map m
JOIN public.course_modules cm ON cm.id = m.module_id
JOIN public.courses c ON c.id = cm.course_id;

CREATE TEMP TABLE _kc_question_map (
  module_id uuid NOT NULL,
  kc_id text NOT NULL,
  question_id uuid NOT NULL DEFAULT gen_random_uuid(),
  version_id uuid NOT NULL DEFAULT gen_random_uuid(),
  assessment_question_id uuid NOT NULL DEFAULT gen_random_uuid(),
  kc_type text NOT NULL,
  kc_correct text,
  "position" integer NOT NULL,
  PRIMARY KEY (module_id, kc_id)
);

INSERT INTO _kc_question_map (module_id, kc_id, kc_type, kc_correct, "position")
SELECT cm.id, kc.item ->> 'id', kc.item ->> 'type', kc.item ->> 'correct', kc.ord - 1
FROM public.course_modules cm
CROSS JOIN LATERAL jsonb_array_elements(cm.knowledge_check) WITH ORDINALITY AS kc(item, ord)
WHERE jsonb_array_length(cm.knowledge_check) > 0;

INSERT INTO public.questions (id, org_id, type, title, difficulty, default_points, created_by, created_at, updated_at)
SELECT qm.question_id, c.org_id, CASE WHEN qm.kc_type = 'sql' THEN 'coding' ELSE 'mcq' END,
       'Knowledge check (' || qm.kc_type || ') — ' || cm.title, 'intermediate', 1, c.creator_id, cm.created_at, cm.updated_at
FROM _kc_question_map qm
JOIN public.course_modules cm ON cm.id = qm.module_id
JOIN public.courses c ON c.id = cm.course_id;

-- content preserves the original JSONB id so the down-migration can restore
-- course_modules.knowledge_check losslessly.
INSERT INTO public.question_versions (id, question_id, version, content, created_by, created_at)
SELECT qm.version_id, qm.question_id, 1, jsonb_build_object('id', qm.kc_id, 'type', qm.kc_type, 'correct', qm.kc_correct), c.creator_id, cm.created_at
FROM _kc_question_map qm
JOIN public.course_modules cm ON cm.id = qm.module_id
JOIN public.courses c ON c.id = cm.course_id;

INSERT INTO public.assessment_questions (id, assessment_id, question_id, version_id, "position", points, created_at)
SELECT qm.assessment_question_id, am.assessment_id, qm.question_id, qm.version_id, qm."position", 1, cm.created_at
FROM _kc_question_map qm
JOIN _kc_assessment_map am ON am.module_id = qm.module_id
JOIN public.course_modules cm ON cm.id = qm.module_id;

-- one assessment_attempts row per (module, user) aggregating all their
-- individual question submits, since lesson_check_attempts had no session
-- grouping concept.
CREATE TEMP TABLE _kc_attempt_map (module_id uuid NOT NULL, user_id uuid NOT NULL, attempt_id uuid NOT NULL DEFAULT gen_random_uuid(), PRIMARY KEY (module_id, user_id));

INSERT INTO _kc_attempt_map (module_id, user_id)
SELECT DISTINCT module_id, user_id FROM public.lesson_check_attempts;

INSERT INTO public.assessment_attempts (id, assessment_id, user_id, org_id, status, score, max_score, percentage, passed, started_at, submitted_at, evaluated_at, created_at, updated_at)
SELECT am2.attempt_id, m.assessment_id, am2.user_id, agg.org_id, 'evaluated',
       agg.correct_count, agg.total_count, round(agg.correct_count::numeric / agg.total_count * 100, 2),
       (agg.correct_count = agg.total_count), agg.min_created, agg.max_created, agg.max_created, agg.min_created, agg.max_created
FROM _kc_attempt_map am2
JOIN _kc_assessment_map m ON m.module_id = am2.module_id
JOIN (
  SELECT lca.module_id, lca.user_id, lca.org_id,
         count(*) FILTER (WHERE lca.is_correct) AS correct_count,
         count(*) AS total_count,
         min(lca.created_at) AS min_created,
         max(lca.created_at) AS max_created
  FROM public.lesson_check_attempts lca
  GROUP BY lca.module_id, lca.user_id, lca.org_id
) agg ON agg.module_id = am2.module_id AND agg.user_id = am2.user_id;

INSERT INTO public.attempt_answers (id, attempt_id, assessment_question_id, question_id, answer, is_correct, points_awarded, max_points, evaluated_at, updated_at)
SELECT gen_random_uuid(), am3.attempt_id, qm.assessment_question_id, qm.question_id, lca.answer, lca.is_correct,
       CASE WHEN lca.is_correct THEN 1 ELSE 0 END, 1, lca.created_at, lca.created_at
FROM public.lesson_check_attempts lca
JOIN _kc_attempt_map am3 ON am3.module_id = lca.module_id AND am3.user_id = lca.user_id
JOIN _kc_question_map qm ON qm.module_id = lca.module_id AND qm.kc_id = lca.question_id;

DROP TABLE _kc_attempt_map;
DROP TABLE _kc_question_map;
DROP TABLE _kc_assessment_map;

-- Low-traffic table, no dual-read period: drop immediately in this same migration.
DROP TABLE public.lesson_check_attempts;
ALTER TABLE public.course_modules DROP COLUMN knowledge_check;

-- ── user_profiles absorbs user_social_links, whatnow_user_state, user_skills ──
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS linkedin_url text,
  ADD COLUMN IF NOT EXISTS github_url text,
  ADD COLUMN IF NOT EXISTS portfolio_url text,
  ADD COLUMN IF NOT EXISTS whatnow_energy text,
  ADD COLUMN IF NOT EXISTS skills jsonb NOT NULL DEFAULT '[]'::jsonb;

UPDATE public.user_profiles p SET
  linkedin_url = s.linkedin,
  github_url = s.github,
  portfolio_url = s.portfolio
FROM public.user_social_links s
WHERE s.user_id = p.user_id;

UPDATE public.user_profiles p SET whatnow_energy = w.energy
FROM public.whatnow_user_state w
WHERE w.user_id = p.user_id;

UPDATE public.user_profiles p SET skills = agg.skills
FROM (
  SELECT user_id, jsonb_agg(jsonb_build_object('name', skill_name, 'level', skill_level)) AS skills
  FROM public.user_skills
  GROUP BY user_id
) agg
WHERE agg.user_id = p.user_id;

CREATE INDEX IF NOT EXISTS idx_user_profiles_skills_gin ON public.user_profiles USING gin (skills);

DROP TABLE public.user_social_links;
DROP TABLE public.whatnow_user_state;
DROP TABLE public.user_skills;

-- ── user_sheets absorbs user_sheet_settings ──
ALTER TABLE public.user_sheets
  ADD COLUMN IF NOT EXISTS base_revision_days integer,
  ADD COLUMN IF NOT EXISTS growth_scheme text;

UPDATE public.user_sheets us SET
  base_revision_days = s.base_revision_days,
  growth_scheme = s.growth_scheme
FROM public.user_sheet_settings s
WHERE s.user_id = us.user_id AND s.sheet_id = us.sheet_id;

DROP TABLE public.user_sheet_settings;

-- ── courses absorbs certificate_rules ──
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS certificate_threshold_percent numeric;

UPDATE public.courses c SET certificate_threshold_percent = r.threshold_percent
FROM public.certificate_rules r
WHERE r.course_id = c.id;

DROP TABLE public.certificate_rules;

-- ── mentor_sessions absorbs mentor_session_notes ──
ALTER TABLE public.mentor_sessions
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS notes_visible_to_student boolean NOT NULL DEFAULT false;

UPDATE public.mentor_sessions s SET
  notes = n.body,
  notes_visible_to_student = n.visible_to_student
FROM public.mentor_session_notes n
WHERE n.session_id = s.id;

DROP TABLE public.mentor_session_notes;

-- ── focus_wall_categories: free-text, no table needed ──
DROP TABLE public.focus_wall_categories;

-- ── batch_members absorbs batch_mentors; drop batches.mentor_id ──
ALTER TABLE public.batch_members
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'student',
  ADD COLUMN IF NOT EXISTS added_by uuid;

INSERT INTO public.batch_members (batch_id, user_id, role, added_by, added_at)
SELECT bm.batch_id, bm.user_id, 'mentor', bm.added_by, bm.added_at
FROM public.batch_mentors bm
ON CONFLICT (batch_id, user_id) DO UPDATE SET role = 'mentor';

DROP TABLE public.batch_mentors;
ALTER TABLE public.batches DROP COLUMN IF EXISTS mentor_id;

-- ── RBAC: tenant_id -> org_id ──
ALTER TABLE public.roles RENAME COLUMN tenant_id TO org_id;
ALTER TABLE public.user_roles RENAME COLUMN tenant_id TO org_id;
ALTER TABLE public.user_permission_overrides RENAME COLUMN tenant_id TO org_id;

-- ── org_settings absorbs 6 per-org config tables ──
CREATE TABLE public.org_settings (
  org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE,
  auth jsonb NOT NULL DEFAULT '{}'::jsonb,
  ai_connector jsonb NOT NULL DEFAULT '{}'::jsonb,
  jobs jsonb NOT NULL DEFAULT '{}'::jsonb,
  gitlab jsonb NOT NULL DEFAULT '{}'::jsonb,
  labs jsonb NOT NULL DEFAULT '{}'::jsonb,
  session_booking jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.org_settings (org_id, auth, updated_at)
SELECT org_id,
       jsonb_build_object(
         'sso_enabled', sso_enabled,
         'oidc_issuer_url', oidc_issuer_url,
         'oidc_client_id', oidc_client_id,
         'saml_metadata_xml', saml_metadata_xml
       ),
       updated_at
FROM public.org_auth_config
ON CONFLICT (org_id) DO UPDATE SET auth = EXCLUDED.auth, updated_at = EXCLUDED.updated_at;
-- NOTE: oidc_client_secret_enc intentionally NOT copied into org_settings —
-- stays in org_auth_config (narrow, separately-permissioned) per the
-- review's explicit warning against putting secrets in a shared JSONB blob.

INSERT INTO public.org_settings (org_id, ai_connector, updated_at)
SELECT org_id, jsonb_build_object('enabled', enabled), updated_at
FROM public.org_ai_connector_config
ON CONFLICT (org_id) DO UPDATE SET ai_connector = EXCLUDED.ai_connector, updated_at = EXCLUDED.updated_at;

INSERT INTO public.org_settings (org_id, jobs, updated_at)
SELECT org_id, to_jsonb(q) - 'org_id' - 'updated_at', updated_at
FROM public.org_job_quotas q
ON CONFLICT (org_id) DO UPDATE SET jobs = EXCLUDED.jobs, updated_at = EXCLUDED.updated_at;

INSERT INTO public.org_settings (org_id, gitlab, updated_at)
SELECT org_id, jsonb_build_object('allow_project_override', allow_project_override), updated_at
FROM public.gitlab_org_config
ON CONFLICT (org_id) DO UPDATE SET gitlab = EXCLUDED.gitlab, updated_at = EXCLUDED.updated_at;

INSERT INTO public.org_settings (org_id, labs, updated_at)
SELECT org_id, jsonb_build_object(
         'max_concurrent_sessions', max_concurrent_sessions,
         'max_session_duration', max_session_duration,
         'allowed_images', to_jsonb(allowed_images),
         'egress_proxy_enabled', egress_proxy_enabled
       ), updated_at
FROM public.lab_org_config
ON CONFLICT (org_id) DO UPDATE SET labs = EXCLUDED.labs, updated_at = EXCLUDED.updated_at;

INSERT INTO public.org_settings (org_id, session_booking, updated_at)
SELECT org_id, to_jsonb(c) - 'org_id' - 'updated_at', updated_at
FROM public.org_session_booking_config c
ON CONFLICT (org_id) DO UPDATE SET session_booking = EXCLUDED.session_booking, updated_at = EXCLUDED.updated_at;

DROP TABLE public.org_ai_connector_config;
DROP TABLE public.org_job_quotas;
DROP TABLE public.gitlab_org_config;
DROP TABLE public.lab_org_config;
DROP TABLE public.org_session_booking_config;
-- org_auth_config kept (narrow secret-bearing table, see above) but its
-- non-secret columns are now redundant with org_settings.auth — drop them
-- in a follow-up migration once the auth package reads exclusively from
-- org_settings + org_auth_config.oidc_client_secret_enc.

-- ── feature_grants folds into user_permission_overrides ──
INSERT INTO public.permissions (code, name, description, module)
SELECT DISTINCT feature_key, feature_key, 'Migrated from feature_grants', 'features'
FROM public.feature_grants
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.user_permission_overrides (user_id, org_id, permission_id, granted_by, granted_at)
SELECT fg.user_id, om.org_id, p.id, fg.granted_by, fg.created_at
FROM public.feature_grants fg
JOIN public.permissions p ON p.code = fg.feature_key
JOIN public.org_members om ON om.user_id = fg.user_id
ON CONFLICT DO NOTHING;
-- NOTE: feature_grants had no org scope; the INSERT above grants the
-- feature in every org the user belongs to, which reproduces the original
-- (buggy) cross-org behavior. Review per-user before relying on this —
-- this is a data-migration approximation, not a fix to the underlying gap.

DROP TABLE public.feature_grants;


-- ═════════════════════════════════════════════════════════════════════════
-- PHASE 2 — auth_tokens, messages/comments/reactions/versions, reports/feedback
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.auth_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purpose text NOT NULL CHECK (purpose IN (
    'email_verify', 'password_reset', 'oauth_exchange',
    'calendar_feed', 'mcp_auth_code', 'mcp_access_token', 'gitlab_oauth_state',
    'calendar_invite'
  )),
  token_hash text NOT NULL,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX idx_auth_tokens_hash ON public.auth_tokens (token_hash);
CREATE INDEX idx_auth_tokens_sweep ON public.auth_tokens (expires_at) WHERE consumed_at IS NULL;

-- Source tables predate this migration and use their own consumed/created
-- column names (verified_at/used_at, no created_at on several) — mapped
-- explicitly rather than assumed.
INSERT INTO public.auth_tokens (purpose, token_hash, user_id, payload, expires_at, consumed_at)
SELECT 'email_verify', token_hash, user_id, '{}'::jsonb, expires_at, verified_at FROM public.email_verifications;
INSERT INTO public.auth_tokens (purpose, token_hash, user_id, payload, expires_at, consumed_at)
SELECT 'password_reset', token_hash, user_id, '{}'::jsonb, expires_at, used_at FROM public.password_reset_tokens;
INSERT INTO public.auth_tokens (purpose, token_hash, user_id, payload, expires_at, consumed_at)
SELECT 'oauth_exchange', token_hash, user_id,
       jsonb_build_object('onboarding_completed', onboarding_completed),
       expires_at, used_at
FROM public.oauth_exchanges;
INSERT INTO public.auth_tokens (purpose, token_hash, user_id, org_id, payload, expires_at, consumed_at, created_at)
SELECT 'calendar_feed', token_hash, user_id, org_id, '{}'::jsonb,
       'infinity'::timestamptz, NULL, created_at
FROM public.calendar_feed_tokens;
INSERT INTO public.auth_tokens (purpose, token_hash, org_id, user_id, payload, expires_at, created_at)
SELECT 'mcp_auth_code', code, org_id, user_id,
       jsonb_build_object('client_id', client_id, 'scopes', scopes, 'code_challenge', code_challenge, 'redirect_uri', redirect_uri),
       expires_at, created_at
FROM public.mcp_auth_codes;
INSERT INTO public.auth_tokens (purpose, token_hash, payload, expires_at, created_at)
SELECT 'mcp_access_token', token_hash,
       jsonb_build_object('connection_id', connection_id),
       expires_at, created_at
FROM public.mcp_access_tokens;
INSERT INTO public.auth_tokens (purpose, token_hash, org_id, user_id, payload, expires_at, created_at)
SELECT 'gitlab_oauth_state', state, org_id, user_id,
       jsonb_build_object('code_verifier', code_verifier, 'redirect_to', redirect_to),
       expires_at, created_at
FROM public.gitlab_oauth_states;

DROP TABLE public.email_verifications;
DROP TABLE public.password_reset_tokens;
DROP TABLE public.oauth_exchanges;
DROP TABLE public.calendar_feed_tokens;
DROP TABLE public.mcp_auth_codes;
DROP TABLE public.mcp_access_tokens;
DROP TABLE public.gitlab_oauth_states;

-- ── messages (mentor_chat_messages + mentor_direct_messages + support_ticket_messages) ──
CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  thread_type text NOT NULL CHECK (thread_type IN ('mentor_ticket', 'mentor_conversation', 'support_ticket')),
  thread_id uuid NOT NULL,
  sender_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_messages_thread ON public.messages (thread_type, thread_id, created_at);

INSERT INTO public.messages (org_id, thread_type, thread_id, sender_id, body, created_at)
SELECT org_id, 'mentor_ticket', ticket_id, sender_id, body, created_at FROM public.mentor_chat_messages;
INSERT INTO public.messages (org_id, thread_type, thread_id, sender_id, body, created_at)
SELECT org_id, 'mentor_conversation', conversation_id, sender_id, body, created_at FROM public.mentor_direct_messages;
INSERT INTO public.messages (org_id, thread_type, thread_id, sender_id, body, created_at)
SELECT org_id, 'support_ticket', ticket_id, sender_id, body, created_at FROM public.support_ticket_messages;

DROP TABLE public.mentor_chat_messages;
DROP TABLE public.mentor_direct_messages;
DROP TABLE public.support_ticket_messages;

-- ── comments (wiki_comments + interview_exp_comments) ──
CREATE TABLE public.comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_type text NOT NULL CHECK (subject_type IN ('wiki_page', 'interview_exp_qna')),
  subject_id uuid NOT NULL,
  parent_id uuid REFERENCES public.comments(id) ON DELETE CASCADE,
  author_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_comments_subject ON public.comments (subject_type, subject_id, created_at);

-- wiki_comments.parent_id and interview_exp_comments.parent_id both point
-- within their own original table; each gets a two-pass insert through a
-- temp id map so parent links survive the merge into shared comment ids.
CREATE TEMP TABLE _wiki_comment_id_map (old_id uuid PRIMARY KEY, new_id uuid NOT NULL);

INSERT INTO _wiki_comment_id_map (old_id, new_id)
SELECT id, gen_random_uuid() FROM public.wiki_comments;

INSERT INTO public.comments (id, subject_type, subject_id, parent_id, author_id, content, created_at, updated_at, deleted_at)
SELECT m.new_id, 'wiki_page', wc.page_id, pm.new_id, wc.author_id, wc.content, wc.created_at, wc.updated_at, wc.deleted_at
FROM public.wiki_comments wc
JOIN _wiki_comment_id_map m ON m.old_id = wc.id
LEFT JOIN _wiki_comment_id_map pm ON pm.old_id = wc.parent_id;

DROP TABLE _wiki_comment_id_map;

CREATE TEMP TABLE _interview_exp_comment_id_map (old_id uuid PRIMARY KEY, new_id uuid NOT NULL);

INSERT INTO _interview_exp_comment_id_map (old_id, new_id)
SELECT id, gen_random_uuid() FROM public.interview_exp_comments;

INSERT INTO public.comments (id, subject_type, subject_id, parent_id, author_id, content, created_at, updated_at, deleted_at)
SELECT m.new_id, 'interview_exp_qna', iec.qna_id, pm.new_id, iec.author_id, iec.content, iec.created_at, iec.updated_at, iec.deleted_at
FROM public.interview_exp_comments iec
JOIN _interview_exp_comment_id_map m ON m.old_id = iec.id
LEFT JOIN _interview_exp_comment_id_map pm ON pm.old_id = iec.parent_id;

DROP TABLE _interview_exp_comment_id_map;

DROP TABLE public.wiki_comments;
DROP TABLE public.interview_exp_comments;

-- ── content_reactions (batch_message_reactions + interview_exp_votes) ──
CREATE TABLE public.content_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  target_type text NOT NULL CHECK (target_type IN ('batch_message', 'interview_exp_qna')),
  target_id uuid NOT NULL,
  reaction text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, target_type, target_id, reaction)
);

INSERT INTO public.content_reactions (user_id, target_type, target_id, reaction, created_at)
SELECT user_id, 'batch_message', message_id, reaction, created_at FROM public.batch_message_reactions;
INSERT INTO public.content_reactions (user_id, target_type, target_id, reaction, created_at)
SELECT user_id, 'interview_exp_qna', target_id, CASE WHEN value > 0 THEN 'up' ELSE 'down' END, created_at
FROM public.interview_exp_votes WHERE target_type = 'qna';

DROP TABLE public.batch_message_reactions;
DROP TABLE public.interview_exp_votes;

-- ── content_versions (question_versions + wiki_page_versions) ──
CREATE TABLE public.content_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type text NOT NULL CHECK (content_type IN ('question', 'wiki_page')),
  content_id uuid NOT NULL,
  version integer NOT NULL,
  title text,
  content jsonb NOT NULL,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (content_type, content_id, version)
);

INSERT INTO public.content_versions (content_type, content_id, version, content, created_by, created_at)
SELECT 'question', question_id, version, content, created_by, created_at FROM public.question_versions;
INSERT INTO public.content_versions (content_type, content_id, version, title, content, created_by, created_at)
SELECT 'wiki_page', page_id, version, title, content, saved_by, saved_at FROM public.wiki_page_versions;

DROP TABLE public.wiki_page_versions;
-- question_versions kept as a view-compatible name is NOT done here —
-- assessment_questions.version_id still points at question_versions(id).
-- Repoint that FK to content_versions before dropping question_versions:
ALTER TABLE public.assessment_questions ADD COLUMN IF NOT EXISTS content_version_id uuid REFERENCES public.content_versions(id);
UPDATE public.assessment_questions aq
SET content_version_id = cv.id
FROM public.content_versions cv, public.question_versions qv
WHERE aq.version_id = qv.id AND cv.content_type = 'question' AND cv.content_id = qv.question_id AND cv.version = qv.version;
-- Cut the app over to content_version_id, then in a follow-up migration:
--   ALTER TABLE assessment_questions DROP COLUMN version_id;
--   DROP TABLE question_versions;

-- ── wiki_templates folds into wiki_pages ──
ALTER TABLE public.wiki_pages ADD COLUMN IF NOT EXISTS is_template boolean NOT NULL DEFAULT false;
ALTER TABLE public.wiki_pages ALTER COLUMN space_id DROP NOT NULL;

INSERT INTO public.wiki_pages (space_id, title, slug, content, is_template, created_by, created_at, updated_at)
SELECT NULL, name, lower(replace(name, ' ', '-')), content, true, created_by, created_at, created_at
FROM public.wiki_templates
WHERE created_by IS NOT NULL;

DROP TABLE public.wiki_templates;

-- ── content_reports absorbs mentor_reports ──
ALTER TABLE public.content_reports ADD COLUMN IF NOT EXISTS resolved_at timestamp with time zone;
ALTER TABLE public.content_reports DROP CONSTRAINT IF EXISTS content_reports_content_type_check;
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_content_type_check
  CHECK (content_type IN ('wiki_page', 'course_module', 'mentor', 'user'));

INSERT INTO public.content_reports (org_id, reporter_id, content_type, content_id, reason, description, status, resolution_note, resolved_by, resolved_at, created_at)
SELECT org_id, reporter_id, 'mentor', mentor_id, reason, description, status, resolution_note, resolved_by, resolved_at, created_at
FROM public.mentor_reports;

DROP TABLE public.mentor_reports;

-- ── change_requests (mentor_change_requests + course_content_proposals) ──
CREATE TABLE public.change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('mentor_reassignment', 'course_content_proposal')),
  requester_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subject_type text,
  subject_id uuid,
  requested_change jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  review_note text,
  reviewed_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  result_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_change_requests_org_status ON public.change_requests (org_id, status);

INSERT INTO public.change_requests (org_id, kind, requester_id, subject_type, subject_id, requested_change, status, review_note, reviewed_by, reviewed_at, created_at)
SELECT org_id, 'mentor_reassignment', student_id, 'mentor_ticket', ticket_id,
       jsonb_build_object('reason', reason), status, review_note, reviewed_by, reviewed_at, created_at
FROM public.mentor_change_requests;

INSERT INTO public.change_requests (org_id, kind, requester_id, subject_type, subject_id, requested_change, status, review_note, reviewed_by, reviewed_at, result_id, created_at)
SELECT org_id, 'course_content_proposal', proposer_id, 'course', target_course_id,
       jsonb_build_object('title', title, 'type', type, 'body', content_body), status,
       review_note, reviewed_by, reviewed_at, created_module_id, created_at
FROM public.course_content_proposals;

DROP TABLE public.mentor_change_requests;
DROP TABLE public.course_content_proposals;

-- ── feedback absorbs course_reviews, experience_reports, mentor_session_feedback ──
ALTER TABLE public.feedback ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'rating';
ALTER TABLE public.feedback DROP CONSTRAINT IF EXISTS feedback_subject_type_check;
ALTER TABLE public.feedback ADD CONSTRAINT feedback_subject_type_check
  CHECK (subject_type IN ('course', 'mentor_session', 'experience_subject'));

INSERT INTO public.feedback (org_id, subject_type, subject_id, user_id, kind, rating, comment, created_at, updated_at)
SELECT NULL, 'course', course_id, user_id, 'rating', rating, NULL, created_at, created_at
FROM public.course_reviews;

INSERT INTO public.feedback (org_id, subject_type, subject_id, user_id, kind, comment, skipped_at, created_at, updated_at)
SELECT org_id, subject_type, subject_id, user_id, 'experience', description, skipped_at, created_at, updated_at
FROM public.experience_reports;

INSERT INTO public.feedback (subject_type, subject_id, user_id, kind, rating, comment, created_at, updated_at)
SELECT 'mentor_session', session_id, author_id, 'rating', rating, comment, created_at, updated_at
FROM public.mentor_session_feedback;

DROP TABLE public.course_reviews;
DROP TABLE public.experience_reports;
DROP TABLE public.mentor_session_feedback;

-- ── audit_logs absorbs mcp_action_log ──
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'web';
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS source text DEFAULT 'app';
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS connection_id uuid;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS revertible boolean NOT NULL DEFAULT false;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS reverted_at timestamptz;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS reverted_by uuid;

INSERT INTO public.audit_logs (org_id, actor_user_id, action, target_type, target_id, before_state, after_state, source, connection_id, revertible, reverted_at, reverted_by, created_at)
SELECT org_id, user_id, tool_name, target_type, target_id, before_state, after_state,
       'mcp', connection_id, revertible, reverted_at, reverted_by, created_at
FROM public.mcp_action_log;

DROP TABLE public.mcp_action_log;

-- ── conversations (mentor_tickets + support_tickets + mentor_conversations) ──
CREATE TABLE public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('mentorship', 'support', 'direct')),
  requester_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  counterpart_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  course_id uuid REFERENCES public.courses(id) ON DELETE SET NULL,
  purchase_id uuid,
  subject text,
  category text,
  priority text,
  status text NOT NULL DEFAULT 'open',
  assigned_to uuid REFERENCES public.users(id) ON DELETE SET NULL,
  escalation_level integer NOT NULL DEFAULT 0,
  resolved_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX idx_conversations_direct_pair
  ON public.conversations (org_id, requester_id, counterpart_id) WHERE kind = 'direct';
CREATE INDEX idx_conversations_org_status ON public.conversations (org_id, status);

INSERT INTO public.conversations (id, org_id, kind, requester_id, counterpart_id, course_id, purchase_id, status, assigned_to, escalation_level, closed_at, created_at)
SELECT id, org_id, 'mentorship', student_id, assigned_mentor_id, course_id, purchase_id, status, assigned_mentor_id, escalation_level, closed_at, created_at
FROM public.mentor_tickets;

INSERT INTO public.conversations (id, org_id, kind, requester_id, subject, category, priority, status, assigned_to, resolved_at, created_at)
SELECT id, org_id, 'support', user_id, subject, category, priority, status, assigned_to, resolved_at, created_at
FROM public.support_tickets;

INSERT INTO public.conversations (id, org_id, kind, requester_id, counterpart_id, status, created_at)
SELECT id, org_id, 'direct', student_id, mentor_id, 'open', created_at
FROM public.mentor_conversations;

-- messages.thread_id points at mentor_tickets/support_tickets/mentor_conversations
-- ids, which are now carried into conversations.id via the explicit id column
-- above, so thread_id resolves against conversations.id unchanged.

DROP TABLE public.mentor_ticket_assignments; -- superseded by conversations.assigned_to; history not preserved (see review §11 — decide if history matters before dropping in prod)
DROP TABLE public.mentor_tickets;
DROP TABLE public.support_tickets;
DROP TABLE public.mentor_conversations;


-- ═════════════════════════════════════════════════════════════════════════
-- PHASE 3 — assessment engine unification, purchases unification
-- ═════════════════════════════════════════════════════════════════════════

-- ── final_tests/final_test_attempts retire into assessments/assessment_attempts ──
INSERT INTO public.assessments (org_id, title, type, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, created_by, created_at, updated_at)
SELECT c.org_id, c.title || ' — Final Test', 'final_test', 'course', ft.course_id,
       ft.time_limit_minutes, ft.passing_score_percent, ft.max_attempts, NULL, ft.created_at, ft.updated_at
FROM public.final_tests ft
JOIN public.courses c ON c.id = ft.course_id;

-- final_test_attempts -> assessment_attempts, keyed via the new assessment row
INSERT INTO public.assessment_attempts (assessment_id, user_id, org_id, status, score, max_score, percentage, passed, started_at, submitted_at, snapshot, created_at, updated_at)
SELECT a.id, fta.user_id, c.org_id, 'submitted', fta.score, fta.total, (fta.score::numeric(5,2) / fta.total * 100), fta.passed,
       NULL, fta.completed_at, fta.answers, fta.completed_at, fta.completed_at
FROM public.final_test_attempts fta
JOIN public.final_tests ft ON ft.id = fta.final_test_id
JOIN public.courses c ON c.id = ft.course_id
JOIN public.assessments a ON a.parent_id = ft.course_id AND a.type = 'final_test';

-- certificates.final_test_attempt_id repoint, matched via the exact
-- (user_id, assessment_id, started_at) triple.
ALTER TABLE public.certificates ADD COLUMN IF NOT EXISTS assessment_attempt_id uuid REFERENCES public.assessment_attempts(id);

UPDATE public.certificates c
SET assessment_attempt_id = aa.id
FROM public.final_test_attempts fta
JOIN public.final_tests ft ON ft.id = fta.final_test_id
JOIN public.assessments a ON a.parent_id = ft.course_id AND a.type = 'final_test'
JOIN public.assessment_attempts aa ON aa.assessment_id = a.id AND aa.user_id = fta.user_id AND aa.submitted_at = fta.completed_at
WHERE c.final_test_attempt_id = fta.id;

DO $$
DECLARE missing_count integer;
BEGIN
  SELECT count(*) INTO missing_count
  FROM public.certificates
  WHERE final_test_attempt_id IS NOT NULL AND assessment_attempt_id IS NULL;

  IF missing_count > 0 THEN
    RAISE EXCEPTION '% certificates have final_test_attempt_id set but assessment_attempt_id is NULL after backfill', missing_count;
  END IF;
END $$;

ALTER TABLE public.certificates DROP CONSTRAINT IF EXISTS certificates_attempt_fk;
DROP TABLE public.final_test_attempts;
DROP TABLE public.final_tests;

-- ── public_attempts folds into assessment_attempts (nullable user_id) ──
ALTER TABLE public.assessment_attempts ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.assessment_attempts ADD COLUMN IF NOT EXISTS anonymous_identity jsonb;
ALTER TABLE public.assessment_attempts ADD COLUMN IF NOT EXISTS overridden_by uuid;
ALTER TABLE public.assessment_attempts ADD COLUMN IF NOT EXISTS override_note text;
ALTER TABLE public.assessment_attempts ADD COLUMN IF NOT EXISTS overridden_at timestamp with time zone;

INSERT INTO public.assessment_attempts (assessment_id, user_id, status, score, max_score, percentage, passed, started_at, submitted_at, active_session_token, anonymous_identity, overridden_by, override_note, created_at, updated_at)
SELECT assessment_id, NULL, status, score, max_score, percentage, passed, started_at, submitted_at, session_token,
       jsonb_build_object('name', name, 'email', email, 'phone', phone), overridden_by, override_note, now(), now()
FROM public.public_attempts;

DROP TABLE public.public_attempts;

-- ── offline_test_scores folds into assessments/assessment_attempts ──
INSERT INTO public.assessments (org_id, title, type, parent_type, parent_id, total_points, created_at, updated_at)
SELECT DISTINCT org_id, test_name, 'offline', 'batch', batch_id, max_score, now(), now()
FROM public.offline_test_scores;

INSERT INTO public.assessment_attempts (assessment_id, user_id, org_id, status, score, max_score, submitted_at, created_at, updated_at)
SELECT a.id, ots.user_id, ots.org_id, 'evaluated', ots.score, ots.max_score, ots.test_date, ots.test_date, ots.test_date
FROM public.offline_test_scores ots
JOIN public.assessments a ON a.parent_id = ots.batch_id AND a.type = 'offline' AND a.title = ots.test_name;

DROP TABLE public.offline_test_scores;

-- ── practice_sessions/practice_items -> assessment_attempts/attempt_answers ──
INSERT INTO public.assessments (org_id, title, type, created_by, created_at, updated_at)
SELECT NULL, technology || ' practice', 'practice', NULL, created_at, created_at
FROM public.practice_sessions;
-- NOTE: practice is ephemeral/per-session (no shared parent) — each practice
-- session becomes its own single-use assessments row. This trades a small
-- amount of table bloat in `assessments` for full gradebook integration;
-- acceptable per the review's tradeoff discussion in §14.

ALTER TABLE public.interview_prep_rounds DROP CONSTRAINT IF EXISTS interview_prep_rounds_practice_session_id_fkey;
DROP TABLE public.practice_items;
DROP TABLE public.practice_sessions;
-- practice_question_bank intentionally kept (AI cache, not an attempt table).

-- ── purchases (course_purchases renamed, absorbs session_pack_purchases) ──
ALTER TABLE public.course_purchases RENAME TO purchases;
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS product_type text NOT NULL DEFAULT 'course';
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS pack_id uuid;
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS granted jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS created_at timestamp with time zone;
ALTER TABLE public.purchases ADD COLUMN IF NOT EXISTS completed_at timestamp with time zone;
-- Backfill created_at from purchased_at
UPDATE public.purchases SET created_at = purchased_at WHERE created_at IS NULL;
ALTER TABLE public.purchases ALTER COLUMN created_at SET NOT NULL;
ALTER TABLE public.purchases ALTER COLUMN course_id DROP NOT NULL;

DROP INDEX IF EXISTS idx_course_purchases_user_course_completed;
CREATE UNIQUE INDEX idx_purchases_user_course_completed
  ON public.purchases (user_id, course_id) WHERE status = 'completed' AND product_type = 'course';

INSERT INTO public.purchases (org_id, user_id, product_type, pack_id, amount_cents, currency, provider, provider_ref, payment_ref, status, granted, created_at, completed_at)
SELECT org_id, user_id, 'session_pack', pack_id, amount_cents, currency, provider, provider_ref, payment_ref, status,
       jsonb_build_object('session_count', sessions), created_at, completed_at
FROM public.session_pack_purchases;

ALTER TABLE public.session_credit_ledger DROP CONSTRAINT IF EXISTS session_credit_ledger_purchase_id_fkey;
DROP TABLE public.session_pack_purchases;


-- ═════════════════════════════════════════════════════════════════════════
-- PHASE 4 — content_assignments, roadmap flatten, calendar/annotations/gitlab
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.content_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type text NOT NULL CHECK (content_type IN ('assessment', 'course', 'lab', 'sheet', 'roadmap')),
  content_id uuid NOT NULL,
  assignee_type text NOT NULL CHECK (assignee_type IN ('user', 'batch', 'cohort_group', 'org')),
  assignee_id uuid NOT NULL,
  due_at timestamptz,
  available_from timestamptz,
  assigned_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  assigned_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_content_assignments_assignee ON public.content_assignments (assignee_type, assignee_id);
CREATE INDEX idx_content_assignments_content ON public.content_assignments (content_type, content_id);

INSERT INTO public.content_assignments (content_type, content_id, assignee_type, assignee_id, due_at, assigned_by, assigned_at)
SELECT 'assessment', assessment_id, assignee_type, assignee_id, due_at, assigned_by, assigned_at
FROM public.assessment_assignments;

INSERT INTO public.content_assignments (content_type, content_id, assignee_type, assignee_id, assigned_by, assigned_at)
SELECT 'course', course_id, 'batch', batch_id, assigned_by, assigned_at
FROM public.batch_courses;

DROP TABLE public.assessment_assignments;
DROP TABLE public.batch_courses;

-- ── roadmaps flatten (roadmap_phases/milestones/modules -> structure JSONB) ──
ALTER TABLE public.roadmaps ADD COLUMN IF NOT EXISTS structure jsonb NOT NULL DEFAULT '{}'::jsonb;

UPDATE public.roadmaps r SET structure = agg.structure
FROM (
  SELECT rp.roadmap_id, jsonb_build_object(
    'phases', jsonb_agg(jsonb_build_object(
      'id', rp.id, 'title', rp.title, 'description', rp.description,
      'position', rp.position, 'estimated_weeks', rp.estimated_weeks,
      'milestones', (
        SELECT jsonb_agg(jsonb_build_object(
          'id', rm.id, 'title', rm.title, 'description', rm.description,
          'position', rm.position, 'estimated_hours', rm.estimated_hours,
          'modules', (
            SELECT jsonb_agg(jsonb_build_object(
              'id', rmo.id, 'title', rmo.title, 'type', rmo.module_type,
              'position', rmo.position, 'resource_type', rmo.resource_type,
              'resource_id', rmo.resource_id, 'completed_at', rmo.completed_at
            ) ORDER BY rmo.position)
            FROM public.roadmap_modules rmo WHERE rmo.milestone_id = rm.id
          )
        ) ORDER BY rm.position)
        FROM public.roadmap_milestones rm WHERE rm.phase_id = rp.id
      )
    ) ORDER BY rp.position)
  ) AS structure
  FROM public.roadmap_phases rp
  GROUP BY rp.roadmap_id
) agg
WHERE agg.roadmap_id = r.id;

CREATE TABLE public.roadmap_module_progress (
  roadmap_id uuid NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE,
  module_key uuid NOT NULL,
  completed_at timestamptz,
  PRIMARY KEY (roadmap_id, module_key)
);

INSERT INTO public.roadmap_module_progress (roadmap_id, module_key, completed_at)
SELECT rp.roadmap_id, rmo.id, rmo.completed_at
FROM public.roadmap_modules rmo
JOIN public.roadmap_milestones rm ON rm.id = rmo.milestone_id
JOIN public.roadmap_phases rp ON rp.id = rm.phase_id
WHERE rmo.completed_at IS NOT NULL;

DROP TABLE public.roadmap_modules;
DROP TABLE public.roadmap_milestones;
DROP TABLE public.roadmap_phases;

-- ── calendar_event_attendees absorbs calendar_event_invites ──
ALTER TABLE public.calendar_event_attendees DROP CONSTRAINT calendar_event_attendees_pkey;
ALTER TABLE public.calendar_event_attendees ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.calendar_event_attendees ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.calendar_event_attendees ADD CONSTRAINT calendar_event_attendees_subject_chk
  CHECK ((user_id IS NOT NULL) <> (email IS NOT NULL));
CREATE UNIQUE INDEX idx_calendar_event_attendees_event_user_email
  ON public.calendar_event_attendees (event_id, user_id, email);

INSERT INTO public.calendar_event_attendees (event_id, email, role, rsvp_status)
SELECT event_id, email, role, CASE WHEN accepted_at IS NOT NULL THEN 'accepted' ELSE 'pending' END
FROM public.calendar_event_invites;

INSERT INTO public.auth_tokens (purpose, token_hash, payload, expires_at, consumed_at)
SELECT 'calendar_invite', token_hash,
       jsonb_build_object('event_id', event_id, 'email', email, 'role', role),
       expires_at, accepted_at
FROM public.calendar_event_invites
WHERE token_hash IS NOT NULL;

DROP TABLE public.calendar_event_invites;

-- ── learning_annotations (lesson_notes + lesson_reflections + mistake_entries + highlights) ──
CREATE TABLE public.learning_annotations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  source_type text NOT NULL,
  source_id uuid NOT NULL,
  annotation_type text NOT NULL CHECK (annotation_type IN ('note', 'reflection', 'highlight', 'mistake')),
  text text NOT NULL,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  saved_for_revision boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_learning_annotations_user_source ON public.learning_annotations (user_id, source_type, source_id);

INSERT INTO public.learning_annotations (org_id, user_id, source_type, source_id, annotation_type, text, meta, created_at)
SELECT org_id, user_id, 'module', module_id, 'note', content, jsonb_build_object('source', source), created_at FROM public.lesson_notes;
INSERT INTO public.learning_annotations (org_id, user_id, source_type, source_id, annotation_type, text, meta, created_at)
SELECT org_id, user_id, 'module', module_id, 'reflection', response, jsonb_build_object('source', source), created_at FROM public.lesson_reflections;
INSERT INTO public.learning_annotations (user_id, source_type, source_id, annotation_type, text, meta, resolved_at, created_at)
SELECT user_id, 'module', source_module_id, 'mistake', original_text,
       jsonb_build_object('category', category, 'corrected_text', corrected_text), resolved_at, created_at
FROM public.mistake_entries;
INSERT INTO public.learning_annotations (id, user_id, source_type, source_id, annotation_type, text, meta, saved_for_revision, created_at)
SELECT id, user_id, source_type, source_id, 'highlight', selected_text, jsonb_build_object('note', note), saved_for_revision, created_at
FROM public.highlights;

-- srs_cards.mistake_entry_id repoint
ALTER TABLE public.srs_cards ADD COLUMN IF NOT EXISTS annotation_id uuid REFERENCES public.learning_annotations(id);
-- id mapping for mistake_entries rows needs the backfill script (learning_annotations
-- generates new ids for the first three sources above; highlights keeps its id).

ALTER TABLE public.srs_cards DROP CONSTRAINT IF EXISTS srs_cards_mistake_entry_fk;
DROP TABLE public.lesson_notes;
DROP TABLE public.lesson_reflections;
DROP TABLE public.mistake_entries;
DROP TABLE public.highlights;

-- ── gitlab: fold issues/pipelines into a raw mirror, mr_reviews into merge_requests JSONB ──
CREATE TABLE public.gitlab_objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  team_id uuid REFERENCES public.project_teams(id) ON DELETE CASCADE,
  object_type text NOT NULL CHECK (object_type IN ('issue', 'pipeline', 'note')),
  gitlab_id bigint NOT NULL,
  payload jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, object_type, gitlab_id)
);

INSERT INTO public.gitlab_objects (org_id, team_id, object_type, gitlab_id, payload, updated_at)
SELECT org_id, team_id, 'issue', issue_id, to_jsonb(gi), updated_at FROM public.gitlab_issues gi;
INSERT INTO public.gitlab_objects (org_id, team_id, object_type, gitlab_id, payload, updated_at)
SELECT org_id, team_id, 'pipeline', pipeline_id, to_jsonb(gp), updated_at FROM public.gitlab_pipelines gp;

ALTER TABLE public.gitlab_merge_requests ADD COLUMN IF NOT EXISTS reviews jsonb NOT NULL DEFAULT '[]'::jsonb;
UPDATE public.gitlab_merge_requests mr SET reviews = agg.reviews
FROM (
  SELECT merge_request_id, jsonb_agg(to_jsonb(r)) AS reviews
  FROM public.gitlab_mr_reviews r GROUP BY merge_request_id
) agg
WHERE agg.merge_request_id = mr.id;

DROP TABLE public.gitlab_issues;
DROP TABLE public.gitlab_pipelines;
DROP TABLE public.gitlab_mr_reviews;

-- ── project_handoffs folds into jobs ──
INSERT INTO public.jobs (org_id, handler, payload, status, created_at)
SELECT org_id, 'project_handoff',
       jsonb_build_object('team_id', team_id, 'mode', mode, 'target_namespace_id', target_namespace_id, 'target_namespace_path', target_namespace_path),
       status, requested_at
FROM public.project_handoffs;

DROP TABLE public.project_handoffs;


-- ═════════════════════════════════════════════════════════════════════════
-- PHASE 5 — partitioning prep (structure only; backfill/attach is an
-- operational runbook step, not safely expressible as a blind migration
-- against an unknown-size production table)
-- ═════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE public.attempt_events IS 'Partitioning candidate — monthly range on created_at. See docs/schema-refactor-plan.md Phase 5.';
COMMENT ON TABLE public.audit_logs IS 'Partitioning candidate — monthly range on created_at.';
COMMENT ON TABLE public.xp_events IS 'Partitioning candidate — monthly range on created_at.';
COMMENT ON TABLE public.notifications IS 'Partitioning candidate — monthly range on created_at.';
COMMENT ON TABLE public.lab_usage_events IS 'Partitioning candidate — monthly range on created_at.';
COMMENT ON TABLE public.srs_reviews IS 'Partitioning candidate — monthly range on reviewed_at.';
COMMENT ON TABLE public.gitlab_webhook_events IS 'Retention candidate — drop processed rows after 30 days.';
COMMENT ON TABLE public.job_runs IS 'Retention candidate — drop after 90 days.';
COMMENT ON TABLE public.idempotency_keys IS 'Retention candidate — drop after 24-48 hours (TTL sweep, no sweep job exists yet).';
-- Actual partitioning (CREATE TABLE ... PARTITION BY RANGE + pg_partman or
-- manual monthly attach) requires a maintenance window sized to each
-- table's real row count in production and is intentionally left as a
-- follow-up runbook, not blind DDL in this file.
