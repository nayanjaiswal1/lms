// Package privacy implements the data-subject rights a user can exercise on
// their own account: exporting a copy of their personal data, and deleting
// (anonymizing) their account. See docs/auth.md for the users.status
// mechanism this reuses to kill sessions and block sign-in.
package privacy

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// PasswordHash returns userID's password_hash, or nil if the account has none
// (social/passkey-only). Used to gate account deletion behind a password
// re-entry when one exists.
func (r *Repo) PasswordHash(ctx context.Context, userID string) (*string, error) {
	var hash *string
	err := r.pool.QueryRow(ctx, `SELECT password_hash FROM users WHERE id = $1`, userID).Scan(&hash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("privacy: user not found")
		}
		return nil, fmt.Errorf("privacy: password hash: %w", err)
	}
	return hash, nil
}

// exportQuery is one section of the export bundle: a label and the query
// that produces it, scoped to userID via $1.
type exportQuery struct {
	key   string
	query string
}

// exportQueries is the MVP scope of an account's exportable data — additive
// by design, more tables can be appended here without touching the API
// contract (see plan doc). Each query is scoped to the caller's own userID
// only, never joins across other users' data.
var exportQueries = []exportQuery{
	{"profile", `SELECT id, name, email, avatar_url, platform_role, created_at FROM users WHERE id = $1`},
	{"org_memberships", `SELECT org_id, role, created_at FROM org_members WHERE user_id = $1`},
	{"course_purchases", `SELECT id, course_id, amount_cents, discount_cents, currency, status, purchased_at
	                        FROM purchases WHERE user_id = $1 AND product_type = 'course'`},
	{"assessment_attempts", `SELECT id, assessment_id, status, score, percentage, created_at
	                          FROM assessment_attempts WHERE user_id = $1`},
	{"support_tickets", `SELECT id, subject, category, status, created_at FROM conversations WHERE requester_id = $1 AND kind = 'support'`},
	{"legal_acceptances", `SELECT doc_type, version, accepted_at FROM legal_acceptances WHERE user_id = $1`},
}

// ExportData gathers every section of userID's exportable data into a single
// map, keyed by section name. A missing/empty section is an empty slice, not
// an error — most users have no course purchases, for instance.
func (r *Repo) ExportData(ctx context.Context, userID string) (map[string]any, error) {
	out := make(map[string]any, len(exportQueries))
	for _, eq := range exportQueries {
		rows, err := r.pool.Query(ctx, eq.query, userID)
		if err != nil {
			return nil, fmt.Errorf("privacy: export %s: %w", eq.key, err)
		}
		section, err := pgx.CollectRows(rows, pgx.RowToMap)
		if err != nil {
			return nil, fmt.Errorf("privacy: export %s scan: %w", eq.key, err)
		}
		out[eq.key] = section
	}
	return out, nil
}

// AnonymizeAndDeletePII scrubs userID's personal data in one transaction:
// the users row is anonymized (never hard-deleted — content it authored may
// be under ON DELETE RESTRICT elsewhere, e.g. assessments.created_by), and
// the remaining PII-bearing child rows that don't cascade from a row we're
// not deleting are removed directly. Session revocation is the caller's
// responsibility (see authz.AdminRepo.SetUserStatus) — this only touches PII.
func (r *Repo) AnonymizeAndDeletePII(ctx context.Context, userID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("privacy: anonymize: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	if _, err := tx.Exec(ctx,
		`UPDATE users
		 SET name = 'Deleted User',
		     email = 'deleted-' || id || '@deleted.mindforge.local',
		     avatar_url = NULL,
		     password_hash = NULL,
		     updated_at = now()
		 WHERE id = $1`,
		userID,
	); err != nil {
		return fmt.Errorf("privacy: anonymize user: %w", err)
	}

	if _, err := tx.Exec(ctx, `DELETE FROM webauthn_credentials WHERE user_id = $1`, userID); err != nil {
		return fmt.Errorf("privacy: delete webauthn credentials: %w", err)
	}
	if _, err := tx.Exec(ctx, `DELETE FROM social_accounts WHERE user_id = $1`, userID); err != nil {
		return fmt.Errorf("privacy: delete social accounts: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("privacy: anonymize: commit: %w", err)
	}
	return nil
}
