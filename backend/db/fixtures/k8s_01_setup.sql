-- ════════════════════════════════════════════════════════════════════════════
-- k8s_01_setup.sql — Lab org config + K8s question category
-- Run AFTER 009_course_extensions.sql (adds 'expert' difficulty + 'lab' type).
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_org_config (org_id, max_concurrent_sessions, max_session_duration, allowed_images)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  50, 120,
  ARRAY['mindforge/lab-k8s:1.31','mindforge/lab-k8s:1.30']
)
ON CONFLICT (org_id) DO NOTHING;

INSERT INTO question_categories (id, org_id, name, slug)
VALUES (
  '00000000-0000-0000-0000-000000050000',
  '00000000-0000-0000-0000-000000000001',
  'Kubernetes', 'kubernetes'
)
ON CONFLICT (id) DO NOTHING;
