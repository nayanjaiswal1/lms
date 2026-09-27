package workspace

import "time"

// models_phase1.go holds the DTOs the contract assigns to the backend agent
// (docs/project-workspace-plan/contract-phase1.md) — a neighbour of the
// lead's models.go, not a replacement for it.

// RequirementView is GET/PUT .../requirement's payload.
type RequirementView struct {
	Requirement        string               `json:"requirement"`
	RequirementVersion int                  `json:"requirement_version"`
	BriefStatus        string               `json:"brief_status"`
	Versions           []RequirementVersion `json:"versions"`
}

// FieldError carries per-field validation messages; the handler writes it as
// a 422 via httputil.WriteFieldErrors. It unwraps to ErrInvalidInput so a
// generic `errors.Is(err, ErrInvalidInput)` check still matches it.
type FieldError struct{ Fields map[string]string }

func (e *FieldError) Error() string { return "validation failed" }
func (e *FieldError) Unwrap() error { return ErrInvalidInput }

// RateLimitError carries the wait the caller should advertise via a
// Retry-After header. It unwraps to ErrRateLimited so a plain
// errors.Is(err, ErrRateLimited) check still matches it.
type RateLimitError struct{ RetryAfter time.Duration }

func (e *RateLimitError) Error() string { return "rate limited" }
func (e *RateLimitError) Unwrap() error { return ErrRateLimited }
