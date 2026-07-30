package practice

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/mindforge/backend/internal/ai"
)

const (
	// questionBankMaxAgeDays bounds how stale a shared bank can be before a
	// fresh LLM generation replaces it.
	questionBankMaxAgeDays = 30
	// questionBankCanonicalSize is generated on a cache miss — larger than
	// any single request needs, so the same bank row serves a range of
	// question_count values by slicing.
	questionBankCanonicalSize = 10
)

type Service struct {
	repo     *Repo
	provider ai.LLMProvider
}

func NewService(repo *Repo, provider ai.LLMProvider) *Service {
	return &Service{repo: repo, provider: provider}
}

// GetSession thinly wraps the repo so external callers going through Service
// (e.g. interviewprep, which delegates its conceptual/behavioral round to a
// practice session) don't need a separate *Repo dependency for this one read.
func (s *Service) GetSession(ctx context.Context, sessionID, userID string) (PracticeSession, error) {
	return s.repo.GetSession(ctx, sessionID, userID)
}

// category is CategoryTechnical or CategoryBehavioral — it picks both the
// question-generation prompt here and the grading rubric in reviewAnswer,
// so a behavioral round reuses this exact same engine end to end, just
// steered by a different pair of prompts.
func (s *Service) CreateSession(ctx context.Context, userID string, orgID *string, technology, difficulty, category string, questionCount int, modelName string) (PracticeSession, error) {
	if !s.provider.Available() {
		return PracticeSession{}, fmt.Errorf("practice: AI provider not available")
	}
	if category == "" {
		category = CategoryTechnical
	}

	questions, modelUsed, err := s.generateQuestions(ctx, technology, difficulty, category, questionCount)
	if err != nil {
		return PracticeSession{}, err
	}

	session := PracticeSession{
		UserID:        userID,
		OrgID:         orgID,
		Technology:    technology,
		Difficulty:    difficulty,
		Category:      category,
		QuestionCount: questionCount,
		AIModel:       &modelUsed,
	}
	created, err := s.repo.CreateSession(ctx, session)
	if err != nil {
		return PracticeSession{}, err
	}

	items, err := s.repo.InsertItems(ctx, created.ID, questions)
	if err != nil {
		return PracticeSession{}, err
	}
	created.Items = items
	return created, nil
}

// questionBankKey normalizes technology for cache lookups so "Go", " go ",
// and "GO" all hit the same shared bank row.
func questionBankKey(technology string) string {
	return strings.ToLower(strings.TrimSpace(technology))
}

// generateQuestions is cache-first: a fresh shared bank for this exact
// (technology, difficulty, category) serves the request with zero LLM calls;
// only a genuine miss falls through to generateQuestionsFromLLM. Question
// generation is shareable across users (unlike per-answer feedback, which
// depends on the specific answer and is never cached) — this is what lets
// the platform's LLM cost stay flat as more users hit common combos instead
// of growing with traffic.
func (s *Service) generateQuestions(ctx context.Context, technology, difficulty, category string, count int) (questions []string, model string, err error) {
	key := questionBankKey(technology)

	banks, lookupErr := s.repo.LookupQuestionBank(ctx, key, difficulty, category, questionBankMaxAgeDays)
	if lookupErr == nil && len(banks) > 0 {
		bank := banks[0]
		if incErr := s.repo.IncrementQuestionBankUse(ctx, bank.ID); incErr != nil {
			slog.WarnContext(ctx, "practice: increment question bank use failed", "error", incErr)
		}
		qs := bank.Questions
		if len(qs) > count {
			qs = qs[:count]
		}
		modelUsed := ""
		if bank.AIModel != nil {
			modelUsed = *bank.AIModel
		}
		return qs, modelUsed, nil
	}
	if lookupErr != nil {
		// Cache lookup failing is non-fatal — fall through to a live generation
		// rather than failing the whole session creation over a cache miss.
		slog.WarnContext(ctx, "practice: question bank lookup failed", "error", lookupErr)
	}

	generated, modelUsed, err := s.generateQuestionsFromLLM(ctx, technology, difficulty, category, questionBankCanonicalSize)
	if err != nil {
		return nil, "", err
	}
	if insErr := s.repo.InsertQuestionBank(ctx, key, difficulty, category, generated, modelUsed); insErr != nil {
		// Non-fatal — this session still gets its questions, the next request
		// for this key just misses the cache too and generates again.
		slog.WarnContext(ctx, "practice: insert question bank failed", "error", insErr)
	}

	result := generated
	if len(result) > count {
		result = result[:count]
	}
	return result, modelUsed, nil
}

