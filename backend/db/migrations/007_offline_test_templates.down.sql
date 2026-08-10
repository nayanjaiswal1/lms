ALTER TABLE public.assessments
    DROP CONSTRAINT IF EXISTS assessments_test_template_id_fkey,
    DROP COLUMN IF EXISTS test_template_id;

DROP TABLE IF EXISTS public.test_templates;
