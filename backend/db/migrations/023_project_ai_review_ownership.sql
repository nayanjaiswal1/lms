-- ══════════════════════════════════════════════════════════════════════════
-- 023_project_ai_review_ownership.sql
-- Phase C of docs/project-marketplace.md: one AI code-quality comment per MR
-- (never an auto-commit/auto-merge — review only), and a feature-ownership
-- view aggregated from real per-file change data, not an AI call.
--
-- gitlab_commit_files stores the added/modified/removed file paths GitLab's
-- push webhook already sends per commit (service_webhook.go's pushEventPayload
-- never parsed them before this) — denormalized (org_id/team_id copied onto
-- every row, no FK to gitlab_commits) so the ownership aggregation never
-- needs to join back through it, same denormalization gitlab_commits itself
-- already uses instead of joining through gitlab_projects.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.gitlab_merge_requests
    ADD COLUMN ai_reviewed_at timestamp with time zone;

CREATE TABLE public.gitlab_commit_files (
    org_id                 uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    team_id                uuid NOT NULL REFERENCES public.project_teams(id) ON DELETE CASCADE,
    sha                    text NOT NULL,
    file_path              text NOT NULL,
    change_type            text NOT NULL CHECK (change_type IN ('added', 'modified', 'removed')),
    author_gitlab_user_id  bigint,
    author_user_id         uuid REFERENCES public.users(id) ON DELETE SET NULL,
    committed_at           timestamp with time zone,
    PRIMARY KEY (team_id, sha, file_path)
);

CREATE INDEX idx_gitlab_commit_files_ownership ON public.gitlab_commit_files (team_id, file_path);
