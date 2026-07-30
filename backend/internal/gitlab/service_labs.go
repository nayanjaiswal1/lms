package gitlab

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"path"
	"strings"
)

// labWorkdir must match internal/labs/service_files.go's own labWorkdir
// constant ("/home/labuser/work") — every lab container's fixed, writable
// working directory. Duplicated as a literal rather than shared: labs is
// unexported there, and adding a shared constants package for one string
// isn't worth the extra package for what it saves.
const labWorkdir = "/home/labuser/work"

// PrepareLabRepo satisfies labs.RepoPreparer (defined in internal/labs, the
// consumer package — internal/api/router.go wires *Service into labs.New's
// RepoPreparer slot via gitlabRouter.Service()). Returns an empty script
// with a nil error whenever there's nothing to clone: no project_team_id on
// this session, the team's project hasn't been forked yet, or the student
// hasn't connected their own GitLab account — labs.Service.runRepoClone
// records that as repo_clone_status='skipped', never a failure. Only an
// actual unexpected error (DB unreachable, token won't decrypt) returns a
// non-nil error, which runRepoClone records as repo_clone_status='failed' —
// either way the student's session is never blocked.
func (s *Service) PrepareLabRepo(ctx context.Context, sessionID, userID, _ string) (string, error) {
	teamID, err := s.sessionProjectTeamID(ctx, sessionID)
	if err != nil {
		return "", fmt.Errorf("gitlab: prepare lab repo: resolve session team: %w", err)
	}
	if teamID == "" {
		return "", nil // session isn't bound to any GitLab-backed project team
	}

	team, err := s.repo.GetTeamByID(ctx, teamID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return "", nil
		}
		return "", fmt.Errorf("gitlab: prepare lab repo: get team: %w", err)
	}
	if team.GitlabProjectID == nil || team.GitlabWebURL == nil || *team.GitlabWebURL == "" {
		return "", nil // team's repo hasn't finished provisioning yet
	}

	conn, err := s.repo.GetConnection(ctx, team.OrgID, userID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return "", nil // student hasn't connected their own GitLab account
		}
		return "", fmt.Errorf("gitlab: prepare lab repo: get connection: %w", err)
	}

	token, err := s.vault.Decrypt(conn.AccessTokenEnc)
	if err != nil {
		return "", fmt.Errorf("gitlab: prepare lab repo: decrypt connection token: %w", err)
	}

	cloneURL, err := credentialedCloneURL(*team.GitlabWebURL, string(token))
	if err != nil {
		return "", fmt.Errorf("gitlab: prepare lab repo: build clone url: %w", err)
	}

	email := conn.GitlabUsername + "@users.noreply.gitlab"
	if conn.GitlabEmail != nil && *conn.GitlabEmail != "" {
		email = *conn.GitlabEmail
	}

	dir := labWorkdir + "/" + labRepoDirName(*team.GitlabWebURL)
	// A short-lived git identity (this container is destroyed at session end,
	// taking the embedded token with it — see RepoPreparer's own doc comment)
	// plus a fresh clone into the lab's fixed workdir. rm -rf first so a
	// re-provision (reset/warm-pool reuse) never fails on a stale non-empty
	// directory from a prior clone attempt.
	script := fmt.Sprintf(
		"git config --global user.name %s && git config --global user.email %s && rm -rf %s && git clone %s %s",
		shellQuote(conn.GitlabUsername), shellQuote(email), shellQuote(dir), shellQuote(cloneURL), shellQuote(dir),
	)
	return script, nil
}

// sessionProjectTeamID reads lab_sessions.project_team_id directly — a
// cross-domain read via the pool this package shares with the rest of the
// app, since RepoPreparer's interface (defined in labs) only passes plain
// IDs, not a labs.LabSession value, and gitlab must not import labs (that
// import would run the wrong direction: labs is the consumer of this
// package's interface, not a dependency of it).
func (s *Service) sessionProjectTeamID(ctx context.Context, sessionID string) (string, error) {
	var teamID *string
	if err := s.pool.QueryRow(ctx, `SELECT project_team_id FROM lab_sessions WHERE id = $1`, sessionID).Scan(&teamID); err != nil {
		return "", fmt.Errorf("query lab_sessions.project_team_id: %w", err)
	}
	if teamID == nil {
		return "", nil
	}
	return *teamID, nil
}

// credentialedCloneURL embeds token as an HTTPS Basic credential in webURL
// (GitLab accepts any username paired with a valid OAuth/PAT token over
// HTTPS — "oauth2" is the conventional placeholder GitLab's own docs use),
// scoped to just this one clone: the credential lives only in the
// container's argv/git-config for the container's lifetime, never written
// to a persisted credential store.
func credentialedCloneURL(webURL, token string) (string, error) {
	u, err := url.Parse(webURL)
	if err != nil {
		return "", fmt.Errorf("parse web url: %w", err)
	}
	u.User = url.UserPassword("oauth2", token)
	if !strings.HasSuffix(u.Path, ".git") {
		u.Path += ".git"
	}
	return u.String(), nil
}

// labRepoDirName derives a clone directory name from the project's web URL
// (its final path segment, e.g. "team-slug") so each team's clone lands in
// its own subdirectory of labWorkdir rather than colliding with a lab's own
// pre-seeded scaffold files.
func labRepoDirName(webURL string) string {
	u, err := url.Parse(webURL)
	if err != nil || u.Path == "" {
		return "repo"
	}
	name := path.Base(u.Path)
	if name == "" || name == "." || name == "/" {
		return "repo"
	}
	return name
}

// shellQuote wraps s in single quotes for safe use inside a `bash -c`
// script, escaping any single quotes in s itself. Mirrors the escaping
// internal/labs.DockerContainerService.Exec/Start and
// internal/assessment's own shellQuote already do for the same reason.
func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}
