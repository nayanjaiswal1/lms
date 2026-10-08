// Package privacy implements the data-subject rights a user can exercise on
// their own account: exporting a copy of their personal data, and deleting
// (anonymizing) their account. See docs/auth.md for the users.status
// mechanism this reuses to kill sessions and block sign-in.
package privacy

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/storage"
)

type Repo struct {
	pool  *pgxpool.Pool
	store storage.StorageClient
}

func NewRepo(pool *pgxpool.Pool, store storage.StorageClient) *Repo {
	return &Repo{pool: pool, store: store}
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
	{"auth_events", `SELECT event, ip, ts FROM auth_events WHERE user_id = $1 ORDER BY ts`},
	// Project Workspace (internal/workspace), Phase 1 — additive per
	// docs/project-workspace-plan/02-auth-security.md §4.7.
	{"workspace_interests", `SELECT project_id, name, email, skills, portfolio_url, message, status, created_at
	                          FROM project_interests WHERE user_id = $1`},
	{"workspace_memberships", `SELECT project_id, role, status, joined_at FROM project_members WHERE user_id = $1`},
}

// exportSkippedTables are user-FK tables left out of the generic export
// sweep: either already covered by a curated section in exportQueries, or
// holding credentials/secret material (token hashes, key material) that is
// not the user's personal data to download and would be dangerous to leak.
var exportSkippedTables = map[string]bool{
	"org_members": true, "purchases": true, "assessment_attempts": true,
	"conversations": true, "legal_acceptances": true, "project_members": true,
	"auth_tokens": true, "refresh_tokens": true, "jti_blocklist": true,
	"webauthn_credentials": true, "social_accounts": true, "mcp_connections": true,
	"gitlab_connections": true, "idempotency_keys": true,
}

// ExportData gathers every section of userID's exportable data into a single
// map, keyed by section name. A missing/empty section is an empty slice, not
// an error — most users have no course purchases, for instance. The curated
// sections in exportQueries come first; every other user-owned table (diary,
// journal, captures, habits, notes, calendar, SRS, AI interactions, labs...)
// is then swept from the live catalog, keyed by table name, so a table added
// later is exported without touching this package.
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

	tables, err := userCascadeTables(ctx, r.pool)
	if err != nil {
		return nil, err
	}
	for _, t := range tables {
		if exportSkippedTables[t.table] {
			continue
		}
		stmt := "SELECT to_jsonb(t) FROM " + pgx.Identifier{t.schema, t.table}.Sanitize() +
			" t WHERE " + pgx.Identifier{t.column}.Sanitize() + " = $1"
		rows, err := r.pool.Query(ctx, stmt, userID)
		if err != nil {
			return nil, fmt.Errorf("privacy: export %s: %w", t.table, err)
		}
		section, err := pgx.CollectRows(rows, pgx.RowTo[map[string]any])
		if err != nil {
			return nil, fmt.Errorf("privacy: export %s scan: %w", t.table, err)
		}
		if len(section) > 0 {
			out[t.table] = section
		}
	}
	return out, nil
}

// retainedUserTables are tables with an ON DELETE CASCADE foreign key to
// users that erasure deliberately keeps: the rows are anonymized in effect
// because the users row they point at is scrubbed. Each is held for a reason
// other than the data subject's own convenience: tax/financial records,
// proof of consent, or records the org (not the user) controls and that other
// people's records depend on. Every other cascade child is deleted. A new
// table with a user FK is therefore erased by default; it must be listed here
// (with a reason) to be kept.
var retainedUserTables = map[string]string{
	// financial / tax records
	"purchases":             "financial record",
	"session_credit_ledger": "financial record",
	"coupon_redemptions":    "financial record",
	// proof of consent
	"legal_acceptances": "proof of consent",
	// records controlled by the org or shared with other people
	"certificates":             "issued credential, publicly verifiable",
	"assessment_attempts":      "org assessment record",
	"attempt_events":           "org assessment record",
	"enrollments":              "org enrolment record",
	"module_progress":          "org progress record",
	"batch_members":            "org cohort roster",
	"org_members":              "org membership roster",
	"meeting_attendance":       "org attendance record",
	"mentor_sessions":          "counterparty's session record",
	"messages":                 "other participants' conversation history",
	"conversations":            "support ticket history",
	"content_reports":          "moderation record",
	"change_requests":          "workspace review record",
	"brief_approvals":          "workspace review record",
	"courses":                  "org-owned course content",
	"project_applications":     "workspace record",
	"project_design_proposals": "workspace record",
	"project_design_votes":     "workspace record",
	"project_members":          "workspace roster",
	"project_team_members":     "workspace roster",
	"work_item_assignees":      "workspace record",
	"interview_exp_entries":    "shared interview content",
	"interview_exp_posts":      "shared interview content",
	"interview_exp_qna":        "shared interview content",
}

