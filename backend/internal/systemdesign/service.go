package systemdesign

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/courses"
)

var (
	ErrAIUnavailable  = errors.New("systemdesign: AI provider not available")
	ErrNotQuestion    = errors.New("systemdesign: module is not a system_design question")
	ErrEmptyMessage   = errors.New("systemdesign: message must not be empty")
	ErrMessageTooLong = errors.New("systemdesign: message exceeds 2000 characters")
	ErrEmptyScene     = errors.New("systemdesign: cannot generate feedback for an empty canvas")
)

const (
	maxChatMessageChars  = 2000
	maxChatHistoryTurns  = 12 // last N messages sent as context, oldest dropped first
	maxSceneTextForModel = 6000
)

type Service struct {
	repo        *Repo
	coursesRepo *courses.Repo
	ai          ai.LLMProvider
}

func NewService(repo *Repo, coursesRepo *courses.Repo, provider ai.LLMProvider) *Service {
	return &Service{repo: repo, coursesRepo: coursesRepo, ai: provider}
}

// getQuestion loads the module and confirms it's a system_design question —
// every entry point in this service is scoped to one, so this doubles as the
// authorization boundary (a chat/attempt can't be created against, say, a
// plain notes module by guessing its ID).
func (s *Service) getQuestion(ctx context.Context, orgID, moduleID string) (Question, error) {
	m, err := s.coursesRepo.GetModule(ctx, orgID, moduleID)
	if err != nil {
		if errors.Is(err, courses.ErrNotFound) {
			return Question{}, ErrNotFound
		}
		return Question{}, fmt.Errorf("systemdesign: load module: %w", err)
	}
	if m.Type != "system_design" {
		return Question{}, ErrNotQuestion
	}
	body := ""
	if m.ContentBody != nil {
		body = *m.ContentBody
	}
	return Question{ModuleID: m.ID, Title: m.Title, ContentBody: body}, nil
}

// ─── Attempts ─────────────────────────────────────────────────────────────────

func (s *Service) ListAttempts(ctx context.Context, orgID, userID, moduleID string) ([]AttemptSummary, error) {
	if _, err := s.getQuestion(ctx, orgID, moduleID); err != nil {
		return nil, err
	}
	return s.repo.ListAttemptSummaries(ctx, moduleID, userID)
}

// CreateAttempt starts a fresh, blank-canvas attempt — the "+ New attempt"
// action. Earlier attempts (and their feedback) are kept, not overwritten.
func (s *Service) CreateAttempt(ctx context.Context, orgID, userID, moduleID string) (Attempt, error) {
	if _, err := s.getQuestion(ctx, orgID, moduleID); err != nil {
		return Attempt{}, err
	}
	next, err := s.repo.NextAttemptNumber(ctx, moduleID, userID)
	if err != nil {
		return Attempt{}, err
	}
	return s.repo.CreateAttempt(ctx, moduleID, userID, next)
}

func (s *Service) GetAttempt(ctx context.Context, orgID, userID, moduleID, attemptID string) (Attempt, error) {
	if _, err := s.getQuestion(ctx, orgID, moduleID); err != nil {
		return Attempt{}, err
	}
	return s.repo.GetAttempt(ctx, moduleID, userID, attemptID)
}

// SaveScene is the autosave path — called on every debounced Excalidraw
// onChange, so it stays a single UPDATE with no extra module lookup.
func (s *Service) SaveScene(ctx context.Context, userID, moduleID, attemptID string, scene Scene) (Attempt, error) {
	return s.repo.SaveScene(ctx, moduleID, userID, attemptID, scene)
}

// GenerateFeedback critiques the candidate's whiteboard against the question's
// guidance. The canvas is read as text, not pixels: every Excalidraw text
// element's content (labels, sticky notes, the written non-functional-
// requirements answer) plus a shape-count summary, in drop order — enough
// for the same qualitative critique a mentor skimming the board would give,
// without needing image understanding.
func (s *Service) GenerateFeedback(ctx context.Context, orgID, userID, moduleID, attemptID string) (FeedbackResponse, error) {
	question, err := s.getQuestion(ctx, orgID, moduleID)
	if err != nil {
		return FeedbackResponse{}, err
	}
	if !s.ai.Available() {
		return FeedbackResponse{}, ErrAIUnavailable
	}
	attempt, err := s.repo.GetAttempt(ctx, moduleID, userID, attemptID)
	if err != nil {
		return FeedbackResponse{}, err
	}
	sceneText := extractSceneText(attempt.Scene)
	if strings.TrimSpace(sceneText) == "" {
		return FeedbackResponse{}, ErrEmptyScene
	}

	userPrompt := fmt.Sprintf(
		"Question: %s\n\nGuidance the candidate was given:\n%s\n\nCandidate's whiteboard content (text and labels, in the order placed):\n%s",
		question.Title,
		ai.SanitizeTopic(question.ContentBody, 3000),
		ai.SanitizeTopic(sceneText, maxSceneTextForModel),
	)

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.SystemDesignFeedbackSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    800,
		Temperature:  0.4,
	})
	if err != nil {
		return FeedbackResponse{}, fmt.Errorf("systemdesign: generate feedback: %w", err)
	}

	saved, err := s.repo.SaveFeedback(ctx, moduleID, userID, attemptID, resp.Content)
	if err != nil {
		return FeedbackResponse{}, err
	}
	return FeedbackResponse{Feedback: resp.Content, FeedbackAt: *saved.FeedbackAt}, nil
}

