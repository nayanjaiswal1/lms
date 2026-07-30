package gitlab

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
)

type createAssignmentRequest struct {
	BatchID              string     `json:"batch_id"`
	CourseID             *string    `json:"course_id"`
	LabID                *string    `json:"lab_id"`
	Title                string     `json:"title"`
	Slug                 string     `json:"slug"`
	Description          *string    `json:"description"`
	TemplateProjectID    *int64     `json:"template_project_id"`
	TemplateProjectPath  *string    `json:"template_project_path"`
	// InstallationID pins this assignment to one of the org's GitLab pool
	// entries instead of following the org default — rejected by the service
	// (ErrOverrideNotAllowed, surfaced as 403) unless the org's
	// gitlab_org_config.allow_project_override is true.
	InstallationID       *string    `json:"installation_id"`
	Visibility           string     `json:"visibility"`
	RequiredApprovals    *int       `json:"required_approvals"`
	ProtectDefaultBranch *bool      `json:"protect_default_branch"`
	DefaultBranch        *string    `json:"default_branch"`
	StartsAt             *time.Time `json:"starts_at"`
	DueAt                *time.Time `json:"due_at"`
}

// CreateAssignment handles POST /api/projects/assignments.
func (h *Handler) CreateAssignment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req createAssignmentRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	if req.Visibility == "" {
		req.Visibility = VisibilityPrivate
	}

	fields := map[string]string{}
	if strings.TrimSpace(req.BatchID) == "" {
		fields["batch_id"] = "A batch is required."
	}
	if strings.TrimSpace(req.Title) == "" {
		fields["title"] = "A title is required."
	}
	if strings.TrimSpace(req.Slug) == "" {
		fields["slug"] = "A slug is required."
	}
	if req.Visibility != VisibilityPrivate && req.Visibility != VisibilityInternal {
		fields["visibility"] = "visibility must be 'private' or 'internal'."
	}
	if req.TemplateProjectID == nil && (req.TemplateProjectPath == nil || strings.TrimSpace(*req.TemplateProjectPath) == "") {
		fields["template_project_path"] = "A template project ID or path is required."
	}
	if req.DueAt != nil && req.StartsAt != nil && !req.DueAt.After(*req.StartsAt) {
		fields["due_at"] = "due_at must be after starts_at."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	requiredApprovals := 1
	if req.RequiredApprovals != nil {
		requiredApprovals = *req.RequiredApprovals
	}
	protectDefault := true
	if req.ProtectDefaultBranch != nil {
		protectDefault = *req.ProtectDefaultBranch
	}
	defaultBranch := "main"
	if req.DefaultBranch != nil && strings.TrimSpace(*req.DefaultBranch) != "" {
		defaultBranch = *req.DefaultBranch
	}

	assignment, err := h.service.CreateAssignment(r.Context(), claims.OrgID, claims.UserID, ProjectAssignment{
		BatchID:              req.BatchID,
		CourseID:             req.CourseID,
		LabID:                req.LabID,
		Title:                req.Title,
		Slug:                 req.Slug,
		Description:          req.Description,
		TemplateProjectID:    req.TemplateProjectID,
		TemplateProjectPath:  req.TemplateProjectPath,
		InstallationID:       req.InstallationID,
		Visibility:           req.Visibility,
		RequiredApprovals:    requiredApprovals,
		ProtectDefaultBranch: protectDefault,
		DefaultBranch:        defaultBranch,
		StartsAt:             req.StartsAt,
		DueAt:                req.DueAt,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, assignment)
}

// ListAssignments handles GET /api/projects/assignments?batch_id=...
func (h *Handler) ListAssignments(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var batchID *string
	if v := r.URL.Query().Get("batch_id"); v != "" {
		batchID = &v
	}
	assignments, err := h.service.ListAssignments(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, assignments)
}

// GetAssignment handles GET /api/projects/assignments/{assignmentID}.
func (h *Handler) GetAssignment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	assignment, err := h.service.GetAssignment(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, assignment)
}

// UpdateAssignment handles PATCH /api/projects/assignments/{assignmentID}.
func (h *Handler) UpdateAssignment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	assignmentID := chi.URLParam(r, "assignmentID")
	var patch AssignmentPatch
	if !decodeJSON(w, r, &patch) {
		return
	}
	if patch.Visibility != nil && *patch.Visibility != VisibilityPrivate && *patch.Visibility != VisibilityInternal {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"visibility": "visibility must be 'private' or 'internal'."})
		return
	}
	assignment, err := h.service.UpdateAssignment(r.Context(), claims.OrgID, assignmentID, patch)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, assignment)
}

type setAssignmentInstallationRequest struct {
	InstallationID *string `json:"installation_id"`
}

// SetAssignmentInstallation handles PUT /api/projects/assignments/{assignmentID}/installation —
// pins (installation_id set) or clears (installation_id omitted/null,
// reverting to the org default) which GitLab pool entry this assignment's
// teams provision against. A dedicated action rather than a field on the
// generic PATCH above — see ProjectAssignment.InstallationID's own doc
// comment for why.
func (h *Handler) SetAssignmentInstallation(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req setAssignmentInstallationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	assignment, err := h.service.SetAssignmentInstallation(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"), req.InstallationID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, assignment)
}

// DeleteAssignment handles DELETE /api/projects/assignments/{assignmentID}.
// Only draft assignments can be deleted this way — see Repo.DeleteAssignment's
// own doc comment for why a published one returns 409 instead.
func (h *Handler) DeleteAssignment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteAssignment(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Assignment deleted."})
}

// PublishAssignment handles POST /api/projects/assignments/{assignmentID}/publish
// — transitions draft -> active and kicks off real GitLab provisioning for
// every team already created under it.
func (h *Handler) PublishAssignment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	assignment, err := h.service.PublishAssignment(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, assignment)
}

// TemplateSync handles POST /api/projects/assignments/{assignmentID}/template-sync
// — instructor-triggered (Batch 6), opens a cross-fork merge request from
// the template's default branch into every ready team's fork.
func (h *Handler) TemplateSync(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.RequestTemplateSync(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, map[string]string{"message": "Template sync started."})
}
