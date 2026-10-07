-- TEN-20: gitlab_project_id was globally UNIQUE, but numeric ids from different
-- tenants' GitLab instances collide. Scope uniqueness to the org. The old
-- constraint was stricter, so no existing row can violate the new index.
ALTER TABLE project_teams DROP CONSTRAINT IF EXISTS project_teams_gitlab_project_id_key;
CREATE UNIQUE INDEX IF NOT EXISTS project_teams_org_gitlab_project_key
    ON project_teams (org_id, gitlab_project_id) WHERE gitlab_project_id IS NOT NULL;
