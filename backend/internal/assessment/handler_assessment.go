package assessment

import (
	"net/http"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/httputil"
)

// ─── Assessment CRUD ─────────────────────────────────────────────────────────

type assessmentRequest struct {
	Title            string            `json:"title"`
	Description      *string           `json:"description"`
	MockMode         bool              `json:"mock_mode"`
	ParentType       string            `json:"parent_type"`
	ParentID         *string           `json:"parent_id"`
	DurationMinutes  int               `json:"duration_minutes"`
	PassPercentage   float64           `json:"pass_percentage"`
	MaxAttempts      int               `json:"max_attempts"`
	ShuffleQuestions bool              `json:"shuffle_questions"`
	ShuffleOptions   bool              `json:"shuffle_options"`
	AllowBacktrack   bool              `json:"allow_backtrack"`
	ShowResults      bool              `json:"show_results"`
	StartsAt         *time.Time        `json:"starts_at"`
	EndsAt           *time.Time        `json:"ends_at"`
	Proctoring       *ProctoringConfig `json:"proctoring"`
}

func (req *assessmentRequest) normalise() map[string]string {
	fields := map[string]string{}
	if strings.TrimSpace(req.Title) == "" {
		fields["title"] = "Title is required."
	}
	if req.ParentType == "" {
		req.ParentType = ParentStandalone
	} else if !contains(ValidParentTypes, req.ParentType) {
		fields["parent_type"] = "Invalid parent type."
	}
	if req.ParentType == ParentStandalone {
		req.ParentID = nil
	}
	if req.DurationMinutes <= 0 {
		req.DurationMinutes = 30
	}
	if req.DurationMinutes > 1440 {
		fields["duration_minutes"] = "Duration cannot exceed 24 hours."
	}
	if req.PassPercentage < 0 || req.PassPercentage > 100 {
		fields["pass_percentage"] = "Pass percentage must be between 0 and 100."
	}
	if req.MaxAttempts <= 0 {
		req.MaxAttempts = 1
	}
	if req.EndsAt != nil && req.StartsAt != nil && !req.EndsAt.After(*req.StartsAt) {
		fields["ends_at"] = "End time must be after the start time."
	}
	return fields
}

// proctoringOrDefault overlays the request's proctoring onto the safe default.
func (req *assessmentRequest) proctoringConfig() ProctoringConfig {
	if req.Proctoring == nil {
		return DefaultProctoring()
	}
	return *req.Proctoring
}

func (h *Handler) CreateAssessment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req assessmentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if fields := req.normalise(); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	a := Assessment{
		OrgID:            claims.OrgID,
		Title:            req.Title,
		Slug:             slugify(req.Title),
		Description:      req.Description,
		Type:             AssessmentTypeMCQ,
		MockMode:         req.MockMode,
		ParentType:       req.ParentType,
		ParentID:         req.ParentID,
		DurationMinutes:  req.DurationMinutes,
		PassPercentage:   req.PassPercentage,
		MaxAttempts:      req.MaxAttempts,
		ShuffleQuestions: req.ShuffleQuestions,
		ShuffleOptions:   req.ShuffleOptions,
		AllowBacktrack:   req.AllowBacktrack,
		ShowResults:      req.ShowResults,
		StartsAt:         req.StartsAt,
		EndsAt:           req.EndsAt,
		Proctoring:       req.proctoringConfig(),
		CreatedBy:        claims.UserID,
	}
	created, err := h.repo.CreateAssessment(r.Context(), a)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) UpdateAssessment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req assessmentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if fields := req.normalise(); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	a := Assessment{
		ID:               chiURLParam(r, "assessmentID"),
		Title:            req.Title,
		Description:      req.Description,
		MockMode:         req.MockMode,
		ParentType:       req.ParentType,
		ParentID:         req.ParentID,
		DurationMinutes:  req.DurationMinutes,
		PassPercentage:   req.PassPercentage,
		MaxAttempts:      req.MaxAttempts,
		ShuffleQuestions: req.ShuffleQuestions,
		ShuffleOptions:   req.ShuffleOptions,
		AllowBacktrack:   req.AllowBacktrack,
		ShowResults:      req.ShowResults,
		StartsAt:         req.StartsAt,
		EndsAt:           req.EndsAt,
		Proctoring:       req.proctoringConfig(),
	}
	updated, err := h.repo.UpdateAssessment(r.Context(), claims.OrgID, a)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) ListAssessments(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	filter := AssessmentFilter{
		Status:     q.Get("status"),
		Type:       q.Get("type"),
		ParentType: q.Get("parent_type"),
		ParentID:   q.Get("parent_id"),
		Search:     q.Get("search"),
		Limit:      queryInt(r, "limit", 50),
		Offset:     queryInt(r, "offset", 0),
	}
	items, err := h.repo.ListAssessments(r.Context(), claims.OrgID, filter)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"assessments": items})
}

