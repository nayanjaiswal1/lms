package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/digest"
	"github.com/mindforge/backend/internal/features"
	"github.com/mindforge/backend/internal/jobs"
)

// digestSendHourLocal is the student's local hour the nightly digest sends
// at — 21:00 (9pm), an end-of-day recap likely to land before the student is
// fully done studying for the night.
const digestSendHourLocal = 21

// DigestNightlyHandler implements jobs.Handler for HandlerDigestNightly —
// the fan-out half of the nightly AI revision digest (see internal/digest's
// package doc). Registered on an hourly cron (cmd/server/main.go), so every
// student's own local send hour is covered by one cron entry; most
// invocations are a no-op for most students, since only those whose local
// clock currently reads digestSendHourLocal are ever enqueued.
type DigestNightlyHandler struct {
	pool     *pgxpool.Pool
	features *features.Repo
	digest   *digest.Repo
}

// NewDigestNightlyHandler constructs a DigestNightlyHandler.
func NewDigestNightlyHandler(pool *pgxpool.Pool) *DigestNightlyHandler {
	return &DigestNightlyHandler{
		pool:     pool,
		features: features.NewRepo(pool),
		digest:   digest.NewRepo(pool),
	}
}

// Handle fans out one digest.user job per features.revision_digest entitled
// user who is currently at their local send hour, hasn't opted out, hasn't
// already received a digest today (revision_digests' UNIQUE(user_id,
// digest_date) is the authoritative cap; this is the cheap pre-check), and
// has something worth sending — today's activity, a due SRS flashcard, a
// periodic cadence closing tonight, or several merged into one digest
// (digest.MergeCadences). A due flashcard with no other activity still
// counts, since this digest replaced the standalone "Cards due for review"
// email (handlers/srs.go) that used to fire on its own.
// Uses a raw INSERT with an idempotency key rather than going through
// jobs.Enqueue, since this handler (unlike digest.user) never needs the
// registry for anything else.
func (h *DigestNightlyHandler) Handle(ctx context.Context, _ jobs.Job) error {
	users, err := h.features.EntitledUserIDs(ctx, "revision_digest")
	if err != nil {
		return fmt.Errorf("handlers.digest_nightly: entitled users: %w", err)
	}
	if len(users) == 0 {
		return nil
	}

	now := time.Now().UTC()
	enqueued := 0

	for _, u := range users {
		if optedOut(u.Notifications) {
			continue
		}

		loc, err := time.LoadLocation(u.Timezone)
		if err != nil {
			loc = time.UTC
		}
		local := now.In(loc)
		if local.Hour() != digestSendHourLocal {
			continue
		}

		alreadySent, err := h.digest.AlreadySent(ctx, u.UserID, local)
		if err != nil {
			return fmt.Errorf("handlers.digest_nightly: already sent check (user %s): %w", u.UserID, err)
		}
		if alreadySent {
			continue
		}

		dayStart := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, loc)
		hasActivityToday, err := h.digest.HasActivity(ctx, u.UserID, u.OrgID, dayStart, local)
		if err != nil {
			return fmt.Errorf("handlers.digest_nightly: activity check (user %s): %w", u.UserID, err)
		}
		hasDueCards, err := h.digest.HasDueCards(ctx, u.UserID)
		if err != nil {
			return fmt.Errorf("handlers.digest_nightly: due cards check (user %s): %w", u.UserID, err)
		}

		anchor, err := h.digest.AnchorDate(ctx, u.UserID)
		if err != nil {
			return fmt.Errorf("handlers.digest_nightly: anchor date (user %s): %w", u.UserID, err)
		}
		cadences := digest.MergeCadences(hasActivityToday || hasDueCards, digest.DueCadences(anchor, local))
		if !digest.ShouldSend(cadences) {
			continue
		}

		count, err := h.enqueue(ctx, u, local.Format("2006-01-02"), cadences)
		if err != nil {
			return fmt.Errorf("handlers.digest_nightly: enqueue (user %s): %w", u.UserID, err)
		}
		enqueued += count
	}

	slog.InfoContext(ctx, "handlers.digest_nightly: digest.user jobs enqueued",
		"enqueued", enqueued, "entitled_users", len(users))
	return nil
}

// enqueue inserts one digest.user job, deduped on
// "revision_digest:{localDate}:{userID}" so a redelivered/re-run nightly
// fan-out never double-enqueues the same user's same night.
func (h *DigestNightlyHandler) enqueue(ctx context.Context, u features.EntitledUser, localDate string, cadences []digest.Cadence) (int, error) {
	cadenceStrs := make([]string, len(cadences))
	for i, c := range cadences {
		cadenceStrs[i] = string(c)
	}
	payload, err := json.Marshal(DigestUserPayload{
		UserID: u.UserID, OrgID: u.OrgID, DigestDate: localDate, Cadences: cadenceStrs,
	})
	if err != nil {
		return 0, fmt.Errorf("marshal payload for user %s: %w", u.UserID, err)
	}

	idemKey := fmt.Sprintf("revision_digest:%s:%s", localDate, u.UserID)
	tag, err := h.pool.Exec(ctx,
		`INSERT INTO jobs (handler, status, priority, payload, idempotency_key)
		 VALUES ($1, 'queued', $2, $3, $4)
		 ON CONFLICT (idempotency_key) DO NOTHING`,
		HandlerDigestUser, jobs.PriorityNormal, payload, idemKey,
	)
	if err != nil {
		return 0, fmt.Errorf("insert digest.user job for user %s: %w", u.UserID, err)
	}
	return int(tag.RowsAffected()), nil
}

// optedOut reports whether the user explicitly turned the digest off via
// their notifications.revision_digest preference (frontend Preferences
// form). Absent/unset defaults to enabled — the same "no row = on"
// convention features.Repo.OrgAIConnectorEnabled already uses elsewhere in
// this codebase, since the feature grant itself is the opt-in; the
// preference is only an opt-*out*.
func optedOut(notifications map[string]any) bool {
	v, ok := notifications["revision_digest"]
	if !ok {
		return false
	}
	enabled, ok := v.(bool)
	return ok && !enabled
}
