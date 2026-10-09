package roadmap

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// Replan re-estimates a behind-schedule roadmap without any AI call: it sets
// timeframe_weeks (see ReplanWeeks) and redistributes phases[].estimated_weeks
// over the unfinished phases, all in one transaction. Module completion rows
// and every other structure field are left untouched. A second call right
// after returns ErrNotBehind because the new timeframe is on pace.
func (r *Repo) Replan(ctx context.Context, id, userID string, now time.Time) (Roadmap, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var status string
	var timeframe *int
	var start time.Time
	var structureRaw []byte
	err = tx.QueryRow(ctx,
		`SELECT status, timeframe_weeks, COALESCE(generated_at, created_at), structure
		 FROM roadmaps WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL FOR UPDATE`,
		id, userID).Scan(&status, &timeframe, &start, &structureRaw)
	if errors.Is(err, pgx.ErrNoRows) {
		return Roadmap{}, ErrNotFound
	}
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan load: %w", err)
	}
	if status != StatusActive {
		return Roadmap{}, ErrNotActive
	}

	rows, err := tx.Query(ctx,
		`SELECT module_key::text FROM roadmap_module_progress WHERE roadmap_id = $1 AND completed_at IS NOT NULL`, id)
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan progress: %w", err)
	}
	done := map[string]bool{}
	for rows.Next() {
		var key string
		if err := rows.Scan(&key); err != nil {
			rows.Close()
			return Roadmap{}, fmt.Errorf("roadmap: replan scan progress: %w", err)
		}
		done[key] = true
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan iterate progress: %w", err)
	}

	var structure map[string]any
	if err := json.Unmarshal(structureRaw, &structure); err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan unmarshal structure: %w", err)
	}
	phases, _ := structure["phases"].([]any)

	total, completed, completedMin, remainingMin := 0, 0, 0, 0
	phaseRemaining := make([]int, len(phases))
	for i, pv := range phases {
		forEachModule(pv, func(mod map[string]any) {
			minutes := DefaultModuleMinutes
			if f, ok := mod["estimated_minutes"].(float64); ok && f > 0 {
				minutes = int(f)
			}
			total++
			if mid, _ := mod["id"].(string); done[mid] {
				completed++
				completedMin += minutes
			} else {
				remainingMin += minutes
				phaseRemaining[i] += minutes
			}
		})
	}

	tf := 0
	if timeframe != nil {
		tf = *timeframe
	}
	if !ComputePace(total, completed, tf, start, now).IsBehind {
		return Roadmap{}, ErrNotBehind
	}

	elapsed := elapsedWeeks(start, now)
	newTotal, weeksLeft := ReplanWeeks(elapsed, completedMin, remainingMin)
	for i, w := range distributeWeeks(weeksLeft, phaseRemaining) {
		if w == nil {
			continue
		}
		if pm, ok := phases[i].(map[string]any); ok {
			pm["estimated_weeks"] = *w
		}
	}
	out, err := json.Marshal(structure)
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan marshal structure: %w", err)
	}
	if _, err := tx.Exec(ctx,
		`UPDATE roadmaps SET timeframe_weeks = $1, structure = $2, updated_at = now() WHERE id = $3`,
		newTotal, out, id); err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan update: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: replan commit: %w", err)
	}
	return r.GetForUser(ctx, id, userID)
}

// forEachModule visits every module object of one structure phase.
func forEachModule(phase any, fn func(map[string]any)) {
	pm, _ := phase.(map[string]any)
	milestones, _ := pm["milestones"].([]any)
	for _, mv := range milestones {
		mm, _ := mv.(map[string]any)
		modules, _ := mm["modules"].([]any)
		for _, modv := range modules {
			if mod, ok := modv.(map[string]any); ok {
				fn(mod)
			}
		}
	}
}
