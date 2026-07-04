-- ════════════════════════════════════════════════════════════════════════════
-- 022_mentor_ticket_permissions.sql — RBAC codes for mentor-ticket assignment
-- ════════════════════════════════════════════════════════════════════════════
-- mentoring.assign_tickets: hand-assign a specific mentor to a student's
--   ticket (self-claim by a mentor uses the existing org-role check, not a
--   permission code). Granted to instructor + tenant_admin by default; a
--   tenant_admin can regrant it to other roles later via /admin/rbac/roles.
-- mentoring.manage_reports: review/resolve mentor complaint reports.
--   Granted to tenant_admin only by default.

INSERT INTO permissions (code, name, description, module) VALUES
  ('mentoring.assign_tickets', 'Assign Mentor Tickets', 'Hand-assign a specific mentor to a student ticket', 'mentoring'),
  ('mentoring.manage_reports', 'Manage Mentor Reports', 'Review and resolve mentor complaint reports', 'mentoring')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.id = '11111111-1111-1111-1111-000000000003' -- instructor
  AND p.code = 'mentoring.assign_tickets'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.id = '11111111-1111-1111-1111-000000000005' -- tenant_admin
  AND p.code IN ('mentoring.assign_tickets', 'mentoring.manage_reports')
ON CONFLICT DO NOTHING;
