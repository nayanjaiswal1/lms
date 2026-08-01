-- Reverse 013_warm_pool_by_image.sql.
--
-- lab_id/task_version_id are NOT NULL with no derivable value for existing
-- rows (an image maps to many labs, so there is no inverse), so every pool row
-- is dropped on the way down — same reasoning as the up migration, minus the
-- claimed-row preservation, which cannot be honoured without the lab_id those
-- rows no longer carry. Run the container cleanup job afterwards.

DROP TABLE IF EXISTS lab_image_warmup_stats;

DELETE FROM lab_warm_containers;

DROP INDEX IF EXISTS idx_lab_warm_containers_ready;
DROP INDEX IF EXISTS idx_lab_warm_containers_image_status;

-- DROP COLUMN in the up migration took the two foreign keys with it, so they
-- are restored explicitly here — a down migration that leaves the schema
-- structurally weaker than it found it is not a reversal.
ALTER TABLE lab_warm_containers
    ADD COLUMN lab_id uuid NOT NULL,
    ADD COLUMN task_version_id uuid NOT NULL,
    ADD CONSTRAINT lab_warm_containers_lab_id_fkey
        FOREIGN KEY (lab_id) REFERENCES lab_definitions (id) ON DELETE CASCADE,
    ADD CONSTRAINT lab_warm_containers_task_version_id_fkey
        FOREIGN KEY (task_version_id) REFERENCES lab_task_versions (id) ON DELETE CASCADE;

CREATE INDEX idx_lab_warm_containers_lab_status
    ON lab_warm_containers (lab_id, status);

CREATE INDEX idx_lab_warm_containers_ready
    ON lab_warm_containers (lab_id, task_version_id, created_at)
    WHERE status = 'ready';

DELETE FROM lab_warm_pool_decisions;

DROP INDEX IF EXISTS idx_lab_warm_pool_decisions_image_time;

ALTER TABLE lab_warm_pool_decisions
    DROP COLUMN image,
    ADD COLUMN lab_id uuid NOT NULL,
    ADD CONSTRAINT lab_warm_pool_decisions_lab_id_fkey
        FOREIGN KEY (lab_id) REFERENCES lab_definitions (id) ON DELETE CASCADE;

CREATE INDEX idx_lab_warm_pool_decisions_lab_time
    ON lab_warm_pool_decisions (lab_id, decided_at DESC);

CREATE TABLE lab_warm_pool_configs (
    lab_id     uuid PRIMARY KEY REFERENCES lab_definitions (id) ON DELETE CASCADE,
    mode       text NOT NULL DEFAULT 'auto',
    fixed_size integer NOT NULL DEFAULT 0,
    max_size   integer NOT NULL DEFAULT 5,
    updated_by uuid REFERENCES users (id) ON DELETE SET NULL,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT lab_warm_pool_configs_fixed_size_check CHECK (fixed_size >= 0 AND fixed_size <= 20),
    CONSTRAINT lab_warm_pool_configs_max_size_check CHECK (max_size >= 0 AND max_size <= 20),
    CONSTRAINT lab_warm_pool_configs_mode_check CHECK (mode = ANY (ARRAY['auto', 'fixed', 'off']))
);
