package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/digest"
	"github.com/mindforge/backend/internal/jobs"
)

// DigestUserPayload is the JSON payload for digest.user jobs. The cadence
// list is decided once, by DigestNightlyHandler, and carried through here
// rather than recomputed — recomputing independently could let the two
// handlers reach different conclusions if time ticks past a boundary
// between enqueue and run.
type DigestUserPayload struct {
	UserID     string   `json:"user_id"`
	OrgID      string   `json:"org_id"`
	DigestDate string   `json:"digest_date"` // YYYY-MM-DD, the user's local date
	Cadences   []string `json:"cadences"`
}

// DigestUserHandler implements jobs.Handler for HandlerDigestUser: gathers
// one student's activity/sheet-tracker sources for the merged cadence
// window, spends at most one AI call (subject to the budget caps —
// generateNarrative), and persists+emails the result via
// digest.Repo.InsertDigest.
type DigestUserHandler struct {
	pool         *pgxpool.Pool
	digest       *digest.Repo
	ai           ai.LLMProvider
	cfg          *config.Config
	jobsRegistry *jobs.Registry
}

// NewDigestUserHandler constructs a DigestUserHandler.
func NewDigestUserHandler(pool *pgxpool.Pool, aiProvider ai.LLMProvider, cfg *config.Config, jobsRegistry *jobs.Registry) *DigestUserHandler {
	return &DigestUserHandler{
		pool: pool, digest: digest.NewRepo(pool), ai: aiProvider, cfg: cfg, jobsRegistry: jobsRegistry,
	}
}

// Handle builds and sends one user's digest for one night.
func (h *DigestUserHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p DigestUserPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.digest_user: unmarshal payload: %w", err)
	}
	if p.UserID == "" || p.DigestDate == "" || len(p.Cadences) == 0 {
		return fmt.Errorf("handlers.digest_user: payload missing user_id/digest_date/cadences")
	}

	digestDate, err := time.Parse("2006-01-02", p.DigestDate)
	if err != nil {
		return fmt.Errorf("handlers.digest_user: parse digest_date %q: %w", p.DigestDate, err)
	}

	// Belt-and-suspenders re-check of the daily cap: DigestNightlyHandler's
	// own pre-check and this job actually running are not atomic, so a
	// retry or a race between two fan-out runs could enqueue twice for the
	// same user+night. revision_digests' UNIQUE constraint (via InsertDigest)
	// is the real guarantee; this just avoids spending an AI call first.
	alreadySent, err := h.digest.AlreadySent(ctx, p.UserID, digestDate)
	if err != nil {
		return fmt.Errorf("handlers.digest_user: already sent check (user %s): %w", p.UserID, err)
	}
	if alreadySent {
		slog.InfoContext(ctx, "handlers.digest_user: already sent today, skipping", "user_id", p.UserID)
		return nil
	}

	toEmail, toName, err := h.userContact(ctx, p.UserID)
	if err != nil {
		return fmt.Errorf("handlers.digest_user: user contact (user %s): %w", p.UserID, err)
	}

	cadences := make([]digest.Cadence, len(p.Cadences))
	for i, c := range p.Cadences {
		cadences[i] = digest.Cadence(c)
	}

	sources, err := h.digest.GatherSources(ctx, p.UserID, p.OrgID, cadences, time.Now())
	if err != nil {
		return fmt.Errorf("handlers.digest_user: gather sources (user %s): %w", p.UserID, err)
	}

	narrative, aiStatus, model, inTok, outTok, costUSD, err := h.generateNarrative(ctx, p.UserID, sources)
	if err != nil {
		return fmt.Errorf("handlers.digest_user: generate narrative (user %s): %w", p.UserID, err)
	}

	subject, body := digest.Render(cadences, sources, narrative)

	d := digest.Digest{
		UserID: p.UserID, OrgID: p.OrgID, DigestDate: p.DigestDate, Cadences: cadences,
		WindowStart: sources.WindowStart, WindowEnd: sources.WindowEnd,
		AIStatus: aiStatus, Model: model, InputTokens: inTok, OutputTokens: outTok, CostUSD: costUSD,
		Subject: subject, Body: body,
	}
	if err := h.digest.InsertDigest(ctx, h.jobsRegistry, d, toEmail, toName); err != nil {
		return fmt.Errorf("handlers.digest_user: insert digest (user %s): %w", p.UserID, err)
	}

	slog.InfoContext(ctx, "handlers.digest_user: digest sent",
		"user_id", p.UserID, "cadences", p.Cadences, "ai_status", aiStatus, "cost_usd", costUSD)
	return nil
}

