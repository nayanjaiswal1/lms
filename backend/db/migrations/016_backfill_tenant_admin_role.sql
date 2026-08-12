-- org_members.role ('owner'/'admin') has never been mirrored into the RBAC
-- user_roles table — nothing assigned it on org creation, invite acceptance,
-- or member promotion (now wired in internal/orgs/rbac_sync.go, called from
-- OrgService.Create, InviteService.Join, and MemberService.Update/Remove).
-- Every org whose owner/admin predates that wiring is still missing the
-- tenant_admin row, so any endpoint gated on an admin.* RBAC permission
-- (e.g. admin.view_audit_log) 403s the org's own admins. Backfill them.
INSERT INTO public.user_roles (user_id, role_id, org_id)
SELECT om.user_id, r.id, om.org_id
FROM public.org_members om
JOIN public.roles r ON r.name = 'tenant_admin' AND r.is_system = true
WHERE om.role IN ('owner', 'admin') AND om.status = 'active'
ON CONFLICT DO NOTHING;
