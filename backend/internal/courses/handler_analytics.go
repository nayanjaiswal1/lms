package courses

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

const (
	defaultQuestionsLimit = 10
	defaultStudentsLimit  = 25
	defaultCoursesLimit   = 20
)

// boundedInt reads an integer query param. Absent or empty yields def; a
// present value that is not an integer in [min,max] records a field error and
// yields def so the caller can keep validating the remaining params.
func boundedInt(r *http.Request, key string, def, min, max int, errs map[string]string) int {
	raw := httputil.QueryStr(r, key)
	if raw == "" {
		return def
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < min || n > max {
		errs[key] = fmt.Sprintf("%s must be an integer between %d and %d.", key, min, max)
		return def
	}
	return n
}

// analyticsCourseID returns the {courseID} path param, or writes a 404 when it
// is not a UUID (indistinguishable from a course in another org).
func analyticsCourseID(w http.ResponseWriter, r *http.Request) (string, bool) {
	id := httputil.URLParam(r, "courseID")
	if _, err := uuid.Parse(id); err != nil {
		writeDomainError(w, ErrNotFound)
		return "", false
	}
	return id, true
}

// rejectInvalid writes a 422 when any query param failed validation.
func rejectInvalid(w http.ResponseWriter, errs map[string]string) bool {
	if len(errs) == 0 {
		return false
	}
	httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, errs)
	return true
}

// CourseAnalytics returns the funnel, per-lesson stats and enrollment trend for one course.
func (h *Handler) CourseAnalytics(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID, ok := analyticsCourseID(w, r)
	if !ok {
		return
	}
	errs := map[string]string{}
	days := boundedInt(r, "days", defaultTrendDays, minTrendDays, maxTrendDays, errs)
	if rejectInvalid(w, errs) {
		return
	}
	ctx := r.Context()
	funnel, err := h.repo.CourseFunnel(ctx, claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	lessons, err := h.repo.LessonStats(ctx, claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	trend, err := h.repo.EnrollmentTrend(ctx, claims.OrgID, &courseID, days)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"course_id":    courseID,
		"generated_at": time.Now().UTC(),
		"funnel":       funnel,
		"lessons":      lessons,
		"trend":        trend,
	})
}

// CourseHardQuestions returns the course's lowest-scoring quiz questions.
func (h *Handler) CourseHardQuestions(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID, ok := analyticsCourseID(w, r)
	if !ok {
		return
	}
	errs := map[string]string{}
	limit := boundedInt(r, "limit", defaultQuestionsLimit, 1, maxAnalyticsLimit, errs)
	offset := boundedInt(r, "offset", 0, 0, maxOffset, errs)
	minAnswers := boundedInt(r, "min_answers", defaultMinAnswers, 1, maxMinAnswers, errs)
	if rejectInvalid(w, errs) {
		return
	}
	qs, total, err := h.repo.HardestQuestions(r.Context(), claims.OrgID, courseID, minAnswers, limit, offset)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"questions": qs, "total": total, "limit": limit, "offset": offset})
}

// CourseStudentRisk lists a course's students, at-risk by default.
func (h *Handler) CourseStudentRisk(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID, ok := analyticsCourseID(w, r)
	if !ok {
		return
	}
	errs := map[string]string{}
	f := StudentFilter{Risk: httputil.QueryStrDef(r, "risk", RiskFilterAtRisk)}
	if f.Risk != RiskFilterAtRisk && f.Risk != RiskFilterAll {
		errs["risk"] = fmt.Sprintf("risk must be %q or %q.", RiskFilterAtRisk, RiskFilterAll)
	}
	f.InactiveDays = boundedInt(r, "inactive_days", defaultInactiveDays, 1, maxInactiveDays, errs)
	f.MaxProgressPct = boundedInt(r, "max_progress_pct", defaultMaxProgressPct, 0, 100, errs)
	f.Limit = boundedInt(r, "limit", defaultStudentsLimit, 1, maxAnalyticsLimit, errs)
	f.Offset = boundedInt(r, "offset", 0, 0, maxOffset, errs)
	if rejectInvalid(w, errs) {
		return
	}
	students, total, err := h.repo.CourseStudents(r.Context(), claims.OrgID, courseID, f)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"students": students, "total": total, "limit": f.Limit, "offset": f.Offset})
}

// OrgCourseAnalytics returns one summary row per course in the caller's org.
func (h *Handler) OrgCourseAnalytics(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	errs := map[string]string{}
	limit := boundedInt(r, "limit", defaultCoursesLimit, 1, maxAnalyticsLimit, errs)
	offset := boundedInt(r, "offset", 0, 0, maxOffset, errs)
	if rejectInvalid(w, errs) {
		return
	}
	cs, total, err := h.repo.CourseSummaries(r.Context(), claims.OrgID, limit, offset)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"courses": cs, "total": total, "limit": limit, "offset": offset})
}

// OrgEnrollmentTrend returns org-wide daily enrollments.
func (h *Handler) OrgEnrollmentTrend(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	errs := map[string]string{}
	days := boundedInt(r, "days", defaultTrendDays, minTrendDays, maxTrendDays, errs)
	if rejectInvalid(w, errs) {
		return
	}
	points, err := h.repo.EnrollmentTrend(r.Context(), claims.OrgID, nil, days)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"points": points})
}
