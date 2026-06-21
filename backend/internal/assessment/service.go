package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/rand"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/srs"
)

// Service holds the assessment domain's business logic. It coordinates the repo,
// the code executor, and the grading/proctoring rules.
type Service struct {
	repo *Repo
	exec CodeExecutor
	cfg  *config.Config
}

// NewService wires the service with its data and execution dependencies.
func NewService(repo *Repo, exec CodeExecutor, cfg *config.Config) *Service {
	return &Service{repo: repo, exec: exec, cfg: cfg}
}

// Business-rule errors distinct from data errors, mapped to 4xx by handlers.
var (
	ErrNotAssigned     = errors.New("assessment: not assigned to you")
	ErrNotOpen         = errors.New("assessment: not open for attempts")
	ErrNoAttemptsLeft  = errors.New("assessment: no attempts remaining")
	ErrAttemptClosed   = errors.New("assessment: attempt already submitted")
	ErrAttemptExpired  = errors.New("assessment: attempt time has expired")
	ErrNotAttemptOwner = errors.New("assessment: attempt belongs to another user")
	ErrNoQuestions     = errors.New("assessment: assessment has no questions")
)

// ─── Lifecycle (staff) ───────────────────────────────────────────────────────

// Publish validates the assessment is takeable and transitions it. A scheduled
// window (starts_at in the future) moves to 'scheduled'; otherwise 'published'.
func (s *Service) Publish(ctx context.Context, orgID, assessmentID string) (Assessment, error) {
	a, err := s.repo.GetAssessment(ctx, orgID, assessmentID)
	if err != nil {
		return Assessment{}, err
	}
	if a.QuestionCount == 0 {
		return Assessment{}, ErrNoQuestions
	}

	target := StatusPublished
	if a.StartsAt != nil && a.StartsAt.After(time.Now()) {
		target = StatusScheduled
	}
	if err := s.repo.SetStatus(ctx, orgID, assessmentID, target, true); err != nil {
		return Assessment{}, err
	}
	a.Status = target
	return a, nil
}

// ─── Attempt lifecycle (student) ─────────────────────────────────────────────

// StartAttempt resumes an in-flight attempt or creates a new one. It enforces
// assignment, the open window, and the per-user attempt cap.
func (s *Service) StartAttempt(ctx context.Context, orgID, userID, assessmentID string) (Attempt, []StudentQuestion, Assessment, error) {
	a, err := s.repo.GetAssessment(ctx, orgID, assessmentID)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}

	assigned, err := s.repo.IsUserAssigned(ctx, assessmentID, userID)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}
	if !assigned {
		return Attempt{}, nil, Assessment{}, ErrNotAssigned
	}
	if err := assertOpen(a); err != nil {
		return Attempt{}, nil, Assessment{}, err
	}

	// Resume a live attempt if one exists.
	if activeID, ok, err := s.repo.FindActiveAttempt(ctx, assessmentID, userID); err != nil {
		return Attempt{}, nil, Assessment{}, err
	} else if ok {
		activeAtt, err := s.repo.GetAttempt(ctx, activeID)
		if err != nil {
			return Attempt{}, nil, Assessment{}, err
		}
		qs, err := s.attemptState(ctx, activeAtt, a)
		if err != nil {
			return Attempt{}, nil, Assessment{}, err
		}
		return activeAtt, qs, a, nil
	}

	used, err := s.repo.CountFinalAttempts(ctx, assessmentID, userID)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}
	if used >= a.MaxAttempts {
		return Attempt{}, nil, Assessment{}, ErrNoAttemptsLeft
	}

	questions, err := s.repo.ListAssessmentQuestions(ctx, assessmentID)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}
	if len(questions) == 0 {
		return Attempt{}, nil, Assessment{}, ErrNoQuestions
	}

	if a.ShuffleQuestions {
		rand.Shuffle(len(questions), func(i, j int) { questions[i], questions[j] = questions[j], questions[i] })
	}

	order := make([]string, len(questions))
	for i, q := range questions {
		order[i] = q.ID
	}
	snapshot, err := json.Marshal(map[string]any{"order": order})
	if err != nil {
		return Attempt{}, nil, Assessment{}, fmt.Errorf("assessment: marshal snapshot: %w", err)
	}

	now := time.Now()
	expires := now.Add(time.Duration(a.DurationMinutes) * time.Minute)
	att := Attempt{
		AssessmentID:  assessmentID,
		UserID:        userID,
		OrgID:         orgID,
		AttemptNumber: used + 1,
		StartedAt:     &now,
		ExpiresAt:     &expires,
		Snapshot:      snapshot,
	}
	att, err = s.repo.CreateAttempt(ctx, att, questions)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}

	views, err := buildStudentViews(questions, order, a.ShuffleOptions)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}
	return att, views, a, nil
}

