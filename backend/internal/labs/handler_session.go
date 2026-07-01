package labs

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ─── Student-safe view types ─────────────────────────────────────────────────

// studentTaskView strips secrets (verification_script, hint_context,
// explanation_context) from a TaskSnapshot before sending it to students.
type studentTaskView struct {
	TaskID      string `json:"task_id"`
	Position    int    `json:"position"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Points      int    `json:"points"`
	IsOptional  bool   `json:"is_optional"`
}

// labStudentResponse is the shape returned by HandleGetLab.
type labStudentResponse struct {
	ID             string            `json:"id"`
	Title          string            `json:"title"`
	LabType        string            `json:"lab_type"`
	Description    *string           `json:"description,omitempty"`
	MaxDuration    int               `json:"max_duration"`
	MaxResets      int               `json:"max_resets"`
	HintPenaltyPct int               `json:"hint_penalty_pct"`
	IsRequired     bool              `json:"is_required"`
	Tasks          []studentTaskView `json:"tasks"`
}

// ─── Handlers ────────────────────────────────────────────────────────────────

// HandleGetLab returns lab metadata and a student-safe task list.
//
//	GET /api/labs/{labId}
func (h *Handler) HandleGetLab(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	labID := chi.URLParam(r, "labId")

	lab, err := h.repo.GetLab(r.Context(), labID, claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	resp := labStudentResponse{
		ID:             lab.ID,
		Title:          lab.Title,
		LabType:        lab.LabType,
		Description:    lab.Description,
		MaxDuration:    lab.MaxDuration,
		MaxResets:      lab.MaxResets,
		HintPenaltyPct: lab.HintPenaltyPct,
		IsRequired:     lab.IsRequired,
		Tasks:          []studentTaskView{},
	}

	if lab.IsPublished && lab.PublishedVersionID != nil {
		tasks, err := h.repo.GetPublishedVersion(r.Context(), *lab.PublishedVersionID)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		views := make([]studentTaskView, len(tasks))
		for i, t := range tasks {
			views[i] = studentTaskView{
				TaskID:      t.ID,
				Position:    t.Position,
				Title:       t.Title,
				Description: t.Description,
				Points:      t.Points,
				IsOptional:  t.IsOptional,
			}
		}
		resp.Tasks = views
	}

	httputil.WriteJSON(w, http.StatusOK, resp)
}

// HandleGetLabByModule returns the published lab linked to a course module.
//
//	GET /api/modules/{moduleId}/lab
func (h *Handler) HandleGetLabByModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")

	lab, err := h.repo.GetLabByModuleID(r.Context(), moduleID, claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	resp := labStudentResponse{
		ID:             lab.ID,
		Title:          lab.Title,
		LabType:        lab.LabType,
		Description:    lab.Description,
		MaxDuration:    lab.MaxDuration,
		MaxResets:      lab.MaxResets,
		HintPenaltyPct: lab.HintPenaltyPct,
		IsRequired:     lab.IsRequired,
		Tasks:          []studentTaskView{},
	}

	if lab.IsPublished && lab.PublishedVersionID != nil {
		tasks, err := h.repo.GetPublishedVersion(r.Context(), *lab.PublishedVersionID)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		views := make([]studentTaskView, len(tasks))
		for i, t := range tasks {
			views[i] = studentTaskView{
				TaskID:      t.ID,
				Position:    t.Position,
				Title:       t.Title,
				Description: t.Description,
				Points:      t.Points,
				IsOptional:  t.IsOptional,
			}
		}
		resp.Tasks = views
	}

	httputil.WriteJSON(w, http.StatusOK, resp)
}

// HandleStartSession starts (or resumes) a lab session for the authenticated user.
//
//	POST /api/labs/{labId}/sessions
func (h *Handler) HandleStartSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	labID := chi.URLParam(r, "labId")

	idempotencyKey := r.Header.Get("Idempotency-Key")
	if idempotencyKey == "" {
		idempotencyKey = fmt.Sprintf("%s-%s", claims.UserID, labID)
	}

	session, err := h.service.StartSession(r.Context(), labID, claims.UserID, claims.OrgID, false, idempotencyKey)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusAccepted, session)
}

// HandleGetSession returns a session and its task completion records.
//
//	GET /api/labs/sessions/{sessionId}
func (h *Handler) HandleGetSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	session, completions, err := h.service.GetSession(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"session":          session,
		"task_completions": completions,
	})
}

// HandleSessionEvents streams Server-Sent Events for container readiness.
//
//	GET /api/labs/sessions/{sessionId}/events
func (h *Handler) HandleSessionEvents(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	// IDOR check: ensure the session belongs to this user.
	if _, err := h.repo.GetSession(r.Context(), sessionID, claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}

	h.service.WaitForReadiness(r.Context(), w, sessionID)
}

// HandleMintWSToken issues a short-lived JWT for the in-browser terminal WebSocket.
//
//	POST /api/labs/sessions/{sessionId}/ws-token
func (h *Handler) HandleMintWSToken(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	token, err := h.service.MintWSToken(r.Context(), sessionID, claims.UserID, h.jwtSecret, h.jwtIssuer)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"session_token": token})
}

// HandleVerifyTask runs the student's submitted code against the task's
// verification harness via Piston and records the result.
//
//	POST /api/labs/sessions/{sessionId}/tasks/{taskId}/verify
func (h *Handler) HandleVerifyTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")
	taskID := chi.URLParam(r, "taskId")

	var body struct {
		Code     string `json:"code"`
		Language string `json:"language"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.Code == "" || body.Language == "" {
		httputil.WriteError(w, http.StatusBadRequest, "code and language are required.")
		return
	}

	result, err := h.service.VerifyTask(r.Context(), sessionID, taskID, claims.UserID, body.Code, body.Language)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, result)
}

// HandleResetSession clears all task completions and zeroes the score,
// consuming one of the session's allowed resets.
//
//	POST /api/labs/sessions/{sessionId}/reset
func (h *Handler) HandleResetSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	session, completions, err := h.service.ResetSession(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"session":          session,
		"task_completions": completions,
	})
}

// HandleEndSession terminates an active session and resolves its final status.
//
//	POST /api/labs/sessions/{sessionId}/end
func (h *Handler) HandleEndSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	if err := h.service.EndSession(r.Context(), sessionID, claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
