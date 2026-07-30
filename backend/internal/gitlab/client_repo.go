package gitlab

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

// Commit is the subset of a GitLab commit this package needs for the
// activity mirror (gitlab_commits) and the per-commit stats fetch.
type Commit struct {
	ID           string       `json:"id"`
	ShortID      string       `json:"short_id"`
	Title        string       `json:"title"`
	Message      string       `json:"message"`
	AuthorName   string       `json:"author_name"`
	AuthorEmail  string       `json:"author_email"`
	AuthoredDate string       `json:"authored_date"`
	Stats        *CommitStats `json:"stats"`
}

// CommitStats is populated only when a commit is fetched with ?stats=true
// (see GetCommit) — GitLab's list endpoint never includes it.
type CommitStats struct {
	Additions int `json:"additions"`
	Deletions int `json:"deletions"`
	Total     int `json:"total"`
}

// ListCommits calls GET /projects/:id/repository/commits — used by the
// poll_sync self-healing sweep to re-list a team's commits directly rather
// than relying solely on webhook delivery. branch/since may be empty to omit
// those filters (empty branch lists across all refs, matching GitLab's own
// default).
func (c *Client) ListCommits(ctx context.Context, projectID int64, branch, since string) ([]Commit, error) {
	q := url.Values{"per_page": {"100"}}
	if branch != "" {
		q.Set("ref_name", branch)
	}
	if since != "" {
		q.Set("since", since)
	}
	var commits []Commit
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/repository/commits?%s", projectID, q.Encode()), nil, &commits); err != nil {
		return nil, fmt.Errorf("gitlab: list commits for project %d: %w", projectID, err)
	}
	return commits, nil
}

// GetCommit calls GET /projects/:id/repository/commits/:sha?stats=true — the
// commit_stats job's per-sha additions/deletions fetch (push webhook payloads
// carry the commit's identity and message but never its diff stats).
func (c *Client) GetCommit(ctx context.Context, projectID int64, sha string) (*Commit, error) {
	var commit Commit
	path := fmt.Sprintf("/projects/%d/repository/commits/%s?stats=true", projectID, url.PathEscape(sha))
	if err := c.do(ctx, http.MethodGet, path, nil, &commit); err != nil {
		return nil, fmt.Errorf("gitlab: get commit %s on project %d: %w", sha, projectID, err)
	}
	return &commit, nil
}

// Branch is the subset of a GitLab branch this package needs.
type Branch struct {
	Name      string `json:"name"`
	Commit    Commit `json:"commit"`
	Protected bool   `json:"protected"`
}

// GetBranch calls GET /projects/:id/repository/branches/:branch.
func (c *Client) GetBranch(ctx context.Context, projectID int64, branch string) (*Branch, error) {
	var b Branch
	path := fmt.Sprintf("/projects/%d/repository/branches/%s", projectID, url.PathEscape(branch))
	if err := c.do(ctx, http.MethodGet, path, nil, &b); err != nil {
		return nil, fmt.Errorf("gitlab: get branch %q on project %d: %w", branch, projectID, err)
	}
	return &b, nil
}

// CompareResult is GET /projects/:id/repository/compare's response shape —
// used by later-batch originality/contribution tooling to diff two refs.
type CompareResult struct {
	Commits []Commit `json:"commits"`
	Diffs   []struct {
		OldPath string `json:"old_path"`
		NewPath string `json:"new_path"`
	} `json:"diffs"`
}

// Compare calls GET /projects/:id/repository/compare?from=...&to=....
func (c *Client) Compare(ctx context.Context, projectID int64, from, to string) (*CompareResult, error) {
	q := url.Values{"from": {from}, "to": {to}}
	var res CompareResult
	if err := c.do(ctx, http.MethodGet, fmt.Sprintf("/projects/%d/repository/compare?%s", projectID, q.Encode()), nil, &res); err != nil {
		return nil, fmt.Errorf("gitlab: compare %s..%s on project %d: %w", from, to, projectID, err)
	}
	return &res, nil
}

// DownloadArchive calls GET /projects/:id/repository/archive.tar.gz and
// returns the raw archive bytes — used by the Batch 6 originality scan to
// fetch a team's full source tree. Bypasses do()'s JSON decode (this
// endpoint returns a binary body, not JSON) by calling the lower-level
// doOnce directly.
func (c *Client) DownloadArchive(ctx context.Context, projectID int64, sha string) ([]byte, error) {
	path := fmt.Sprintf("/projects/%d/repository/archive.tar.gz", projectID)
	if sha != "" {
		path += "?sha=" + url.QueryEscape(sha)
	}
	resp, body, err := c.doOnce(ctx, http.MethodGet, path, nil)
	if err != nil {
		return nil, fmt.Errorf("gitlab: download archive for project %d: %w", projectID, err)
	}
	if resp.StatusCode >= 300 {
		return nil, &APIError{StatusCode: resp.StatusCode, Message: strings.TrimSpace(string(body))}
	}
	return body, nil
}
