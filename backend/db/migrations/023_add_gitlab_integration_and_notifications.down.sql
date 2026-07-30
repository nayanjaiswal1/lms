-- ═════════════════════════════════════════════════════════════════════════
-- Migration 023 — add_gitlab_integration_and_notifications (rollback)
-- Drops in reverse FK order.
-- ═════════════════════════════════════════════════════════════════════════

DELETE FROM public.role_permissions
    WHERE permission_id IN (SELECT id FROM public.permissions WHERE code IN ('projects.view', 'projects.manage'));
DELETE FROM public.permissions WHERE code IN ('projects.view', 'projects.manage');

ALTER TABLE public.lab_sessions
    DROP CONSTRAINT IF EXISTS lab_sessions_repo_clone_status_check,
    DROP CONSTRAINT IF EXISTS lab_sessions_project_team_fk;
ALTER TABLE public.lab_sessions
    DROP COLUMN IF EXISTS repo_clone_error,
    DROP COLUMN IF EXISTS repo_clone_status,
    DROP COLUMN IF EXISTS project_team_id;

DROP TABLE IF EXISTS public.notifications;

DROP TABLE IF EXISTS public.project_handoffs;
DROP TABLE IF EXISTS public.project_originality_matches;
DROP TABLE IF EXISTS public.project_originality_reports;

DROP TABLE IF EXISTS public.gitlab_webhook_events;
DROP TABLE IF EXISTS public.gitlab_issues;
DROP TABLE IF EXISTS public.gitlab_pipelines;
DROP TABLE IF EXISTS public.gitlab_mr_reviews;
DROP TABLE IF EXISTS public.gitlab_merge_requests;
DROP TABLE IF EXISTS public.gitlab_commits;

DROP TABLE IF EXISTS public.project_team_checkpoints;
DROP TABLE IF EXISTS public.project_checkpoints;

DROP TABLE IF EXISTS public.project_team_members;
DROP TABLE IF EXISTS public.project_teams;
DROP TABLE IF EXISTS public.project_assignments;

DROP TABLE IF EXISTS public.gitlab_oauth_states;
DROP TABLE IF EXISTS public.gitlab_connections;
DROP TABLE IF EXISTS public.gitlab_installations;
