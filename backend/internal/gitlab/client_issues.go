package gitlab

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// Issue is the subset of a GitLab issue this package needs for the activity
// mirror (gitlab_issues) and, in later batches, milestone/checkpoint mapping.
type Issue struct {
	ID        int64  `json:"id"`
	IID       int64  `json:"iid"`
	ProjectID int64  `json:"project_id"`
	Title     string `json:"title"`
	State     string `json:"state"`
	Milestone *struct {
		ID int64 `json:"id"`
	} `json:"milestone"`
	Assignee *struct {
		ID int64 `json:"id"`
	} `json:"assignee"`
	Weight    *int       `json:"weight"`
	Labels    []string   `json:"labels"`
	CreatedAt time.Time  `json:"created_at"`
	ClosedAt  *time.Time `json:"closed_at"`
}

// ListIssues calls GET /projects/:id/issues?state=... — state is one of
// "opened"/"closed"/"all".
func (c *Client) ListIssues(ctx context.Context, projectID int64, state string) ([]Issue, error) {
	q := url.Values{"per_page": {"100"}}
	if state != "" {
		q.Set("state", state)
	}
	var issues []Issue
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/issues?%s", projectID, q.Encode()), nil, &issues); err != nil {
		return nil, fmt.Errorf("gitlab: list issues for project %d: %w", projectID, err)
	}
	return issues, nil
}

type createIssueRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
}

// CreateIssue calls POST /projects/:id/issues.
func (c *Client) CreateIssue(ctx context.Context, projectID int64, title, description string) (*Issue, error) {
	var issue Issue
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/issues", projectID), createIssueRequest{
		Title: title, Description: description,
	}, &issue); err != nil {
		return nil, fmt.Errorf("gitlab: create issue on project %d: %w", projectID, err)
	}
	return &issue, nil
}

// GetIssue calls GET /projects/:id/issues/:issue_iid.
func (c *Client) GetIssue(ctx context.Context, projectID, issueIID int64) (*Issue, error) {
	var issue Issue
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/issues/%d", projectID, issueIID), nil, &issue); err != nil {
		return nil, fmt.Errorf("gitlab: get issue %d on project %d: %w", issueIID, projectID, err)
	}
	return &issue, nil
}
