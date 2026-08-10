-- ══════════════════════════════════════════════════════════════════════════
-- 007_offline_test_templates.sql
-- test_templates lets a teacher save an offline/paper test's name + default
-- max score once and reuse it across batches, instead of retyping the same
-- "test_name"/"max_score" pair (see assessment.CreateOfflineTestScores) every
-- time. Mirrors the ad-hoc offline-test shape exactly — this package's
-- "test" has never carried anything beyond a name, a date, and a max score
-- (no rubric field exists anywhere in the offline-test flow to template).
-- test_id on assessments records which template (if any) an offline test
-- was created from, purely informational — editing a template never
-- retroactively changes tests already created from it.
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE public.test_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name text NOT NULL,
    max_score numeric(9,2) NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT test_templates_pkey PRIMARY KEY (id),
    CONSTRAINT test_templates_max_score_check CHECK (max_score > 0),
    CONSTRAINT test_templates_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT test_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE CASCADE
);

CREATE INDEX test_templates_org_id_name_idx ON public.test_templates (org_id, name);

ALTER TABLE public.assessments
    ADD COLUMN test_template_id uuid,
    ADD CONSTRAINT assessments_test_template_id_fkey FOREIGN KEY (test_template_id) REFERENCES public.test_templates(id) ON DELETE SET NULL;
