-- ══════════════════════════════════════════════════════════════════════════
-- 020_project_marketplace.sql
-- Phase A, Slice 1 of docs/project-marketplace.md: the marketplace layer in
-- front of the existing project_assignments/project_teams system
-- (backend/internal/gitlab, batches 1-6). Staff post a requirement, students
-- browse an open board and apply, staff reviews and shortlists/selects.
--
-- Deliberately NOT in this migration: AI scoring columns, external profile
-- (GitHub OAuth/resume) storage, or any link to project_assignments —
-- project_assignments.batch_id is NOT NULL and provisioning-coupled (real
-- GitLab groups/templates), so turning a marketplace selection into an
-- actual team is a staff action via the existing project creation flow, not
-- an automatic write from this package. Reusing the gitlab_integration
-- feature flag (migration 019) for this domain rather than adding a new one
-- — same feature area from the org's perspective.
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE public.project_requirements (
    id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id               uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    title                text NOT NULL,
    brief                text NOT NULL,
    required_skills      text[] NOT NULL DEFAULT '{}',
    team_size_min        integer NOT NULL DEFAULT 1,
    team_size_max        integer NOT NULL DEFAULT 1,
    application_deadline timestamp with time zone NOT NULL,
    status               text NOT NULL DEFAULT 'draft'
                             CHECK (status IN ('draft', 'open', 'closed', 'archived')),
    created_by           uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    created_at           timestamp with time zone DEFAULT now() NOT NULL,
    updated_at           timestamp with time zone DEFAULT now() NOT NULL,
    CHECK (team_size_max >= team_size_min)
);

CREATE INDEX idx_project_requirements_board ON public.project_requirements (org_id, status, application_deadline);

CREATE TABLE public.project_applications (
    id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id         uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    requirement_id uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
    user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    motivation     text,
    status         text NOT NULL DEFAULT 'submitted'
                       CHECK (status IN ('submitted', 'shortlisted', 'selected', 'rejected')),
    reviewed_by    uuid REFERENCES public.users(id) ON DELETE SET NULL,
    reviewed_at    timestamp with time zone,
    applied_at     timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE (requirement_id, user_id)
);

CREATE INDEX idx_project_applications_requirement ON public.project_applications (requirement_id, status);
CREATE INDEX idx_project_applications_user ON public.project_applications (user_id);
