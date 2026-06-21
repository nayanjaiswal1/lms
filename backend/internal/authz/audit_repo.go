package authz

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AuditRepo handles all audit_log persistence against PostgreSQL.
type AuditRepo struct {
	pool *pgxpool.Pool
}

// NewAuditRepo constructs an AuditRepo backed by the given connection pool.
func NewAuditRepo(pool *pgxpool.Pool) *AuditRepo {
	return &AuditRepo{pool: pool}
}

// Write inserts a single row into audit_log. diff is marshalled to JSON when
// non-nil; a nil diff stores NULL in the diff column.
func (r *AuditRepo) Write(ctx context.Context, tenantID, actorID, action, entityType, entityID string, diff *AuditDiff) error {
	var diffJSON []byte
	if diff != nil {
		var err error
		diffJSON, err = json.Marshal(diff)
		if err != nil {
			return fmt.Errorf("audit: write: marshal diff: %w", err)
		}
	}

	const q = `
		INSERT INTO audit_log (id, tenant_id, actor_id, action, entity_type, entity_id, diff, created_at)
		VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, now())`

	var tenantParam, actorParam interface{}
	if tenantID != "" {
		tenantParam = tenantID
	}
	if actorID != "" {
		actorParam = actorID
	}

	_, err := r.pool.Exec(ctx, q, tenantParam, actorParam, action, entityType, entityID, diffJSON)
	if err != nil {
		return fmt.Errorf("audit: write: %w", err)
	}
	return nil
}

// List returns a page of audit_log rows matching params plus the total count of
// matching rows. Limit is clamped to [1, 100]; default is 20 when zero.
func (r *AuditRepo) List(ctx context.Context, params ListAuditParams) ([]AuditEntry, int, error) {
	limit := params.Limit
	switch {
	case limit <= 0:
		limit = 20
	case limit > 100:
		limit = 100
	}

	// Build WHERE clause dynamically.
	// tenant_id filter is always applied (even if empty string the caller scopes it).
	args := []interface{}{params.TenantID} // $1
	where := "WHERE tenant_id = $1"

	if params.EntityType != "" {
		args = append(args, params.EntityType)
		where += fmt.Sprintf(" AND entity_type = $%d", len(args))
	}
	if params.EntityID != "" {
		args = append(args, params.EntityID)
		where += fmt.Sprintf(" AND entity_id = $%d", len(args))
	}

	countQ := "SELECT COUNT(*) FROM audit_log " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("audit: list: count: %w", err)
	}

	args = append(args, limit, params.Offset)
	listQ := fmt.Sprintf(`
		SELECT id, tenant_id, actor_id, action, entity_type, entity_id, diff, created_at
		FROM audit_log
		%s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d`, where, len(args)-1, len(args))

	rows, err := r.pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("audit: list: %w", err)
	}
	defer rows.Close()

	var entries []AuditEntry
	for rows.Next() {
		var e AuditEntry
		var tenantID pgtype.UUID
		var actorID pgtype.UUID
		var diffRaw []byte

		if err := rows.Scan(
			&e.ID,
			&tenantID,
			&actorID,
			&e.Action,
			&e.EntityType,
			&e.EntityID,
			&diffRaw,
			&e.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("audit: list: scan: %w", err)
		}

		if tenantID.Valid {
			s := uuidToString(tenantID)
			e.TenantID = &s
		}
		if actorID.Valid {
			s := uuidToString(actorID)
			e.ActorID = &s
		}
		if diffRaw != nil {
			e.Diff = json.RawMessage(diffRaw)
		}

		entries = append(entries, e)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("audit: list: %w", err)
	}
	if entries == nil {
		entries = []AuditEntry{}
	}
	return entries, total, nil
}

// uuidToString converts a pgtype.UUID to its string representation.
func uuidToString(u pgtype.UUID) string {
	b := u.Bytes
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%012x",
		b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}
