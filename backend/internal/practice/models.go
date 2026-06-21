package practice

import (
	"encoding/json"
	"time"
)

type SessionStatus string

const (
	StatusActive    SessionStatus = "active"
	StatusCompleted SessionStatus = "completed"
	StatusAbandoned SessionStatus = "abandoned"
)

type PracticeSession struct {
	ID            string        `json:"id"`
	UserID        string        `json:"user_id"`
	OrgID         *string       `json:"org_id"`
	Technology    string        `json:"technology"`
	Difficulty    string        `json:"difficulty"`
	QuestionCount int           `json:"question_count"`
	Status        SessionStatus `json:"status"`
	AIModel       *string       `json:"ai_model"`
	CreatedAt     time.Time     `json:"created_at"`
	CompletedAt   *time.Time    `json:"completed_at"`
	Items         []PracticeItem `json:"items,omitempty"`
}

type AIFeedback struct {
	Score               int      `json:"score"`
	MaxScore            int      `json:"max_score"`
	Strengths           []string `json:"strengths"`
	Gaps                []string `json:"gaps"`
	SuggestedAnswer     string   `json:"suggested_answer"`
	FollowUpResources   []string `json:"follow_up_resources"`
	Model               string   `json:"model"`
}

type PracticeItem struct {
	ID           string          `json:"id"`
	SessionID    string          `json:"session_id"`
	Position     int             `json:"position"`
	QuestionText string          `json:"question_text"`
	UserAnswer   *string         `json:"user_answer"`
	AIFeedback   *AIFeedback     `json:"ai_feedback"`
	AnsweredAt   *time.Time      `json:"answered_at"`
	FeedbackAt   *time.Time      `json:"feedback_at"`
	CreatedAt    time.Time       `json:"created_at"`
	rawFeedback  json.RawMessage `json:"-"`
}