// ─── Chat ─────────────────────────────────────────────────────────────────────

func (s *Service) ListChat(ctx context.Context, orgID, userID, moduleID string) ([]ChatMessage, error) {
	if _, err := s.getQuestion(ctx, orgID, moduleID); err != nil {
		return nil, err
	}
	return s.repo.ListChatMessages(ctx, moduleID, userID)
}

// SendChatMessage appends the student's clarifying question, answers it with
// the question's guidance as grounding context plus recent thread history,
// and appends the assistant's reply. Returns both messages in send order.
func (s *Service) SendChatMessage(ctx context.Context, orgID, userID, moduleID, content string) ([]ChatMessage, error) {
	question, err := s.getQuestion(ctx, orgID, moduleID)
	if err != nil {
		return nil, err
	}
	trimmed := strings.TrimSpace(content)
	if trimmed == "" {
		return nil, ErrEmptyMessage
	}
	if len(trimmed) > maxChatMessageChars {
		return nil, ErrMessageTooLong
	}
	if !s.ai.Available() {
		return nil, ErrAIUnavailable
	}

	history, err := s.repo.ListChatMessages(ctx, moduleID, userID)
	if err != nil {
		return nil, err
	}

	userMsg, err := s.repo.InsertChatMessage(ctx, moduleID, userID, "user", trimmed)
	if err != nil {
		return nil, err
	}

	userPrompt := fmt.Sprintf(
		"System design question: %s\n\nGuidance given to the candidate:\n%s\n\n%s\n\nCandidate's question:\n%s",
		question.Title,
		ai.SanitizeTopic(question.ContentBody, 3000),
		formatChatHistory(history),
		ai.SanitizeTopic(trimmed, maxChatMessageChars),
	)

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.SystemDesignChatSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    400,
		Temperature:  0.5,
	})
	if err != nil {
		return nil, fmt.Errorf("systemdesign: chat completion: %w", err)
	}

	assistantMsg, err := s.repo.InsertChatMessage(ctx, moduleID, userID, "assistant", resp.Content)
	if err != nil {
		return nil, err
	}
	return []ChatMessage{userMsg, assistantMsg}, nil
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// extractSceneText pulls every non-empty Excalidraw text element's content,
// in the order Excalidraw stores them (creation order), plus a one-line
// shape-count summary so the model knows roughly how built-out the diagram
// is even though it never sees the geometry.
func extractSceneText(scene Scene) string {
	var texts []string
	shapeCounts := map[string]int{}
	for _, el := range scene.Elements {
		t, _ := el["type"].(string)
		if t == "" {
			continue
		}
		shapeCounts[t]++
		if t != "text" {
			continue
		}
		if boundTo, ok := el["containerId"]; ok && boundTo != nil {
			continue // counted via its container shape below to avoid double text
		}
		if text, ok := el["text"].(string); ok && strings.TrimSpace(text) != "" {
			texts = append(texts, strings.TrimSpace(text))
		}
	}
	// Container-bound labels (text typed inside a rectangle/ellipse) live on
	// the container element itself as boundElements — fall back to scanning
	// every element's own "text" field too, since Excalidraw sets it on
	// container-bound labels as well as freestanding text elements.
	for _, el := range scene.Elements {
		t, _ := el["type"].(string)
		if t == "text" {
			continue // already handled above
		}
		if text, ok := el["text"].(string); ok && strings.TrimSpace(text) != "" {
			texts = append(texts, strings.TrimSpace(text))
		}
	}

	var b strings.Builder
	if len(shapeCounts) > 0 {
		b.WriteString("Shapes on canvas: ")
		parts := make([]string, 0, len(shapeCounts))
		for shape, count := range shapeCounts {
			parts = append(parts, fmt.Sprintf("%d %s", count, shape))
		}
		b.WriteString(strings.Join(parts, ", "))
		b.WriteString("\n\n")
	}
	for _, t := range texts {
		b.WriteString("- ")
		b.WriteString(t)
		b.WriteString("\n")
	}
	return b.String()
}

func formatChatHistory(history []ChatMessage) string {
	if len(history) == 0 {
		return "No prior questions in this thread."
	}
	start := 0
	if len(history) > maxChatHistoryTurns {
		start = len(history) - maxChatHistoryTurns
	}
	var b strings.Builder
	b.WriteString("Prior thread (for context, oldest first):\n")
	for _, m := range history[start:] {
		who := "Candidate"
		if m.Role == "assistant" {
			who = "You"
		}
		fmt.Fprintf(&b, "%s: %s\n", who, m.Content)
	}
	return b.String()
}
