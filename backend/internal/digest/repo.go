package digest

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/sheets"
)

// emailSendHandler is jobs/handlers' HandlerEmailSend ("email.send"),
// duplicated here as a plain string literal for the same import-cycle
// reason as internal/notifications' own emailSendHandler const
// (internal/notifications/service.go): jobs/handlers imports domain
// packages — including, transitively, this one, since
// handlers/digest_user.go calls into it — so this package must never import
// jobs/handlers back. MUST stay in sync with handlers.HandlerEmailSend.
const emailSendHandler = "email.send"

// Repo is the data-access layer for the revision digest domain, composing
// activity.Repo and sheets.Repo rather than duplicating their queries.
type Repo struct {
	pool     *pgxpool.Pool
	activity *activity.Repo
	sheets   *sheets.Repo
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool, activity: activity.NewRepo(pool), sheets: sheets.NewRepo(pool)}
}

// AnchorDate returns userID's first-ever digest_date, or the zero Time if
// they have none yet — see DueCadences for how that zero value is
// interpreted (first digest is always daily-only).
func (r *Repo) AnchorDate(ctx context.Context, userID string) (time.Time, error) {
	var anchor *time.Time
	err := r.pool.QueryRow(ctx,
		`SELECT MIN(digest_date) FROM revision_digests WHERE user_id = $1`, userID,
	).Scan(&anchor)
	if err != nil {
		return time.Time{}, fmt.Errorf("digest: anchor date: %w", err)
	}
	if anchor == nil {
		return time.Time{}, nil
	}
	return *anchor, nil
}

// AlreadySent reports whether userID already has a revision_digests row for
// digestDate — the daily-cap check the nightly fan-out handler makes before
// even bothering to gather sources or spend an AI call.
func (r *Repo) AlreadySent(ctx context.Context, userID string, digestDate time.Time) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM revision_digests WHERE user_id = $1 AND digest_date = $2)`,
		userID, digestDate.Format("2006-01-02"),
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("digest: already sent: %w", err)
	}
	return exists, nil
}

// MonthlyCostUSD sums cost_usd for the current calendar month — for userID
// when non-nil (the per-user budget check), across every user when nil (the
// global budget check).
func (r *Repo) MonthlyCostUSD(ctx context.Context, userID *string) (float64, error) {
	var total float64
	var err error
	if userID != nil {
		err = r.pool.QueryRow(ctx,
			`SELECT COALESCE(SUM(cost_usd), 0) FROM revision_digests
			  WHERE user_id = $1 AND digest_date >= date_trunc('month', CURRENT_DATE)::date`,
			*userID,
		).Scan(&total)
	} else {
		err = r.pool.QueryRow(ctx,
			`SELECT COALESCE(SUM(cost_usd), 0) FROM revision_digests
			  WHERE digest_date >= date_trunc('month', CURRENT_DATE)::date`,
		).Scan(&total)
	}
	if err != nil {
		return 0, fmt.Errorf("digest: monthly cost: %w", err)
	}
	return total, nil
}

// HasActivity reports whether userID has any activity entry in [from, to) —
// the nightly handler's cheap existence check for gating the "daily"
// cadence (see MergeCadences), without pulling the full entry list
// GatherSources fetches once, later, inside digest.user.
func (r *Repo) HasActivity(ctx context.Context, userID, orgID string, from, to time.Time) (bool, error) {
	entries, err := r.activity.ListWindow(ctx, userID, orgID, from, to, 1)
	if err != nil {
		return false, fmt.Errorf("digest: has activity: %w", err)
	}
	return len(entries) > 0, nil
}

// GatherSources pulls everything one digest needs: activity in the window
// covering every cadence being merged tonight, plus the student's next
// sheet-tracker tasks (not window-bound — "what's next" is always current,
// not historical).
func (r *Repo) GatherSources(ctx context.Context, userID, orgID string, cadences []Cadence, now time.Time) (Sources, error) {
	start, end := WindowFor(cadences, now)
	entries, err := r.activity.ListWindow(ctx, userID, orgID, start, end, 200)
	if err != nil {
		return Sources{}, fmt.Errorf("digest: gather activity: %w", err)
	}
	tasks, err := r.sheets.NextTasks(ctx, userID, 5)
	if err != nil {
		return Sources{}, fmt.Errorf("digest: gather sheet tasks: %w", err)
	}
	return Sources{
		Activity: entries, NextTasks: tasks, Cadences: cadences,
		WindowStart: start, WindowEnd: end,
	}, nil
}

// InsertDigest persists d and enqueues its delivery email. jobs.Enqueue only
// ever accepts a *pgxpool.Pool, never a caller's tx (see jobs/store.go's
// Enqueue) — internal/notifications' own enqueueEmail documents exactly why
// a queued job row is always its own independent write, and this mirrors
// that precedent rather than fighting it. The 1-email/day cap is actually
// enforced by revision_digests' UNIQUE(user_id, digest_date) constraint, not
// by application logic: ON CONFLICT DO NOTHING here makes a racing retry
// (two digest.user jobs for the same user+night) a safe no-op instead of a
// constraint-violation error bubbling up as a job failure.
func (r *Repo) InsertDigest(ctx context.Context, registry *jobs.Registry, d Digest, toEmail, toName string) error {
	var id string
	var model *string
	if d.Model != "" {
		model = &d.Model
	}
	cadenceStrs := make([]string, len(d.Cadences))
	for i, c := range d.Cadences {
		cadenceStrs[i] = string(c)
	}

	err := r.pool.QueryRow(ctx,
		`INSERT INTO revision_digests
		   (user_id, org_id, digest_date, cadences, window_start, window_end,
		    ai_status, model, input_tokens, output_tokens, cost_usd, subject, body)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
		 ON CONFLICT (user_id, digest_date) DO NOTHING
		 RETURNING id`,
		d.UserID, d.OrgID, d.DigestDate, cadenceStrs, d.WindowStart, d.WindowEnd,
		d.AIStatus, model, d.InputTokens, d.OutputTokens, d.CostUSD, d.Subject, d.Body,
	).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil // another run already sent today's digest for this user
		}
		return fmt.Errorf("digest: insert digest: %w", err)
	}

	orgID := d.OrgID
	idemKey := fmt.Sprintf("revision_digest_email:%s:%s", d.UserID, d.DigestDate)
	_, err = jobs.Enqueue(ctx, r.pool, registry, jobs.EnqueueParams{
		Handler:  emailSendHandler,
		Priority: jobs.PriorityNormal,
		Payload: map[string]any{
			"type": "notification", "to": toEmail, "to_name": toName,
			"template_data": map[string]any{"subject": d.Subject, "body": d.Body},
		},
		OrgID:          &orgID,
		IdempotencyKey: &idemKey,
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("digest: enqueue email: %w", err)
	}
	return nil
}
