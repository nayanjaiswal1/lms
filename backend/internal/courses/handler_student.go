package courses

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/rewards"
)

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
// When a module is marked completed, XP is awarded and streak is updated.
// When that completion finishes the entire course, course-completion XP fires too.
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
	p := ModuleProgress{
		UserID:              claims.UserID,
		ModuleID:            moduleID,
		CourseID:            m.CourseID,
		Status:              req.Status,
		LastPositionSeconds: req.LastPositionSeconds,
	}
	if req.Status == ProgressCompleted {
		now := time.Now()
		p.CompletedAt = &now
	}
	updated, err := h.repo.UpsertProgress(r.Context(), p)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	// Award XP on module completion (non-fatal).
	var rewardResult *rewards.AwardResult
	if req.Status == ProgressCompleted && h.rewardsSvc != nil {
		courseID := m.CourseID
		refType := "module"
		moduleResult := h.rewardsSvc.AwardXP(r.Context(), rewards.AwardXPRequest{
			UserID:   claims.UserID,
			OrgID:    claims.OrgID,
			CourseID: &courseID,
			Reason:   "module_completed",
			RefID:    &moduleID,
			RefType:  &refType,
			XP:       rewards.XPModuleCompleted,
		})
		rewardResult = &moduleResult

		// Streak update after any learning activity.
		streakResult := h.rewardsSvc.UpdateStreakAndCheckMilestones(r.Context(), claims.UserID, claims.OrgID)
		rewardResult.XPGained += streakResult.XPGained
		rewardResult.NewAchievements = append(rewardResult.NewAchievements, streakResult.NewAchievements...)
		if streakResult.NewLevel != nil {
			rewardResult.NewLevel = streakResult.NewLevel
		}

		// Course completion check: if every module is now done, award course XP.
		cp, cpErr := h.repo.GetCourseProgress(r.Context(), claims.UserID, courseID)
		if cpErr != nil {
			slog.Error("courses: check completion for rewards", "course", courseID, "err", cpErr)
		} else if cp.Total > 0 && cp.Completed == cp.Total {
			refTypeCourse := "course"
			courseResult := h.rewardsSvc.AwardXP(r.Context(), rewards.AwardXPRequest{
				UserID:   claims.UserID,
				OrgID:    claims.OrgID,
				CourseID: &courseID,
				Reason:   "course_completed",
				RefID:    &courseID,
				RefType:  &refTypeCourse,
				XP:       rewards.XPCourseCompleted,
			})
			rewardResult.XPGained += courseResult.XPGained
			rewardResult.NewAchievements = append(rewardResult.NewAchievements, courseResult.NewAchievements...)
			if courseResult.NewLevel != nil {
				rewardResult.NewLevel = courseResult.NewLevel
			}
		}
	}

	resp := map[string]any{"progress": updated}
	if rewardResult != nil {
		if raw, err := json.Marshal(rewardResult); err == nil {
			resp["rewards"] = json.RawMessage(raw)
		}
	}
	httputil.WriteJSON(w, http.StatusOK, resp)
}

// GetMyProgress returns the authenticated student's progress in a course.
func (h *Handler) GetMyProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	cp, err := h.repo.GetCourseProgress(r.Context(), claims.UserID, urlParam(r, "courseID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cp)
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
