-- Per-handler alerting rules for dead-letter jobs (internal/opsalert). The '*'
-- row is the default for any handler without its own row.
CREATE TABLE ops_alert_rules (
    handler                text PRIMARY KEY,
    severity               text NOT NULL DEFAULT 'normal' CHECK (severity IN ('low', 'normal', 'high')),
    dedupe_window_minutes  integer NOT NULL DEFAULT 15 CHECK (dedupe_window_minutes BETWEEN 1 AND 1440),
    storm_threshold        integer NOT NULL DEFAULT 10 CHECK (storm_threshold BETWEEN 1 AND 100000),
    storm_window_minutes   integer NOT NULL DEFAULT 10 CHECK (storm_window_minutes BETWEEN 1 AND 1440),
    enabled                boolean NOT NULL DEFAULT true,
    updated_at             timestamptz NOT NULL DEFAULT now()
);

INSERT INTO ops_alert_rules (handler, severity) VALUES
    ('*', 'normal'),
    ('email.send', 'high'),
    ('invite.bulk', 'high'),
    ('payments.reconcile', 'high'),
    ('retention.purge', 'high'),
    ('gitlab.token_refresh', 'high'),
    ('lab.recipe_build', 'high'),
    ('lab.recipe_verify', 'high');

-- Health-check queries scan dead/running jobs by recency.
CREATE INDEX IF NOT EXISTS idx_jobs_dead_handler_updated ON jobs (handler, updated_at) WHERE status = 'dead';