// ResumeAttempt returns the current state (questions + saved answers) of an
// owned attempt, enforcing ownership and expiry.
func (s *Service) ResumeAttempt(ctx context.Context, orgID, userID, attemptID string) (Attempt, []StudentQuestion, Assessment, error) {
	att, err := s.repo.GetAttempt(ctx, attemptID)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}
	if att.UserID != userID {
		return Attempt{}, nil, Assessment{}, ErrNotAttemptOwner
	}
	a, err := s.repo.GetAssessment(ctx, orgID, att.AssessmentID)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}
	// Pass the already-loaded attempt to avoid a second GetAttempt call inside attemptState.
	views, err := s.attemptState(ctx, att, a)
	if err != nil {
		return Attempt{}, nil, Assessment{}, err
	}
	return att, views, a, nil
}

// attemptState loads sanitized questions for an in-flight attempt in snapshot order.
// It accepts the already-loaded Attempt so callers that fetched it themselves do not
// pay for a second DB round-trip.
func (s *Service) attemptState(ctx context.Context, att Attempt, a Assessment) ([]StudentQuestion, error) {
	questions, err := s.repo.ListAssessmentQuestions(ctx, att.AssessmentID)
	if err != nil {
		return nil, err
	}

	var snap struct {
		Order []string `json:"order"`
	}
	if len(att.Snapshot) > 0 {
		_ = json.Unmarshal(att.Snapshot, &snap)
	}
	order := snap.Order
	if len(order) == 0 {
		order = make([]string, len(questions))
		for i, q := range questions {
			order[i] = q.ID
		}
	}

	return buildStudentViews(questions, order, a.ShuffleOptions)
}

// SaveAnswer stores a draft answer for an in-flight, owned, non-expired attempt.
// For subjective questions the caller passes transcript; for MCQ/coding, answer.
func (s *Service) SaveAnswer(ctx context.Context, userID, attemptID, assessmentQuestionID string, answer json.RawMessage, transcript *string, timeSpent int) error {
	att, err := s.repo.GetAttempt(ctx, attemptID)
	if err != nil {
		return err
	}
	if att.UserID != userID {
		return ErrNotAttemptOwner
	}
	if att.Status != AttemptInProgress {
		return ErrAttemptClosed
	}
	if att.ExpiresAt != nil && time.Now().After(*att.ExpiresAt) {
		return ErrAttemptExpired
	}
	return s.repo.SaveAnswer(ctx, attemptID, assessmentQuestionID, answer, transcript, timeSpent)
}

