package gitlab

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
)

// ProjectMember is the subset of a GitLab project member this package needs
// for roster sync — AccessLevel maps to project_team_members.gitlab_access_level.
type ProjectMember struct {
	ID          int64  `json:"id"`
	Username    string `json:"username"`
	Name        string `json:"name"`
	AccessLevel int    `json:"access_level"`
}

// ListProjectMembers calls GET /projects/:id/members/all — "all" (not the
// plain /members endpoint) so inherited group-level members show up too;
// roster sync needs the full effective membership to compute an accurate
// diff, not just direct project-level adds.
func (c *Client) ListProjectMembers(ctx context.Context, projectID int64) ([]ProjectMember, error) {
	var members []ProjectMember
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/members/all?per_page=100", projectID), nil, &members); err != nil {
		return nil, fmt.Errorf("gitlab: list project %d members: %w", projectID, err)
	}
	return members, nil
}

// AddProjectMember adds gitlabUserID to projectID at accessLevel.
func (c *Client) AddProjectMember(ctx context.Context, projectID, gitlabUserID int64, accessLevel int) error {
	form := url.Values{
		"user_id":      {fmt.Sprintf("%d", gitlabUserID)},
		"access_level": {fmt.Sprintf("%d", accessLevel)},
	}
	if err := c.do(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/members?%s", projectID, form.Encode()), nil, nil); err != nil {
		return fmt.Errorf("gitlab: add member %d to project %d: %w", gitlabUserID, projectID, err)
	}
	return nil
}

// EditProjectMember changes an existing member's access level.
func (c *Client) EditProjectMember(ctx context.Context, projectID, gitlabUserID int64, accessLevel int) error {
	form := url.Values{"access_level": {fmt.Sprintf("%d", accessLevel)}}
	if err := c.do(ctx, http.MethodPut, fmt.Sprintf("/projects/%d/members/%d?%s", projectID, gitlabUserID, form.Encode()), nil, nil); err != nil {
		return fmt.Errorf("gitlab: edit member %d on project %d: %w", gitlabUserID, projectID, err)
	}
	return nil
}

// RemoveProjectMember removes gitlabUserID from projectID. A 404 (already
// gone — e.g. removed manually on GitLab's side) is treated as success:
// the caller's goal ("this person no longer has project access") already holds.
func (c *Client) RemoveProjectMember(ctx context.Context, projectID, gitlabUserID int64) error {
	err := c.do(ctx, http.MethodDelete, fmt.Sprintf("/projects/%d/members/%d", projectID, gitlabUserID), nil, nil)
	if err != nil {
		var apiErr *APIError
		if errors.As(err, &apiErr) && apiErr.StatusCode == http.StatusNotFound {
			return nil
		}
		return fmt.Errorf("gitlab: remove member %d from project %d: %w", gitlabUserID, projectID, err)
	}
	return nil
}

// GetUserByUsername resolves a GitLab username to its numeric user ID. Not
// called anywhere in Batch 2 yet — roster sync resolves each member's GitLab
// identity via their own gitlab_connections row, not by username lookup —
// but is part of this package's committed client surface per kind-herding-
// cookie.md §2's module-layout table for later batches (e.g. resolving a
// capstone handoff target's own account).
func (c *Client) GetUserByUsername(ctx context.Context, username string) (*GitlabUser, error) {
	var users []GitlabUser
	if err := c.do(ctx, http.MethodGet, "/users?username="+url.QueryEscape(username), nil, &users); err != nil {
		return nil, fmt.Errorf("gitlab: get user by username %q: %w", username, err)
	}
	if len(users) == 0 {
		return nil, fmt.Errorf("gitlab: user %q not found", username)
	}
	return &users[0], nil
}
