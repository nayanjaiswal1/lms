package gitlab

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type createTaskRequest struct {
	Title        string     `json:"title"`
	Description  *string    `json:"description"`
	CheckpointID *string    `json:"checkpoint_id"`
	DueAt        *time.Time `json:"due_at"`
}

func validateCreateTaskRequest(req createTaskRequest) map[string]string {
	fields := map[string]string{}
	if strings.TrimSpace(req.Title) == "" {
		fields["title"] = "A title is required."
	} else if len(req.Title) > maxTitleLen {
		fields["title"] = fmt.Sprintf("Title must be %d characters or fewer.", maxTitleLen)
	}
	if req.Description != nil && len(*req.Description) > maxDescriptionLen {
		fields["description"] = fmt.Sprintf("Description must be %d characters or fewer.", maxDescriptionLen)
	}
	return fields
}

// CreateTask handles POST /api/projects/teams/{teamID}/tasks.
func (h *Handler) CreateTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req createTaskRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if fields := validateCreateTaskRequest(req); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	task, err := h.service.CreateTask(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "teamID"), req.Title, req.Description, req.CheckpointID, req.DueAt)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, task)
}

// ListTasksForTeam handles GET /api/projects/teams/{teamID}/tasks.
func (h *Handler) ListTasksForTeam(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	tasks, err := h.service.ListTasksForTeam(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tasks)
}

// UpdateTask handles PATCH /api/projects/tasks/{taskID}.
func (h *Handler) UpdateTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var patch TaskPatch
	if !decodeJSON(w, r, &patch) {
		return
	}
	fields := map[string]string{}
	if patch.Status != nil && !validTaskStatuses[*patch.Status] {
		fields["status"] = "Not a recognized task status."
	}
	if patch.Title != nil {
		if strings.TrimSpace(*patch.Title) == "" {
			fields["title"] = "A title is required."
		} else if len(*patch.Title) > maxTitleLen {
			fields["title"] = fmt.Sprintf("Title must be %d characters or fewer.", maxTitleLen)
		}
	}
	if patch.Description != nil && len(*patch.Description) > maxDescriptionLen {
		fields["description"] = fmt.Sprintf("Description must be %d characters or fewer.", maxDescriptionLen)
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	task, err := h.service.UpdateTask(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "taskID"), patch)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, task)
}

type setTaskAssigneeRequest struct {
	AssigneeUserID *string `json:"assignee_user_id"`
}

// SetTaskAssignee handles PUT /api/projects/tasks/{taskID}/assignee.
func (h *Handler) SetTaskAssignee(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req setTaskAssigneeRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	task, err := h.service.SetTaskAssignee(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "taskID"), req.AssigneeUserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, task)
}

// DeleteTask handles DELETE /api/projects/tasks/{taskID}.
func (h *Handler) DeleteTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteTask(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "taskID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Task deleted."})
}
