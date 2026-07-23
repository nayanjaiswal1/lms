-- Warm pool test config — pins one real, published, container-backed lab to
-- mode=fixed so a sandbox is always kept warm in dev regardless of traffic
-- signals (auto mode legitimately targets 0 with no users/history yet).
-- Lab: "Django Middleware — Request ID & Response Time" (interview-prep-45.generated.sql).

INSERT INTO lab_warm_pool_configs (lab_id, mode, fixed_size, max_size)
VALUES ('6df2b109-3e39-5312-835c-53d1c4f2091c', 'fixed', 1, 3)
ON CONFLICT (lab_id) DO UPDATE
SET mode = EXCLUDED.mode, fixed_size = EXCLUDED.fixed_size, max_size = EXCLUDED.max_size, updated_at = now();
