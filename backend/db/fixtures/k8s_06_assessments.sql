-- ════════════════════════════════════════════════════════════════════════════
-- k8s_06_assessments.sql — 8 K8s quizzes + assessment_questions links
-- parent_type='module' with parent_id pointing to the module UUIDs created
-- in k8s_07_courses.sql (no FK on parent_id so forward-reference is safe).
-- Quiz 1-4 total_points=17; Quiz 5-8 total_points=20.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Assessment 1: K8s Fundamentals Quiz (Advanced course, Section 1 module 3) ─
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060001',
  '00000000-0000-0000-0000-000000000001',
  'Kubernetes Fundamentals Quiz', 'k8s-fundamentals-quiz',
  'Tests understanding of Pods, lifecycle phases, init containers, resource management, and QoS classes.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000071003',
  25, 60, 5, 17,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ─── Assessment 2: Workloads & Controllers Quiz ────────────────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060002',
  '00000000-0000-0000-0000-000000000001',
  'Workloads & Controllers Quiz', 'k8s-workloads-quiz',
  'Covers Deployments, DaemonSets, StatefulSets, rolling updates, HPA, and replica management.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000072003',
  25, 60, 5, 17,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ─── Assessment 3: Networking & Services Quiz ─────────────────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060003',
  '00000000-0000-0000-0000-000000000001',
  'Networking & Services Quiz', 'k8s-networking-quiz',
  'Covers Service types, CNI plugins, kube-proxy modes, NetworkPolicies, and DNS resolution.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000073003',
  25, 60, 5, 17,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ─── Assessment 4: Storage & Configuration Quiz ───────────────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060004',
  '00000000-0000-0000-0000-000000000001',
  'Storage & Configuration Quiz', 'k8s-storage-config-quiz',
  'Tests PV/PVC access modes, reclaim policies, ConfigMaps, Secrets, and StorageClass provisioning.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000074003',
  25, 60, 5, 17,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ─── Assessment 5: Cluster Administration Quiz ────────────────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060005',
  '00000000-0000-0000-0000-000000000001',
  'Cluster Administration Quiz', 'k8s-cluster-admin-quiz',
  'Expert-level: etcd quorum, audit policies, Node Authorizer, RBAC, and admission webhooks.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000081003',
  30, 65, 5, 20,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ─── Assessment 6: Advanced Networking Quiz ───────────────────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060006',
  '00000000-0000-0000-0000-000000000001',
  'Advanced Networking Quiz', 'k8s-advanced-networking-quiz',
  'Expert-level: eBPF/Cilium, CoreDNS internals, IPVS vs iptables, NetworkPolicy design patterns.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000082003',
  30, 65, 5, 20,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ─── Assessment 7: Observability & Troubleshooting Quiz ───────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060007',
  '00000000-0000-0000-0000-000000000001',
  'Observability & Troubleshooting Quiz', 'k8s-observability-quiz',
  'Expert-level: metrics-server API, audit log stages, probe interactions, and cascading failure patterns.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000083003',
  30, 65, 5, 20,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ─── Assessment 8: CKA Exam Preparation Quiz ──────────────────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type, parent_id,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
) VALUES (
  '00000000-0000-0000-0000-000000060008',
  '00000000-0000-0000-0000-000000000001',
  'CKA Exam Preparation Quiz', 'k8s-cka-prep-quiz',
  'Expert-level: kubeadm upgrade sequence, etcd backup/restore, node maintenance, and cluster lifecycle.',
  'mixed', 'published', 'module',
  '00000000-0000-0000-0000-000000084003',
  30, 65, 5, 20,
  true, true, true, true,
  '{}'::jsonb,
  '00000000-0000-0000-0000-000000000012', now()
) ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- Assessment questions (links) — 5 per quiz, pinned to version 1
-- position 0-indexed; points match question.default_points
-- ════════════════════════════════════════════════════════════════════════════

