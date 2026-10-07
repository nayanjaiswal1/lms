DROP INDEX IF EXISTS project_teams_org_gitlab_project_key;
-- Keep the oldest team per project id so the global constraint can be restored.
UPDATE project_teams t SET gitlab_project_id = NULL
WHERE gitlab_project_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM project_teams o
    WHERE o.gitlab_project_id = t.gitlab_project_id
      AND (o.created_at, o.id) < (t.created_at, t.id));
ALTER TABLE project_teams ADD CONSTRAINT project_teams_gitlab_project_id_key UNIQUE (gitlab_project_id);
