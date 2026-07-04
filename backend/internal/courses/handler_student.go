package courses

import (
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// clientCompletableModuleTypes are module types whose "completed" status may
// be set directly by the student's client. Lab and assessment modules are
// deliberately excluded — those only complete via server-verified events
// (lab.Service.VerifyTask, assessment.Service.Submit) that call
// Service.CompleteModule themselves, so a client can never PATCH its way to
// finishing a lab or assessment without actually doing it.
var clientCompletableModuleTypes = map[string]bool{
	ModuleTypeVideo: true,
	ModuleTypePDF:   true,
	ModuleTypeNotes: true,
}

// GetModuleContent serves module content to enrolled students (or free-preview viewers).
func (h *Handler) GetModuleContent(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	mc, err := h.service.GetModuleContent(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "moduleID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, mc)
}

// Enroll enrolls the authenticated student in a free course.
func (h *Handler) Enroll(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	courseID := urlParam(r, "courseID")
	course, err := h.repo.GetCourse(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if !course.IsFree {
		httputil.WriteError(w, http.StatusPaymentRequired, "This course requires payment.")
		return
	}
	userID := claims.UserID
	e := Enrollment{UserID: userID, CourseID: courseID, EnrolledBy: &userID}
	created, err := h.repo.CreateEnrollment(r.Context(), e)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

// Purchase charges the authenticated student for a paid course via the
// mentoring package's charge -> purchase -> enrollment -> mentor-ticket flow,
// then returns the resulting purchase (and mentor ticket, if one was opened).
// Free courses must go through Enroll instead — that endpoint stays
// 402-blocked for paid courses, and this one is 400-blocked for free
// courses, so each course only ever has one valid path to access.
func (h *Handler) Purchase(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	courseID := urlParam(r, "courseID")
	course, err := h.repo.GetCourse(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if course.IsFree || course.PriceCents <= 0 {
		httputil.WriteError(w, http.StatusBadRequest, "This course is free — use /enroll instead.")
		return
	}
	purchase, enrollment, ticket, err := h.mentorTickets.PurchaseCourse(r.Context(), claims.OrgID, claims.UserID, courseID, course.PriceCents)
	if err != nil {
		var ce conflictError
		if errors.As(err, &ce) && ce.IsConflict() {
			httputil.WriteError(w, http.StatusConflict, "You have already purchased this course.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Purchase failed.")
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, map[string]any{"purchase": purchase, "enrollment": enrollment, "ticket": ticket})
}

// MyEnrollments returns all courses the authenticated student is enrolled in.
func (h *Handler) MyEnrollments(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	enrollments, err := h.repo.GetMyEnrollments(r.Context(), claims.UserID, claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"enrollments": enrollments})
}

// UpdateProgress updates module progress for the authenticated student.
// When a video/pdf/notes module is marked completed, XP is awarded and streak
// is updated; if that finishes the entire course, course-completion XP fires
// too. Lab and assessment modules reject a client-submitted "completed" status
// — those only complete through server-verified events (see
// clientCompletableModuleTypes).
func (h *Handler) UpdateProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Status              string `json:"status"`
		LastPositionSeconds int    `json:"last_position_seconds"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	validStatuses := map[string]bool{ProgressNotStarted: true, ProgressInProgress: true, ProgressCompleted: true}
	if !validStatuses[req.Status] {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"status": "Invalid status."})
		return
	}
	moduleID := urlParam(r, "moduleID")
	m, err := h.repo.GetModule(r.Context(), claims.OrgID, moduleID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	if req.Status == ProgressCompleted {
		if !clientCompletableModuleTypes[m.Type] {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
				"status": "This module completes automatically once you finish it.",
			})
			return
		}
		updated, rewardResult, err := h.service.CompleteModule(r.Context(), claims.UserID, claims.OrgID, moduleID, m.CourseID)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		httputil.WriteJSON(w, http.StatusOK, map[string]any{"progress": updated, "rewards": rewardResult})
		return
	}

	updated, err := h.repo.UpsertProgress(r.Context(), ModuleProgress{
		UserID:              claims.UserID,
		ModuleID:            moduleID,
		CourseID:            m.CourseID,
		Status:              req.Status,
		LastPositionSeconds: req.LastPositionSeconds,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"progress": updated})
}

// GetMyProgress returns the authenticated student's aggregate and per-module
// progress in a course.
func (h *Handler) GetMyProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	courseID := urlParam(r, "courseID")
	cp, err := h.repo.GetCourseProgress(r.Context(), claims.UserID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	modules, err := h.repo.GetModuleProgressForCourse(r.Context(), claims.UserID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, CourseProgressSummary{
		Completed: cp.Completed,
		Total:     cp.Total,
		Pct:       cp.Pct,
		Modules:   modules,
	})
}

// GetAllProgress returns all student progress for a course (instructor/mentor view).
func (h *Handler) GetAllProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	rows, err := h.repo.GetAllStudentProgress(r.Context(), claims.OrgID, urlParam(r, "courseID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"progress": rows})
}
