package practice

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/mindforge/backend/internal/ai"
)

type Service struct {
	repo     *Repo
	provider ai.LLMProvider
}

func NewService(repo *Repo, provider ai.LLMProvider) *Service {
	return &Service{repo: repo, provider: provider}
}

func (s *Service) CreateSession(ctx context.Context, userID string, orgID *string, technology, difficulty string, questionCount int, modelName string) (PracticeSession, error) {
	if !s.provider.Available() {
		return PracticeSession{}, fmt.Errorf("practice: AI provider not available")
	}

	questions, modelUsed, err := s.generateQuestions(ctx, technology, difficulty, questionCount)
	if err != nil {
		return PracticeSession{}, err
	}

	session := PracticeSession{
		UserID:        userID,
		OrgID:         orgID,
		Technology:    technology,
		Difficulty:    difficulty,
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

func (s *Service) generateQuestions(ctx context.Context, technology, difficulty string, count int) (questions []string, model string, err error) {
	userPrompt := fmt.Sprintf("Technology: %s\nDifficulty: %s\nNumber of questions: %d",
		ai.SanitizeTopic(technology, 100), difficulty, count)

	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.InterviewQuestionSystemPrompt,
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
	item, err := s.repo.SaveAnswer(ctx, sessionID, userID, position, answerText)
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

	feedback, err := s.reviewAnswer(ctx, item.QuestionText, answerText)
	if err != nil {
		// Feedback failure is non-fatal; item is saved, feedback_at stays NULL.
		return item, nil
	}

	return s.repo.SaveFeedback(ctx, item.ID, feedback)
}

func (s *Service) reviewAnswer(ctx context.Context, question, answer string) (AIFeedback, error) {
	userPrompt := fmt.Sprintf("Question: %s\n\nCandidate's answer: %s",
		question, ai.SanitizeAnswer(answer))

	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.InterviewReviewSystemPrompt,
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
