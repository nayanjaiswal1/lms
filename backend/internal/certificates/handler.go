package certificates

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/middleware"
)

type Handler struct {
	service  *Service
	pool     *pgxpool.Pool
	authzSvc *authz.Service // set by RegisterRoutes
}

func newHandler(service *Service, pool *pgxpool.Pool) *Handler {
	return &Handler{service: service, pool: pool}
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

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong.")

// UpsertFinalTest handles PUT /api/courses/{courseID}/final-test
func (h *Handler) UpsertFinalTest(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpsertFinalTestRequest
	if !httputil.DecodeJSON(w, r, &req) {
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

// GetFinalTest handles GET /api/courses/{courseID}/final-test — one resource
// whose fields depend on the caller: instructors+ get the authoring view
// (answers included); anyone else needs content.certificates and gets the
// student view.
func (h *Handler) GetFinalTest(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	if middleware.HasLiveOrgRole(r.Context(), h.pool, claims.UserID, claims.OrgID,
		middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor) {
		ft, err := h.service.GetFinalTestForEdit(r.Context(), claims.OrgID, courseID)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		httputil.WriteJSON(w, http.StatusOK, ft)
		return
	}
	allowed, err := h.authzSvc.HasPermission(r.Context(), claims.UserID, claims.OrgID, PermCertificates)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	if !allowed {
		httputil.WriteError(w, http.StatusForbidden, "You do not have permission to do that.")
		return
	}
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
	if !httputil.DecodeJSON(w, r, &req) {
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

// GetMyCertificateForCourse handles GET /api/courses/{courseID}/certificates/me
// — the caller's own certificate for one course, if any. Scoped to (user,
// course) rather than ListMyCertificates' full-list-then-filter, for callers
// (the course detail page) that only need one course's certificate.
func (h *Handler) GetMyCertificateForCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	cert, err := h.service.GetMyCertificateForCourse(r.Context(), claims.UserID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cert)
}

// VerifyCertificate handles GET /api/certificates/{uuid} — public, no auth.
func (h *Handler) VerifyCertificate(w http.ResponseWriter, r *http.Request) {
	certUUID := chi.URLParam(r, "uuid")
	cert, err := h.service.VerifyCertificate(r.Context(), certUUID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, PublicCertificate{
		CertUUID:    cert.CertUUID,
		CourseTitle: cert.CourseTitle,
		LearnerName: cert.LearnerName,
		IssuedAt:    cert.IssuedAt,
		IssueType:   cert.IssueType,
	})
}

// IssueCertificate handles POST /api/courses/{courseID}/certificates/issue —
// mentor/instructor/admin manual award for a specific student.
func (h *Handler) IssueCertificate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req IssueCertificateRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if req.StudentID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"student_id": "required"})
		return
	}
	courseID := chi.URLParam(r, "courseID")
	// Live-looked-up org role, not claims.OrgRole: a demoted admin's stale
	// JWT would otherwise skip the mentor-assignment check below (see
	// middleware.LiveOrgRole).
	liveRole, _ := middleware.LiveOrgRole(r.Context(), h.pool, claims.UserID, claims.OrgID)
	cert, err := h.service.IssueByMentor(r.Context(), claims.OrgID, claims.UserID, liveRole, req.StudentID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, cert)
}

// ClaimCertificate handles POST /api/courses/{courseID}/certificates — creates
// the caller's own threshold-based certificate if they are eligible.
// Idempotent: returns the existing certificate once issued, null while not
// yet eligible.
func (h *Handler) ClaimCertificate(w http.ResponseWriter, r *http.Request) {
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

// UpsertCertificateThreshold handles PUT /api/courses/{courseID}/certificate-threshold
// — instructor authoring of the threshold-based auto-issue configuration.
func (h *Handler) UpsertCertificateThreshold(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpsertCertificateRuleRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	err := h.service.UpsertCertificateThreshold(r.Context(), claims.OrgID, courseID, &req.ThresholdPercent)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]interface{}{"threshold_percent": req.ThresholdPercent})
}

// GetCertificateThreshold handles GET /api/courses/{courseID}/certificate-threshold —
// instructor authoring read.
func (h *Handler) GetCertificateThreshold(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	threshold, err := h.service.GetCertificateThreshold(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]interface{}{"threshold_percent": threshold})
}
