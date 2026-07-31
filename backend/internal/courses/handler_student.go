package courses

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/payments"
)

// clientCompletableModuleTypes are module types whose "completed" status may
// be set directly by the student's client. Lab and assessment modules are
// deliberately excluded — those only complete via server-verified events
// (lab.Service.VerifyTask, assessment.Service.Submit) that call
// Service.CompleteModule themselves, so a client can never PATCH its way to
// finishing a lab or assessment without actually doing it.
var clientCompletableModuleTypes = map[string]bool{
	ModuleTypeVideo:        true,
	ModuleTypePDF:          true,
	ModuleTypeNotes:        true,
	ModuleTypeSystemDesign: true,
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

// StartCheckout begins a paid-course purchase: validates the course and any
// coupon code, opens a checkout with the requested (or default) payments
// provider, and returns what the frontend needs to send the student to
// finish paying. It does NOT grant access — only a webhook-confirmed
// purchase (see PurchaseStatus) does, since a real gateway confirms
// asynchronously and the request/response here only starts that process.
// Free courses must go through Enroll instead — that endpoint stays
// 402-blocked for paid courses, and this one is 400-blocked for free
// courses, so each course only ever has one valid path to access.
func (h *Handler) StartCheckout(w http.ResponseWriter, r *http.Request) {
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
	var req struct {
		Provider   string `json:"provider"`
		CouponCode string `json:"coupon_code"`
	}
	if r.ContentLength != 0 && !decodeJSON(w, r, &req) {
		return
	}

	session, err := h.purchaser.StartCheckout(r.Context(), CheckoutRequest{
		OrgID: claims.OrgID, UserID: claims.UserID, CourseID: courseID,
		Provider: req.Provider, CouponCode: req.CouponCode,
	})
	if err != nil {
		var ce conflictError
		if errors.As(err, &ce) && ce.IsConflict() {
			httputil.WriteError(w, http.StatusConflict, "You have already purchased this course.")
			return
		}
		if errors.Is(err, payments.ErrUnknownProvider) {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Unknown payment provider.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Could not start checkout.")
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, session)
}

// PurchaseStatus is polled by the frontend's checkout return page after a
// gateway redirect (or Checkout.js modal close) — the redirect itself never
// grants access, only a webhook-confirmed "completed" status does, which may
// arrive slightly after the redirect.
func (h *Handler) PurchaseStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	status, err := h.purchaser.PurchaseStatus(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "courseID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, status)
}

// PreviewCoupon validates a coupon code against a paid course and returns the
// discount it would apply — advisory only, re-validated and recomputed
// server-side again at webhook confirmation, so a client can never trust
// (or forge) the discount shown here into a lower actual charge.
func (h *Handler) PreviewCoupon(w http.ResponseWriter, r *http.Request) {
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
		httputil.WriteError(w, http.StatusBadRequest, "This course is free — no coupon needed.")
		return
	}
	var req struct {
		Code string `json:"code"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	preview, err := h.coupons.Preview(r.Context(), claims.OrgID, claims.UserID, courseID, req.Code, course.PriceCents)
	if err != nil {
		switch {
		case errors.Is(err, coupons.ErrNotFound):
			httputil.WriteError(w, http.StatusNotFound, "Invalid coupon code.")
		case errors.Is(err, coupons.ErrExpired):
			httputil.WriteError(w, http.StatusUnprocessableEntity, "This coupon is expired or not yet active.")
		case errors.Is(err, coupons.ErrExhausted):
			httputil.WriteError(w, http.StatusUnprocessableEntity, "This coupon has reached its redemption limit.")
		case errors.Is(err, coupons.ErrAlreadyUsed):
			httputil.WriteError(w, http.StatusUnprocessableEntity, "You've already used this coupon.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Could not apply coupon.")
		}
		return
	}
	httputil.WriteJSON(w, http.StatusOK, preview)
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
		// A notes module authored with an embedded ```knowledge-check block
		// (see contentpipeline/generator/render_lesson.go) can't be marked
		// complete until every required question has a recorded correct
		// attempt — checked server-side (not just the UI button's disabled
		// state) so a direct API call can't skip the questions, same
		// rationale as the clientCompletableModuleTypes check above.
		if len(m.KnowledgeCheck) > 0 {
			passed, err := h.repo.GetPassedQuestionIDs(r.Context(), claims.UserID, moduleID)
			if err != nil {
				writeDomainError(w, err)
				return
			}
			passedSet := make(map[string]bool, len(passed))
			for _, id := range passed {
				passedSet[id] = true
			}
			for _, q := range m.KnowledgeCheck {
				if !passedSet[q.ID] {
					httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
						"status": "Answer the knowledge check correctly first.",
					})
					return
				}
			}
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

// RecordCheckAttempt records one submit of an embedded lesson knowledge-check
// question (right or wrong — every attempt is kept for future analytics).
// MCQ answers are graded here, server-side, against the module's stored
// answer key, so a client can't fake a pass. "sql" questions have no
// server-side executor (see backend/internal/assessment/executor.go, which
// has no "sql" language entry either) — ClientCorrect is trusted only for
// that type, the same trust level the pre-existing sql-challenge lesson
// segment already ships for SQL grading.
func (h *Handler) RecordCheckAttempt(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		QuestionID    string          `json:"question_id"`
		Answer        json.RawMessage `json:"answer"`
		ClientCorrect bool            `json:"client_correct"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	moduleID := urlParam(r, "moduleID")
	m, err := h.repo.GetModule(r.Context(), claims.OrgID, moduleID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	var spec *KnowledgeCheckQuestion
	for i := range m.KnowledgeCheck {
		if m.KnowledgeCheck[i].ID == req.QuestionID {
			spec = &m.KnowledgeCheck[i]
			break
		}
	}
	if spec == nil {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"question_id": "Unknown knowledge-check question."})
		return
	}

	var isCorrect bool
	switch spec.Type {
	case "mcq":
		var a struct {
			Selected string `json:"selected"`
		}
		if err := json.Unmarshal(req.Answer, &a); err != nil {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"answer": "Invalid answer."})
			return
		}
		isCorrect = a.Selected != "" && a.Selected == spec.Correct
	case "sql":
		isCorrect = req.ClientCorrect
	default:
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"question_type": "Unsupported question type."})
		return
	}

	attempt, err := h.repo.InsertCheckAttempt(r.Context(), LessonCheckAttempt{
		OrgID:        claims.OrgID,
		UserID:       claims.UserID,
		ModuleID:     moduleID,
		QuestionID:   req.QuestionID,
		QuestionType: spec.Type,
		Answer:       req.Answer,
		IsCorrect:    isCorrect,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, attempt)
}

// GetMyCheckProgress returns the knowledge-check question IDs the
// authenticated student has ever answered correctly for a module — used to
// seed the frontend's Mark-Complete gate on page load without re-asking
// already-passed questions.
func (h *Handler) GetMyCheckProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	ids, err := h.repo.GetPassedQuestionIDs(r.Context(), claims.UserID, urlParam(r, "moduleID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"passed_question_ids": ids})
}

// GetRandomTopic serves the "surprise me" discovery card — one published
// course from the student's org catalog they haven't tried yet, weighted
// toward their stated topic interests when possible.
func (h *Handler) GetRandomTopic(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	topic, err := h.service.GetRandomTopic(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, topic)
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
