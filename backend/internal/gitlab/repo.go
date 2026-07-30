package gitlab

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the gitlab domain. Every method takes an
// orgID and filters on it, so a caller can never reach another org's rows.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Domain errors surfaced by the repo and service; handlers map these to HTTP codes.
var (
	// ErrNotFound — row does not exist or is not visible to the org.
	ErrNotFound = errors.New("gitlab: not found")
	// ErrConflict — a uniqueness or state-transition rule was violated.
	ErrConflict = errors.New("gitlab: conflict")
	// ErrNoOAuthApp — the org's installation has no OAuth Application
	// registered (oauth_client_id), so a personal connect cannot start.
	ErrNoOAuthApp = errors.New("gitlab: no oauth application configured for this installation")
	// ErrStateExpired — an oauth state row was found but past its TTL.
	ErrStateExpired = errors.New("gitlab: oauth state expired")
	// ErrAlreadyOnTeam — the student already belongs to a different team for
	// this same assignment (project_team_members_assignment_user_key), the
	// composite-FK-backed "one team per student per assignment" rule.
	ErrAlreadyOnTeam = errors.New("gitlab: this student is already on a team for this assignment")
	// ErrInvalidWebhookToken — the inbound webhook's X-Gitlab-Token did not
	// constant-time-match the installation's decrypted webhook secret.
	ErrInvalidWebhookToken = errors.New("gitlab: invalid webhook token")
	// ErrInsufficientApprovals — TryMergeCheckpoint's merge gate rejected the
	// attempt because approvals_count is below the assignment's
	// required_approvals. Never bypassed silently — see TryMergeCheckpoint's
	// own doc comment.
	ErrInsufficientApprovals = errors.New("gitlab: not enough approvals to merge this checkpoint")
	// ErrCannotDeleteDefault — the installation being deleted is the org's
	// current default and other installations still exist; the admin must
	// set a different one as default first (DeleteInstallationByID's own
	// doc comment). Deleting an org's *only* installation is allowed — it
	// just returns the org to "GitLab not configured", today's ErrNotFound
	// behavior everywhere that already handles it.
	ErrCannotDeleteDefault = errors.New("gitlab: cannot delete the default installation while other installations exist")
	// ErrOverrideNotAllowed — the org's gitlab_org_config.allow_project_override
	// is false, so an assignment create/update tried to set a non-nil
	// InstallationID and was rejected.
	ErrOverrideNotAllowed = errors.New("gitlab: this organization does not allow per-project GitLab overrides")
)

// tx runs fn inside a transaction, committing on nil error and rolling back
// otherwise. Used for multi-table writes.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("gitlab: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("gitlab: commit tx: %w", err)
	}
	return nil
}
