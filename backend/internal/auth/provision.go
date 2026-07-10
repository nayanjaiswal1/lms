package auth

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// FindOrCreateUserByEmail returns the ID of the user with the given email,
// creating a minimal passwordless account if none exists, and ensures that
// user holds an active 'learner' membership in orgID (upserted, never
// downgrading an existing membership).
//
// This is the account-creation path for flows where the caller already has
// out-of-band proof of email ownership (an accepted, unexpired invite token)
// instead of a provider identity — the same trust assumption
// findOrCreateSocialUser (social.go) makes for a provider-verified email, but
// keyed directly by email since there is no social_accounts row to fast-path
// through. Kept as its own function rather than folded into
// findOrCreateSocialUser: that one's primary lookup key is
// (provider, provider_uid), this one's is email; forcing a shared signature
// would cost more in cs than it saves in duplicated lines.
func FindOrCreateUserByEmail(ctx context.Context, pool *pgxpool.Pool, orgID, email, name string) (userID string, err error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("auth: find or create user: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	err = tx.QueryRow(ctx, `SELECT id FROM users WHERE email = $1`, email).Scan(&userID)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		if err = tx.QueryRow(ctx,
			`INSERT INTO users (email, name, email_verified) VALUES ($1, $2, true) RETURNING id`,
			email, name,
		).Scan(&userID); err != nil {
			return "", fmt.Errorf("auth: find or create user: insert user: %w", err)
		}
	case err != nil:
		return "", fmt.Errorf("auth: find or create user: lookup: %w", err)
	}

	if _, err = tx.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status)
		 VALUES ($1, $2, 'learner', 'active')
		 ON CONFLICT (org_id, user_id) DO NOTHING`,
		orgID, userID,
	); err != nil {
		return "", fmt.Errorf("auth: find or create user: upsert org membership: %w", err)
	}

	if err = tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("auth: find or create user: commit: %w", err)
	}
	return userID, nil
}
