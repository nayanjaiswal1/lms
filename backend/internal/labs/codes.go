package labs

// Machine-readable error codes in the API error envelope ({"error", "code"}),
// see httputil.WriteErrorCode. Stable snake_case; the frontend mirrors them in
// frontend/lib/labs.ts (LAB_ERROR_CODES) — keep the two in sync.
const (
	CodeSessionExpired             = "lab_session_expired"
	CodeSessionCompletedAtDeadline = "lab_session_completed_at_deadline"
	CodeSessionAlreadyEnded        = "lab_session_already_ended"
	CodeRateLimited                = "rate_limited"
	CodeGraderBusy                 = "grader_busy"
	CodeHintNotSupported           = "hint_not_supported"
	CodeMaxHintsReached            = "max_hints_reached"
	CodeWriteupReviewLimit         = "writeup_review_limit"
	CodeAIUnavailable              = "ai_unavailable"
)
