-- ══════════════════════════════════════════════════════════════════════════
-- gitlab_integration_seed.sql — Batch 2 (Teams & provisioning) fixture
-- ══════════════════════════════════════════════════════════════════════════
-- Seeds MindForge's own project_assignments/project_teams/project_team_members
-- rows only, so the /projects UI has a real draft assignment + roster to
-- publish through the app. Reuses dev_seed.sql's default org
-- (00000000-0000-0000-0000-000000000001), instructor
-- (...-000000000012, "Nayan Jaiswal") and its existing dev student
-- (...-000000000014) — run dev_seed.sql first if starting from an empty
-- database. Three additional student users are added here (one goes on the
-- solo team, two more join the dev student on the multi-member team) using a
-- dedicated a1000000-... UUID block that cannot collide with dev_seed.sql's
-- own 00000000-...-0NNN/1NN/5NN ranges. All writes are idempotent
-- (ON CONFLICT ... DO NOTHING) — safe to run multiple times, and safe to run
-- before or after dev_seed.sql.
--
-- IMPORTANT CAVEAT: this fixture seeds MindForge's own tables only — it
-- cannot fake GitLab-side state (a real forked repo, subgroup, protected
-- branch, or synced membership). Those only come into existence once the
-- gitlab.provision_team job actually runs against a real or self-hosted-
-- sandbox GitLab instance, which only happens when a staff user publishes
-- this assignment for real through the UI/API (POST .../publish) — that is
-- the point of leaving the assignment in status='draft' here rather than
-- hand-inserting a fake "ready" provision_status. Before publishing for
-- real, an admin must first connect an org GitLab installation
-- (POST /api/gitlab/installations) and this assignment's template_project_path
-- must point at a real template repo that installation can see.
--
-- Login for the three new students: password Admin123! (same as dev_seed.sql).

-- ─── Additional student users (a1000000 block) ─────────────────────────────

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  'a1000000-0000-0000-0000-000000000001',
  'gitlab-student1@mindforge.dev',
  'GitLab Test Student One',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  'a1000000-0000-0000-0000-000000000002',
  'gitlab-student2@mindforge.dev',
  'GitLab Test Student Two',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  'a1000000-0000-0000-0000-000000000003',
  'gitlab-student3@mindforge.dev',
  'GitLab Test Student Three',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

-- ─── Org membership ─────────────────────────────────────────────────────────

INSERT INTO org_members (id, org_id, user_id, role)
VALUES
  ('a1000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'learner'),
  ('a1000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', 'learner'),
  ('a1000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000003', 'learner')
ON CONFLICT (org_id, user_id) DO NOTHING;

-- ─── Batch ───────────────────────────────────────────────────────────────────

INSERT INTO batches (id, org_id, name, slug, description, mentor_id, created_by)
VALUES (
  'a1000000-0000-0000-0000-000000000030',
  '00000000-0000-0000-0000-000000000001',
  'GitLab Projects Cohort 2026', 'gitlab-projects-cohort-2026',
  'Dev fixture batch for the GitLab integration Batch 2 (project assignments/teams/provisioning) feature.',
  '00000000-0000-0000-0000-000000000013',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO batch_members (batch_id, user_id)
VALUES
  ('a1000000-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000014'),
  ('a1000000-0000-0000-0000-000000000030', 'a1000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000030', 'a1000000-0000-0000-0000-000000000002'),
  ('a1000000-0000-0000-0000-000000000030', 'a1000000-0000-0000-0000-000000000003')
ON CONFLICT (batch_id, user_id) DO NOTHING;

-- ─── Project assignment (draft — publish for real through the UI) ─────────
-- template_project_path is a placeholder; point it at a real template repo
-- path your GitLab installation can see before publishing this assignment.

INSERT INTO project_assignments (
  id, org_id, batch_id, title, slug, description,
  template_project_path, visibility, required_approvals,
  protect_default_branch, default_branch, status, created_by
)
VALUES (
  'a1000000-0000-0000-0000-000000000040',
  '00000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000030',
  'Capstone: REST API Service', 'capstone-rest-api-service',
  'Dev fixture assignment — each team forks the template into their own subgroup project and submits checkpoints via merge request.',
  'mindforge-templates/capstone-rest-api-starter',
  'private', 1, true, 'main', 'draft',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Teams: one solo, one multi-member ─────────────────────────────────────

INSERT INTO project_teams (id, org_id, assignment_id, name, slug, provision_status, created_by)
VALUES (
  'a1000000-0000-0000-0000-000000000050',
  '00000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000040',
  'Solo — Student One', 'solo-student-one',
  'pending',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO project_teams (id, org_id, assignment_id, name, slug, provision_status, created_by)
VALUES (
  'a1000000-0000-0000-0000-000000000051',
  '00000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000040',
  'Team Byte Bandits', 'team-byte-bandits',
  'pending',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- Solo team: gitlab-student1 only.
INSERT INTO project_team_members (team_id, user_id, assignment_id, role, gitlab_access_level, sync_status, added_by)
VALUES (
  'a1000000-0000-0000-0000-000000000050',
  'a1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000040',
  'lead', 40, 'pending',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (team_id, user_id) DO NOTHING;

-- Multi-member team: dev student (lead) + the other two new students.
INSERT INTO project_team_members (team_id, user_id, assignment_id, role, gitlab_access_level, sync_status, added_by)
VALUES
  ('a1000000-0000-0000-0000-000000000051', '00000000-0000-0000-0000-000000000014', 'a1000000-0000-0000-0000-000000000040', 'lead', 40, 'pending', '00000000-0000-0000-0000-000000000012'),
  ('a1000000-0000-0000-0000-000000000051', 'a1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000040', 'member', 30, 'pending', '00000000-0000-0000-0000-000000000012'),
  ('a1000000-0000-0000-0000-000000000051', 'a1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000040', 'member', 30, 'pending', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (team_id, user_id) DO NOTHING;
