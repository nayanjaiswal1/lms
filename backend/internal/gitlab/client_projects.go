package gitlab

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
)

// Project is the subset of a GitLab project this package needs across fork
// creation, import-status polling, and branch-protection setup.
type Project struct {
	ID                int64  `json:"id"`
	Name              string `json:"name"`
	Path              string `json:"path"`
	PathWithNamespace string `json:"path_with_namespace"`
	WebURL            string `json:"web_url"`
	Visibility        string `json:"visibility"`
	DefaultBranch     string `json:"default_branch"`
	ImportStatus      string `json:"import_status"`
}

// GetProject fetches a project by numeric ID — used both to resolve a
// template's visibility at assignment-creation time and to poll a fresh
// fork's import_status until GitLab finishes copying it.
func (c *Client) GetProject(ctx context.Context, projectID int64) (*Project, error) {
	var p Project
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d", projectID), nil, &p); err != nil {
		return nil, fmt.Errorf("gitlab: get project %d: %w", projectID, err)
	}
	return &p, nil
}

// GetProjectByPath fetches a project by its URL-encoded path_with_namespace
// (e.g. "group/subgroup/project") — resolves a template project's numeric ID
// from the human-friendly path an instructor enters when a request supplies
// template_project_path instead of template_project_id.
func (c *Client) GetProjectByPath(ctx context.Context, path string) (*Project, error) {
	var p Project
	if err := c.do(ctx, http.MethodGet, "/projects/"+url.PathEscape(path), nil, &p); err != nil {
		return nil, fmt.Errorf("gitlab: get project %q: %w", path, err)
	}
	return &p, nil
}

// ForkProject forks templateProjectID into namespaceID (a team's assignment
// subgroup) as a new project at path/name. Per this feature's architecture
// (kind-herding-cookie.md §0 decision #3), the fork relationship is always
// kept — this package never calls the unfork endpoint — so mid-project
// template updates can later land as a single cross-fork MR instead of a
// manual patch pipeline.
func (c *Client) ForkProject(ctx context.Context, templateProjectID, namespaceID int64, path, name string) (*Project, error) {
	form := url.Values{
		"namespace_id": {fmt.Sprintf("%d", namespaceID)},
		"path":         {path},
		"name":         {name},
	}
	var p Project
	if err := c.do(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/fork?%s", templateProjectID, form.Encode()), nil, &p); err != nil {
		return nil, fmt.Errorf("gitlab: fork project %d: %w", templateProjectID, err)
	}
	return &p, nil
}

type updateProjectRequest struct {
	Visibility string `json:"visibility"`
}

// UpdateProject sets a project's visibility. Batch 2's only caller is the
// post-fork step that forces a new fork back to the assignment's configured
// visibility — GitLab forks otherwise inherit the source's visibility, and
// this feature's own architecture requires the template (and therefore every
// fork) stay private/internal, never public.
func (c *Client) UpdateProject(ctx context.Context, projectID int64, visibility string) (*Project, error) {
	var p Project
	if err := c.doJSON(ctx, http.MethodPut, fmt.Sprintf("/projects/%d", projectID), updateProjectRequest{Visibility: visibility}, &p); err != nil {
		return nil, fmt.Errorf("gitlab: update project %d: %w", projectID, err)
	}
	return &p, nil
}

// Pages is the subset of a GitLab Pages deployment this package needs — the
// Batch 6 Pages-URL-refresh step's read side (service_webhook.go's
// maybeRefreshPagesURL calls this after a pipeline succeeds).
type Pages struct {
	URL string `json:"url"`
}

// GetPages calls GET /projects/:id/pages. GitLab returns 404 until Pages has
// been deployed at least once for the project — callers must treat that as
// "no Pages site yet," not an error worth surfacing.
func (c *Client) GetPages(ctx context.Context, projectID int64) (*Pages, error) {
	var p Pages
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/pages", projectID), nil, &p); err != nil {
		return nil, fmt.Errorf("gitlab: get pages for project %d: %w", projectID, err)
	}
	return &p, nil
}

// ArchiveProject calls POST /projects/:id/archive. Part of this package's
// committed Batch 6 client surface (kind-herding-cookie.md §2's
// client_projects.go table); no caller within this batch's own scope yet —
// same "ships ahead of its first caller" shape Batch 1's userClientFor had.
func (c *Client) ArchiveProject(ctx context.Context, projectID int64) (*Project, error) {
	var p Project
	if err := c.do(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/archive", projectID), nil, &p); err != nil {
		return nil, fmt.Errorf("gitlab: archive project %d: %w", projectID, err)
	}
	return &p, nil
}

// TransferProject calls PUT /projects/:id/transfer?namespace=... — moves an
// existing project into a different namespace in place (same project ID,
// new path_with_namespace/web_url). The transfer-mode half of Batch 6's
// capstone handoff (service_handoff.go); fork-mode reuses ForkProject
// instead of this, per §0.5's own reasoning (fork-and-keep-relationship is
// this feature's one repo-creation mechanism).
func (c *Client) TransferProject(ctx context.Context, projectID, namespaceID int64) (*Project, error) {
	form := url.Values{"namespace": {fmt.Sprintf("%d", namespaceID)}}
	var p Project
	if err := c.do(ctx, http.MethodPut, fmt.Sprintf("/projects/%d/transfer?%s", projectID, form.Encode()), nil, &p); err != nil {
		return nil, fmt.Errorf("gitlab: transfer project %d to namespace %d: %w", projectID, namespaceID, err)
	}
	return &p, nil
}

// ProtectBranch protects branch on projectID with the given push/merge
// access levels (GitLab's 20/30/40/50 access-level scale). Idempotent: a
// branch already protected returns 409 from GitLab, which is treated as
// success so reprovisioning a team is always safe to call again. Batch 2
// only sets who can push/merge — how many approvals additionally gate a
// merge (project_team_checkpoints.approvals_count, EE approval_rules) is a
// Batch 5 concern layered on top of this, not built here.
func (c *Client) ProtectBranch(ctx context.Context, projectID int64, branch string, pushAccessLevel, mergeAccessLevel int) error {
	form := url.Values{
		"name":               {branch},
		"push_access_level":  {fmt.Sprintf("%d", pushAccessLevel)},
		"merge_access_level": {fmt.Sprintf("%d", mergeAccessLevel)},
	}
	err := c.do(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/protected_branches?%s", projectID, form.Encode()), nil, nil)
	if err != nil {
		var apiErr *APIError
		if errors.As(err, &apiErr) && apiErr.StatusCode == http.StatusConflict {
			return nil
		}
		return fmt.Errorf("gitlab: protect branch %q on project %d: %w", branch, projectID, err)
	}
	return nil
}
