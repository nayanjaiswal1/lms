-- ════════════════════════════════════════════════════════════════════════════
-- 008_labs_core.sql — Labs feature: sandboxed terminal/code/guided environments
-- ════════════════════════════════════════════════════════════════════════════

-- 1. Per-org lab configuration (no FKs to lab tables)
CREATE TABLE lab_org_config (
  org_id                    UUID  PRIMARY KEY REFERENCES organizations(id),
  max_concurrent_sessions   INT   NOT NULL DEFAULT 20,
  max_session_duration      INT   NOT NULL DEFAULT 120,
  allowed_images            TEXT[],
  egress_proxy_enabled      BOOLEAN NOT NULL DEFAULT false,
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Lab definitions (FKs: orgs, courses, course_modules, users)
--    published_version_id FK is deferred until after lab_task_versions exists.
CREATE TABLE lab_definitions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           UUID        NOT NULL REFERENCES organizations(id),
  course_id        UUID        REFERENCES courses(id),
  module_id        UUID        REFERENCES course_modules(id),
  scope            TEXT        NOT NULL DEFAULT 'module'
                     CHECK (scope IN ('module','course','standalone')),
  title            TEXT        NOT NULL,
  description      TEXT,
  lab_type         TEXT        NOT NULL CHECK (lab_type IN ('terminal','code','playground','guided')),
  environment      TEXT        NOT NULL,
  setup_script     TEXT,
  max_duration     INT         NOT NULL DEFAULT 60,
  max_resets       INT         NOT NULL DEFAULT 3,
  hint_penalty_pct INT         NOT NULL DEFAULT 0 CHECK (hint_penalty_pct BETWEEN 0 AND 100),
  is_required      BOOLEAN     NOT NULL DEFAULT false,
  is_published     BOOLEAN     NOT NULL DEFAULT false,
  published_version_id UUID,
  created_by       UUID        NOT NULL REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT required_lab_has_module CHECK (NOT is_required OR module_id IS NOT NULL),
  CONSTRAINT scope_module_consistency CHECK (
    (scope = 'standalone' AND module_id IS NULL) OR
    (scope = 'course'     AND course_id IS NOT NULL) OR
    (scope = 'module'     AND module_id IS NOT NULL)
  )
);

-- 3. Individual tasks within a lab definition
CREATE TABLE lab_tasks (
  id                    UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id                UUID  NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  position              INT   NOT NULL,
  title                 TEXT  NOT NULL,
  description           TEXT  NOT NULL,
  verification_script   TEXT  NOT NULL,
  hint_context          TEXT,
  explanation_context   TEXT,
  points                INT   NOT NULL DEFAULT 10,
  is_optional           BOOLEAN NOT NULL DEFAULT false,
  is_stateful           BOOLEAN NOT NULL DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lab_id, position)
);

-- 4. Immutable snapshots of task sets — published versions of a lab
CREATE TABLE lab_task_versions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id        UUID        NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  version       INT         NOT NULL,
  tasks         JSONB       NOT NULL,
  published_by  UUID        NOT NULL REFERENCES users(id),
  published_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lab_id, version)
);

-- 5. Resolve the circular FK: lab_definitions.published_version_id → lab_task_versions
ALTER TABLE lab_definitions
  ADD CONSTRAINT lab_definitions_published_version_fk
  FOREIGN KEY (published_version_id) REFERENCES lab_task_versions(id);

-- 6. Active or historical student lab sessions
CREATE TABLE lab_sessions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id           UUID        NOT NULL REFERENCES lab_definitions(id),
  task_version_id  UUID        NOT NULL REFERENCES lab_task_versions(id),
  user_id          UUID        NOT NULL REFERENCES users(id),
  org_id           UUID        NOT NULL REFERENCES organizations(id),
  container_id     TEXT,
  container_host   TEXT,
  status           TEXT        NOT NULL DEFAULT 'provisioning'
                     CHECK (status IN ('provisioning','running','paused','completed','expired','failed','terminated_abuse')),
  reset_count      INT         NOT NULL DEFAULT 0,
  score            INT         NOT NULL DEFAULT 0,
  is_test          BOOLEAN     NOT NULL DEFAULT false,
  started_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ NOT NULL,
  paused_seconds   INT         NOT NULL DEFAULT 0,
  completed_at     TIMESTAMPTZ,
  last_active_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enforce one active session per (user, lab) at the DB level
