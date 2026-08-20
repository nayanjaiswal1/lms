package gitlab

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// MergeRequest is the subset of a GitLab merge request this package needs
// for the activity mirror (gitlab_merge_requests) and, in later batches,
// checkpoint binding.
type MergeRequest struct {
	ID           int64  `json:"id"`
	IID          int64  `json:"iid"`
	ProjectID    int64  `json:"project_id"`
	Title        string `json:"title"`
	Description  string `json:"description"`
	State        string `json:"state"`
	SourceBranch string `json:"source_branch"`
	TargetBranch string `json:"target_branch"`
	Author       struct {
		ID       int64  `json:"id"`
		Username string `json:"username"`
	} `json:"author"`
	WebURL    string     `json:"web_url"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	MergedAt  *time.Time `json:"merged_at"`
	ClosedAt  *time.Time `json:"closed_at"`
}

// ListMergeRequests calls GET /projects/:id/merge_requests?state=... — state
// is one of "opened"/"closed"/"locked"/"merged"/"all".
func (c *Client) ListMergeRequests(ctx context.Context, projectID int64, state string) ([]MergeRequest, error) {
	q := url.Values{"per_page": {"100"}}
	if state != "" {
		q.Set("state", state)
	}
	var mrs []MergeRequest
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/merge_requests?%s", projectID, q.Encode()), nil, &mrs); err != nil {
		return nil, fmt.Errorf("gitlab: list merge requests for project %d: %w", projectID, err)
	}
	return mrs, nil
}

// GetMergeRequest calls GET /projects/:id/merge_requests/:iid.
func (c *Client) GetMergeRequest(ctx context.Context, projectID, mrIID int64) (*MergeRequest, error) {
	var mr MergeRequest
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/merge_requests/%d", projectID, mrIID), nil, &mr); err != nil {
		return nil, fmt.Errorf("gitlab: get merge request %d on project %d: %w", mrIID, projectID, err)
	}
	return &mr, nil
}

type createMergeRequestRequest struct {
	SourceBranch    string `json:"source_branch"`
	TargetBranch    string `json:"target_branch"`
	Title           string `json:"title"`
	TargetProjectID int64  `json:"target_project_id,omitempty"`
}

// CreateMergeRequest calls POST /projects/:id/merge_requests — opens a new
// MR from sourceBranch into targetBranch.
func (c *Client) CreateMergeRequest(ctx context.Context, projectID int64, sourceBranch, targetBranch, title string) (*MergeRequest, error) {
	var mr MergeRequest
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/merge_requests", projectID), createMergeRequestRequest{
		SourceBranch: sourceBranch, TargetBranch: targetBranch, Title: title,
	}, &mr); err != nil {
		return nil, fmt.Errorf("gitlab: create merge request on project %d: %w", projectID, err)
	}
	return &mr, nil
}

// CreateCrossForkMergeRequest calls POST /projects/:id/merge_requests
// (:id = sourceProjectID) with target_project_id set — Batch 6's
// gitlab.template_sync job body opens exactly this: an MR from the
// assignment's template project (sourceProjectID, sourceBranch) into a
// team's own forked project (targetProjectID, targetBranch), reusing the
// fork network relationship every team already has from provisioning (§0
// decision #3). GitLab requires source and target to be in the same fork
// network for this to succeed; unrelated projects get rejected.
func (c *Client) CreateCrossForkMergeRequest(ctx context.Context, sourceProjectID int64, sourceBranch string, targetProjectID int64, targetBranch, title string) (*MergeRequest, error) {
	var mr MergeRequest
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/merge_requests", sourceProjectID), createMergeRequestRequest{
		SourceBranch: sourceBranch, TargetBranch: targetBranch, TargetProjectID: targetProjectID, Title: title,
	}, &mr); err != nil {
		return nil, fmt.Errorf("gitlab: create cross-fork merge request from project %d to project %d: %w", sourceProjectID, targetProjectID, err)
	}
	return &mr, nil
}

// MergeMergeRequest calls PUT /projects/:id/merge_requests/:iid/merge — the
// merge gate this package's checkpoint/approval logic (later batches) calls
// once its own approvals_count requirement is satisfied.
func (c *Client) MergeMergeRequest(ctx context.Context, projectID, mrIID int64) (*MergeRequest, error) {
	var mr MergeRequest
	if err := c.do(ctx, http.MethodPut, fmt.Sprintf("/projects/%d/merge_requests/%d/merge", projectID, mrIID), nil, &mr); err != nil {
		return nil, fmt.Errorf("gitlab: merge merge request %d on project %d: %w", mrIID, projectID, err)
	}
	return &mr, nil
}

// MRChange is one file's diff within a merge request's changes.
type MRChange struct {
	OldPath     string `json:"old_path"`
	NewPath     string `json:"new_path"`
	Diff        string `json:"diff"`
	NewFile     bool   `json:"new_file"`
	RenamedFile bool   `json:"renamed_file"`
	DeletedFile bool   `json:"deleted_file"`
}

// MRChanges is GET /projects/:id/merge_requests/:iid/changes' response body —
// the MR's own fields plus its per-file diffs.
type MRChanges struct {
	MergeRequest
	Changes []MRChange `json:"changes"`
}

// GetMergeRequestChanges calls GET
// /projects/:id/merge_requests/:iid/changes — the file-level diffs
// Service.ReviewMergeRequest (Phase C) feeds to the AI reviewer.
func (c *Client) GetMergeRequestChanges(ctx context.Context, projectID, mrIID int64) (*MRChanges, error) {
	var changes MRChanges
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/merge_requests/%d/changes", projectID, mrIID), nil, &changes); err != nil {
		return nil, fmt.Errorf("gitlab: get merge request changes %d on project %d: %w", mrIID, projectID, err)
	}
	return &changes, nil
}

// Note is the subset of a GitLab MR note/comment this package needs for the
// activity mirror (gitlab_mr_reviews).
type Note struct {
	ID     int64  `json:"id"`
	Body   string `json:"body"`
	Author struct {
		ID       int64  `json:"id"`
		Username string `json:"username"`
	} `json:"author"`
	CreatedAt time.Time `json:"created_at"`
	System    bool      `json:"system"`
}

// ListMRNotes calls GET /projects/:id/merge_requests/:iid/notes — used by
// the poll_sync self-healing sweep and, in later batches, review-thread
// display.
func (c *Client) ListMRNotes(ctx context.Context, projectID, mrIID int64) ([]Note, error) {
	var notes []Note
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/merge_requests/%d/notes?per_page=100", projectID, mrIID), nil, &notes); err != nil {
		return nil, fmt.Errorf("gitlab: list notes for merge request %d on project %d: %w", mrIID, projectID, err)
	}
	return notes, nil
}

type createNoteRequest struct {
	Body string `json:"body"`
}

// CreateMRNote calls POST /projects/:id/merge_requests/:iid/notes — used by
// later batches to post MindForge-generated feedback (e.g. grading comments)
// back onto the MR.
func (c *Client) CreateMRNote(ctx context.Context, projectID, mrIID int64, body string) (*Note, error) {
	var note Note
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/merge_requests/%d/notes", projectID, mrIID), createNoteRequest{Body: body}, &note); err != nil {
		return nil, fmt.Errorf("gitlab: create note on merge request %d on project %d: %w", mrIID, projectID, err)
	}
	return &note, nil
}

// ApprovalRule is the subset of a GitLab merge-request approval rule this
// package needs — the EE-only server-side mirror of MindForge's own
// approvals_count gate (kind-herding-cookie.md §0.4's layer 2).
type ApprovalRule struct {
	ID                int64  `json:"id"`
	Name              string `json:"name"`
	ApprovalsRequired int    `json:"approvals_required"`
}

type createApprovalRuleRequest struct {
	Name              string `json:"name"`
	ApprovalsRequired int    `json:"approvals_required"`
	RuleType          string `json:"rule_type"`
}

// CreateApprovalRule calls POST /projects/:id/approval_rules — GitLab
// Premium/Ultimate (EE) only; a Free/CE instance returns 404/403 for this
// endpoint. Callers (service_checkpoint.go's dual-layer approval
// enforcement) must tier-guard the call themselves and treat any error here
// as best-effort — MindForge's own approvals_count gate (TryMergeCheckpoint)
// is what actually enforces the requirement; this is only a nice-to-have
// server-side mirror for orgs whose GitLab tier supports it.
func (c *Client) CreateApprovalRule(ctx context.Context, projectID int64, name string, approvalsRequired int) (*ApprovalRule, error) {
	var rule ApprovalRule
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/projects/%d/approval_rules", projectID), createApprovalRuleRequest{
		Name: name, ApprovalsRequired: approvalsRequired, RuleType: "regular",
	}, &rule); err != nil {
		return nil, fmt.Errorf("gitlab: create approval rule on project %d: %w", projectID, err)
	}
	return &rule, nil
}
