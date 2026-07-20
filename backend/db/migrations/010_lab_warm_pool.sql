-- 010_lab_warm_pool.sql
-- Pre-warmed lab sandbox pool: containers are provisioned ahead of demand so
-- StartSession can hand a student a ready sandbox in one DB round trip
-- instead of a cold docker-run + setup_script wait.
--
-- Pool sizing is demand-driven, not statically configured. Every minute the
-- reconciler computes a per-lab target from live signals (recent starts,
-- active enrolled users, hour-of-week history, upcoming batch schedules) and
-- records WHY in lab_warm_pool_decisions so admins can audit every scaling
-- decision: what was decided, based on which inputs, at what time.

-- Per-lab operator config. Absent row = mode 'auto' with defaults.
--   auto  - reconciler sizes the pool from demand signals (0 when idle)
--   fixed - operator pins the pool at fixed_size
--   off   - never pre-warm this lab
CREATE TABLE lab_warm_pool_configs (
    lab_id uuid NOT NULL,
    mode text DEFAULT 'auto'::text NOT NULL,
    fixed_size integer DEFAULT 0 NOT NULL,
    max_size integer DEFAULT 5 NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lab_warm_pool_configs_pkey PRIMARY KEY (lab_id),
    CONSTRAINT lab_warm_pool_configs_mode_check
      CHECK (mode = ANY (ARRAY['auto'::text, 'fixed'::text, 'off'::text])),
    CONSTRAINT lab_warm_pool_configs_fixed_size_check
      CHECK (fixed_size >= 0 AND fixed_size <= 20),
    CONSTRAINT lab_warm_pool_configs_max_size_check
      CHECK (max_size >= 0 AND max_size <= 20),
    CONSTRAINT lab_warm_pool_configs_lab_id_fkey
      FOREIGN KEY (lab_id) REFERENCES lab_definitions(id) ON DELETE CASCADE,
    CONSTRAINT lab_warm_pool_configs_updated_by_fkey
      FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Scaling decision audit log: one row per lab per reconciler tick where the
-- target changed (plus a periodic heartbeat row). inputs is the full signal
-- snapshot the decision was computed from, e.g.
--   {"platform_active_15m":12,"enrolled_active":4,"recent_starts_60m":3,
--    "hist_expected_starts":1.5,"scheduled_starts_60m":0,"ready":1,
--    "warming":0,"global_cap":40,"mode":"auto"}
-- reason is the human-readable explanation shown in /admin/labs/warm-pools.
CREATE TABLE lab_warm_pool_decisions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lab_id uuid NOT NULL,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    mode text NOT NULL,
    target integer NOT NULL,
    previous_target integer NOT NULL,
    inputs jsonb DEFAULT '{}'::jsonb NOT NULL,
    reason text NOT NULL,
    CONSTRAINT lab_warm_pool_decisions_pkey PRIMARY KEY (id),
    CONSTRAINT lab_warm_pool_decisions_target_check
      CHECK (target >= 0 AND previous_target >= 0),
    CONSTRAINT lab_warm_pool_decisions_lab_id_fkey
      FOREIGN KEY (lab_id) REFERENCES lab_definitions(id) ON DELETE CASCADE
);

-- Admin page reads "latest N decisions per lab"; reconciler prunes by age.
CREATE INDEX idx_lab_warm_pool_decisions_lab_time
  ON lab_warm_pool_decisions (lab_id, decided_at DESC);
CREATE INDEX idx_lab_warm_pool_decisions_time
  ON lab_warm_pool_decisions (decided_at);

-- One row per pre-warmed sandbox. Lifecycle:
--   warming -> ready            (reconciler provisions the container)
--   ready   -> claimed          (StartSession atomically claims it for a session)
--   claimed -> row deleted      (reconciler purges once the session is terminal)
-- Warm containers are keyed to (lab_id, task_version_id): publishing a new
-- task version invalidates the pool, and the reconciler retires stale rows.
CREATE TABLE lab_warm_containers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lab_id uuid NOT NULL,
    task_version_id uuid NOT NULL,
    image text NOT NULL,
    status text DEFAULT 'warming'::text NOT NULL,
    container_id text,
    container_host text,
    session_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ready_at timestamp with time zone,
    claimed_at timestamp with time zone,
    CONSTRAINT lab_warm_containers_pkey PRIMARY KEY (id),
    CONSTRAINT lab_warm_containers_status_check
      CHECK (status = ANY (ARRAY['warming'::text, 'ready'::text, 'claimed'::text])),
    CONSTRAINT lab_warm_containers_ready_has_container
      CHECK (status = 'warming'::text OR (container_id IS NOT NULL AND container_host IS NOT NULL)),
    CONSTRAINT lab_warm_containers_claimed_has_session
      CHECK (status <> 'claimed'::text OR session_id IS NOT NULL),
    CONSTRAINT lab_warm_containers_lab_id_fkey
      FOREIGN KEY (lab_id) REFERENCES lab_definitions(id) ON DELETE CASCADE,
    CONSTRAINT lab_warm_containers_task_version_id_fkey
      FOREIGN KEY (task_version_id) REFERENCES lab_task_versions(id) ON DELETE CASCADE,
    CONSTRAINT lab_warm_containers_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES lab_sessions(id) ON DELETE SET NULL
);

-- Claim path: "oldest ready container for this lab+version" under
-- FOR UPDATE SKIP LOCKED.
CREATE INDEX idx_lab_warm_containers_ready
  ON lab_warm_containers (lab_id, task_version_id, created_at)
  WHERE status = 'ready'::text;

-- Reconciler paths: per-lab occupancy counts and claimed-row purge.
CREATE INDEX idx_lab_warm_containers_lab_status
  ON lab_warm_containers (lab_id, status);
CREATE INDEX idx_lab_warm_containers_session
  ON lab_warm_containers (session_id)
  WHERE session_id IS NOT NULL;

-- Demand-signal query support: "starts in the last hour / same hour-of-week
-- over the trailing 4 weeks" scans lab_sessions by (lab_id, started_at).
CREATE INDEX IF NOT EXISTS idx_lab_sessions_lab_started
  ON lab_sessions (lab_id, started_at);