CREATE UNIQUE INDEX lab_sessions_one_active
  ON lab_sessions (user_id, lab_id)
  WHERE status IN ('provisioning','running','paused');

-- 7. Per-task progress records tied to a session
CREATE TABLE lab_task_completions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID        NOT NULL REFERENCES lab_sessions(id) ON DELETE CASCADE,
  task_id       UUID        NOT NULL,
  status        TEXT        NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','passed','skipped')),
  attempts      INT         NOT NULL DEFAULT 0,
  hints_used    INT         NOT NULL DEFAULT 0,
  completed_at  TIMESTAMPTZ,
  UNIQUE (session_id, task_id)
);

-- 8. AI hint/explain/diagnose interactions within a session
CREATE TABLE lab_ai_interactions (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id        UUID        NOT NULL REFERENCES lab_sessions(id) ON DELETE CASCADE,
  task_id           UUID,
  interaction_type  TEXT        NOT NULL CHECK (interaction_type IN ('hint','explain','diagnose','generate')),
  hint_level        INT,
  cache_key         TEXT,
  prompt            TEXT        NOT NULL,
  response          TEXT        NOT NULL,
  tokens_used       INT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deduplicate identical AI responses via cache_key
CREATE UNIQUE INDEX ON lab_ai_interactions (cache_key) WHERE cache_key IS NOT NULL;

-- 9. Per-lab network egress allowlist (used by the egress proxy)
CREATE TABLE lab_egress_rules (
  id          UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id      UUID  NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  host        TEXT  NOT NULL,
  port        INT,
  protocol    TEXT  NOT NULL DEFAULT 'https' CHECK (protocol IN ('http','https','tcp')),
  reason      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lab_id, host, port)
);

-- 10. Append-only usage events for billing / quota tracking
CREATE TABLE lab_usage_events (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        UUID        NOT NULL REFERENCES organizations(id),
  session_id    UUID        REFERENCES lab_sessions(id) ON DELETE SET NULL,
  event_type    TEXT        NOT NULL CHECK (event_type IN ('container_seconds','ai_tokens','validation_seconds')),
  quantity      BIGINT      NOT NULL,
  image         TEXT,
  recorded_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 11. Daily roll-up analytics per lab definition
CREATE TABLE lab_analytics (
  lab_id              UUID        NOT NULL REFERENCES lab_definitions(id) ON DELETE CASCADE,
  day                 DATE        NOT NULL,
  sessions_started    INT         NOT NULL DEFAULT 0,
  sessions_completed  INT         NOT NULL DEFAULT 0,
  avg_duration_sec    INT         NOT NULL DEFAULT 0,
  avg_score           NUMERIC(6,2) NOT NULL DEFAULT 0,
  total_hints_used    INT         NOT NULL DEFAULT 0,
  per_task_pass_rate  JSONB       NOT NULL DEFAULT '{}',
  computed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (lab_id, day)
);

-- ─── Indexes ─────────────────────────────────────────────────────────────────

CREATE INDEX ON lab_definitions (course_id, module_id) WHERE is_published;
CREATE INDEX ON lab_sessions (user_id, lab_id, status);
CREATE INDEX ON lab_sessions (status, expires_at);
CREATE INDEX ON lab_sessions (org_id, status);
CREATE INDEX ON lab_task_completions (session_id);
CREATE INDEX ON lab_egress_rules (lab_id);
CREATE INDEX ON lab_usage_events (org_id, recorded_at);

-- ─── Triggers ────────────────────────────────────────────────────────────────

CREATE TRIGGER set_lab_definitions_updated_at BEFORE UPDATE ON lab_definitions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_lab_org_config_updated_at BEFORE UPDATE ON lab_org_config
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
