-- ═════════════════════════════════════════════════════════════════════════
-- Migration 005 — add_cohort_groups
-- Optional hierarchy ABOVE batches (e.g. Class 10 -> Section A -> batch),
-- for orgs that group cohorts more than one level deep. Self-referencing
-- tree via parent_id so depth is unbounded and org-defined; level_label is
-- free text so one org can call its levels "Class"/"Section" and another
-- "Program"/"Cohort" without another migration. batches.cohort_group_id is
-- nullable — orgs that don't use this keep flat batches, zero impact.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.cohort_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    parent_id uuid,
    name text NOT NULL,
    slug text NOT NULL,
    level_label text,
    status text DEFAULT 'active'::text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cohort_groups_pkey PRIMARY KEY (id),
    CONSTRAINT cohort_groups_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT cohort_groups_parent_fk FOREIGN KEY (parent_id)
        REFERENCES public.cohort_groups(id) ON DELETE CASCADE,
    CONSTRAINT cohort_groups_no_self_parent CHECK (parent_id IS NULL OR parent_id <> id),
    CONSTRAINT cohort_groups_status_check CHECK ((status = ANY (ARRAY['active'::text, 'archived'::text])))
);

CREATE INDEX idx_cohort_groups_org ON public.cohort_groups (org_id, status);
CREATE INDEX idx_cohort_groups_parent ON public.cohort_groups (parent_id);
CREATE UNIQUE INDEX idx_cohort_groups_slug ON public.cohort_groups (org_id, slug);

ALTER TABLE public.batches
    ADD COLUMN cohort_group_id uuid REFERENCES public.cohort_groups(id) ON DELETE SET NULL;

CREATE INDEX idx_batches_cohort_group ON public.batches (cohort_group_id);
