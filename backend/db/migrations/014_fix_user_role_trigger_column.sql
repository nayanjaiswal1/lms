-- fn_check_user_role_tenant_scope (001_baseline.sql) reads roles.tenant_id
-- and NEW.tenant_id, but neither column exists: roles and user_roles both
-- scope by org_id. Every INSERT INTO user_roles fires
-- trg_user_role_tenant_scope BEFORE INSERT and immediately fails with
-- 42703 column "tenant_id" does not exist, so no role can ever be assigned
-- through the application. Swap both references to org_id; the
-- system-role-bypass / mismatch-raises-exception logic is unchanged.
CREATE OR REPLACE FUNCTION public.fn_check_user_role_tenant_scope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  role_org_id UUID;
BEGIN
  SELECT org_id INTO role_org_id FROM roles WHERE id = NEW.role_id;
  IF role_org_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF role_org_id IS DISTINCT FROM NEW.org_id THEN
    RAISE EXCEPTION
      'Org-scope violation: role % belongs to org % but assignment targets org %.',
      NEW.role_id, role_org_id, NEW.org_id
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
