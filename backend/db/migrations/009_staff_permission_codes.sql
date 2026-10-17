-- 009_staff_permission_codes.sql
-- Phase 2 of the RBAC consolidation: every route that used to compare the
-- org_members.role label (middleware.RequireOrgRole, CallerRole checks) now
-- checks a permission code. Four staff actions had no code that the exact
-- same role set holds, so they get their own:
--   messaging.moderate      instructor, mentor, tenant_admin (owner/admin)
--   wiki.manage_spaces      instructor, mentor, tenant_admin
--   wiki.create_spaces      instructor, tenant_admin (mentors never could)
--   mentoring.claim_tickets mentor only (the claim route was mentor-only)
--
-- effective_permissions is the single definition of "user U holds code C in
-- org O": active role grants unioned with direct overrides, both limited to
-- active permissions, active roles and an active org membership. Per-user
-- resolution (authz.Repo.GetEffectivePermissions) and recipient lookups
-- (authz.Repo.OrgPermissionHolders, auth MFA enforcement) all read it.

INSERT INTO permissions (id, code, name, description, module, is_active) VALUES
    ('b452c544-ff11-4e5c-af2d-ae9c8b9874d1', 'messaging.moderate', 'Moderate Messaging', 'Resolve, pin, promote and delete batch messages, reorder FAQs, and read every batch conversation in the org', 'messaging', true),
    ('5bd4326e-2d6e-431e-afd1-411486b1da53', 'wiki.manage_spaces', 'Manage Wiki Content', 'Read every course wiki space, see drafts, create pages and templates, edit own pages', 'content', true),
    ('473ca95e-c9ae-4858-9dec-c5acdd3d1f83', 'wiki.create_spaces', 'Create Wiki Spaces', 'Create org-wide and course-linked wiki spaces', 'content', true),
    ('aac97b45-8806-4836-9b99-b78cd91846c2', 'mentoring.claim_tickets', 'Claim Mentor Tickets', 'Claim open mentor tickets from the org queue', 'mentoring', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM (VALUES
    ('instructor',   'messaging.moderate'),
    ('mentor',       'messaging.moderate'),
    ('tenant_admin', 'messaging.moderate'),
    ('instructor',   'wiki.manage_spaces'),
    ('mentor',       'wiki.manage_spaces'),
    ('tenant_admin', 'wiki.manage_spaces'),
    ('instructor',   'wiki.create_spaces'),
    ('tenant_admin', 'wiki.create_spaces'),
    ('mentor',       'mentoring.claim_tickets')
) AS g(role_name, perm_code)
JOIN roles r ON r.name = g.role_name AND r.is_system
JOIN permissions p ON p.code = g.perm_code
ON CONFLICT DO NOTHING;

CREATE VIEW effective_permissions AS
SELECT ur.user_id, ur.org_id, p.code
FROM user_roles ur
JOIN roles r ON r.id = ur.role_id AND r.is_active = true
JOIN role_permissions rp ON rp.role_id = r.id
JOIN permissions p ON p.id = rp.permission_id AND p.is_active = true
JOIN org_members om ON om.org_id = ur.org_id AND om.user_id = ur.user_id AND om.status = 'active'
UNION
SELECT upo.user_id, upo.org_id, p.code
FROM user_permission_overrides upo
JOIN permissions p ON p.id = upo.permission_id AND p.is_active = true
JOIN org_members om ON om.org_id = upo.org_id AND om.user_id = upo.user_id AND om.status = 'active';
