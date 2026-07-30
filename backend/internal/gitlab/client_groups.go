package gitlab

import (
	"context"
	"fmt"
	"net/http"
)

// Group is the subset of a GitLab group/subgroup this package needs.
type Group struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	Path       string `json:"path"`
	FullPath   string `json:"full_path"`
	WebURL     string `json:"web_url"`
	Visibility string `json:"visibility"`
}

type createGroupRequest struct {
	Name       string `json:"name"`
	Path       string `json:"path"`
	ParentID   int64  `json:"parent_id"`
	Visibility string `json:"visibility"`
}

// CreateGroup creates a subgroup under parentID (the installation's own
// root_group_id) to hold one project_assignment's per-team forked projects.
// Called once per assignment, the first time any of its teams is
// provisioned — path must be unique within the parent namespace, which
// callers guarantee by deriving it from the assignment's own uuid rather
// than its (batch-scoped, not globally unique) slug.
func (c *Client) CreateGroup(ctx context.Context, name, path string, parentID int64, visibility string) (*Group, error) {
	var g Group
	if err := c.doJSON(ctx, http.MethodPost, "/groups", createGroupRequest{
		Name: name, Path: path, ParentID: parentID, Visibility: visibility,
	}, &g); err != nil {
		return nil, fmt.Errorf("gitlab: create group: %w", err)
	}
	return &g, nil
}

// GetGroup fetches a group/subgroup by numeric ID.
func (c *Client) GetGroup(ctx context.Context, groupID int64) (*Group, error) {
	var g Group
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/groups/%d", groupID), nil, &g); err != nil {
		return nil, fmt.Errorf("gitlab: get group %d: %w", groupID, err)
	}
	return &g, nil
}

// Milestone is the subset of a GitLab group milestone this package needs.
type Milestone struct {
	ID    int64  `json:"id"`
	IID   int64  `json:"iid"`
	Title string `json:"title"`
	State string `json:"state"`
}

type createGroupMilestoneRequest struct {
	Title   string `json:"title"`
	DueDate string `json:"due_date,omitempty"`
}

// CreateGroupMilestone calls POST /groups/:id/milestones — creates a
// milestone in the assignment's GitLab subgroup so a checkpoint can be
// tagged onto issues (their milestone_id) and mapped back to the checkpoint
// via the Issue Hook (see service_checkpoint.go's checkpoint-create path and
// service_webhook.go's ingestIssueEvent). dueDate, when non-nil, must be
// "YYYY-MM-DD" (GitLab's own milestone date format).
func (c *Client) CreateGroupMilestone(ctx context.Context, groupID int64, title string, dueDate *string) (*Milestone, error) {
	req := createGroupMilestoneRequest{Title: title}
	if dueDate != nil {
		req.DueDate = *dueDate
	}
	var m Milestone
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/groups/%d/milestones", groupID), req, &m); err != nil {
		return nil, fmt.Errorf("gitlab: create group milestone on group %d: %w", groupID, err)
	}
	return &m, nil
}