func (s *Service) generateQuestionsFromLLM(ctx context.Context, technology, difficulty, category string, count int) (questions []string, model string, err error) {
	userPrompt := fmt.Sprintf("Technology: %s\nDifficulty: %s\nNumber of questions: %d",
		ai.SanitizeTopic(technology, 100), difficulty, count)

	systemPrompt := ai.InterviewQuestionSystemPrompt
	if category == CategoryBehavioral {
		systemPrompt = ai.BehavioralQuestionSystemPrompt
	}

	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: systemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    2048,
		Temperature:  0.7,
		JSONMode:     true,
	})
	if err != nil {
		return nil, "", fmt.Errorf("practice: generate questions: %w", err)
	}

	var items []struct {
		QuestionText string `json:"question_text"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &items); err != nil {
		return nil, "", fmt.Errorf("practice: parse questions: %w", err)
	}

	result := make([]string, 0, len(items))
	for _, item := range items {
		if item.QuestionText != "" {
			result = append(result, item.QuestionText)
		}
	}
	if len(result) == 0 {
		return nil, "", fmt.Errorf("practice: AI returned no questions")
	}
	return result, resp.Model, nil
}

func (s *Service) SubmitAnswer(ctx context.Context, sessionID, userID string, position int, answerText string) (PracticeItem, error) {
	item, category, err := s.repo.SaveAnswer(ctx, sessionID, userID, position, answerText)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			// The item may already have an answer (user_answer IS NULL guard in SaveAnswer).
			// Return the existing item with its cached feedback rather than a 404.
			existing, lookupErr := s.repo.GetItemByPosition(ctx, sessionID, userID, position)
			if lookupErr != nil {
				return PracticeItem{}, ErrNotFound
			}
			return existing, nil
		}
		return PracticeItem{}, err
	}

	if !s.provider.Available() {
		return item, nil
	}

	// Feedback is already stored (shouldn't happen on a freshly saved answer, but
	// guard defensively in case of concurrent requests).
	if item.AIFeedback != nil {
		return item, nil
	}

	feedback, err := s.reviewAnswer(ctx, item.QuestionText, answerText, category)
	if err != nil {
		// Feedback failure is non-fatal; item is saved, feedback_at stays NULL.
		return item, nil
	}

	return s.repo.SaveFeedback(ctx, item.ID, feedback)
}

func (s *Service) reviewAnswer(ctx context.Context, question, answer, category string) (AIFeedback, error) {
	userPrompt := fmt.Sprintf("Question: %s\n\nCandidate's answer: %s",
		question, ai.SanitizeAnswer(answer))

	systemPrompt := ai.InterviewReviewSystemPrompt
	if category == CategoryBehavioral {
		systemPrompt = ai.BehavioralReviewSystemPrompt
	}

	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: systemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    1024,
		Temperature:  0.3,
		JSONMode:     true,
	})
	if err != nil {
		return AIFeedback{}, fmt.Errorf("practice: review answer: %w", err)
	}

	var feedback AIFeedback
	if err := json.Unmarshal([]byte(resp.Content), &feedback); err != nil {
		return AIFeedback{}, fmt.Errorf("practice: parse feedback: %w", err)
	}
	feedback.Model = resp.Model
	return feedback, nil
}
