package handlers

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/storage"
)

const HandlerLabBundleGC = "lab.bundle_gc"

// labBundleGCGrace is how old an unreferenced bundle must be before it is
// deleted. Bundles are uploaded BEFORE the DB row referencing them commits
// (so a crash can never leave a row pointing at a missing object), which
// means a fresh unreferenced key is normal for the duration of a build.
const labBundleGCGrace = 24 * time.Hour

// LabBundleGCHandler deletes lab-bundles/* objects no lab_build_variants /
// lab_block_versions row references anymore (superseded/failed builds).
type LabBundleGCHandler struct {
	pool  *pgxpool.Pool
	store storage.PrivateStore
}

// NewLabBundleGCHandler constructs a LabBundleGCHandler.
func NewLabBundleGCHandler(pool *pgxpool.Pool, store storage.PrivateStore) *LabBundleGCHandler {
	return &LabBundleGCHandler{pool: pool, store: store}
}

// Handle lists the bundle prefix, loads every referenced key, and deletes the
// unreferenced objects older than the grace period.
func (h *LabBundleGCHandler) Handle(ctx context.Context, _ jobs.Job) error {
	objects, err := h.store.List(ctx, labs.BundleKeyPrefix)
	if err != nil {
		return fmt.Errorf("lab.bundle_gc: list: %w", err)
	}
	if len(objects) == 0 {
		return nil
	}
	rows, err := h.pool.Query(ctx, `
		SELECT workspace_bundle_key FROM lab_build_variants
		UNION SELECT grader_bundle_key FROM lab_build_variants
		UNION SELECT payload->>'verify_bundle_key' FROM lab_build_variants WHERE payload ? 'verify_bundle_key'
		UNION SELECT payload_key FROM lab_block_versions WHERE payload_key IS NOT NULL`)
	if err != nil {
		return fmt.Errorf("lab.bundle_gc: load references: %w", err)
	}
	defer rows.Close()
	referenced := map[string]bool{}
	for rows.Next() {
		var k string
		if err := rows.Scan(&k); err != nil {
			return fmt.Errorf("lab.bundle_gc: scan: %w", err)
		}
		referenced[k] = true
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("lab.bundle_gc: rows: %w", err)
	}

	deleted := 0
	for _, o := range objects {
		if !strings.HasPrefix(o.Key, labs.BundleKeyPrefix) || referenced[o.Key] || time.Since(o.LastModified) < labBundleGCGrace {
			continue
		}
		if err := h.store.Delete(ctx, o.Key); err != nil {
			slog.Error("lab.bundle_gc: delete", "key", o.Key, "error", err)
			continue
		}
		deleted++
	}
	if deleted > 0 {
		slog.Info("lab.bundle_gc: removed orphaned bundles", "count", deleted)
	}
	return nil
}
