DELETE FROM role_permissions rp
USING roles r, permissions p
WHERE rp.role_id = r.id AND rp.permission_id = p.id AND r.is_system
  AND ((p.code = 'content.captures' AND r.name IN ('member','instructor','mentor','tenant_admin'))
    OR (p.code = 'content.interview_exp' AND r.name IN ('instructor','mentor')));
