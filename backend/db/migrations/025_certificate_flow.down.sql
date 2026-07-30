DROP TABLE IF EXISTS public.certificate_rules;

ALTER TABLE public.certificates
    DROP CONSTRAINT IF EXISTS certificates_issued_by_fkey,
    DROP CONSTRAINT IF EXISTS certificates_issue_type_check,
    DROP COLUMN IF EXISTS issued_by,
    DROP COLUMN IF EXISTS issue_type,
    ALTER COLUMN final_test_attempt_id SET NOT NULL;
