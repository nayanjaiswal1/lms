-- Grant jaiswal2062@gmail.com every role and permission on the platform.
-- Safe to run multiple times (all writes are idempotent).
--
-- Notes on the org_members role column:
--   owner > admin > instructor > mentor > student
--   The enforce_last_owner trigger blocks demoting the last active owner.
--   We only upgrade non-owner members — owners are already the highest.
--
-- Notes on user_roles (RBAC):
--   Requires migrations 016 + 017. The block below is guarded by a table
--   existence check so this file stays safe to run before those migrations.

-- 1. Platform-level: elevate to super_admin
UPDATE users
SET    platform_role = 'super_admin',
       email_verified = true,
       updated_at     = now()
WHERE  email = 'jaiswal2062@gmail.com';

-- 2. Org-level: add to the default org as owner if not already a member
INSERT INTO org_members (org_id, user_id, role)
SELECT '00000000-0000-0000-0000-000000000001',
       u.id,
       'owner'
FROM   users u
WHERE  u.email = 'jaiswal2062@gmail.com'
ON CONFLICT (org_id, user_id) DO NOTHING;

-- 3. Org-level: upgrade non-owner memberships to admin
--    (owners are not touched — demoting the last owner is blocked by trigger)
UPDATE org_members
SET    role = 'admin'
WHERE  user_id = (SELECT id FROM users WHERE email = 'jaiswal2062@gmail.com')
  AND  role NOT IN ('owner');

-- 4. RBAC: assign every system role per org (only if migrations 016+017 applied)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_roles'
  ) THEN
    INSERT INTO user_roles (user_id, role_id, tenant_id)
    SELECT u.id,
           r.id,
           om.org_id
    FROM   users u
    JOIN   org_members om ON om.user_id = u.id
    CROSS  JOIN roles r
    WHERE  u.email = 'jaiswal2062@gmail.com'
      AND  r.is_system = true
    ON CONFLICT DO NOTHING;
  END IF;
END $$;