-- Quiz 1
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000061001','00000000-0000-0000-0000-000000060001','00000000-0000-0000-0000-000000051001','00000000-0000-0000-0000-000000051101',0,2),
  ('00000000-0000-0000-0000-000000061002','00000000-0000-0000-0000-000000060001','00000000-0000-0000-0000-000000051002','00000000-0000-0000-0000-000000051102',1,3),
  ('00000000-0000-0000-0000-000000061003','00000000-0000-0000-0000-000000060001','00000000-0000-0000-0000-000000051003','00000000-0000-0000-0000-000000051103',2,2),
  ('00000000-0000-0000-0000-000000061004','00000000-0000-0000-0000-000000060001','00000000-0000-0000-0000-000000051004','00000000-0000-0000-0000-000000051104',3,5),
  ('00000000-0000-0000-0000-000000061005','00000000-0000-0000-0000-000000060001','00000000-0000-0000-0000-000000051005','00000000-0000-0000-0000-000000051105',4,5)
ON CONFLICT (id) DO NOTHING;

-- Quiz 2
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000062001','00000000-0000-0000-0000-000000060002','00000000-0000-0000-0000-000000052001','00000000-0000-0000-0000-000000052101',0,2),
  ('00000000-0000-0000-0000-000000062002','00000000-0000-0000-0000-000000060002','00000000-0000-0000-0000-000000052002','00000000-0000-0000-0000-000000052102',1,3),
  ('00000000-0000-0000-0000-000000062003','00000000-0000-0000-0000-000000060002','00000000-0000-0000-0000-000000052003','00000000-0000-0000-0000-000000052103',2,2),
  ('00000000-0000-0000-0000-000000062004','00000000-0000-0000-0000-000000060002','00000000-0000-0000-0000-000000052004','00000000-0000-0000-0000-000000052104',3,5),
  ('00000000-0000-0000-0000-000000062005','00000000-0000-0000-0000-000000060002','00000000-0000-0000-0000-000000052005','00000000-0000-0000-0000-000000052105',4,5)
ON CONFLICT (id) DO NOTHING;

-- Quiz 3
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000063001','00000000-0000-0000-0000-000000060003','00000000-0000-0000-0000-000000053001','00000000-0000-0000-0000-000000053101',0,2),
  ('00000000-0000-0000-0000-000000063002','00000000-0000-0000-0000-000000060003','00000000-0000-0000-0000-000000053002','00000000-0000-0000-0000-000000053102',1,3),
  ('00000000-0000-0000-0000-000000063003','00000000-0000-0000-0000-000000060003','00000000-0000-0000-0000-000000053003','00000000-0000-0000-0000-000000053103',2,2),
  ('00000000-0000-0000-0000-000000063004','00000000-0000-0000-0000-000000060003','00000000-0000-0000-0000-000000053004','00000000-0000-0000-0000-000000053104',3,5),
  ('00000000-0000-0000-0000-000000063005','00000000-0000-0000-0000-000000060003','00000000-0000-0000-0000-000000053005','00000000-0000-0000-0000-000000053105',4,5)
ON CONFLICT (id) DO NOTHING;

-- Quiz 4
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000064001','00000000-0000-0000-0000-000000060004','00000000-0000-0000-0000-000000054001','00000000-0000-0000-0000-000000054101',0,2),
  ('00000000-0000-0000-0000-000000064002','00000000-0000-0000-0000-000000060004','00000000-0000-0000-0000-000000054002','00000000-0000-0000-0000-000000054102',1,3),
  ('00000000-0000-0000-0000-000000064003','00000000-0000-0000-0000-000000060004','00000000-0000-0000-0000-000000054003','00000000-0000-0000-0000-000000054103',2,2),
  ('00000000-0000-0000-0000-000000064004','00000000-0000-0000-0000-000000060004','00000000-0000-0000-0000-000000054004','00000000-0000-0000-0000-000000054104',3,5),
  ('00000000-0000-0000-0000-000000064005','00000000-0000-0000-0000-000000060004','00000000-0000-0000-0000-000000054005','00000000-0000-0000-0000-000000054105',4,5)
ON CONFLICT (id) DO NOTHING;

