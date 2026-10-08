-- Least-privilege DB role for labproxy (audit C4). labproxy sits on the lab
-- network, so a compromise must not expose the app database. It reads exactly:
--   lab_sessions (id, user_id, status, container_host, lab_id, variant_key)
--   lab_definitions (id, preview_port, build_id)
--   lab_build_variants (build_id, variant_key, ide_port)
-- and writes only lab_sessions.last_active_at (terminal heartbeat).
-- The role is NOLOGIN here so no password lives in a migration; an operator
-- enables it out-of-band: ALTER ROLE labproxy LOGIN PASSWORD '...'
-- (see docs/infrastructure.md).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'labproxy') THEN
        CREATE ROLE labproxy NOLOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO labproxy;
GRANT SELECT ON lab_sessions, lab_definitions, lab_build_variants TO labproxy;
GRANT UPDATE (last_active_at) ON lab_sessions TO labproxy;
