package jobs

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// CheckEnqueueQuota returns ErrQuotaExceeded if the org has too many pending+queued jobs.
func CheckEnqueueQuota(ctx context.Context, pool *pgxpool.Pool, orgID string, quota Quota) error {
	var count int
	err := pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM jobs WHERE org_id = $1 AND status IN ('pending', 'queued') AND deleted_at IS NULL`,
		orgID,
	).Scan(&count)
	if err != nil {
		return fmt.Errorf("jobs.CheckEnqueueQuota: %w", err)
	}
	if count >= quota.MaxQueued {
		return ErrQuotaExceeded
	}
	return nil
}

// EnforcePriorityFloor clamps params.Priority to be no less urgent than quota.PriorityFloor.
// Priority numbers are 1 (highest urgency) to 5 (lowest). The floor is the least urgent (highest number) allowed.
// If params.Priority > floor (less urgent than allowed), it is clamped to the floor.
func EnforcePriorityFloor(params *EnqueueParams, quota Quota) error {
	if params.Priority > quota.PriorityFloor {
		params.Priority = quota.PriorityFloor
	}
	return nil
}
