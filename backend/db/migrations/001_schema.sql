-- ════════════════════════════════════════════════════════════════════════════
-- 001_schema.sql — Consolidated MindForge Database Schema
-- Replaces migrations 001–018 with the final resolved state.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Extensions ──────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- ─── Shared trigger function ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- CORE: Organizations & Users
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE organizations (
  id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                    TEXT        NOT NULL UNIQUE,
  name                    TEXT        NOT NULL,
  status                  TEXT        NOT NULL DEFAULT 'active',
  logo_url                TEXT,
  description             TEXT,
  seat_limit              INTEGER,
  active_member_count     INTEGER     NOT NULL DEFAULT 0,
  onboarding_step         INTEGER     NOT NULL DEFAULT 4,
  onboarding_completed_at TIMESTAMPTZ,
  activated_at            TIMESTAMPTZ DEFAULT now(),
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT orgs_status_check CHECK (status IN ('pending_verification','onboarding','active','suspended','archived')),
  CONSTRAINT orgs_slug_format  CHECK (slug ~ '^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$')
);

CREATE INDEX IF NOT EXISTS idx_organizations_status ON organizations (status);

CREATE TABLE users (
  id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  email           CITEXT  NOT NULL UNIQUE,
  name            TEXT    NOT NULL,
  password_hash   TEXT,
  avatar_url      TEXT,
  platform_role   TEXT    NOT NULL DEFAULT 'user'
                          CHECK (platform_role IN ('super_admin', 'user')),
  email_verified  BOOLEAN NOT NULL DEFAULT false,
  session_version INT     NOT NULL DEFAULT 1,
  max_sessions    INT     NOT NULL DEFAULT 2,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- role: final set includes 'owner' added in phase-4; 'student' was renamed to 'learner'
CREATE TABLE org_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
  role       TEXT NOT NULL DEFAULT 'learner'
             CHECK (role IN ('owner','admin','instructor','mentor','learner')),
  status     TEXT NOT NULL DEFAULT 'active'
             CHECK (status IN ('active','suspended','removed')),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (org_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_org_members_user    ON org_members (user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON org_members (user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_org_status ON org_members (org_id, status);

CREATE TABLE org_auth_config (
  org_id             UUID    PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  allow_password     BOOLEAN DEFAULT true,
  allow_google       BOOLEAN DEFAULT false,
  allow_github       BOOLEAN DEFAULT false,
  allow_microsoft    BOOLEAN DEFAULT false,
  allow_magic_link   BOOLEAN DEFAULT false,
  require_sso        BOOLEAN DEFAULT false,
  oidc_issuer_url    TEXT,
  oidc_client_id     TEXT,
  oidc_client_secret TEXT,
  saml_metadata_xml  TEXT,
  sso_enabled        BOOLEAN NOT NULL DEFAULT false,
  sso_provider       TEXT,
  password_policy    JSONB   NOT NULL DEFAULT '{}'::jsonb,
  allowed_domains    TEXT[]  NOT NULL DEFAULT '{}',
  updated_at         TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT org_auth_sso_provider_check CHECK (sso_provider IN ('google','azure_ad','okta','saml','oidc'))
);

-- ─── Auth tables ──────────────────────────────────────────────────────────────

CREATE TABLE refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  device_hint TEXT,
  ip          TEXT,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  rotated_at  TIMESTAMPTZ,
  family_id   UUID NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_revoked ON refresh_tokens (user_id, revoked_at);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family       ON refresh_tokens (family_id);

-- FK on user_id added inline (was retroactively added in migration 011)
CREATE TABLE jti_blocklist (
  jti        TEXT        PRIMARY KEY,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  reason     TEXT
);

CREATE INDEX IF NOT EXISTS idx_jti_blocklist_expires ON jti_blocklist (expires_at);
CREATE INDEX IF NOT EXISTS idx_jti_blocklist_user    ON jti_blocklist (user_id);

CREATE TABLE social_accounts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider     TEXT NOT NULL CHECK (provider IN ('google', 'github', 'microsoft')),
  provider_uid TEXT NOT NULL,
  email        TEXT,
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (provider, provider_uid)
);

CREATE INDEX IF NOT EXISTS idx_social_accounts_user ON social_accounts (user_id);

CREATE TABLE password_reset_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user ON password_reset_tokens (user_id);

CREATE TABLE email_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_email_verifications_user ON email_verifications (user_id);

-- ─── Seed: default org ────────────────────────────────────────────────────────
INSERT INTO organizations (id, slug, name, status)
VALUES ('00000000-0000-0000-0000-000000000001', 'default', 'MindForge', 'active')
ON CONFLICT DO NOTHING;

INSERT INTO org_auth_config (org_id, allow_password, allow_google, allow_github)
VALUES ('00000000-0000-0000-0000-000000000001', true, true, true)
ON CONFLICT DO NOTHING;

-- ─── OAuth exchange tokens ─────────────────────────────────────────────────────
CREATE TABLE oauth_exchanges (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  token                TEXT        NOT NULL UNIQUE,
  user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  onboarding_completed BOOLEAN     NOT NULL DEFAULT false,
  expires_at           TIMESTAMPTZ NOT NULL,
  used_at              TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_oauth_exchanges_expires ON oauth_exchanges (expires_at);
CREATE INDEX IF NOT EXISTS idx_oauth_exchanges_user    ON oauth_exchanges (user_id);

-- ════════════════════════════════════════════════════════════════════════════
-- USER PROFILES (combined from migrations 002, 003, 006)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE user_profiles (
  user_id                  UUID    PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,

  -- Onboarding wizard v1
  timeline                 TEXT,
  experience_level         TEXT,
  role_intent              TEXT,
  completed_at             TIMESTAMPTZ,

  -- Onboarding wizard v2
  learning_goal            TEXT,
  job_title                TEXT,
  topics_interest          TEXT[],
  weekly_time_commitment   TEXT,
  skill_level              TEXT,
  industry                 TEXT,
  career_goal              TEXT,

  -- Personalization preferences
  ui_theme                 TEXT    DEFAULT 'system'
                                   CHECK (ui_theme IN ('light', 'dark', 'system')),
  language                 TEXT    DEFAULT 'en',
  timezone                 TEXT,
  weekly_goal_hrs          SMALLINT,
  notifications            JSONB   DEFAULT '{}'::jsonb,
  meta                     JSONB   DEFAULT '{}'::jsonb,

  -- Public profile fields
  display_name             TEXT    UNIQUE,
  bio                      TEXT    CHECK (char_length(bio) <= 500),
  profile_slug             TEXT    UNIQUE,
  public_enabled           BOOLEAN NOT NULL DEFAULT false,
  show_skills              BOOLEAN NOT NULL DEFAULT true,
  show_achievements        BOOLEAN NOT NULL DEFAULT true,
  show_certificates        BOOLEAN NOT NULL DEFAULT true,
  show_activity            BOOLEAN NOT NULL DEFAULT true,
  "current_role"           TEXT,
  years_of_experience      SMALLINT CHECK (years_of_experience BETWEEN 0 AND 50),
  preferred_learning_style TEXT    CHECK (preferred_learning_style IN ('video', 'reading', 'hands_on', 'mixed')),

  created_at               TIMESTAMPTZ DEFAULT now(),
  updated_at               TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_slug ON user_profiles (profile_slug)
  WHERE profile_slug IS NOT NULL;

CREATE TRIGGER trg_user_profiles_updated_at
BEFORE UPDATE ON user_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE user_skills (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  skill_name  TEXT NOT NULL,
  skill_level TEXT NOT NULL CHECK (skill_level IN ('beginner', 'intermediate', 'advanced')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, skill_name)
);

CREATE INDEX IF NOT EXISTS idx_user_skills_user ON user_skills (user_id);

CREATE TABLE user_social_links (
  user_id    UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  linkedin   TEXT,
  github     TEXT,
  portfolio  TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE user_stats (
  user_id             UUID         PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  courses_enrolled    INT          NOT NULL DEFAULT 0,
  courses_completed   INT          NOT NULL DEFAULT 0,
  tests_attempted     INT          NOT NULL DEFAULT 0,
  problems_solved     INT          NOT NULL DEFAULT 0,
  certificates_earned INT          NOT NULL DEFAULT 0,
  current_streak_days INT          NOT NULL DEFAULT 0,
  learning_hours      NUMERIC(10,2) NOT NULL DEFAULT 0,
  roadmaps_completed  INT          NOT NULL DEFAULT 0,
  updated_at          TIMESTAMPTZ  DEFAULT now()
);

-- ════════════════════════════════════════════════════════════════════════════
-- ASSESSMENT DOMAIN (migration 005)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE batches (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  slug        TEXT NOT NULL,
  description TEXT,
  mentor_id   UUID REFERENCES users(id) ON DELETE SET NULL,
  status      TEXT NOT NULL DEFAULT 'active'
              CHECK (status IN ('active', 'archived')),
  created_by  UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_batches_org    ON batches (org_id, status);
CREATE INDEX IF NOT EXISTS idx_batches_mentor ON batches (mentor_id);

CREATE TABLE batch_members (
  id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  user_id  UUID NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (batch_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_batch_members_user ON batch_members (user_id);

CREATE TABLE question_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES organizations(id)      ON DELETE CASCADE,
  parent_id  UUID REFERENCES question_categories(id)         ON DELETE SET NULL,
  name       TEXT NOT NULL,
  slug       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_question_categories_org    ON question_categories (org_id);
CREATE INDEX IF NOT EXISTS idx_question_categories_parent ON question_categories (parent_id);

-- type: final set includes interview_prep (010) and subjective (013)
CREATE TABLE questions (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          UUID         NOT NULL REFERENCES organizations(id)      ON DELETE CASCADE,
  category_id     UUID         REFERENCES question_categories(id)         ON DELETE SET NULL,
  type            TEXT         NOT NULL
                               CHECK (type IN ('mcq', 'coding', 'interview_prep', 'subjective')),
  title           TEXT         NOT NULL,
  difficulty      TEXT         NOT NULL DEFAULT 'intermediate'
                               CHECK (difficulty IN ('beginner', 'intermediate', 'advanced', 'expert')),
  default_points  NUMERIC(7,2) NOT NULL DEFAULT 1 CHECK (default_points >= 0),
  tags            TEXT[]       NOT NULL DEFAULT '{}',
  status          TEXT         NOT NULL DEFAULT 'active'
                               CHECK (status IN ('active', 'archived')),
  current_version INT          NOT NULL DEFAULT 1,
  created_by      UUID         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_questions_org_type  ON questions (org_id, type, status);
CREATE INDEX IF NOT EXISTS idx_questions_category  ON questions (category_id);
CREATE INDEX IF NOT EXISTS idx_questions_tags      ON questions USING GIN (tags);

CREATE TABLE question_versions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID        NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  version     INT         NOT NULL,
  content     JSONB       NOT NULL,
  created_by  UUID        NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (question_id, version)
);

CREATE INDEX IF NOT EXISTS idx_question_versions_question ON question_versions (question_id, version DESC);

-- mock_mode added in 013
CREATE TABLE assessments (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id            UUID         NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title             TEXT         NOT NULL,
  slug              TEXT         NOT NULL,
  description       TEXT,
  type              TEXT         NOT NULL DEFAULT 'mcq'
                                 CHECK (type IN ('mcq', 'coding', 'mixed')),
  status            TEXT         NOT NULL DEFAULT 'draft'
                                 CHECK (status IN ('draft', 'published', 'scheduled', 'active', 'completed', 'archived')),
  parent_type       TEXT         NOT NULL DEFAULT 'standalone'
                                 CHECK (parent_type IN ('standalone', 'course', 'module', 'roadmap', 'batch', 'bootcamp')),
  parent_id         UUID,
  duration_minutes  INT          NOT NULL DEFAULT 30 CHECK (duration_minutes BETWEEN 1 AND 1440),
  pass_percentage   NUMERIC(5,2) NOT NULL DEFAULT 40  CHECK (pass_percentage BETWEEN 0 AND 100),
  max_attempts      INT          NOT NULL DEFAULT 1   CHECK (max_attempts BETWEEN 1 AND 100),
  total_points      NUMERIC(9,2) NOT NULL DEFAULT 0,
  shuffle_questions BOOLEAN      NOT NULL DEFAULT false,
  shuffle_options   BOOLEAN      NOT NULL DEFAULT false,
  allow_backtrack   BOOLEAN      NOT NULL DEFAULT true,
  show_results      BOOLEAN      NOT NULL DEFAULT true,
  mock_mode         BOOLEAN      NOT NULL DEFAULT false,
  starts_at         TIMESTAMPTZ,
  ends_at           TIMESTAMPTZ,
  proctoring        JSONB        NOT NULL DEFAULT '{}'::jsonb,
  created_by        UUID         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  published_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (org_id, slug),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_assessments_org_status ON assessments (org_id, status);
CREATE INDEX IF NOT EXISTS idx_assessments_parent     ON assessments (parent_type, parent_id);

CREATE TABLE assessment_questions (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID         NOT NULL REFERENCES assessments(id)      ON DELETE CASCADE,
  question_id   UUID         NOT NULL REFERENCES questions(id)        ON DELETE RESTRICT,
  version_id    UUID         NOT NULL REFERENCES question_versions(id) ON DELETE RESTRICT,
  position      INT          NOT NULL DEFAULT 0,
  points        NUMERIC(7,2) NOT NULL DEFAULT 1 CHECK (points >= 0),
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (assessment_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_assessment_questions_order ON assessment_questions (assessment_id, position);

CREATE TABLE assessment_assignments (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID        NOT NULL REFERENCES assessments(id) ON DELETE CASCADE,
  assignee_type TEXT        NOT NULL CHECK (assignee_type IN ('student', 'batch')),
  assignee_id   UUID        NOT NULL,
  due_at        TIMESTAMPTZ,
  assigned_by   UUID        NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (assessment_id, assignee_type, assignee_id)
);

CREATE INDEX IF NOT EXISTS idx_assignments_assignee   ON assessment_assignments (assignee_type, assignee_id);
CREATE INDEX IF NOT EXISTS idx_assignments_assessment ON assessment_assignments (assessment_id);

-- status: includes evaluating/eval_failed added in 013
CREATE TABLE assessment_attempts (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id      UUID         NOT NULL REFERENCES assessments(id)   ON DELETE CASCADE,
  user_id            UUID         NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  org_id             UUID         NOT NULL REFERENCES organizations(id)  ON DELETE CASCADE,
  attempt_number     INT          NOT NULL DEFAULT 1,
  status             TEXT         NOT NULL DEFAULT 'created'
                                  CHECK (status IN (
                                    'created', 'in_progress', 'submitted',
                                    'evaluating', 'evaluated', 'eval_failed', 'expired'
                                  )),
  started_at         TIMESTAMPTZ,
  submitted_at       TIMESTAMPTZ,
  evaluated_at       TIMESTAMPTZ,
  expires_at         TIMESTAMPTZ,
  duration_seconds   INT          NOT NULL DEFAULT 0,
  score              NUMERIC(9,2),
  max_score          NUMERIC(9,2),
  percentage         NUMERIC(5,2),
  passed             BOOLEAN,
  auto_submitted     BOOLEAN      NOT NULL DEFAULT false,
  snapshot           JSONB        NOT NULL DEFAULT '{}'::jsonb,
  proctoring_summary JSONB        NOT NULL DEFAULT '{}'::jsonb,
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (assessment_id, user_id, attempt_number)
);

CREATE INDEX IF NOT EXISTS idx_attempts_assessment         ON assessment_attempts (assessment_id, status);
CREATE INDEX IF NOT EXISTS idx_attempts_user               ON assessment_attempts (user_id, status);
CREATE INDEX IF NOT EXISTS idx_attempts_org                ON assessment_attempts (org_id);
CREATE INDEX IF NOT EXISTS idx_attempts_org_user           ON assessment_attempts (org_id, user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_assessment_created ON assessment_attempts (assessment_id, created_at DESC);

-- ai_feedback (010) and transcript (013) included from the start
CREATE TABLE attempt_answers (
  id                     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id             UUID         NOT NULL REFERENCES assessment_attempts(id)  ON DELETE CASCADE,
  assessment_question_id UUID         NOT NULL REFERENCES assessment_questions(id) ON DELETE CASCADE,
  question_id            UUID         NOT NULL REFERENCES questions(id)            ON DELETE RESTRICT,
  answer                 JSONB        NOT NULL DEFAULT '{}'::jsonb,
  ai_feedback            JSONB,
  transcript             TEXT         CHECK (transcript IS NULL OR length(transcript) <= 50000),
  is_correct             BOOLEAN,
  points_awarded         NUMERIC(7,2) NOT NULL DEFAULT 0,
  max_points             NUMERIC(7,2) NOT NULL DEFAULT 0,
  time_spent_seconds     INT          NOT NULL DEFAULT 0,
  evaluated_at           TIMESTAMPTZ,
  updated_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (attempt_id, assessment_question_id)
);

CREATE INDEX IF NOT EXISTS idx_attempt_answers_attempt ON attempt_answers (attempt_id);
CREATE INDEX IF NOT EXISTS idx_attempt_answers_aq      ON attempt_answers (assessment_question_id);

CREATE TABLE coding_submissions (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_answer_id UUID        NOT NULL REFERENCES attempt_answers(id) ON DELETE CASCADE,
  language          TEXT        NOT NULL,
  source_code       TEXT        NOT NULL,
  status            TEXT        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'running', 'passed', 'failed', 'error')),
  tests_total       INT         NOT NULL DEFAULT 0,
  tests_passed      INT         NOT NULL DEFAULT 0,
  runtime_ms        INT,
  memory_kb         INT,
  compile_output    TEXT,
  result            JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  evaluated_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_coding_submissions_answer ON coding_submissions (attempt_answer_id);
CREATE INDEX IF NOT EXISTS idx_coding_submissions_status ON coding_submissions (status);

CREATE TABLE attempt_events (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id UUID        NOT NULL REFERENCES assessment_attempts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id)               ON DELETE CASCADE,
  event_type TEXT        NOT NULL CHECK (event_type IN (
               'tab_switch', 'focus_loss', 'focus_gain', 'fullscreen_exit',
               'fullscreen_enter', 'copy', 'paste', 'cut', 'right_click',
               'devtools_open', 'visibility_hidden', 'visibility_visible',
               'window_resize', 'network_offline', 'heartbeat')),
  severity   TEXT        NOT NULL DEFAULT 'info'
             CHECK (severity IN ('info', 'warning', 'critical')),
  metadata   JSONB       NOT NULL DEFAULT '{}'::jsonb,
  client_ts  TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attempt_events_attempt ON attempt_events (attempt_id, created_at);
CREATE INDEX IF NOT EXISTS idx_attempt_events_type    ON attempt_events (attempt_id, event_type);
CREATE INDEX IF NOT EXISTS idx_attempt_events_user    ON attempt_events (user_id);

-- ════════════════════════════════════════════════════════════════════════════
-- COURSE DOMAIN (migration 007)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE courses (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          UUID         NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  creator_id      UUID         NOT NULL REFERENCES users(id)         ON DELETE RESTRICT,
  title           TEXT         NOT NULL CHECK (length(title) BETWEEN 3 AND 200),
  slug            TEXT         NOT NULL,
  description     TEXT         CHECK (length(description) <= 2000),
  cover_url       TEXT,
  difficulty      TEXT         NOT NULL DEFAULT 'beginner'
                               CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  tags            TEXT[]       NOT NULL DEFAULT '{}',
  status          TEXT         NOT NULL DEFAULT 'draft'
                               CHECK (status IN ('draft', 'review', 'published', 'archived')),
  forked_from_id  UUID         REFERENCES courses(id) ON DELETE SET NULL,
  price_cents     INT          NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
  is_free         BOOLEAN      NOT NULL DEFAULT true,
  estimated_hours NUMERIC(5,1) CHECK (estimated_hours > 0),
  created_at      TIMESTAMPTZ  DEFAULT now(),
  updated_at      TIMESTAMPTZ  DEFAULT now(),
  UNIQUE (org_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_courses_org_status ON courses (org_id, status);
CREATE INDEX IF NOT EXISTS idx_courses_tags        ON courses USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_courses_creator     ON courses (creator_id);

CREATE TABLE course_sections (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title      TEXT        NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  position   INT         NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (course_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX IF NOT EXISTS idx_course_sections_course ON course_sections (course_id, position);

CREATE TABLE course_modules (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id         UUID        NOT NULL REFERENCES courses(id)         ON DELETE CASCADE,
  section_id        UUID        NOT NULL REFERENCES course_sections(id) ON DELETE CASCADE,
  title             TEXT        NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  type              TEXT        NOT NULL
                                CHECK (type IN ('video', 'pdf', 'notes', 'assessment')),
  position          INT         NOT NULL DEFAULT 0,
  is_free_preview   BOOLEAN     NOT NULL DEFAULT false,
  storage_key       TEXT,
  duration_seconds  INT         CHECK (duration_seconds > 0),
  content_body      TEXT,
  assessment_id     UUID        REFERENCES assessments(id) ON DELETE SET NULL,
  estimated_minutes INT         CHECK (estimated_minutes > 0),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  deleted_at        TIMESTAMPTZ,
  UNIQUE (section_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX IF NOT EXISTS idx_course_modules_course     ON course_modules (course_id)        WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_course_modules_section    ON course_modules (section_id, position) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_course_modules_assessment ON course_modules (assessment_id)    WHERE assessment_id IS NOT NULL;

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

CREATE INDEX IF NOT EXISTS idx_enrollments_user   ON enrollments (user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON enrollments (course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_batch  ON enrollments (batch_id) WHERE batch_id IS NOT NULL;

CREATE TABLE module_progress (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID        NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
  module_id             UUID        NOT NULL REFERENCES course_modules(id) ON DELETE CASCADE,
  course_id             UUID        NOT NULL REFERENCES courses(id)        ON DELETE CASCADE,
  status                TEXT        NOT NULL DEFAULT 'not_started'
                                    CHECK (status IN ('not_started', 'in_progress', 'completed')),
  last_position_seconds INT         DEFAULT 0,
  completed_at          TIMESTAMPTZ,
  updated_at            TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, module_id)
);

CREATE INDEX IF NOT EXISTS idx_module_progress_user_course  ON module_progress (user_id, course_id);
CREATE INDEX IF NOT EXISTS idx_module_progress_module       ON module_progress (module_id);
CREATE INDEX IF NOT EXISTS idx_module_progress_user_status  ON module_progress (user_id, status);

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

-- ════════════════════════════════════════════════════════════════════════════
-- BATCH ENHANCEMENTS (migration 008)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE batch_mentors (
  id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID        NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  user_id  UUID        NOT NULL REFERENCES users(id)   ON DELETE RESTRICT,
  added_by UUID        NOT NULL REFERENCES users(id)   ON DELETE RESTRICT,
  added_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (batch_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_batch_mentors_batch ON batch_mentors (batch_id);
CREATE INDEX IF NOT EXISTS idx_batch_mentors_user  ON batch_mentors (user_id);

CREATE TABLE batch_courses (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id    UUID        NOT NULL REFERENCES batches(id)  ON DELETE CASCADE,
  course_id   UUID        NOT NULL REFERENCES courses(id)  ON DELETE CASCADE,
  assigned_by UUID        NOT NULL REFERENCES users(id)    ON DELETE RESTRICT,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (batch_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_batch_courses_batch  ON batch_courses (batch_id);
CREATE INDEX IF NOT EXISTS idx_batch_courses_course ON batch_courses (course_id);

CREATE TABLE batch_invitations (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id    UUID        NOT NULL REFERENCES batches(id)        ON DELETE CASCADE,
  org_id      UUID        NOT NULL REFERENCES organizations(id)  ON DELETE CASCADE,
  email       TEXT        NOT NULL,
  invited_by  UUID        NOT NULL REFERENCES users(id)          ON DELETE RESTRICT,
  token_hash  TEXT        NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  invited_at  TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  resent_at   TIMESTAMPTZ,
  UNIQUE (batch_id, email)
);

CREATE INDEX IF NOT EXISTS idx_batch_invitations_batch   ON batch_invitations (batch_id, accepted_at, declined_at);
CREATE INDEX IF NOT EXISTS idx_batch_invitations_expires ON batch_invitations (expires_at) WHERE accepted_at IS NULL AND declined_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_batch_invitations_email   ON batch_invitations (email, accepted_at);
CREATE INDEX IF NOT EXISTS idx_batch_invitations_org     ON batch_invitations (org_id);

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

-- ════════════════════════════════════════════════════════════════════════════
-- MESSAGING & FAQ (migration 009)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE batch_messages (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id    UUID        NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  sender_id   UUID        NOT NULL REFERENCES users(id)   ON DELETE RESTRICT,
  parent_id   UUID        REFERENCES batch_messages(id)   ON DELETE CASCADE,
  body        TEXT        NOT NULL CHECK (length(body) BETWEEN 1 AND 5000),
  type        TEXT        NOT NULL DEFAULT 'question'
              CHECK (type IN ('question', 'answer', 'announcement', 'resource')),
  is_pinned   BOOLEAN     NOT NULL DEFAULT false,
  is_resolved BOOLEAN     NOT NULL DEFAULT false,
  edited_at   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_batch_messages_batch_ts   ON batch_messages (batch_id, created_at DESC, id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_batch_messages_parent     ON batch_messages (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_batch_messages_pinned     ON batch_messages (batch_id, is_pinned) WHERE is_pinned = true AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_batch_messages_unresolved ON batch_messages (batch_id, is_resolved) WHERE is_resolved = false AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_batch_messages_sender     ON batch_messages (sender_id);

CREATE TABLE batch_message_reactions (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID        NOT NULL REFERENCES batch_messages(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  reaction   TEXT        NOT NULL CHECK (reaction IN ('upvote', 'helpful')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (message_id, user_id, reaction)
);

CREATE INDEX IF NOT EXISTS idx_batch_message_reactions_msg  ON batch_message_reactions (message_id);
CREATE INDEX IF NOT EXISTS idx_batch_message_reactions_user ON batch_message_reactions (user_id);

CREATE TABLE course_faqs (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id         UUID        NOT NULL REFERENCES courses(id)       ON DELETE CASCADE,
  org_id            UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  question          TEXT        NOT NULL CHECK (length(question) BETWEEN 10 AND 500),
  answer            TEXT        NOT NULL CHECK (length(answer) BETWEEN 10 AND 5000),
  ai_generated      BOOLEAN     NOT NULL DEFAULT false,
  source_message_id UUID        REFERENCES batch_messages(id) ON DELETE SET NULL,
  created_by        UUID        REFERENCES users(id) ON DELETE SET NULL,
  position          INT         NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_course_faqs_course     ON course_faqs (course_id, position);
CREATE INDEX IF NOT EXISTS idx_course_faqs_org        ON course_faqs (org_id);
CREATE INDEX IF NOT EXISTS idx_course_faqs_course_org ON course_faqs (course_id, org_id);

-- ════════════════════════════════════════════════════════════════════════════
-- AI PRACTICE (migration 010)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE practice_sessions (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  org_id         UUID        REFERENCES organizations(id)           ON DELETE CASCADE,
  technology     TEXT        NOT NULL CHECK (length(technology) BETWEEN 1 AND 100),
  difficulty     TEXT        NOT NULL DEFAULT 'intermediate'
                             CHECK (difficulty IN ('beginner', 'intermediate', 'advanced', 'expert')),
  question_count INT         NOT NULL DEFAULT 5 CHECK (question_count BETWEEN 1 AND 20),
  status         TEXT        NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active', 'completed', 'abandoned')),
  ai_model       TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  completed_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_practice_sessions_user_ts     ON practice_sessions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_practice_sessions_user_status ON practice_sessions (user_id, status);
CREATE INDEX IF NOT EXISTS idx_practice_sessions_org         ON practice_sessions (org_id) WHERE org_id IS NOT NULL;

CREATE TABLE practice_items (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID        NOT NULL REFERENCES practice_sessions(id) ON DELETE CASCADE,
  position      INT         NOT NULL DEFAULT 0,
  question_text TEXT        NOT NULL,
  user_answer   TEXT,
  ai_feedback   JSONB,
  answered_at   TIMESTAMPTZ,
  feedback_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (session_id, position)
);

CREATE INDEX IF NOT EXISTS idx_practice_items_session ON practice_items (session_id, position);

-- ════════════════════════════════════════════════════════════════════════════
-- ORGANIZATIONS PHASE 4 (migration 012)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE org_domains (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  domain              TEXT        NOT NULL,
  verified            BOOLEAN     NOT NULL DEFAULT false,
  verification_method TEXT        CHECK (verification_method IN ('dns_txt','email')),
  verification_token  TEXT        NOT NULL,
  verified_at         TIMESTAMPTZ,
  auto_join_enabled   BOOLEAN     NOT NULL DEFAULT false,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, domain)
);

CREATE INDEX IF NOT EXISTS idx_org_domains_org_id ON org_domains (org_id);

CREATE TABLE org_invites (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email               TEXT        NOT NULL,
  role                TEXT        NOT NULL CHECK (role IN ('admin','mentor','instructor','learner')),
  invited_by_user_id  UUID        NOT NULL REFERENCES users(id),
  token_hash          TEXT        NOT NULL UNIQUE,
  expires_at          TIMESTAMPTZ NOT NULL,
  accepted_at         TIMESTAMPTZ,
  accepted_by_user_id UUID        REFERENCES users(id),
  revoked_at          TIMESTAMPTZ,
  revoke_reason       TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_org_invite_pending ON org_invites (org_id, email)
  WHERE accepted_at IS NULL AND revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_org_invites_token_hash  ON org_invites (token_hash);
CREATE INDEX IF NOT EXISTS idx_org_invites_org_created ON org_invites (org_id, created_at DESC);

CREATE TABLE audit_logs (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  actor_user_id UUID        REFERENCES users(id),
  action        TEXT        NOT NULL,
  target_type   TEXT        NOT NULL,
  target_id     UUID,
  before_state  JSONB,
  after_state   JSONB,
  ip_address    INET,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_org_time ON audit_logs (org_id, created_at DESC);

CREATE TABLE idempotency_keys (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  idem_key      TEXT        NOT NULL,
  endpoint      TEXT        NOT NULL,
  user_id       UUID        REFERENCES users(id),
  request_hash  TEXT        NOT NULL,
  status_code   INTEGER     NOT NULL,
  response_body TEXT        NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (idem_key, endpoint, user_id)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_created ON idempotency_keys (created_at);

CREATE OR REPLACE FUNCTION update_active_member_count() RETURNS TRIGGER AS $$
DECLARE
  affected_org_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    affected_org_id := OLD.org_id;
  ELSE
    affected_org_id := NEW.org_id;
  END IF;
  UPDATE organizations SET active_member_count = (
    SELECT COUNT(*) FROM org_members WHERE org_id = affected_org_id AND status = 'active'
  ) WHERE id = affected_org_id;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_org_member_count
  AFTER INSERT OR UPDATE OR DELETE ON org_members
  FOR EACH ROW EXECUTE FUNCTION update_active_member_count();

CREATE OR REPLACE FUNCTION enforce_slug_immutable() RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status = 'active' AND NEW.slug <> OLD.slug THEN
    RAISE EXCEPTION 'org slug cannot be changed after activation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_org_slug_immutable
  BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION enforce_slug_immutable();

CREATE OR REPLACE FUNCTION enforce_last_owner() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF (OLD.role = 'owner' AND (NEW.status <> 'active' OR NEW.role <> 'owner')) THEN
      IF (SELECT COUNT(*) FROM org_members
          WHERE org_id = OLD.org_id AND role = 'owner' AND status = 'active' AND id <> OLD.id) = 0 THEN
        RAISE EXCEPTION 'cannot remove the last active owner of an organization';
      END IF;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.role = 'owner' AND OLD.status = 'active' THEN
      IF (SELECT COUNT(*) FROM org_members
          WHERE org_id = OLD.org_id AND role = 'owner' AND status = 'active' AND id <> OLD.id) = 0 THEN
        RAISE EXCEPTION 'cannot remove the last active owner of an organization';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_org_last_owner
  BEFORE UPDATE OR DELETE ON org_members
  FOR EACH ROW EXECUTE FUNCTION enforce_last_owner();

-- ════════════════════════════════════════════════════════════════════════════
-- INTERVIEW EVALUATION (migration 013)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE interview_evaluations (
  id                        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id                UUID         NOT NULL REFERENCES assessment_attempts(id) ON DELETE CASCADE,
  question_id               UUID         REFERENCES question_versions(id),
  scope                     TEXT         NOT NULL CHECK (scope IN ('question', 'overall')),
  score_technical_accuracy  NUMERIC(5,2),
  score_completeness        NUMERIC(5,2),
  score_communication       NUMERIC(5,2),
  score_clarity             NUMERIC(5,2),
  score_structure           NUMERIC(5,2),
  score_confidence          NUMERIC(5,2),
  score_seniority_alignment NUMERIC(5,2),
  composite_score           NUMERIC(5,2),
  readiness_score           NUMERIC(5,2),
  strengths                 TEXT[]       NOT NULL DEFAULT '{}',
  weaknesses                TEXT[]       NOT NULL DEFAULT '{}',
  missing_concepts          TEXT[]       NOT NULL DEFAULT '{}',
  incorrect_concepts        TEXT[]       NOT NULL DEFAULT '{}',
  improvements              TEXT[]       NOT NULL DEFAULT '{}',
  better_answer             TEXT,
  reference_comparison      TEXT,
  injection_detected        BOOLEAN      NOT NULL DEFAULT false,
  injection_score           INT          NOT NULL DEFAULT 0,
  review_required           BOOLEAN      NOT NULL DEFAULT false,
  ai_model                  TEXT,
  created_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (attempt_id, question_id, scope)
);

CREATE INDEX IF NOT EXISTS idx_interview_evals_attempt ON interview_evaluations (attempt_id, scope);
CREATE INDEX IF NOT EXISTS idx_interview_evals_review  ON interview_evaluations (review_required) WHERE review_required = true;

CREATE TABLE interview_skill_scores (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id      UUID         NOT NULL REFERENCES assessment_attempts(id) ON DELETE CASCADE,
  user_id         UUID         NOT NULL REFERENCES users(id),
  org_id          UUID         NOT NULL REFERENCES organizations(id),
  skill           TEXT         NOT NULL CHECK (length(skill) BETWEEN 1 AND 100),
  composite_score NUMERIC(5,2) NOT NULL,
  question_count  INT          NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interview_skill_scores_user_skill ON interview_skill_scores (user_id, org_id, skill, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_interview_skill_scores_user_ts    ON interview_skill_scores (user_id, created_at DESC);

-- ════════════════════════════════════════════════════════════════════════════
-- SPACED REPETITION (migration 014)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE srs_cards (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES users(id)      ON DELETE CASCADE,
  question_id      UUID        REFERENCES questions(id)           ON DELETE SET NULL,
  front            TEXT        NOT NULL,
  back             TEXT        NOT NULL,
  source_type      TEXT        NOT NULL DEFAULT 'assessment',
  interval_days    INT         NOT NULL DEFAULT 1,
  repetitions      INT         NOT NULL DEFAULT 0,
  ease_factor      FLOAT       NOT NULL DEFAULT 2.5,
  due_date         DATE        NOT NULL DEFAULT CURRENT_DATE,
  last_reviewed_at TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_srs_cards_user_due ON srs_cards (user_id, due_date);

-- ════════════════════════════════════════════════════════════════════════════
-- NAVIGATION PERMISSIONS (migration 015_nav_permissions)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE nav_permissions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  role          TEXT        NOT NULL
                            CHECK (role IN ('student', 'instructor', 'mentor', 'admin')),
  section_label TEXT,
  section_order INT         NOT NULL DEFAULT 0,
  item_key      TEXT        NOT NULL,
  item_order    INT         NOT NULL DEFAULT 0,
  in_bottom_nav BOOLEAN     NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (role, item_key)
);

CREATE INDEX IF NOT EXISTS idx_nav_permissions_role ON nav_permissions (role, section_order, item_order);

INSERT INTO nav_permissions (role, section_label, section_order, item_key, item_order, in_bottom_nav) VALUES
  ('student', NULL,       0, 'dashboard',       0, true),
  ('student', NULL,       0, 'courses',         1, true),
  ('student', NULL,       0, 'practice',        2, true),
  ('student', 'Learning', 1, 'assessments',     0, true),
  ('student', 'Learning', 1, 'flashcards',      1, false),
  ('student', 'Learning', 1, 'sheet_tracker',   2, false),
  ('student', 'Learning', 1, 'mentor_chat',     3, false),
  ('student', 'Learning', 1, 'certificates',    4, false),
  ('student', 'Tools',    2, 'wiki',            0, false),
  ('student', 'Tools',    2, 'system_design',   1, false),
  ('student', 'Tools',    2, 'interview_board', 2, false),
  ('student', 'Tools',    2, 'load_test',       3, false),
  ('instructor', NULL,           0, 'instructor_dashboard',   0, true),
  ('instructor', NULL,           0, 'instructor_courses',     1, true),
  ('instructor', 'Assessments',  1, 'instructor_assessments', 0, true),
  ('instructor', 'Assessments',  1, 'question_bank',          1, false),
  ('instructor', 'Assessments',  1, 'batches',                2, true),
  ('instructor', 'Tools',        2, 'wiki',                   0, false),
  ('instructor', 'Tools',        2, 'system_design',          1, false),
  ('instructor', 'Tools',        2, 'interview_board',        2, false),
  ('mentor', NULL,      0, 'mentor_dashboard', 0, true),
  ('mentor', NULL,      0, 'mentor_messages',  1, true),
  ('mentor', 'Batches', 1, 'mentor_batches',   0, true),
  ('admin', NULL,           0, 'instructor_dashboard',   0, true),
  ('admin', NULL,           0, 'instructor_courses',     1, true),
  ('admin', 'Assessments',  1, 'instructor_assessments', 0, true),
  ('admin', 'Assessments',  1, 'question_bank',          1, false),
  ('admin', 'Assessments',  1, 'batches',                2, true),
  ('admin', 'Tools',        2, 'wiki',                   0, false),
  ('admin', 'Tools',        2, 'system_design',          1, false),
  ('admin', 'Tools',        2, 'interview_board',        2, false),
  ('admin', 'Tools',        2, 'load_test',              3, false);

-- ════════════════════════════════════════════════════════════════════════════
-- JOB MANAGEMENT (migration 015_jobs)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE jobs (
  id               UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  handler          TEXT      NOT NULL,
  status           TEXT      NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','queued','running','success','failed','dead','cancelled')),
  priority         SMALLINT  NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  payload          JSONB     NOT NULL DEFAULT '{}',
  job_type         TEXT      NOT NULL DEFAULT 'one_time' CHECK (job_type IN ('one_time','cron')),
  schedule         TEXT,
  run_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  next_run_at      TIMESTAMPTZ,
  last_run_at      TIMESTAMPTZ,
  last_duration_ms INT,
  last_error       TEXT,
  max_retries      SMALLINT  NOT NULL DEFAULT 3,
  retry_count      SMALLINT  NOT NULL DEFAULT 0,
  timeout_ms       INT       NOT NULL DEFAULT 30000,
  idempotency_key  TEXT      UNIQUE,
  org_id           UUID      REFERENCES organizations(id) ON DELETE CASCADE,
  created_by       UUID      REFERENCES users(id)         ON DELETE SET NULL,
  worker_id        TEXT,
  claimed_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at       TIMESTAMPTZ
);

CREATE TABLE job_runs (
  id           UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id       UUID      NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  status       TEXT      NOT NULL
               CHECK (status IN ('running','success','failed','timeout','cancelled')),
  attempt      SMALLINT  NOT NULL DEFAULT 1,
  worker_id    TEXT      NOT NULL,
  started_at   TIMESTAMPTZ,
  finished_at  TIMESTAMPTZ,
  duration_ms  INT,
  error        TEXT,
  heartbeat_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE org_job_quotas (
  org_id         UUID     PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  max_concurrent INT      NOT NULL DEFAULT 5,
  max_queued     INT      NOT NULL DEFAULT 200,
  priority_floor SMALLINT NOT NULL DEFAULT 5,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_jobs_claim     ON jobs (priority ASC, run_at ASC) WHERE status = 'queued' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_org_list  ON jobs (org_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_orphan    ON jobs (claimed_at) WHERE status = 'running';
CREATE INDEX IF NOT EXISTS idx_jobs_cron      ON jobs (next_run_at ASC) WHERE job_type = 'cron' AND deleted_at IS NULL AND status != 'cancelled';
CREATE INDEX IF NOT EXISTS idx_runs_job       ON job_runs (job_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_runs_heartbeat ON job_runs (heartbeat_at) WHERE status = 'running';

-- ════════════════════════════════════════════════════════════════════════════
-- RBAC SCHEMA (migration 016)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE permissions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT        NOT NULL UNIQUE,
  name        TEXT        NOT NULL,
  description TEXT        NOT NULL DEFAULT '',
  module      TEXT        NOT NULL,
  is_active   BOOLEAN     NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_permissions_module ON permissions (module, is_active);

CREATE TABLE roles (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID        REFERENCES organizations(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,
  description TEXT        NOT NULL DEFAULT '',
  is_system   BOOLEAN     NOT NULL DEFAULT false,
  is_editable BOOLEAN     NOT NULL DEFAULT true,
  is_active   BOOLEAN     NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT roles_system_tenant_biconditional CHECK (
    (is_system = true  AND tenant_id IS NULL) OR
    (is_system = false AND tenant_id IS NOT NULL)
  ),
  UNIQUE NULLS NOT DISTINCT (tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_roles_tenant_active ON roles (tenant_id, is_active);

CREATE TABLE role_permissions (
  role_id       UUID NOT NULL REFERENCES roles(id)       ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE RESTRICT,
  PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_role_permissions_perm ON role_permissions (permission_id);

CREATE TABLE user_roles (
  user_id   UUID NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
  role_id   UUID NOT NULL REFERENCES roles(id)         ON DELETE RESTRICT,
  tenant_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_tenant ON user_roles (user_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role        ON user_roles (role_id);

CREATE OR REPLACE FUNCTION fn_check_user_role_tenant_scope()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  role_tenant_id UUID;
BEGIN
  SELECT tenant_id INTO role_tenant_id FROM roles WHERE id = NEW.role_id;
  IF role_tenant_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF role_tenant_id IS DISTINCT FROM NEW.tenant_id THEN
    RAISE EXCEPTION
      'Tenant-scope violation: role % belongs to tenant % but assignment targets tenant %.',
      NEW.role_id, role_tenant_id, NEW.tenant_id
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_user_role_tenant_scope
  BEFORE INSERT OR UPDATE ON user_roles
  FOR EACH ROW EXECUTE FUNCTION fn_check_user_role_tenant_scope();

-- RBAC audit log (separate from org audit_logs)
CREATE TABLE audit_log (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID        REFERENCES organizations(id) ON DELETE SET NULL,
  actor_id    UUID        REFERENCES users(id)         ON DELETE SET NULL,
  action      TEXT        NOT NULL,
  entity_type TEXT        NOT NULL,
  entity_id   TEXT        NOT NULL,
  diff        JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_tenant_created ON audit_log (tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity         ON audit_log (entity_type, entity_id);

-- ════════════════════════════════════════════════════════════════════════════
-- RBAC SEED DATA (migration 017)
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO permissions (code, name, description, module) VALUES
  ('courses.view',              'View Courses',            'Browse and read published course content',           'courses'),
  ('courses.enroll',            'Enroll in Courses',       'Enroll in available courses',                        'courses'),
  ('courses.create',            'Create Courses',          'Create new draft courses',                           'courses'),
  ('courses.edit',              'Edit Courses',            'Edit course content and settings',                   'courses'),
  ('courses.publish',           'Publish Courses',         'Publish or unpublish courses to learners',           'courses'),
  ('courses.delete',            'Delete Courses',          'Archive or permanently delete courses',              'courses'),
  ('courses.view_analytics',    'Course Analytics',        'View engagement and completion analytics',           'courses'),
  ('assessments.take',             'Take Assessments',       'Attempt assigned assessments',                    'assessments'),
  ('assessments.view_assigned',    'View Assigned Tests',    'See which assessments are assigned to the user',  'assessments'),
  ('assessments.create',           'Create Assessments',     'Create new assessments',                          'assessments'),
  ('assessments.edit',             'Edit Assessments',       'Edit assessment questions and settings',          'assessments'),
  ('assessments.publish',          'Publish Assessments',    'Publish or unpublish assessments',                'assessments'),
  ('assessments.delete',           'Delete Assessments',     'Archive or delete assessments',                   'assessments'),
  ('assessments.view_results',     'View Results',           'See learner scores and attempt analytics',        'assessments'),
  ('assessments.manage_questions', 'Manage Question Bank',   'Add, edit, and tag questions in the bank',        'assessments'),
  ('assessments.manage_batches',   'Manage Batches',         'Create and assign learner batches',               'assessments'),
  ('practice.use',             'Use AI Practice',      'Access AI-powered coding practice and hints',    'practice'),
  ('mentoring.chat',           'Mentor Chat',          'Send and receive messages with a mentor',        'mentoring'),
  ('mentoring.manage_batches', 'Manage Mentor Batches','Create and supervise mentoring batches',         'mentoring'),
  ('mentoring.view_students',  'View Student Progress','View students'' progress in mentor batches',     'mentoring'),
  ('content.wiki',            'Wiki',            'Access org wiki spaces and pages',         'content'),
  ('content.system_design',   'System Design',   'Use the system design canvas tool',        'content'),
  ('content.interview_board', 'Interview Board', 'Use the interview simulation board',       'content'),
  ('content.load_test',       'Load Test',       'Run load test simulations',                'content'),
  ('content.sheets',          'Sheet Tracker',   'Access DSA sheet trackers',                'content'),
  ('content.srs',             'Review Cards',    'Use spaced-repetition flashcard system',   'content'),
  ('content.certificates',    'Certificates',    'View and download earned certificates',    'content'),
  ('admin.view_members',       'View Members',          'List org members and their roles',             'admin'),
  ('admin.manage_members',     'Manage Members',        'Invite, remove, and update org members',       'admin'),
  ('admin.manage_roles',       'Manage Roles',          'Create and edit tenant-owned roles',           'admin'),
  ('admin.manage_permissions', 'Manage Permissions',    'Assign permissions to roles',                  'admin'),
  ('admin.view_audit_log',     'View Audit Log',        'Read the RBAC audit trail',                    'admin'),
  ('admin.manage_org',         'Manage Organisation',   'Update org settings, seat limits, and status', 'admin')
ON CONFLICT (code) DO NOTHING;

INSERT INTO roles (id, name, description, is_system, is_editable, tenant_id) VALUES
  ('11111111-1111-1111-1111-000000000001', 'viewer',       'Read-only access to published content',        true, false, NULL),
  ('11111111-1111-1111-1111-000000000002', 'member',       'Standard learner — courses, practice, tools',  true, false, NULL),
  ('11111111-1111-1111-1111-000000000003', 'instructor',   'Course and assessment author',                 true, false, NULL),
  ('11111111-1111-1111-1111-000000000004', 'mentor',       'Mentoring and batch supervision',              true, false, NULL),
  ('11111111-1111-1111-1111-000000000005', 'tenant_admin', 'Full organisation administration',             true, false, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.id = '11111111-1111-1111-1111-000000000001' AND p.code IN ('courses.view')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.id = '11111111-1111-1111-1111-000000000002'
  AND p.code IN (
    'courses.view','courses.enroll','assessments.take','assessments.view_assigned',
    'practice.use','mentoring.chat','content.wiki','content.system_design',
    'content.interview_board','content.load_test','content.sheets','content.srs','content.certificates'
  )
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.id = '11111111-1111-1111-1111-000000000003'
  AND p.code IN (
    'courses.view','courses.enroll','courses.create','courses.edit','courses.publish',
    'courses.delete','courses.view_analytics','assessments.take','assessments.view_assigned',
    'assessments.create','assessments.edit','assessments.publish','assessments.delete',
    'assessments.view_results','assessments.manage_questions','assessments.manage_batches',
    'practice.use','mentoring.chat','content.wiki','content.system_design',
    'content.interview_board','content.load_test','content.sheets','content.srs',
    'content.certificates','admin.view_members'
  )
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.id = '11111111-1111-1111-1111-000000000004'
  AND p.code IN (
    'courses.view','courses.enroll','assessments.take','assessments.view_assigned',
    'assessments.view_results','practice.use','mentoring.chat','mentoring.manage_batches',
    'mentoring.view_students','content.wiki','content.system_design','content.interview_board',
    'content.load_test','content.sheets','content.srs','content.certificates','admin.view_members'
  )
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.id = '11111111-1111-1111-1111-000000000005'
ON CONFLICT DO NOTHING;
