package assessment

import (
	"context"
	"fmt"
	"log/slog"
)

// AutoSubmitExpiredAttempts force-submits every in-progress attempt whose time
// limit has passed, up to limit per call. Called by the assessment.expire_attempts
// background job (mirrors labs.Service's lab.expire_sessions reaper). Answers
// saved before expiry are already frozen — SaveAnswer rejects writes once
// expires_at has passed — so this only finalizes what was already locked in;
// it does not let a late run change what gets graded.
//
// Reuses the same Submit + post-processing path as a manual SubmitAttempt call
// (enqueue eval for subjective attempts, otherwise award XP and complete the
// embedding course module) so an abandoned attempt is graded and reported on
// exactly like one the student submitted themselves.
func (h *Handler) AutoSubmitExpiredAttempts(ctx context.Context, limit int) (int, error) {
	refs, err := h.repo.ListExpiredInProgressAttempts(ctx, limit)
	if err != nil {
		return 0, fmt.Errorf("assessment.AutoSubmitExpiredAttempts: list: %w", err)
	}

	count := 0
	for _, ref := range refs {
		att, needsEval, err := h.service.finalizeSubmit(ctx, ref.OrgID, ref.UserID, ref.ID, true)
		if err != nil {
			slog.Error("assessment.AutoSubmitExpiredAttempts: submit failed",
				"attempt", ref.ID, "error", err)
			continue
		}

		if needsEval {
			h.enqueueEval(ctx, att.ID)
		} else if att.Passed != nil && *att.Passed {
			if h.rewardsSvc != nil {
				att = h.awardAttemptXP(ctx, att)
			}
			h.completeEmbeddingModule(ctx, att)
		}
		count++
	}
	return count, nil
}
