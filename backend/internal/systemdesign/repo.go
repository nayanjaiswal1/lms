package systemdesign

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("systemdesign: not found")
	ErrNotOwner = errors.New("systemdesign: not owner")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ─── Attempts ─────────────────────────────────────────────────────────────────

func (r *Repo) ListAttemptSummaries(ctx context.Context, moduleID, userID string) ([]AttemptSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, attempt_number, feedback IS NOT NULL, created_at, updated_at
		 FROM system_design_attempts
		 WHERE module_id = $1 AND user_id = $2
		 ORDER BY attempt_number ASC`, moduleID, userID)
	if err != nil {
		return nil, fmt.Errorf("systemdesign: list attempt summaries: %w", err)
	}
	defer rows.Close()

	out := []AttemptSummary{}
	for rows.Next() {
		var a AttemptSummary
		if err := rows.Scan(&a.ID, &a.AttemptNum, &a.HasFeedback, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, fmt.Errorf("systemdesign: scan attempt summary: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// NextAttemptNumber returns 1 + the highest existing attempt_number for this
// module+user (0 if none exist yet).
func (r *Repo) NextAttemptNumber(ctx context.Context, moduleID, userID string) (int, error) {
	var max int
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(MAX(attempt_number), 0) FROM system_design_attempts WHERE module_id = $1 AND user_id = $2`,
		moduleID, userID).Scan(&max)
	if err != nil {
		return 0, fmt.Errorf("systemdesign: next attempt number: %w", err)
	}
	return max + 1, nil
}

func (r *Repo) CreateAttempt(ctx context.Context, moduleID, userID string, attemptNum int) (Attempt, error) {
	return r.scanAttemptRow(r.pool.QueryRow(ctx,
		`INSERT INTO system_design_attempts (module_id, user_id, attempt_number)
		 VALUES ($1, $2, $3)
		 RETURNING id, module_id, user_id, attempt_number, scene, feedback, feedback_at, created_at, updated_at`,
		moduleID, userID, attemptNum))
}

// GetAttempt returns an attempt scoped to its owner — a moduleID/userID
// mismatch (IDOR) or a missing row both surface as ErrNotFound.
func (r *Repo) GetAttempt(ctx context.Context, moduleID, userID, attemptID string) (Attempt, error) {
	return r.scanAttemptRow(r.pool.QueryRow(ctx,
		`SELECT id, module_id, user_id, attempt_number, scene, feedback, feedback_at, created_at, updated_at
		 FROM system_design_attempts WHERE id = $1 AND module_id = $2 AND user_id = $3`,
		attemptID, moduleID, userID))
}

func (r *Repo) SaveScene(ctx context.Context, moduleID, userID, attemptID string, scene Scene) (Attempt, error) {
	raw, err := json.Marshal(scene)
	if err != nil {
		return Attempt{}, fmt.Errorf("systemdesign: marshal scene: %w", err)
	}
	return r.scanAttemptRow(r.pool.QueryRow(ctx,
		`UPDATE system_design_attempts SET scene = $1, updated_at = now()
		 WHERE id = $2 AND module_id = $3 AND user_id = $4
		 RETURNING id, module_id, user_id, attempt_number, scene, feedback, feedback_at, created_at, updated_at`,
		raw, attemptID, moduleID, userID))
}

func (r *Repo) SaveFeedback(ctx context.Context, moduleID, userID, attemptID, feedback string) (Attempt, error) {
	return r.scanAttemptRow(r.pool.QueryRow(ctx,
		`UPDATE system_design_attempts SET feedback = $1, feedback_at = now(), updated_at = now()
		 WHERE id = $2 AND module_id = $3 AND user_id = $4
		 RETURNING id, module_id, user_id, attempt_number, scene, feedback, feedback_at, created_at, updated_at`,
		feedback, attemptID, moduleID, userID))
}

func (r *Repo) scanAttemptRow(row pgx.Row) (Attempt, error) {
	var a Attempt
	var raw []byte
	err := row.Scan(&a.ID, &a.ModuleID, &a.UserID, &a.AttemptNum, &raw, &a.Feedback, &a.FeedbackAt, &a.CreatedAt, &a.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Attempt{}, ErrNotFound
		}
		return Attempt{}, fmt.Errorf("systemdesign: scan attempt: %w", err)
	}
	if err := json.Unmarshal(raw, &a.Scene); err != nil {
		return Attempt{}, fmt.Errorf("systemdesign: unmarshal scene: %w", err)
	}
	return a, nil
}

// ─── Chat ─────────────────────────────────────────────────────────────────────

func (r *Repo) ListChatMessages(ctx context.Context, moduleID, userID string) ([]ChatMessage, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, role, content, created_at FROM system_design_chat_messages
		 WHERE module_id = $1 AND user_id = $2 ORDER BY created_at ASC`, moduleID, userID)
	if err != nil {
		return nil, fmt.Errorf("systemdesign: list chat messages: %w", err)
	}
	defer rows.Close()

	out := []ChatMessage{}
	for rows.Next() {
		var m ChatMessage
		if err := rows.Scan(&m.ID, &m.Role, &m.Content, &m.CreatedAt); err != nil {
			return nil, fmt.Errorf("systemdesign: scan chat message: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r *Repo) InsertChatMessage(ctx context.Context, moduleID, userID, role, content string) (ChatMessage, error) {
	var m ChatMessage
	err := r.pool.QueryRow(ctx,
		`INSERT INTO system_design_chat_messages (module_id, user_id, role, content)
		 VALUES ($1, $2, $3, $4) RETURNING id, role, content, created_at`,
		moduleID, userID, role, content).Scan(&m.ID, &m.Role, &m.Content, &m.CreatedAt)
	if err != nil {
		return ChatMessage{}, fmt.Errorf("systemdesign: insert chat message: %w", err)
	}
	return m, nil
}
