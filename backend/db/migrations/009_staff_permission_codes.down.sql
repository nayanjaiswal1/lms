DROP VIEW IF EXISTS effective_permissions;

DELETE FROM user_permission_overrides upo
USING permissions p
WHERE upo.permission_id = p.id
  AND p.code IN ('messaging.moderate', 'wiki.manage_spaces', 'wiki.create_spaces', 'mentoring.claim_tickets');

DELETE FROM role_permissions rp
USING permissions p
WHERE rp.permission_id = p.id
  AND p.code IN ('messaging.moderate', 'wiki.manage_spaces', 'wiki.create_spaces', 'mentoring.claim_tickets');

DELETE FROM permissions
WHERE code IN ('messaging.moderate', 'wiki.manage_spaces', 'wiki.create_spaces', 'mentoring.claim_tickets');
