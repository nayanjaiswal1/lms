-- Restores the original (buggy) 001_baseline.sql body, which references the
-- non-existent tenant_id column on both roles and user_roles and makes every
-- INSERT INTO user_roles fail with 42703.
CREATE OR REPLACE FUNCTION public.fn_check_user_role_tenant_scope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  role_tenant_id UUID;
BEGIN
  SELECT tenant_id INTO role_tenant_id FROM roles WHERE id = NEW.role_id;
  IF role_tenant_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF role_tenant_id IS DISTINCT FROM NEW.tenant_id THEN
    RAISE EXCEPTION
      'Tenant-scope violation: role % belongs to tenant % but assignment targets tenant %.',
      NEW.role_id, role_tenant_id, NEW.tenant_id
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
