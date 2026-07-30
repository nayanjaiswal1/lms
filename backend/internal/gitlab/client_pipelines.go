package gitlab

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

// Pipeline is the subset of a GitLab CI pipeline this package needs for the
// activity mirror (gitlab_pipelines).
type Pipeline struct {
	ID         int64      `json:"id"`
	ProjectID  int64      `json:"project_id"`
	SHA        string     `json:"sha"`
	Ref        string     `json:"ref"`
	Status     string     `json:"status"`
	WebURL     string     `json:"web_url"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
	StartedAt  *time.Time `json:"started_at"`
	FinishedAt *time.Time `json:"finished_at"`
	Duration   *int       `json:"duration"`
}

// ListPipelines calls GET /projects/:id/pipelines — used by the poll_sync
// self-healing sweep.
func (c *Client) ListPipelines(ctx context.Context, projectID int64) ([]Pipeline, error) {
	var pipelines []Pipeline
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/pipelines?per_page=100", projectID), nil, &pipelines); err != nil {
		return nil, fmt.Errorf("gitlab: list pipelines for project %d: %w", projectID, err)
	}
	return pipelines, nil
}

// GetPipeline calls GET /projects/:id/pipelines/:pipeline_id — the full
// pipeline detail (list omits duration/started_at/finished_at on some
// GitLab versions).
func (c *Client) GetPipeline(ctx context.Context, projectID, pipelineID int64) (*Pipeline, error) {
	var p Pipeline
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/pipelines/%d", projectID, pipelineID), nil, &p); err != nil {
		return nil, fmt.Errorf("gitlab: get pipeline %d on project %d: %w", pipelineID, projectID, err)
	}
	return &p, nil
}
