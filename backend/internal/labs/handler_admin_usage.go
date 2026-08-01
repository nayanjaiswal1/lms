package labs

import (
	"net/http"
	"strconv"
	"time"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// maxUsageWindowDays / defaultUsageWindowDays / defaultUsageStudentLimit
// bound the ?days= and ?limit= query params on HandleGetLabUsage — an org
// admin can widen the window or the student list, but not to something that
// turns this into an unbounded full-table scan.
const (
	maxUsageWindowDays       = 365
	defaultUsageWindowDays   = 30
	defaultUsageStudentLimit = 50
	maxUsageStudentLimit     = 200
)

// labUsageResponse is the payload for GET /api/admin/labs/usage: the same
// container_seconds usage window sliced three ways — org total (+ per-lab
// breakdown), per-course, and per-student — so an admin can answer "who or
// what is burning compute" at whichever grain the question is actually
// about.
type labUsageResponse struct {
	WindowDays int                  `json:"window_days"`
	Org        *OrgLabUsage         `json:"org"`
	ByCourse   []CourseLabUsageRow  `json:"by_course"`
	ByStudent  []StudentLabUsageRow `json:"by_student"`
}

// HandleGetLabUsage returns org/course/student lab compute usage for the
// caller's org over a trailing window.
//
//	GET /api/admin/labs/usage?days=30&student_limit=50
func (h *Handler) HandleGetLabUsage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	days := defaultUsageWindowDays
	if raw := r.URL.Query().Get("days"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > maxUsageWindowDays {
			httputil.WriteError(w, http.StatusBadRequest, "days must be between 1 and 365.")
			return
		}
		days = parsed
	}
	studentLimit := defaultUsageStudentLimit
	if raw := r.URL.Query().Get("student_limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > maxUsageStudentLimit {
			httputil.WriteError(w, http.StatusBadRequest, "student_limit must be between 1 and 200.")
			return
		}
		studentLimit = parsed
	}
	window := time.Duration(days) * 24 * time.Hour

	org, err := h.repo.GetOrgLabUsage(r.Context(), claims.OrgID, window)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	byCourse, err := h.repo.GetCourseLabUsage(r.Context(), claims.OrgID, window)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	byStudent, err := h.repo.GetStudentLabUsage(r.Context(), claims.OrgID, window, studentLimit)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, labUsageResponse{
		WindowDays: days,
		Org:        org,
		ByCourse:   byCourse,
		ByStudent:  byStudent,
	})
}