// GetAssessment returns the full staff view including answer keys (server side).
func (h *Handler) GetAssessment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chiURLParam(r, "assessmentID")
	a, err := h.repo.GetAssessment(r.Context(), claims.OrgID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	questions, err := h.repo.ListAssessmentQuestions(r.Context(), id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"assessment": a, "questions": questions})
}

type addQuestionRequest struct {
	QuestionID string   `json:"question_id"`
	Points     *float64 `json:"points"`
}

func (h *Handler) AddAssessmentQuestion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req addQuestionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.QuestionID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"question_id": "Question is required."})
		return
	}
	aq, err := h.repo.AddQuestion(r.Context(), claims.OrgID, chiURLParam(r, "assessmentID"), req.QuestionID, req.Points)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, aq)
}

func (h *Handler) RemoveAssessmentQuestion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	err := h.repo.RemoveQuestion(r.Context(), claims.OrgID,
		chiURLParam(r, "assessmentID"), chiURLParam(r, "aqID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Question removed."})
}

func (h *Handler) PublishAssessment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	a, err := h.service.Publish(r.Context(), claims.OrgID, chiURLParam(r, "assessmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, a)
}

type statusRequest struct {
	Status string `json:"status"`
}

// SetAssessmentStatus performs lifecycle transitions other than publish
// (active, completed, archived). Draft→published goes through PublishAssessment.
func (h *Handler) SetAssessmentStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req statusRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	allowed := map[string]bool{StatusActive: true, StatusCompleted: true, StatusArchived: true, StatusDraft: true}
	if !allowed[req.Status] {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"status": "Invalid status transition."})
		return
	}
	if err := h.repo.SetStatus(r.Context(), claims.OrgID, chiURLParam(r, "assessmentID"), req.Status, false); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Status updated.", "status": req.Status})
}

// ─── Assignments ─────────────────────────────────────────────────────────────

type assignmentRequest struct {
	AssigneeType string   `json:"assignee_type"`
	AssigneeIDs  []string `json:"assignee_ids"`
	DueAt        *string  `json:"due_at"`
}

func (h *Handler) CreateAssignment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req assignmentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.AssigneeType != AssigneeStudent && req.AssigneeType != AssigneeBatch {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"assignee_type": "Must be 'student' or 'batch'."})
		return
	}
	if len(req.AssigneeIDs) == 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"assignee_ids": "Select at least one assignee."})
		return
	}
	assessmentID := chiURLParam(r, "assessmentID")
	created, err := h.repo.CreateAssignments(r.Context(), claims.OrgID, assessmentID, req.AssigneeType, req.AssigneeIDs, claims.UserID, req.DueAt)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, map[string]any{"assignment_ids": created})
}

func (h *Handler) ListAssignments(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	items, err := h.repo.ListAssignments(r.Context(), claims.OrgID, chiURLParam(r, "assessmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"assignments": items})
}

func (h *Handler) DeleteAssignment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	err := h.repo.DeleteAssignment(r.Context(), claims.OrgID,
		chiURLParam(r, "assessmentID"), chiURLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Assignment removed."})
}

// ─── Batches ─────────────────────────────────────────────────────────────────

type batchRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description"`
	MentorID    *string `json:"mentor_id"`
}

func (h *Handler) CreateBatch(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req batchRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"name": "Name is required."})
		return
	}
	b := Batch{
		OrgID:       claims.OrgID,
		Name:        req.Name,
		Slug:        slugify(req.Name),
		Description: req.Description,
		MentorID:    req.MentorID,
		CreatedBy:   claims.UserID,
	}
	created, err := h.repo.CreateBatch(r.Context(), b)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) ListBatches(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	items, err := h.repo.ListBatches(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"batches": items})
}

func (h *Handler) GetBatch(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chiURLParam(r, "batchID")
	b, err := h.repo.GetBatch(r.Context(), claims.OrgID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	members, err := h.repo.ListBatchMembers(r.Context(), claims.OrgID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"batch": b, "members": members})
}

type batchMembersRequest struct {
	UserIDs []string `json:"user_ids"`
}

func (h *Handler) AddBatchMembers(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req batchMembersRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.UserIDs) == 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"user_ids": "Select at least one user."})
		return
	}
	if err := h.repo.AddBatchMembers(r.Context(), claims.OrgID, chiURLParam(r, "batchID"), req.UserIDs); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Members added."})
}

func (h *Handler) RemoveBatchMember(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	err := h.repo.RemoveBatchMember(r.Context(), claims.OrgID,
		chiURLParam(r, "batchID"), chiURLParam(r, "userID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Member removed."})
}
