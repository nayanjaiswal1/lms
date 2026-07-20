package systemdesign

import "time"

// Attempt is one student's whiteboard try at a system-design question
// (a course_modules row of type='system_design'). Scene is the full
// Excalidraw document (elements + appState) round-tripped verbatim — the
// backend never inspects its shape except to extract text for AI feedback.
type Attempt struct {
	ID         string     `json:"id"`
	ModuleID   string     `json:"module_id"`
	UserID     string     `json:"user_id"`
	AttemptNum int        `json:"attempt_number"`
	Scene      Scene      `json:"scene"`
	Feedback   *string    `json:"feedback,omitempty"`
	FeedbackAt *time.Time `json:"feedback_at,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

// Scene is deliberately typed as opaque JSON on the wire — Excalidraw's
// element schema evolves independently of this backend, so the server does
// not attempt to model it field-by-field.
type Scene struct {
	Elements []map[string]any `json:"elements"`
	AppState map[string]any   `json:"appState"`
	Files    map[string]any   `json:"files,omitempty"`
}

// AttemptSummary is what the attempt selector needs — no scene payload.
type AttemptSummary struct {
	ID          string    `json:"id"`
	AttemptNum  int       `json:"attempt_number"`
	HasFeedback bool      `json:"has_feedback"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// ChatMessage is one turn in the per-question "ask clarifying questions" thread.
type ChatMessage struct {
	ID        string    `json:"id"`
	Role      string    `json:"role"` // "user" | "assistant"
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

// Question is the guidance content a system_design module already carries —
// read from course_modules, not a separate table.
type Question struct {
	ModuleID    string `json:"module_id"`
	Title       string `json:"title"`
	ContentBody string `json:"content_body"`
}

// ─── Request / Response ───────────────────────────────────────────────────────

type SaveSceneRequest struct {
	Scene Scene `json:"scene"`
}

type SendChatMessageRequest struct {
	Content string `json:"content"`
}

type FeedbackResponse struct {
	Feedback   string    `json:"feedback"`
	FeedbackAt time.Time `json:"feedback_at"`
}
