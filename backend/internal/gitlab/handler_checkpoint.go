package gitlab

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type createCheckpointRequest struct {
	Title          string     `json:"title"`
	Description    *string    `json:"description"`
	Position       int        `json:"position"`
	DueAt          *time.Time `json:"due_at"`
	Weight         *int       `json:"weight"`
	RequiresMR     *bool      `json:"requires_mr"`
	RequiresCIPass *bool      `json:"requires_ci_pass"`
	// Kind defaults to CheckpointKindMilestone (matches migration 022's own
	// column default) when omitted or empty.
	Kind string `json:"kind"`
}

// CreateCheckpoint handles POST /api/projects/assignments/{assignmentID}/checkpoints.
func (h *Handler) CreateCheckpoint(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	assignmentID := chi.URLParam(r, "assignmentID")
	var req createCheckpointRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Title) == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"title": "A title is required."})
		return
	}

	weight := 100
	if req.Weight != nil {
		weight = *req.Weight
	}
	requiresMR := true
	if req.RequiresMR != nil {
		requiresMR = *req.RequiresMR
	}
	requiresCIPass := true
	if req.RequiresCIPass != nil {
		requiresCIPass = *req.RequiresCIPass
	}
	kind := CheckpointKindMilestone
	if req.Kind != "" {
		if !ValidCheckpointKinds[req.Kind] {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"kind": "Not a recognized checkpoint kind."})
			return
		}
		kind = req.Kind
	}

	cp, err := h.service.CreateCheckpoint(r.Context(), claims.OrgID, assignmentID, ProjectCheckpoint{
		Title: req.Title, Description: req.Description, Position: req.Position,
		DueAt: req.DueAt, Weight: weight, RequiresMR: requiresMR, RequiresCIPass: requiresCIPass, Kind: kind,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, cp)
}

// ListCheckpoints handles GET /api/projects/assignments/{assignmentID}/checkpoints.
func (h *Handler) ListCheckpoints(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	list, err := h.service.ListCheckpoints(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, list)
}

// UpdateCheckpoint handles PATCH /api/projects/checkpoints/{checkpointID}.
func (h *Handler) UpdateCheckpoint(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var patch CheckpointPatch
	if !decodeJSON(w, r, &patch) {
		return
	}
	if patch.Kind != nil && !ValidCheckpointKinds[*patch.Kind] {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"kind": "Not a recognized checkpoint kind."})
		return
	}
	cp, err := h.service.UpdateCheckpoint(r.Context(), claims.OrgID, chi.URLParam(r, "checkpointID"), patch)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cp)
}

// DeleteCheckpoint handles DELETE /api/projects/checkpoints/{checkpointID}.
func (h *Handler) DeleteCheckpoint(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteCheckpoint(r.Context(), claims.OrgID, chi.URLParam(r, "checkpointID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Checkpoint deleted."})
}

// ListSubmissions handles GET /api/projects/checkpoints/{checkpointID}/submissions.
func (h *Handler) ListSubmissions(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	list, err := h.service.ListSubmissions(r.Context(), claims.OrgID, chi.URLParam(r, "checkpointID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, list)
}

// GradeSubmission handles PATCH /api/projects/checkpoints/{checkpointID}/submissions/{teamID}/grade.
func (h *Handler) GradeSubmission(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var patch GradePatch
	if !decodeJSON(w, r, &patch) {
		return
	}
	if patch.Score < 0 || patch.Score > 100 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"score": "score must be between 0 and 100."})
		return
	}
	updated, err := h.service.GradeSubmission(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"), chi.URLParam(r, "checkpointID"), claims.UserID, patch)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

// MergeSubmission handles POST /api/projects/checkpoints/{checkpointID}/submissions/{teamID}/merge
// — calls Service.TryMergeCheckpoint, the merge gate that never merges below
// the assignment's required_approvals.
func (h *Handler) MergeSubmission(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	updated, err := h.service.TryMergeCheckpoint(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"), chi.URLParam(r, "checkpointID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

type commentRequest struct {
	Body string `json:"body"`
}

// CommentOnSubmission handles POST /api/projects/checkpoints/{checkpointID}/submissions/{teamID}/comment
// — posts a staff comment directly onto the team's bound merge request.
func (h *Handler) CommentOnSubmission(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req commentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Body) == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"body": "A comment body is required."})
		return
	}
	if err := h.service.PostCheckpointComment(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"), chi.URLParam(r, "checkpointID"), req.Body); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Comment posted."})
}
