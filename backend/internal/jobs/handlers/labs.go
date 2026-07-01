package handlers

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os/exec"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

const (
	HandlerLabExpire  = "lab.expire_sessions"
	HandlerLabCleanup = "lab.cleanup_containers"
)

// LabExpireHandler marks stale lab sessions as expired and removes their containers.
type LabExpireHandler struct {
	pool *pgxpool.Pool
}

// NewLabExpireHandler constructs a LabExpireHandler.
func NewLabExpireHandler(pool *pgxpool.Pool) *LabExpireHandler {
	return &LabExpireHandler{pool: pool}
}

// Handle finds all running/paused sessions past their expires_at, removes the
// Docker container if one is assigned, and marks the session expired.
func (h *LabExpireHandler) Handle(ctx context.Context, job jobs.Job) error {
	rows, err := h.pool.Query(ctx,
		`SELECT id, container_id FROM lab_sessions
		 WHERE status IN ('running','paused') AND expires_at < now()
		 LIMIT 100`)
	if err != nil {
		return fmt.Errorf("lab.expire_sessions: query sessions: %w", err)
	}
	defer rows.Close()

	type sessionRow struct {
		id          string
		containerID *string
	}

	var sessions []sessionRow
	for rows.Next() {
		var r sessionRow
		if err := rows.Scan(&r.id, &r.containerID); err != nil {
			return fmt.Errorf("lab.expire_sessions: scan row: %w", err)
		}
		sessions = append(sessions, r)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("lab.expire_sessions: iterate rows: %w", err)
	}

	count := 0
	for _, s := range sessions {
		if s.containerID != nil && *s.containerID != "" {
			if rmErr := exec.CommandContext(ctx, "docker", "rm", "-f", *s.containerID).Run(); rmErr != nil {
				slog.Error("lab.expire_sessions: docker rm failed",
					"container", *s.containerID, "error", rmErr)
			}
		}
		if _, execErr := h.pool.Exec(ctx,
			`UPDATE lab_sessions SET status='expired' WHERE id=$1`, s.id); execErr != nil {
			slog.Error("lab.expire_sessions: update status",
				"session", s.id, "error", execErr)
			continue
		}
		count++
	}

	slog.Info("lab.expire_sessions: expired N sessions", "count", count)
	return nil
}

// LabCleanupHandler removes orphaned Docker containers that have no active session row.
type LabCleanupHandler struct {
	pool *pgxpool.Pool
}

// NewLabCleanupHandler constructs a LabCleanupHandler.
func NewLabCleanupHandler(pool *pgxpool.Pool) *LabCleanupHandler {
	return &LabCleanupHandler{pool: pool}
}

// Handle scans all mindforge-lab-* and mindforge-validate-* containers and
// removes those that are old enough and have no corresponding active session row.
func (h *LabCleanupHandler) Handle(ctx context.Context, job jobs.Job) error {
	removed := 0

	// --- lab containers ---
	labOut, labErr := exec.CommandContext(ctx,
		"docker", "ps", "-a",
		"--filter", "name=mindforge-lab-",
		"--format", "{{.Names}}\t{{.ID}}\t{{.CreatedAt}}",
	).Output()
	if labErr != nil {
		slog.Warn("lab.cleanup_containers: docker ps (lab)", "error", labErr)
	} else {
		for _, line := range strings.Split(strings.TrimSpace(string(labOut)), "\n") {
			if line == "" {
				continue
			}
			parts := strings.SplitN(line, "\t", 3)
			if len(parts) != 3 {
				continue
			}
			name, containerID, createdAtStr := parts[0], parts[1], parts[2]

			// Extract sessionID: mindforge-lab-{UUID36}-{resetCount}
			trimmed := strings.TrimPrefix(name, "mindforge-lab-")
			if len(trimmed) < 36 {
				continue
			}
			sessionID := trimmed[:36]

			createdAt, parseErr := time.Parse(time.RFC3339, createdAtStr)
			if parseErr != nil {
				createdAt = time.Time{}
			}
			if time.Since(createdAt) < 2*time.Minute {
				continue
			}

			// Only remove if no active session row exists.
			var activeID string
			qErr := h.pool.QueryRow(ctx,
				`SELECT id FROM lab_sessions
				 WHERE id=$1 AND status IN ('provisioning','running','paused')
				 LIMIT 1`,
				sessionID,
			).Scan(&activeID)
			if qErr == nil {
				// Active session found — leave the container alone.
				continue
			}
			if !errors.Is(qErr, pgx.ErrNoRows) {
				// Real DB error — skip removal to avoid accidentally destroying a live container.
				slog.Warn("lab.cleanup_containers: query active session",
					"session", sessionID, "error", qErr)
				continue
			}

			if rmErr := exec.CommandContext(ctx, "docker", "rm", "-f", containerID).Run(); rmErr != nil {
				slog.Error("lab.cleanup_containers: docker rm (lab)",
					"container", containerID, "error", rmErr)
				continue
			}
			removed++
		}
	}

	// --- validate containers (older than 15 minutes are always orphaned) ---
	vOut, vErr := exec.CommandContext(ctx,
		"docker", "ps", "-a",
		"--filter", "name=mindforge-validate-",
		"--format", "{{.Names}}\t{{.ID}}\t{{.CreatedAt}}",
	).Output()
	if vErr != nil {
		slog.Warn("lab.cleanup_containers: docker ps (validate)", "error", vErr)
	} else {
		for _, line := range strings.Split(strings.TrimSpace(string(vOut)), "\n") {
			if line == "" {
				continue
			}
			parts := strings.SplitN(line, "\t", 3)
			if len(parts) != 3 {
				continue
			}
			_, containerID, createdAtStr := parts[0], parts[1], parts[2]

			createdAt, parseErr := time.Parse(time.RFC3339, createdAtStr)
			if parseErr != nil {
				createdAt = time.Time{}
			}
			if time.Since(createdAt) < 15*time.Minute {
				continue
			}

			if rmErr := exec.CommandContext(ctx, "docker", "rm", "-f", containerID).Run(); rmErr != nil {
				slog.Error("lab.cleanup_containers: docker rm (validate)",
					"container", containerID, "error", rmErr)
				continue
			}
			removed++
		}
	}

	slog.Info("lab.cleanup_containers: removed orphaned containers", "count", removed)
	return nil
}