// querier is satisfied by both *pgxpool.Pool and pgx.Tx.
type querier interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
}

type userFKTable struct {
	schema, table, column string
}

// userCascadeTables lists every (table, column) whose single-column foreign
// key to users(id) is ON DELETE CASCADE, read from the live catalog so a
// table added by a later migration is erased without touching this package.
func userCascadeTables(ctx context.Context, q querier) ([]userFKTable, error) {
	rows, err := q.Query(ctx, `
		SELECT n.nspname, cl.relname, a.attname
		FROM pg_constraint c
		JOIN pg_class cl ON cl.oid = c.conrelid
		JOIN pg_namespace n ON n.oid = cl.relnamespace
		JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
		WHERE c.contype = 'f'
		  AND c.confrelid = 'public.users'::regclass
		  AND c.confdeltype = 'c'
		  AND array_length(c.conkey, 1) = 1
		ORDER BY cl.relname, a.attname`)
	if err != nil {
		return nil, fmt.Errorf("privacy: list user fk tables: %w", err)
	}
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (userFKTable, error) {
		var t userFKTable
		err := row.Scan(&t.schema, &t.table, &t.column)
		return t, err
	})
}

// AnonymizeAndDeletePII erases userID's personal data in one transaction:
// every cascade child of users except retainedUserTables is deleted, MCP
// action logs (full tool args and before/after text) are deleted, the users
// row is anonymized (never hard-deleted: content it authored sits under
// ON DELETE RESTRICT elsewhere, e.g. assessments.created_by), and the stored
// capture blobs are removed from object storage before the commit, so a
// storage failure rolls everything back and the request can be retried.
// Session revocation is the caller's responsibility (see
// authz.AdminRepo.SetUserStatusUnscoped); this only touches PII.
func (r *Repo) AnonymizeAndDeletePII(ctx context.Context, userID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("privacy: anonymize: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	// Read the pre-anonymize email first: project_interests are keyed by the
	// applicant's own submitted email (citext), not by user_id, for
	// anonymous public-form submissions later linked to an account.
	var oldEmail string
	if err := tx.QueryRow(ctx, `SELECT email FROM users WHERE id = $1`, userID).Scan(&oldEmail); err != nil {
		return fmt.Errorf("privacy: anonymize: read email: %w", err)
	}
	if _, err := tx.Exec(ctx,
		`DELETE FROM project_interests WHERE user_id = $1 OR lower(email) = lower($2)`,
		userID, oldEmail,
	); err != nil {
		return fmt.Errorf("privacy: delete project interests: %w", err)
	}

	blobKeys, err := captureBlobKeys(ctx, tx, userID)
	if err != nil {
		return err
	}

	tables, err := userCascadeTables(ctx, tx)
	if err != nil {
		return err
	}
	for _, t := range tables {
		if _, keep := retainedUserTables[t.table]; keep {
			continue
		}
		stmt := "DELETE FROM " + pgx.Identifier{t.schema, t.table}.Sanitize() +
			" WHERE " + pgx.Identifier{t.column}.Sanitize() + " = $1"
		if _, err := tx.Exec(ctx, stmt, userID); err != nil {
			return fmt.Errorf("privacy: erase %s: %w", t.table, err)
		}
	}
	if _, err := tx.Exec(ctx, `DELETE FROM audit_logs WHERE source = 'mcp' AND actor_user_id = $1`, userID); err != nil {
		return fmt.Errorf("privacy: delete mcp action log: %w", err)
	}

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

	for _, key := range blobKeys {
		if err := r.store.Delete(ctx, key); err != nil {
			return fmt.Errorf("privacy: delete capture blob: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("privacy: anonymize: commit: %w", err)
	}
	return nil
}

// captureBlobKeys returns the object-storage keys of userID's uploaded
// captures, read before the capture rows are deleted.
func captureBlobKeys(ctx context.Context, tx pgx.Tx, userID string) ([]string, error) {
	rows, err := tx.Query(ctx, `SELECT storage_key FROM captures WHERE user_id = $1 AND storage_key IS NOT NULL`, userID)
	if err != nil {
		return nil, fmt.Errorf("privacy: list capture blobs: %w", err)
	}
	keys, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return nil, fmt.Errorf("privacy: scan capture blobs: %w", err)
	}
	return keys, nil
}
