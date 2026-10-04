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
	CodeNotFound = "lab_not_found"
	CodeForbidden = "lab_forbidden"
	CodeSessionActive = "lab_session_active"
	CodeCapacityReached = "lab_capacity_reached"
	CodeUserHasActiveSession = "lab_other_session_active"
	CodeSessionNotRunning = "lab_session_not_running"
	CodeNoRunScript = "lab_no_run_script"
	CodeLabNotPublished = "lab_not_published"
	CodeMaxResetsReached = "max_resets_reached"
	CodeTaskNotOptional = "task_not_optional"
	CodeExecutorUnavailable = "executor_unavailable"
	CodeInvalidPath = "invalid_path"
	CodeImageNotAllowed = "lab_image_not_allowed"
	CodeProvisioningUnstable = "lab_provisioning_unstable"
	CodeResetFailed = "lab_reset_failed"
	CodeLabTypeUnsupported = "lab_type_unsupported"
	CodeContentTooLarge = "content_too_large"
	CodeKindLabNotBuilt = "lab_not_built"
	CodeBundleStoreUnavailable = "bundle_store_unavailable"
	CodeNoDebrief = "debrief_unavailable"
)
