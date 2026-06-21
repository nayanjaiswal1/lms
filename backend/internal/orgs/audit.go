package orgs

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

type auditEntry struct {
	OrgID       string
	ActorUserID *string
	Action      string
	TargetType  string
	TargetID    *string
	BeforeState any
	AfterState  any
	IPAddress   *string
}

func writeAuditLog(ctx context.Context, pool *pgxpool.Pool, e auditEntry) {
	var before, after []byte
	if e.BeforeState != nil {
		before, _ = json.Marshal(e.BeforeState)
	}
	if e.AfterState != nil {
		after, _ = json.Marshal(e.AfterState)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO audit_logs (org_id, actor_user_id, action, target_type, target_id, before_state, after_state, ip_address)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		e.OrgID, e.ActorUserID, e.Action, e.TargetType, e.TargetID,
		nullableJSON(before), nullableJSON(after), e.IPAddress,
	); err != nil {
		slog.Error("orgs: write audit log", "action", e.Action, "error", err)
	}
}

func nullableJSON(b []byte) any {
	if len(b) == 0 {
		return nil
	}
	return string(b)
}
