-- 010_lab_warm_pool.down.sql
DROP INDEX IF EXISTS idx_lab_sessions_lab_started;
DROP TABLE IF EXISTS lab_warm_containers;
DROP TABLE IF EXISTS lab_warm_pool_decisions;
DROP TABLE IF EXISTS lab_warm_pool_configs;
