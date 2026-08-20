-- ══════════════════════════════════════════════════════════════════════════
-- 022_project_sdlc_workflow.sql
-- Phase B of docs/project-marketplace.md: models the SDLC gates a team walks
-- through (requirement doc, design review, architecture review, MR review,
-- graded milestone) as `kind` on the existing project_checkpoints — reuses
-- every MR/CI-gating and grading column already there, no new submission
-- machinery. Adds design-proposal voting for the design/architecture review
-- stages, and a lightweight ungraded task board for day-to-day work —
-- distinct from checkpoints, which stay the graded gates.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.project_checkpoints
    ADD COLUMN kind text NOT NULL DEFAULT 'milestone'
        CHECK (kind IN ('requirement_doc', 'design_review', 'architecture_review', 'mr_review', 'milestone'));

CREATE TABLE public.project_design_proposals (
    id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id       uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    checkpoint_id uuid NOT NULL REFERENCES public.project_checkpoints(id) ON DELETE CASCADE,
    team_id      uuid NOT NULL REFERENCES public.project_teams(id) ON DELETE CASCADE,
    submitted_by uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title        text NOT NULL,
    description  text,
    link         text,
    is_accepted  boolean DEFAULT false NOT NULL,
    created_at   timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_project_design_proposals_lookup ON public.project_design_proposals (checkpoint_id, team_id);

-- At most one accepted proposal per team per checkpoint — DB-level guarantee,
-- same partial-unique-index pattern gitlab_installations' "one default per
-- org" already uses.
CREATE UNIQUE INDEX idx_project_design_proposals_one_accepted
    ON public.project_design_proposals (checkpoint_id, team_id) WHERE is_accepted;

CREATE TABLE public.project_design_votes (
    proposal_id uuid NOT NULL REFERENCES public.project_design_proposals(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at  timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (proposal_id, user_id)
);

CREATE TABLE public.project_tasks (
    id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id           uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    team_id          uuid NOT NULL REFERENCES public.project_teams(id) ON DELETE CASCADE,
    checkpoint_id    uuid REFERENCES public.project_checkpoints(id) ON DELETE SET NULL,
    title            text NOT NULL,
    description      text,
    assignee_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    status           text NOT NULL DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'review', 'done')),
    due_at           timestamp with time zone,
    created_by       uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    created_at       timestamp with time zone DEFAULT now() NOT NULL,
    updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_project_tasks_team ON public.project_tasks (team_id, status);
