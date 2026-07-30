package gitlab

import (
	"context"
	"errors"
	"fmt"
	"net/http"
)

// ProjectHook is the subset of a GitLab project webhook this package needs.
// token is write-only on GitLab's side (never returned by GET/POST/PUT), so
// it is intentionally absent from this struct.
type ProjectHook struct {
	ID                    int64  `json:"id"`
	URL                   string `json:"url"`
	PushEvents            bool   `json:"push_events"`
	MergeRequestsEvents   bool   `json:"merge_requests_events"`
	PipelineEvents        bool   `json:"pipeline_events"`
	IssuesEvents          bool   `json:"issues_events"`
	NoteEvents            bool   `json:"note_events"`
	JobEvents             bool   `json:"job_events"`
	DeploymentEvents      bool   `json:"deployment_events"`
	EnableSSLVerification bool   `json:"enable_ssl_verification"`
}

type addProjectHookRequest struct {
	URL                   string `json:"url"`
	Token                 string `json:"token"`
	PushEvents            bool   `json:"push_events"`
	MergeRequestsEvents   bool   `json:"merge_requests_events"`
	PipelineEvents        bool   `json:"pipeline_events"`
	IssuesEvents          bool   `json:"issues_events"`
	NoteEvents            bool   `json:"note_events"`
	JobEvents             bool   `json:"job_events"`
	DeploymentEvents      bool   `json:"deployment_events"`
	EnableSSLVerification bool   `json:"enable_ssl_verification"`
}

// AddProjectHook calls POST /projects/:id/hooks, registering hookURL for
// push/merge_requests/pipeline/issues/note events — job_events and
// deployment_events are deliberately left false (kind-herding-cookie.md §4:
// this feature never needs CI job-level or deployment-level granularity,
// only pipeline-level status). token is GitLab's own per-hook shared secret,
// echoed back on every delivery as X-Gitlab-Token — see handler_webhook.go.
func (c *Client) AddProjectHook(ctx context.Context, projectID int64, hookURL, token string) (*ProjectHook, error) {
	var hook ProjectHook
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/hooks", projectID), addProjectHookRequest{
		URL: hookURL, Token: token,
		PushEvents: true, MergeRequestsEvents: true, PipelineEvents: true, IssuesEvents: true, NoteEvents: true,
		JobEvents: false, DeploymentEvents: false, EnableSSLVerification: true,
	}, &hook); err != nil {
		return nil, fmt.Errorf("gitlab: add project hook to project %d: %w", projectID, err)
	}
	return &hook, nil
}

// ListProjectHooks calls GET /projects/:id/hooks.
func (c *Client) ListProjectHooks(ctx context.Context, projectID int64) ([]ProjectHook, error) {
	var hooks []ProjectHook
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/hooks", projectID), nil, &hooks); err != nil {
		return nil, fmt.Errorf("gitlab: list project hooks for project %d: %w", projectID, err)
	}
	return hooks, nil
}

// DeleteProjectHook calls DELETE /projects/:id/hooks/:hook_id. A 404 (already
// gone) is treated as success, mirroring RemoveProjectMember's own reasoning:
// the caller's goal ("this hook no longer exists") already holds.
func (c *Client) DeleteProjectHook(ctx context.Context, projectID, hookID int64) error {
	err := c.do(ctx, http.MethodDelete, fmt.Sprintf("/projects/%d/hooks/%d", projectID, hookID), nil, nil)
	if err != nil {
		var apiErr *APIError
		if errors.As(err, &apiErr) && apiErr.StatusCode == http.StatusNotFound {
			return nil
		}
		return fmt.Errorf("gitlab: delete project hook %d on project %d: %w", hookID, projectID, err)
	}
	return nil
}