// Submit grades every answer and finalizes the attempt. autoSubmitted marks a
// proctoring-forced submission. Returns needsEval=true when the attempt contains
// subjective answers — the caller must enqueue an eval job and return 202.
func (s *Service) Submit(ctx context.Context, orgID, userID, attemptID string, autoSubmitted bool) (Attempt, bool, error) {
	att, err := s.repo.GetAttempt(ctx, attemptID)
	if err != nil {
		return Attempt{}, false, err
	}
	if att.UserID != userID {
		return Attempt{}, false, ErrNotAttemptOwner
	}
	if att.Status != AttemptInProgress && att.Status != AttemptCreated {
		return Attempt{}, false, ErrAttemptClosed
	}

	a, err := s.repo.GetAssessment(ctx, orgID, att.AssessmentID)
	if err != nil {
		return Attempt{}, false, err
	}

	answers, err := s.repo.ListAnswersForGrading(ctx, attemptID)
	if err != nil {
		return Attempt{}, false, err
	}

	var score, maxScore float64
	pendingManual := false
	hasSubjective := false
	graded := make([]GradedAnswer, 0, len(answers))

	for _, ans := range answers {
		maxScore += ans.MaxPoints
		switch ans.Type {
		case QuestionTypeMCQ:
			correct, pts, gErr := gradeMCQ(ans.Content, ans.Answer, ans.MaxPoints)
			if gErr != nil {
				return Attempt{}, false, gErr
			}
			score += pts
			graded = append(graded, GradedAnswer{AnswerID: ans.ID, IsCorrect: correct, PointsAwarded: pts})

		case QuestionTypeCoding:
			runCtx, cancel := runDeadline(ctx, s.cfg.Judge0Timeout)
			done, correct, pts, run, lang, src, gErr := gradeCoding(runCtx, s.exec, ans.Content, ans.Answer, ans.MaxPoints)
			cancel()
			if gErr != nil {
				return Attempt{}, false, gErr
			}
			if src != "" {
				if recErr := s.repo.RecordCodingSubmission(ctx, ans.ID, lang, src, run); recErr != nil {
					return Attempt{}, false, recErr
				}
			}
			if !done {
				pendingManual = true
				continue // leave answer ungraded for manual review
			}
			score += pts
			graded = append(graded, GradedAnswer{AnswerID: ans.ID, IsCorrect: correct, PointsAwarded: pts})

		case QuestionTypeSubjective:
			// Routed to the AI evaluator — not auto-graded here.
			hasSubjective = true
		}
	}

	percentage := 0.0
	if maxScore > 0 {
		percentage = score / maxScore * 100
	}
	passed := percentage >= a.PassPercentage

	// Subjective questions pend AI evaluation; coding with no executor pends manual grading.
	status := AttemptEvaluated
	if hasSubjective {
		status = AttemptSubmitted // handler will transition to 'evaluating' after enqueue
	} else if pendingManual {
		status = AttemptSubmitted
	}

	tally, err := s.repo.TallyEvents(ctx, attemptID)
	if err != nil {
		return Attempt{}, false, err
	}
	summary, err := json.Marshal(map[string]any{
		"events":         tally,
		"auto_submitted": autoSubmitted,
	})
	if err != nil {
		return Attempt{}, false, fmt.Errorf("assessment: marshal proctoring summary: %w", err)
	}

	duration := att.DurationSeconds
	if att.StartedAt != nil {
		duration = int(time.Since(*att.StartedAt).Seconds())
	}

	if err := s.repo.FinalizeAttempt(ctx, attemptID, status, score, maxScore, percentage,
		passed, autoSubmitted, duration, summary, graded); err != nil {
		return Attempt{}, false, err
	}

	// Create SRS cards for every MCQ or coding question the student got wrong.
	// Errors are non-fatal: the attempt is already finalized and the student can
	// always create cards manually from the review screen.
	s.maybeCreateSRSCards(ctx, userID, answers, graded)

	final, err := s.repo.GetAttempt(ctx, attemptID)
	return final, hasSubjective, err
}

// maybeCreateSRSCards fires-and-logs SRS card creation for each wrong answer.
// It is called after a successful FinalizeAttempt; failures are logged but do
// not affect the attempt result.
func (s *Service) maybeCreateSRSCards(ctx context.Context, userID string, answers []AnswerRow, graded []GradedAnswer) {
	// Build a lookup of graded results by answer ID.
	gradedByID := make(map[string]GradedAnswer, len(graded))
	for _, g := range graded {
		gradedByID[g.AnswerID] = g
	}

	for _, ans := range answers {
		g, wasGraded := gradedByID[ans.ID]
		if !wasGraded || g.IsCorrect {
			continue
		}
		// Only MCQ and coding questions get SRS cards; subjective are AI-graded
		// asynchronously and not suitable for front/back flash cards.
		if ans.Type != QuestionTypeMCQ && ans.Type != QuestionTypeCoding {
			continue
		}

		front := ans.Title
		back := srsBack(ans)
		qid := ans.QuestionID

		if err := srs.MaybeCreateCard(ctx, s.repo.pool, userID, srs.CreateCardRequest{
			QuestionID: &qid,
			Front:      front,
			Back:       back,
			SourceType: "assessment",
		}); err != nil {
			slog.Error("srs: create card after wrong answer", "question_id", qid, "user_id", userID, "error", err)
		}
	}
}

