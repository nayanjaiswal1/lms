package gitlab

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// ─── project_design_proposals / project_design_votes ──────────────────────
// Batch 7 — see models.go's own "Batch 7" section.

const designProposalColumns = `
	id, org_id, checkpoint_id, team_id, submitted_by, title, description, link, is_accepted, created_at`

func scanDesignProposal(row pgx.Row) (*ProjectDesignProposal, error) {
	var p ProjectDesignProposal
	err := row.Scan(&p.ID, &p.OrgID, &p.CheckpointID, &p.TeamID, &p.SubmittedBy, &p.Title, &p.Description, &p.Link, &p.IsAccepted, &p.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan design proposal: %w", err)
	}
	return &p, nil
}

// CreateDesignProposal inserts a new proposal from a team member.
func (r *Repo) CreateDesignProposal(ctx context.Context, p ProjectDesignProposal) (*ProjectDesignProposal, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_design_proposals (org_id, checkpoint_id, team_id, submitted_by, title, description, link)
		 VALUES ($1,$2,$3,$4,$5,$6,$7)
		 RETURNING `+designProposalColumns,
		p.OrgID, p.CheckpointID, p.TeamID, p.SubmittedBy, p.Title, p.Description, p.Link,
	)
	created, err := scanDesignProposal(row)
	if err != nil {
		return nil, fmt.Errorf("gitlab: create design proposal: %w", err)
	}
	return created, nil
}

// GetDesignProposal returns a single org-scoped proposal.
func (r *Repo) GetDesignProposal(ctx context.Context, orgID, id string) (*ProjectDesignProposal, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+designProposalColumns+` FROM project_design_proposals WHERE id = $1 AND org_id = $2`, id, orgID)
	return scanDesignProposal(row)
}

// ListDesignProposals returns every proposal a team has submitted against a
// checkpoint, each with its vote count and whether callerUserID has voted,
// highest-voted first — the ranked view voting exists to produce.
func (r *Repo) ListDesignProposals(ctx context.Context, checkpointID, teamID, callerUserID string) ([]DesignProposalView, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT p.id, p.org_id, p.checkpoint_id, p.team_id, p.submitted_by, p.title, p.description, p.link, p.is_accepted, p.created_at,
		        COUNT(v.user_id) AS vote_count,
		        bool_or(v.user_id = $3) AS my_vote
		 FROM project_design_proposals p
		 LEFT JOIN project_design_votes v ON v.proposal_id = p.id
		 WHERE p.checkpoint_id = $1 AND p.team_id = $2
		 GROUP BY p.id
		 ORDER BY vote_count DESC, p.created_at`,
		checkpointID, teamID, callerUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list design proposals: %w", err)
	}
	defer rows.Close()

	out := []DesignProposalView{}
	for rows.Next() {
		var v DesignProposalView
		if err := rows.Scan(
			&v.ID, &v.OrgID, &v.CheckpointID, &v.TeamID, &v.SubmittedBy, &v.Title, &v.Description, &v.Link, &v.IsAccepted, &v.CreatedAt,
			&v.VoteCount, &v.MyVote,
		); err != nil {
			return nil, fmt.Errorf("gitlab: scan design proposal view: %w", err)
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// ListAllDesignProposalsForCheckpoint returns every team's proposals against
// a checkpoint (not scoped to one team) — the staff view that decides which
// proposal to accept, since AcceptDesignProposal is staff-only but staff are
// never project_team_members themselves, so ListDesignProposals' membership
// guard would always 404 for them.
func (r *Repo) ListAllDesignProposalsForCheckpoint(ctx context.Context, checkpointID, callerUserID string) ([]DesignProposalView, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT p.id, p.org_id, p.checkpoint_id, p.team_id, p.submitted_by, p.title, p.description, p.link, p.is_accepted, p.created_at,
		        COUNT(v.user_id) AS vote_count,
		        bool_or(v.user_id = $2) AS my_vote
		 FROM project_design_proposals p
		 LEFT JOIN project_design_votes v ON v.proposal_id = p.id
		 WHERE p.checkpoint_id = $1
		 GROUP BY p.id
		 ORDER BY p.team_id, vote_count DESC, p.created_at`,
		checkpointID, callerUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list all design proposals for checkpoint: %w", err)
	}
	defer rows.Close()

	out := []DesignProposalView{}
	for rows.Next() {
		var v DesignProposalView
		if err := rows.Scan(
			&v.ID, &v.OrgID, &v.CheckpointID, &v.TeamID, &v.SubmittedBy, &v.Title, &v.Description, &v.Link, &v.IsAccepted, &v.CreatedAt,
			&v.VoteCount, &v.MyVote,
		); err != nil {
			return nil, fmt.Errorf("gitlab: scan design proposal view: %w", err)
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// VoteForProposal casts callerUserID's vote — idempotent, a second vote from
// the same user is a no-op rather than an error (ON CONFLICT DO NOTHING on
// the (proposal_id, user_id) primary key).
func (r *Repo) VoteForProposal(ctx context.Context, proposalID, userID string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO project_design_votes (proposal_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		proposalID, userID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: vote for proposal: %w", err)
	}
	return nil
}

// RemoveVote retracts callerUserID's vote — also idempotent.
func (r *Repo) RemoveVote(ctx context.Context, proposalID, userID string) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM project_design_votes WHERE proposal_id = $1 AND user_id = $2`, proposalID, userID)
	if err != nil {
		return fmt.Errorf("gitlab: remove vote: %w", err)
	}
	return nil
}

// AcceptDesignProposal marks proposalID the accepted proposal for its
// (checkpoint, team) pair, clearing any previously-accepted proposal for
// that same pair first — in one transaction, so the migration 022 partial
// unique index (at most one accepted proposal per team per checkpoint) is
// never transiently violated between the clear and the set.
func (r *Repo) AcceptDesignProposal(ctx context.Context, orgID, proposalID string) (*ProjectDesignProposal, error) {
	var accepted *ProjectDesignProposal
	err := r.tx(ctx, func(tx pgx.Tx) error {
		current, err := scanDesignProposal(tx.QueryRow(ctx, `SELECT `+designProposalColumns+` FROM project_design_proposals WHERE id = $1 AND org_id = $2`, proposalID, orgID))
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx,
			`UPDATE project_design_proposals SET is_accepted = false
			 WHERE checkpoint_id = $1 AND team_id = $2 AND is_accepted`,
			current.CheckpointID, current.TeamID,
		); err != nil {
			return fmt.Errorf("gitlab: clear previously accepted proposal: %w", err)
		}
		row := tx.QueryRow(ctx,
			`UPDATE project_design_proposals SET is_accepted = true WHERE id = $1 AND org_id = $2 RETURNING `+designProposalColumns,
			proposalID, orgID,
		)
		accepted, err = scanDesignProposal(row)
		return err
	})
	if err != nil {
		return nil, err
	}
	return accepted, nil
}

// DeleteDesignProposal removes a proposal, scoped to its own submitter so a
// team member can only withdraw their own.
func (r *Repo) DeleteDesignProposal(ctx context.Context, orgID, id, submittedBy string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM project_design_proposals WHERE id = $1 AND org_id = $2 AND submitted_by = $3`, id, orgID, submittedBy)
	if err != nil {
		return fmt.Errorf("gitlab: delete design proposal: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
