-- ══════════════════════════════════════════════════════════════════════════
-- seed_role_test_accounts.sql — One dedicated dev login per RBAC system role
-- ══════════════════════════════════════════════════════════════════════════
-- Five accounts, each holding exactly one system RBAC role (unlike
-- grant_all_roles_jaiswal.sql, which grants jaiswal2062@gmail.com every
-- role on one account). Useful for testing role-gated UI/API in isolation.
-- All writes are idempotent — safe to run multiple times.
--
-- Login:  jaiswal2062+<role>@gmail.com / 123
--   jaiswal2062+viewer@gmail.com       -> viewer
--   jaiswal2062+member@gmail.com       -> member
--   jaiswal2062+instructor@gmail.com   -> instructor
--   jaiswal2062+mentor@gmail.com       -> mentor
--   jaiswal2062+tenant_admin@gmail.com -> tenant_admin

-- ─── Users ────────────────────────────────────────────────────────────────────

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000030', 'jaiswal2062+viewer@gmail.com', 'Test Viewer',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000031', 'jaiswal2062+member@gmail.com', 'Test Member',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000032', 'jaiswal2062+instructor@gmail.com', 'Test Instructor',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000033', 'jaiswal2062+mentor@gmail.com', 'Test Mentor',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000034', 'jaiswal2062+tenant_admin@gmail.com', 'Test Tenant Admin',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

-- ─── Org membership (coarse org_members.role) ────────────────────────────────
-- org_members.role only accepts owner/admin/instructor/mentor/learner — viewer
-- and member both map to the closest coarse role, 'learner'.

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000040', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000030', 'learner')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000031', 'learner')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000032', 'instructor')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000043', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000033', 'mentor')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000044', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000034', 'admin')
ON CONFLICT (org_id, user_id) DO NOTHING;

-- ─── Fine-grained RBAC (user_roles) — exactly one system role each ───────────

INSERT INTO user_roles (user_id, role_id, tenant_id)
VALUES ('00000000-0000-0000-0000-000000000030', '11111111-1111-1111-1111-000000000001', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, tenant_id)
VALUES ('00000000-0000-0000-0000-000000000031', '11111111-1111-1111-1111-000000000002', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, tenant_id)
VALUES ('00000000-0000-0000-0000-000000000032', '11111111-1111-1111-1111-000000000003', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, tenant_id)
VALUES ('00000000-0000-0000-0000-000000000033', '11111111-1111-1111-1111-000000000004', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, tenant_id)
VALUES ('00000000-0000-0000-0000-000000000034', '11111111-1111-1111-1111-000000000005', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;
