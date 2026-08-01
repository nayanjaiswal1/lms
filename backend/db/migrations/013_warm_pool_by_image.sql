-- Warm pool: key by image (flavor), not by lab.
--
-- The pool used to be keyed (lab_id, task_version_id), so every published lab
-- got its own private pool: 23 labs across 4 images meant 23 pools competing
-- for one global container budget, and republishing a lab retired that lab's
-- entire pool because task_version_id changed. Neither multiplication bought
-- anything — every warm container of a given image is interchangeable, since
-- the only lab-specific work (starter files + setup_script) is now applied at
-- CLAIM time by Service.prepareLabEnvironment rather than baked in at warm
-- time. What a warm container pre-pays is the image's boot cost (lab-k8s
-- boots etcd + apiserver + controller-manager + scheduler + kwok; ~30s), and
-- that cost is a property of the image alone.
--
-- Consequences encoded below:
--   * lab_warm_containers loses lab_id/task_version_id — `image` is the key.
--   * lab_warm_pool_configs is dropped entirely. Pool sizing is platform
--     infrastructure shared across every org, so a per-lab row writable by any
--     org admin was both the wrong granularity and a cross-tenant write. The
--     operator escape hatch is now LABS_WARM_POOL_OVERRIDES (env, same shape
--     as LABS_IMAGE_PROFILES); the admin API is read-only observability.
--   * lab_warm_pool_decisions is keyed by image for the same reason.
--   * lab_image_warmup_stats is new: the planner measures how long each image
--     actually takes to become ready and sizes the pool from it (Little's Law,
--     N = arrival_rate x warmup_seconds x safety). Without a measured warmup
--     the old formula treated a 2-second image and a 30-second image
--     identically, which is precisely backwards.

-- Ready/warming rows have no session behind them; drop them and let
-- lab.cleanup_containers reap the now-unreferenced "mindforge-warm-*"
-- containers on its next pass. CLAIMED rows are deliberately preserved: each
-- one belongs to a live session, and lab.cleanup_containers kills any
-- "mindforge-warm-<id>" container whose row is missing — deleting them here
-- would destroy running students' containers. They drain on their own via
-- ListStaleWarmContainers once their session ends.
DELETE FROM lab_warm_containers WHERE status IN ('warming', 'ready');

DROP INDEX IF EXISTS idx_lab_warm_containers_lab_status;
DROP INDEX IF EXISTS idx_lab_warm_containers_ready;

ALTER TABLE lab_warm_containers
    DROP COLUMN lab_id,
    DROP COLUMN task_version_id;

-- Claim path: oldest ready container for an image (FOR UPDATE SKIP LOCKED).
CREATE INDEX idx_lab_warm_containers_ready
    ON lab_warm_containers (image, created_at)
    WHERE status = 'ready';

-- Occupancy counts per image, all statuses.
CREATE INDEX idx_lab_warm_containers_image_status
    ON lab_warm_containers (image, status);

DROP TABLE IF EXISTS lab_warm_pool_configs;

-- Decisions are a 14-day-retention audit log; re-keying beats backfilling a
-- lab_id -> image mapping for rows nobody will read again.
DELETE FROM lab_warm_pool_decisions;

DROP INDEX IF EXISTS idx_lab_warm_pool_decisions_lab_time;

ALTER TABLE lab_warm_pool_decisions
    DROP COLUMN lab_id,
    ADD COLUMN image text NOT NULL;

CREATE INDEX idx_lab_warm_pool_decisions_image_time
    ON lab_warm_pool_decisions (image, decided_at DESC);

-- Measured warm-start latency per image, as an exponentially weighted moving
-- average. Updated by the planner after every successful warm start; read by
-- computeWarmTarget. samples is kept so the planner can tell "measured once,
-- treat with suspicion" from "measured 500 times".
CREATE TABLE lab_image_warmup_stats (
    image        text PRIMARY KEY,
    ewma_seconds double precision NOT NULL,
    samples      bigint NOT NULL DEFAULT 0,
    updated_at   timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT lab_image_warmup_stats_ewma_positive CHECK (ewma_seconds >= 0),
    CONSTRAINT lab_image_warmup_stats_samples_positive CHECK (samples >= 0)
);
