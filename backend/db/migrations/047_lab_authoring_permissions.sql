-- ══════════════════════════════════════════════════════════════════════════
-- 047_lab_authoring_permissions.sql — RBAC codes for the generic lab-authoring
-- engine (backend/internal/labauthor; docs/debug-labs.md Part 2 §B7, where
-- they are named debuglabs.* — the generic names apply because composition is
-- kind-agnostic, see the "Generic lab-kind architecture" section).
--
--   labauthor.compose       use the block library and build/validate recipes
--                           (instructor; tenant_admin holds all permissions)
--   labauthor.manage_blocks create/edit/delete org-owned text blocks
--                           (ticket/hints/rubric/preset)
--                           (instructor + tenant_admin = org admin)
--
-- Publishing a built lab reuses courses.publish. Yanking a block version is a
-- platform super_admin action gated by RequirePlatformRole, not a permission.
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

INSERT INTO public.permissions (code, name, description, module)
VALUES
  ('labauthor.compose',       'Compose Lab Recipes',      'Browse the lab block library and compose, validate and build lab recipes', 'labs'),
  ('labauthor.manage_blocks', 'Manage Lab Text Blocks',   'Create, edit and delete organization-owned lab text blocks (ticket, hints, rubric, presets)', 'labs')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.role_id, p.id
FROM public.permissions p
JOIN (VALUES
  ('11111111-1111-1111-1111-000000000003'::uuid, 'labauthor.compose'),       -- instructor
  ('11111111-1111-1111-1111-000000000005'::uuid, 'labauthor.compose'),       -- tenant_admin
  ('11111111-1111-1111-1111-000000000003'::uuid, 'labauthor.manage_blocks'), -- instructor
  ('11111111-1111-1111-1111-000000000005'::uuid, 'labauthor.manage_blocks')  -- tenant_admin
) AS r(role_id, code) ON r.code = p.code
ON CONFLICT DO NOTHING;
