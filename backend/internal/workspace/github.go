package workspace

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// githubHTTPTimeout bounds one unauthenticated GitHub API call — this runs
// inline in the manager's rank request (service_ai.go), so it must not hang
// that request on a slow/unresponsive GitHub.
const githubHTTPTimeout = 8 * time.Second

// githubMaxBodyBytes caps how much of a GitHub response is read.
const githubMaxBodyBytes = 1 << 20

// githubUsernameFrom extracts a plain username from whatever the student
// typed into profile.social_links.github — a bare handle, a full profile
// URL with or without scheme, and trailing slashes are all accepted.
func githubUsernameFrom(raw string) string {
	trimmed := strings.TrimSpace(raw)
	trimmed = strings.TrimPrefix(trimmed, "https://")
	trimmed = strings.TrimPrefix(trimmed, "http://")
	trimmed = strings.TrimPrefix(trimmed, "www.")
	trimmed = strings.TrimPrefix(trimmed, "github.com/")
	trimmed = strings.Trim(trimmed, "/")
	if slash := strings.Index(trimmed, "/"); slash >= 0 {
		trimmed = trimmed[:slash]
	}
	return trimmed
}

type githubUser struct {
	PublicRepos int    `json:"public_repos"`
	Followers   int    `json:"followers"`
}

type githubRepo struct {
	Name     string `json:"name"`
	Language string `json:"language"`
	Stars    int    `json:"stargazers_count"`
	Fork     bool   `json:"fork"`
}

// fetchGitHubSignal reads a compact, human-readable summary of a public
// GitHub profile straight from GitHub's own public API — unauthenticated,
// no OAuth connection needed since only public data is read. Returns "" when
// the profile link is empty, unparsable, or GitHub returns anything other
// than 200 — a missing/broken GitHub link degrades the AI score's evidence,
// it does not fail the whole scoring run (see service_ai.go's caller).
//
// ponytail: unauthenticated GitHub API caps out at 60 req/hr per server IP —
// fine for occasional staff-triggered scoring. Swap in a GitHub App/PAT
// (secrets.Vault already has the encryption primitive gitlab_installations
// uses for its own tokens) if scoring volume ever needs a higher ceiling.
func fetchGitHubSignal(ctx context.Context, rawProfileURL string) string {
	username := githubUsernameFrom(rawProfileURL)
	if username == "" {
		return ""
	}
	client := &http.Client{Timeout: githubHTTPTimeout}

	user, ok := fetchGitHubJSON[githubUser](ctx, client, "https://api.github.com/users/"+url.PathEscape(username))
	if !ok {
		return ""
	}
	repos, _ := fetchGitHubJSON[[]githubRepo](ctx, client, "https://api.github.com/users/"+url.PathEscape(username)+"/repos?sort=pushed&per_page=8")

	// Aggregates only: login, bio and repo names are identity, and the rank
	// model must never see who the applicant is.
	langs := map[string]bool{}
	var order []string
	stars, active := 0, 0
	for _, repo := range repos {
		if repo.Fork {
			continue
		}
		active++
		stars += repo.Stars
		if repo.Language != "" && !langs[repo.Language] {
			langs[repo.Language] = true
			order = append(order, repo.Language)
		}
	}
	var b strings.Builder
	fmt.Fprintf(&b, "GitHub: %d public repos, %d followers; %d recently pushed original repos, %d total stars on them.", user.PublicRepos, user.Followers, active, stars)
	if len(order) > 0 {
		fmt.Fprintf(&b, " Languages: %s.", strings.Join(order, ", "))
	}
	return b.String()
}

func fetchGitHubJSON[T any](ctx context.Context, client *http.Client, apiURL string) (T, bool) {
	var out T
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, apiURL, nil)
	if err != nil {
		return out, false
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("User-Agent", "mindforge-project-marketplace")

	resp, err := client.Do(req)
	if err != nil {
		return out, false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return out, false
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, githubMaxBodyBytes)).Decode(&out); err != nil {
		return out, false
	}
	return out, true
}
