-- ════════════════════════════════════════════════════════════════════════════
-- 003_rewards_schema.sql — XP, badges, leaderboard
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Reward catalog ──────────────────────────────────────────────────────────

CREATE TABLE reward_definitions (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              TEXT        NOT NULL UNIQUE,
  name              TEXT        NOT NULL,
  description       TEXT        NOT NULL,
  icon              TEXT        NOT NULL,
  badge_tier        TEXT        NOT NULL CHECK (badge_tier IN ('bronze','silver','gold','platinum')),
  xp_value          INTEGER     NOT NULL DEFAULT 0,
  trigger_event     TEXT        NOT NULL, -- problem_solved | quiz_passed | quiz_perfect | course_completed | streak_milestone | certificate_earned | level_reached
  trigger_threshold INTEGER     NOT NULL DEFAULT 1,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── Per-user earned achievements ────────────────────────────────────────────

CREATE TABLE user_achievements (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reward_definition_id UUID        NOT NULL REFERENCES reward_definitions(id),
  org_id               UUID        REFERENCES organizations(id) ON DELETE CASCADE,
  earned_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_org  ON user_achievements(org_id) WHERE org_id IS NOT NULL;

-- Functional unique index: one badge per (user, definition, org), treating NULL org as global.
-- ON CONFLICT DO NOTHING in GrantAchievement relies on this index.
CREATE UNIQUE INDEX ua_user_def_org_uniq ON user_achievements
  (user_id, reward_definition_id,
   COALESCE(org_id, '00000000-0000-0000-0000-000000000000'::UUID));

-- ─── XP audit log (source of truth for scoped leaderboards) ─────────────────

CREATE TABLE xp_events (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id         UUID        REFERENCES organizations(id) ON DELETE SET NULL,
  batch_id       UUID        REFERENCES batches(id) ON DELETE SET NULL,
  course_id      UUID        REFERENCES courses(id) ON DELETE SET NULL,
  xp_amount      INTEGER     NOT NULL,
  reason         TEXT        NOT NULL,
  reference_id   UUID,
  reference_type TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_xp_events_user   ON xp_events(user_id, created_at DESC);
CREATE INDEX idx_xp_events_org    ON xp_events(org_id, user_id) WHERE org_id IS NOT NULL;
CREATE INDEX idx_xp_events_batch  ON xp_events(batch_id, user_id) WHERE batch_id IS NOT NULL;
CREATE INDEX idx_xp_events_course ON xp_events(course_id, user_id) WHERE course_id IS NOT NULL;

-- ─── XP + level on user_stats ────────────────────────────────────────────────

ALTER TABLE user_stats
  ADD COLUMN total_xp      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN xp_level      INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN xp_level_name TEXT    NOT NULL DEFAULT 'Apprentice';

-- ─── Reward result piggybacked on assessment attempts ────────────────────────
-- Populated after evaluation so the result endpoint can surface it without a second fetch.

ALTER TABLE assessment_attempts
  ADD COLUMN reward_result JSONB;
