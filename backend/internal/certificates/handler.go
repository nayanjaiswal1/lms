package certificates

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:            {Status: http.StatusNotFound, Message: "Not found."},
	ErrCourseNotFound:      {Status: http.StatusNotFound, Message: "Not found."},
	ErrNoFinalTest:         {Status: http.StatusNotFound, Message: "Not found."},
	ErrNotEnrolled:         {Status: http.StatusForbidden, Message: "You are not enrolled in this course."},
	ErrNotAssignedMentor:   {Status: http.StatusForbidden, Message: "You are not this student's assigned mentor."},
	ErrCourseNotComplete:   {Status: http.StatusUnprocessableEntity, Message: "Complete every module in this course before taking the final test."},
	ErrAttemptsExhausted:   {Status: http.StatusUnprocessableEntity, Message: "You have used all of your attempts for this final test."},
	ErrInvalidQuestions:    {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"questions": "must have at least one question"}},
	ErrInvalidTimeLimit:    {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"time_limit_minutes": "must be positive"}},
	ErrInvalidPassingScore: {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"passing_score_percent": "must be between 1 and 100"}},
	ErrInvalidMaxAttempts:  {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"max_attempts": "must be positive"}},
	ErrInvalidThreshold:    {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"threshold_percent": "must be between 1 and 100"}},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

// UpsertFinalTest handles PUT /api/courses/{courseID}/final-test
func (h *Handler) UpsertFinalTest(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpsertFinalTestRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	ft, err := h.service.UpsertFinalTest(r.Context(), claims.OrgID, courseID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ft)
}

// GetFinalTestForEdit handles GET /api/courses/{courseID}/final-test/edit
func (h *Handler) GetFinalTestForEdit(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	ft, err := h.service.GetFinalTestForEdit(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ft)
}

// GetFinalTestForStudent handles GET /api/courses/{courseID}/final-test
func (h *Handler) GetFinalTestForStudent(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	ft, err := h.service.GetFinalTestForStudent(r.Context(), claims.UserID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ft)
}

// SubmitAttempt handles POST /api/courses/{courseID}/final-test/attempt
func (h *Handler) SubmitAttempt(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req SubmitAttemptRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	resp, err := h.service.SubmitAttempt(r.Context(), claims.OrgID, claims.UserID, courseID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, resp)
}

// ListMyCertificates handles GET /api/certificates/me
func (h *Handler) ListMyCertificates(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	certs, err := h.service.ListMyCertificates(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, certs)
}

// VerifyCertificate handles GET /api/certificates/{uuid} — public, no auth.
func (h *Handler) VerifyCertificate(w http.ResponseWriter, r *http.Request) {
	certUUID := chi.URLParam(r, "uuid")
	cert, err := h.service.VerifyCertificate(r.Context(), certUUID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cert)
}

// IssueCertificate handles POST /api/courses/{courseID}/certificates/issue —
// mentor/instructor/admin manual award for a specific student.
func (h *Handler) IssueCertificate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req IssueCertificateRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.StudentID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"student_id": "required"})
		return
	}
	courseID := chi.URLParam(r, "courseID")
	cert, err := h.service.IssueByMentor(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, req.StudentID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, cert)
}

// CheckThresholdCertificate handles POST
// /api/courses/{courseID}/certificates/check-threshold — evaluates and, if
// eligible, issues the caller's own threshold-based certificate. Called by
// the course page on every load; idempotent no-op once issued.
func (h *Handler) CheckThresholdCertificate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	cert, err := h.service.CheckThresholdIssue(r.Context(), claims.OrgID, claims.UserID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cert)
}

// UpsertCertificateRule handles PUT /api/courses/{courseID}/certificate-rule
// — instructor authoring of the threshold-based auto-issue rule.
func (h *Handler) UpsertCertificateRule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpsertCertificateRuleRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	rule, err := h.service.UpsertCertificateRule(r.Context(), claims.OrgID, courseID, req.ThresholdPercent)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rule)
}

// GetCertificateRule handles GET /api/courses/{courseID}/certificate-rule —
// instructor authoring read.
func (h *Handler) GetCertificateRule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	rule, err := h.service.GetCertificateRule(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rule)
}
