DELETE FROM public.user_roles
WHERE role_id = (SELECT id FROM public.roles WHERE name = 'tenant_admin' AND is_system = true)
  AND (user_id, org_id) IN (
    SELECT om.user_id, om.org_id
    FROM public.org_members om
    WHERE om.role IN ('owner', 'admin') AND om.status = 'active'
  );
