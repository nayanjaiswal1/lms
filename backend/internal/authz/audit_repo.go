package authz

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AuditRepo handles all audit_logs persistence against PostgreSQL.
type AuditRepo struct {
	pool *pgxpool.Pool
}

// NewAuditRepo constructs an AuditRepo backed by the given connection pool.
func NewAuditRepo(pool *pgxpool.Pool) *AuditRepo {
	return &AuditRepo{pool: pool}
}

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// Write inserts a single row into audit_logs. entityID is stored as target_id
// when it is a valid UUID; otherwise target_id is left NULL and the original
// value is preserved under "original_entity_id" in after_state (mirrors
// 002_merge_audit_logs.sql's handling of compound IDs like "userID/roleID").
func (r *AuditRepo) Write(ctx context.Context, orgID, actorID, action, entityType, entityID string, diff *AuditDiff) error {
	var before, after json.RawMessage
	var targetID *string

	if uuidPattern.MatchString(entityID) {
		targetID = &entityID
		if diff != nil {
			before, _ = json.Marshal(diff.Before)
			after, _ = json.Marshal(diff.After)
		}
	} else if diff != nil {
		before, _ = json.Marshal(diff.Before)
		afterMap := map[string]any{"original_entity_id": entityID}
		if diff.After != nil {
			if b, err := json.Marshal(diff.After); err == nil {
				_ = json.Unmarshal(b, &afterMap)
				afterMap["original_entity_id"] = entityID
			}
		}
		after, _ = json.Marshal(afterMap)
	} else {
		after, _ = json.Marshal(map[string]any{"original_entity_id": entityID})
	}

	const q = `
		INSERT INTO audit_logs (org_id, actor_user_id, action, target_type, target_id, before_state, after_state, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, now())`

	var actorParam interface{}
	if actorID != "" {
		actorParam = actorID
	}

	_, err := r.pool.Exec(ctx, q, orgID, actorParam, action, entityType, targetID, before, after)
	if err != nil {
		return fmt.Errorf("audit: write: %w", err)
	}
	return nil
}

// List returns a page of audit_logs rows matching params plus the total count of
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
	// org_id filter is always applied (even if empty string the caller scopes it).
	args := []interface{}{params.OrgID} // $1
	where := "WHERE org_id = $1"

	if params.EntityType != "" {
		args = append(args, params.EntityType)
		where += fmt.Sprintf(" AND target_type = $%d", len(args))
	}
	if params.EntityID != "" {
		args = append(args, params.EntityID)
		// Cast to text so non-UUID (compound) entity IDs still compare cleanly.
		where += fmt.Sprintf(" AND target_id::text = $%d", len(args))
	}

	countQ := "SELECT COUNT(*) FROM audit_logs " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("audit: list: count: %w", err)
	}

	args = append(args, limit, params.Offset)
	listQ := fmt.Sprintf(`
		SELECT al.id, al.org_id, al.actor_user_id, al.action, al.target_type, al.target_id,
			al.before_state, al.after_state, al.created_at, u.name, u.email
		FROM audit_logs al
		LEFT JOIN users u ON u.id = al.actor_user_id
		%s
		ORDER BY al.created_at DESC
		LIMIT $%d OFFSET $%d`, where, len(args)-1, len(args))

	rows, err := r.pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("audit: list: %w", err)
	}
	defer rows.Close()

	var entries []AuditEntry
	for rows.Next() {
		var e AuditEntry
		var orgID pgtype.UUID
		var actorID pgtype.UUID
		var targetID pgtype.UUID
		var before, after []byte

		if err := rows.Scan(
			&e.ID,
			&orgID,
			&actorID,
			&e.Action,
			&e.EntityType,
			&targetID,
			&before,
			&after,
			&e.CreatedAt,
			&e.ActorName,
			&e.ActorEmail,
		); err != nil {
			return nil, 0, fmt.Errorf("audit: list: scan: %w", err)
		}

		if orgID.Valid {
			s := uuidToString(orgID)
			e.OrgID = &s
		}
		if actorID.Valid {
			s := uuidToString(actorID)
			e.ActorID = &s
		}
		if targetID.Valid {
			e.EntityID = uuidToString(targetID)
		}

		diff := AuditDiff{}
		if before != nil {
			_ = json.Unmarshal(before, &diff.Before)
		}
		if after != nil {
			_ = json.Unmarshal(after, &diff.After)
		}
		if diffJSON, err := json.Marshal(diff); err == nil {
			e.Diff = diffJSON
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