-- Quiz 5
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000065001','00000000-0000-0000-0000-000000060005','00000000-0000-0000-0000-000000055001','00000000-0000-0000-0000-000000055101',0,3),
  ('00000000-0000-0000-0000-000000065002','00000000-0000-0000-0000-000000060005','00000000-0000-0000-0000-000000055002','00000000-0000-0000-0000-000000055102',1,4),
  ('00000000-0000-0000-0000-000000065003','00000000-0000-0000-0000-000000060005','00000000-0000-0000-0000-000000055003','00000000-0000-0000-0000-000000055103',2,3),
  ('00000000-0000-0000-0000-000000065004','00000000-0000-0000-0000-000000060005','00000000-0000-0000-0000-000000055004','00000000-0000-0000-0000-000000055104',3,5),
  ('00000000-0000-0000-0000-000000065005','00000000-0000-0000-0000-000000060005','00000000-0000-0000-0000-000000055005','00000000-0000-0000-0000-000000055105',4,5)
ON CONFLICT (id) DO NOTHING;

-- Quiz 6
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000066001','00000000-0000-0000-0000-000000060006','00000000-0000-0000-0000-000000056001','00000000-0000-0000-0000-000000056101',0,3),
  ('00000000-0000-0000-0000-000000066002','00000000-0000-0000-0000-000000060006','00000000-0000-0000-0000-000000056002','00000000-0000-0000-0000-000000056102',1,4),
  ('00000000-0000-0000-0000-000000066003','00000000-0000-0000-0000-000000060006','00000000-0000-0000-0000-000000056003','00000000-0000-0000-0000-000000056103',2,3),
  ('00000000-0000-0000-0000-000000066004','00000000-0000-0000-0000-000000060006','00000000-0000-0000-0000-000000056004','00000000-0000-0000-0000-000000056104',3,5),
  ('00000000-0000-0000-0000-000000066005','00000000-0000-0000-0000-000000060006','00000000-0000-0000-0000-000000056005','00000000-0000-0000-0000-000000056105',4,5)
ON CONFLICT (id) DO NOTHING;

-- Quiz 7
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000067001','00000000-0000-0000-0000-000000060007','00000000-0000-0000-0000-000000057001','00000000-0000-0000-0000-000000057101',0,3),
  ('00000000-0000-0000-0000-000000067002','00000000-0000-0000-0000-000000060007','00000000-0000-0000-0000-000000057002','00000000-0000-0000-0000-000000057102',1,4),
  ('00000000-0000-0000-0000-000000067003','00000000-0000-0000-0000-000000060007','00000000-0000-0000-0000-000000057003','00000000-0000-0000-0000-000000057103',2,3),
  ('00000000-0000-0000-0000-000000067004','00000000-0000-0000-0000-000000060007','00000000-0000-0000-0000-000000057004','00000000-0000-0000-0000-000000057104',3,5),
  ('00000000-0000-0000-0000-000000067005','00000000-0000-0000-0000-000000060007','00000000-0000-0000-0000-000000057005','00000000-0000-0000-0000-000000057105',4,5)
ON CONFLICT (id) DO NOTHING;

-- Quiz 8
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points) VALUES
  ('00000000-0000-0000-0000-000000068001','00000000-0000-0000-0000-000000060008','00000000-0000-0000-0000-000000058001','00000000-0000-0000-0000-000000058101',0,3),
  ('00000000-0000-0000-0000-000000068002','00000000-0000-0000-0000-000000060008','00000000-0000-0000-0000-000000058002','00000000-0000-0000-0000-000000058102',1,4),
  ('00000000-0000-0000-0000-000000068003','00000000-0000-0000-0000-000000060008','00000000-0000-0000-0000-000000058003','00000000-0000-0000-0000-000000058103',2,3),
  ('00000000-0000-0000-0000-000000068004','00000000-0000-0000-0000-000000060008','00000000-0000-0000-0000-000000058004','00000000-0000-0000-0000-000000058104',3,5),
  ('00000000-0000-0000-0000-000000068005','00000000-0000-0000-0000-000000060008','00000000-0000-0000-0000-000000058005','00000000-0000-0000-0000-000000058105',4,5)
ON CONFLICT (id) DO NOTHING;
