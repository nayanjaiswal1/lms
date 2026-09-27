package workspace

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// repo_ai_cache.go — workspace_ai_cache data layer (D11 "AI called once"):
// one row per (project, kind, cache_key), shared by every phase's cached AI
// feature (RequirementGaps today; epic/task-breakdown/change-impact/summary
// suggestions in later phases). Assignee suggestion is deliberately not
// cached (D20) and never uses this table.

// GetAICache loads a cached AI output into out, reporting false (not an
// error) when no row exists yet — the normal "compute it" path.
func (r *Repo) GetAICache(ctx context.Context, db DBTX, projectID, kind, cacheKey string, out any) (bool, error) {
	var raw []byte
	err := db.QueryRow(ctx,
		`SELECT output FROM workspace_ai_cache WHERE project_id = $1 AND kind = $2 AND cache_key = $3`,
		projectID, kind, cacheKey,
	).Scan(&raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("workspace: get ai cache: %w", err)
	}
	if err := json.Unmarshal(raw, out); err != nil {
		return false, fmt.Errorf("workspace: unmarshal ai cache: %w", err)
	}
	return true, nil
}

// SetAICache stores output under (projectID, kind, cacheKey). A concurrent
// computer racing this insert is harmless — ON CONFLICT DO NOTHING keeps
// whichever wrote first, and callers always re-read rather than trust their
// own just-computed value as authoritative.
func (r *Repo) SetAICache(ctx context.Context, db DBTX, projectID, kind, cacheKey string, output any) error {
	raw, err := json.Marshal(output)
	if err != nil {
		return fmt.Errorf("workspace: marshal ai cache: %w", err)
	}
	if _, err := db.Exec(ctx,
		`INSERT INTO workspace_ai_cache (project_id, kind, cache_key, output) VALUES ($1,$2,$3,$4)
		 ON CONFLICT (project_id, kind, cache_key) DO NOTHING`,
		projectID, kind, cacheKey, raw,
	); err != nil {
		return fmt.Errorf("workspace: set ai cache: %w", err)
	}
	return nil
}

// SetAICacheForce overwrites an existing cache row — the one deliberate
// exception to SetAICache's first-write-wins rule, used only by
// WeeklySummary's own "regenerate" (contract-phase5.md 5c): a manager
// explicitly asking for a fresh weekly summary, capped by
// SummaryRegenPerDay, must actually replace the cached text rather than
// silently keep the old one.
func (r *Repo) SetAICacheForce(ctx context.Context, db DBTX, projectID, kind, cacheKey string, output any) error {
	raw, err := json.Marshal(output)
	if err != nil {
		return fmt.Errorf("workspace: marshal ai cache: %w", err)
	}
	if _, err := db.Exec(ctx,
		`INSERT INTO workspace_ai_cache (project_id, kind, cache_key, output) VALUES ($1,$2,$3,$4)
		 ON CONFLICT (project_id, kind, cache_key) DO UPDATE SET output = EXCLUDED.output, created_at = now()`,
		projectID, kind, cacheKey, raw,
	); err != nil {
		return fmt.Errorf("workspace: force-set ai cache: %w", err)
	}
	return nil
}
