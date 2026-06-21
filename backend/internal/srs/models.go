package srs

import "time"

// Card is one spaced-repetition flash card belonging to a user.
type Card struct {
	ID             string     `json:"id"`
	UserID         string     `json:"user_id"`
	QuestionID     *string    `json:"question_id,omitempty"`
	Front          string     `json:"front"`
	Back           string     `json:"back"`
	SourceType     string     `json:"source_type"`
	IntervalDays   int        `json:"interval_days"`
	Repetitions    int        `json:"repetitions"`
	EaseFactor     float64    `json:"ease_factor"`
	DueDate        string     `json:"due_date"` // YYYY-MM-DD
	LastReviewedAt *time.Time `json:"last_reviewed_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

// ReviewRequest is the payload sent when a student reviews a card.
// Quality maps to the SM-2 grades:
//
//	0 = Again (complete blackout)
//	1 = Hard  (incorrect but close)
//	2 = Good  (correct with hesitation)
//	3 = Easy  (perfect recall)
type ReviewRequest struct {
	CardID  string `json:"card_id"`
	Quality int    `json:"quality"`
}

// ReviewResult is returned after a card is reviewed.
type ReviewResult struct {
	NextDue      string  `json:"next_due"`
	IntervalDays int     `json:"interval_days"`
	EaseFactor   float64 `json:"ease_factor"`
}

// DueCardsResponse is the payload returned by GET /api/srs/due.
type DueCardsResponse struct {
	Cards []Card `json:"cards"`
	Total int    `json:"total"`
}

// CreateCardRequest is the body for POST /api/srs/cards.
type CreateCardRequest struct {
	QuestionID *string `json:"question_id,omitempty"`
	Front      string  `json:"front"`
	Back       string  `json:"back"`
	SourceType string  `json:"source_type"`
}
