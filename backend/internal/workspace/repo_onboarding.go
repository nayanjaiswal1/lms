package workspace

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

const onboardingStepColumns = `os.id, os.project_id, os.title, os.wiki_page_id, os.required, os.position, os.created_at`

// onboardingStepColumnsPlain is onboardingStepColumns without the "os."
// alias — INSERT/UPDATE RETURNING clauses have no FROM alias to qualify.
const onboardingStepColumnsPlain = `id, project_id, title, wiki_page_id, required, position, created_at`

func scanOnboardingStep(row pgx.Row) (*OnboardingStep, error) {
	var s OnboardingStep
	if err := row.Scan(&s.ID, &s.ProjectID, &s.Title, &s.WikiPageID, &s.Required, &s.Position, &s.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan onboarding step: %w", err)
	}
	return &s, nil
}

// ListOnboardingSteps returns every step for a project with userID's own
// completion attached (DoneAt is that caller's, per the contract).
func (r *Repo) ListOnboardingSteps(ctx context.Context, db DBTX, projectID, userID string) ([]OnboardingStep, error) {
	rows, err := db.Query(ctx,
		`SELECT `+onboardingStepColumns+`, op.done_at
		   FROM onboarding_steps os
		   LEFT JOIN onboarding_progress op ON op.step_id = os.id AND op.user_id = $2
		  WHERE os.project_id = $1
		  ORDER BY os.position ASC, os.id ASC`,
		projectID, userID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list onboarding steps: %w", err)
	}
	defer rows.Close()

	out := []OnboardingStep{}
	for rows.Next() {
		var s OnboardingStep
		if err := rows.Scan(&s.ID, &s.ProjectID, &s.Title, &s.WikiPageID, &s.Required, &s.Position, &s.CreatedAt, &s.DoneAt); err != nil {
			return nil, fmt.Errorf("workspace: scan onboarding step: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// GetOnboardingStep fetches one step scoped to its project.
func (r *Repo) GetOnboardingStep(ctx context.Context, db DBTX, projectID, stepID string) (*OnboardingStep, error) {
	return scanOnboardingStep(db.QueryRow(ctx,
		`SELECT `+onboardingStepColumns+` FROM onboarding_steps os WHERE os.id = $1 AND os.project_id = $2`,
		stepID, projectID))
}

// NextStepPosition returns one past the current highest position, for a
// create request that doesn't specify one explicitly.
func (r *Repo) NextStepPosition(ctx context.Context, db DBTX, projectID string) (int, error) {
	var max *int
	if err := db.QueryRow(ctx, `SELECT max(position) FROM onboarding_steps WHERE project_id = $1`, projectID).Scan(&max); err != nil {
		return 0, fmt.Errorf("workspace: next step position: %w", err)
	}
	if max == nil {
		return 0, nil
	}
	return *max + 1, nil
}

func (r *Repo) InsertOnboardingStep(ctx context.Context, db DBTX, projectID, title string, wikiPageID *string, required bool, position int) (*OnboardingStep, error) {
	return scanOnboardingStep(db.QueryRow(ctx,
		`INSERT INTO onboarding_steps (project_id, title, wiki_page_id, required, position)
		 VALUES ($1,$2,$3,$4,$5) RETURNING `+onboardingStepColumnsPlain,
		projectID, title, wikiPageID, required, position))
}

// UpdateOnboardingStep applies a fully-resolved patch.
func (r *Repo) UpdateOnboardingStep(ctx context.Context, db DBTX, projectID, stepID, title string, wikiPageID *string, required bool, position int) (*OnboardingStep, error) {
	return scanOnboardingStep(db.QueryRow(ctx,
		`UPDATE onboarding_steps SET title = $3, wiki_page_id = $4, required = $5, position = $6
		  WHERE id = $1 AND project_id = $2 RETURNING `+onboardingStepColumnsPlain,
		stepID, projectID, title, wikiPageID, required, position))
}

// DeleteOnboardingStep removes a step (onboarding_progress cascades).
func (r *Repo) DeleteOnboardingStep(ctx context.Context, db DBTX, projectID, stepID string) error {
	tag, err := db.Exec(ctx, `DELETE FROM onboarding_steps WHERE id = $1 AND project_id = $2`, stepID, projectID)
	if err != nil {
		return fmt.Errorf("workspace: delete onboarding step: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetOnboardingStepDone marks a step done/undone for userID.
func (r *Repo) SetOnboardingStepDone(ctx context.Context, db DBTX, stepID, userID string, done bool) error {
	if done {
		if _, err := db.Exec(ctx,
			`INSERT INTO onboarding_progress (step_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
			stepID, userID,
		); err != nil {
			return fmt.Errorf("workspace: set onboarding step done: %w", err)
		}
		return nil
	}
	if _, err := db.Exec(ctx, `DELETE FROM onboarding_progress WHERE step_id = $1 AND user_id = $2`, stepID, userID); err != nil {
		return fmt.Errorf("workspace: unset onboarding step done: %w", err)
	}
	return nil
}

// IsOnboardingComplete reports whether userID has completed every required
// step of a project (vacuously true when there are none).
func (r *Repo) IsOnboardingComplete(ctx context.Context, db DBTX, projectID, userID string) (bool, error) {
	var incomplete bool
	err := db.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM onboarding_steps os
		   LEFT JOIN onboarding_progress op ON op.step_id = os.id AND op.user_id = $2
		  WHERE os.project_id = $1 AND os.required = true AND op.step_id IS NULL)`,
		projectID, userID,
	).Scan(&incomplete)
	if err != nil {
		return false, fmt.Errorf("workspace: check onboarding complete: %w", err)
	}
	return !incomplete, nil
}
