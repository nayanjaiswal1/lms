-- Sidebar/Learn-hub items were gated on permissions no system role held
-- (Captures) or only some roles held (Interview Experiences).
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM (VALUES
    ('member',       'content.captures'),
    ('instructor',   'content.captures'),
    ('mentor',       'content.captures'),
    ('tenant_admin', 'content.captures'),
    ('instructor',   'content.interview_exp'),
    ('mentor',       'content.interview_exp')
) AS g(role_name, perm_code)
JOIN roles r ON r.name = g.role_name AND r.is_system
JOIN permissions p ON p.code = g.perm_code
ON CONFLICT DO NOTHING;