// generateNarrative spends at most one AI call, subject to both budget caps
// (checked user-first, then global, since a hit either way skips generation
// the same way). Any skip/failure path still returns a nil error — this is
// never fatal to the job, since Render always produces a sendable
// deterministic body even with an empty narrative (see internal/digest's
// package doc and Render's own comment on why "no AI" must never mean
// "no email").
func (h *DigestUserHandler) generateNarrative(ctx context.Context, userID string, sources digest.Sources) (narrative, status, model string, inputTokens, outputTokens int, costUSD float64, err error) {
	if !h.ai.Available() {
		return "", digest.AIStatusSkippedUnavailable, "", 0, 0, 0, nil
	}

	userSpend, err := h.digest.MonthlyCostUSD(ctx, &userID)
	if err != nil {
		return "", "", "", 0, 0, 0, fmt.Errorf("user monthly cost: %w", err)
	}
	if userSpend >= h.cfg.DigestUserMonthlyBudgetUSD {
		slog.WarnContext(ctx, "handlers.digest_user: user monthly budget reached, sending fallback",
			"user_id", userID, "spend_usd", userSpend, "cap_usd", h.cfg.DigestUserMonthlyBudgetUSD)
		return "", digest.AIStatusSkippedBudget, "", 0, 0, 0, nil
	}

	globalSpend, err := h.digest.MonthlyCostUSD(ctx, nil)
	if err != nil {
		return "", "", "", 0, 0, 0, fmt.Errorf("global monthly cost: %w", err)
	}
	if globalSpend >= h.cfg.DigestGlobalMonthlyBudgetUSD {
		slog.WarnContext(ctx, "handlers.digest_user: global monthly budget reached, sending fallback",
			"spend_usd", globalSpend, "cap_usd", h.cfg.DigestGlobalMonthlyBudgetUSD)
		return "", digest.AIStatusSkippedBudget, "", 0, 0, 0, nil
	}

	llmCtx, cancel := context.WithTimeout(ctx, h.cfg.LLMTimeout)
	defer cancel()

	resp, err := h.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.RevisionDigestSystemPrompt,
		UserPrompt:   ai.SanitizeAnswer(digest.PromptContext(sources)),
		MaxTokens:    1200,
		Temperature:  0.4,
	})
	if err != nil {
		slog.WarnContext(ctx, "handlers.digest_user: AI call failed, sending fallback",
			"user_id", userID, "error", err)
		return "", digest.AIStatusFailed, "", 0, 0, 0, nil
	}

	cost := (float64(resp.Usage.InputTokens)/1_000_000)*h.cfg.LLMCostInputPerMTok +
		(float64(resp.Usage.OutputTokens)/1_000_000)*h.cfg.LLMCostOutputPerMTok
	return resp.Content, digest.AIStatusGenerated, resp.Model, resp.Usage.InputTokens, resp.Usage.OutputTokens, cost, nil
}

// userContact resolves email/name for the delivery email, mirroring
// internal/notifications' own unexported Repo.userContact — small enough
// (one query) that duplicating it here beats adding a cross-package
// dependency on notifications for a single helper.
func (h *DigestUserHandler) userContact(ctx context.Context, userID string) (email, name string, err error) {
	err = h.pool.QueryRow(ctx, `SELECT email, name FROM users WHERE id = $1`, userID).Scan(&email, &name)
	if err != nil {
		return "", "", fmt.Errorf("resolve user contact: %w", err)
	}
	return email, name, nil
}