// srsBack extracts a human-readable "back" for the flash card from the question
// content. For MCQ it uses the explanation; for coding it uses the problem prompt.
func srsBack(ans AnswerRow) string {
	switch ans.Type {
	case QuestionTypeMCQ:
		var c MCQContent
		if err := json.Unmarshal(ans.Content, &c); err == nil && c.Explanation != "" {
			return c.Explanation
		}
		// Fallback: list the correct options.
		var correct []string
		for _, o := range c.Options {
			if o.IsCorrect {
				correct = append(correct, o.Text)
			}
		}
		if len(correct) > 0 {
			out := "Correct: "
			for i, t := range correct {
				if i > 0 {
					out += "; "
				}
				out += t
			}
			return out
		}
		return "Review the correct answer."
	case QuestionTypeCoding:
		var c CodingContent
		if err := json.Unmarshal(ans.Content, &c); err == nil && c.Prompt != "" {
			return c.Prompt
		}
		return "Review the problem statement and solution."
	default:
		return "Review this question."
	}
}

// RecordEvent appends a proctoring signal and, when a hard cap is breached and
// auto-submit is enabled, force-submits the attempt. Returns whether the attempt
// was force-submitted so the client can react.
func (s *Service) RecordEvent(ctx context.Context, orgID, userID, attemptID, eventType, severity string, metadata json.RawMessage, clientTS *time.Time) (bool, error) {
	att, err := s.repo.GetAttempt(ctx, attemptID)
	if err != nil {
		return false, err
	}
	if att.UserID != userID {
		return false, ErrNotAttemptOwner
	}
	if att.Status != AttemptInProgress {
		return false, nil // ignore late events on a closed attempt
	}
	if err := s.repo.InsertEvent(ctx, attemptID, userID, eventType, severity, metadata, clientTS); err != nil {
		return false, err
	}

	a, err := s.repo.GetAssessment(ctx, orgID, att.AssessmentID)
	if err != nil {
		return false, err
	}
	if !a.Proctoring.AutoSubmitOnViolation {
		return false, nil
	}

	tally, err := s.repo.TallyEvents(ctx, attemptID)
	if err != nil {
		return false, err
	}
	if breachedHardCap(a.Proctoring, tally) {
		if _, _, err := s.Submit(ctx, orgID, userID, attemptID, true); err != nil {
			return false, err
		}
		return true, nil
	}
	return false, nil
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// assertOpen verifies the assessment is currently takeable.
func assertOpen(a Assessment) error {
	switch a.Status {
	case StatusPublished, StatusActive, StatusScheduled:
	default:
		return ErrNotOpen
	}
	now := time.Now()
	if a.StartsAt != nil && now.Before(*a.StartsAt) {
		return ErrNotOpen
	}
	if a.EndsAt != nil && now.After(*a.EndsAt) {
		return ErrNotOpen
	}
	return nil
}

// breachedHardCap reports whether a hard proctoring threshold has been exceeded.
func breachedHardCap(p ProctoringConfig, tally EventTally) bool {
	if p.MaxTabSwitches > 0 {
		if tally["tab_switch"]+tally["visibility_hidden"] > p.MaxTabSwitches {
			return true
		}
	}
	if p.MaxFocusLoss > 0 {
		if tally["focus_loss"] > p.MaxFocusLoss {
			return true
		}
	}
	return false
}

// buildStudentViews maps questions to sanitized views, ordered by the snapshot.
func buildStudentViews(questions []AssessmentQuestion, order []string, shuffleOptions bool) ([]StudentQuestion, error) {
	byID := make(map[string]AssessmentQuestion, len(questions))
	for _, q := range questions {
		byID[q.ID] = q
	}
	views := make([]StudentQuestion, 0, len(order))
	pos := 0
	for _, id := range order {
		q, ok := byID[id]
		if !ok {
			continue
		}
		view, err := toStudentView(q, shuffleOptions)
		if err != nil {
			return nil, err
		}
		view.Position = pos
		views = append(views, view)
		pos++
	}
	return views, nil
}
