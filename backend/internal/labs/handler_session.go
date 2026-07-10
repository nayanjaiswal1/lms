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
	// Language is the authoritative language for "code" type labs; nil for
	// other lab types. The frontend locks its editor/dropdown to this value
	// instead of letting the student pick a language independent of what the
	// task's verification script actually expects.
	Language       *string           `json:"language"`
	MaxDuration    int               `json:"max_duration"`
	MaxResets      int               `json:"max_resets"`
	HintPenaltyPct int               `json:"hint_penalty_pct"`
	IsRequired     bool              `json:"is_required"`
	// Layout selects the student workspace arrangement: "split" or "console".
	// See LabDefinition.WorkspaceLayout.
	Layout         string            `json:"layout"`
	Tasks          []studentTaskView `json:"tasks"`
}

// newLabStudentResponse builds the student-safe lab view shared by
// HandleGetLab and HandleGetLabByModule.
func newLabStudentResponse(lab *LabDefinition) labStudentResponse {
	return labStudentResponse{
		ID:             lab.ID,
		Title:          lab.Title,
		LabType:        lab.LabType,
		Description:    lab.Description,
		Language:       lab.Language,
		MaxDuration:    lab.MaxDuration,
		MaxResets:      lab.MaxResets,
		HintPenaltyPct: lab.HintPenaltyPct,
		IsRequired:     lab.IsRequired,
		Layout:         lab.WorkspaceLayout,
		Tasks:          []studentTaskView{},
	}
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

	resp := newLabStudentResponse(lab)

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

	resp := newLabStudentResponse(lab)

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

// HandleListActiveSessions returns the authenticated user's currently active
// lab sessions (provisioning/running/paused) across all labs.
//
//	GET /api/labs/sessions/active
func (h *Handler) HandleListActiveSessions(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	sessions, err := h.service.ListActiveSessions(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, sessions)
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

// HandleVerifyTask runs the task's verification harness and records the
// result. Code-type labs run the student's submitted code through Piston,
// executed under the lab's own `language` column — never a client-supplied
// value, since that previously let a stale/mismatched frontend language
// setting run a task's verification script under the wrong interpreter.
// Terminal/guided/playground labs run the verification script inside the
// session's Docker container and ignore the request body entirely.
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
		Code string `json:"code"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	// code is only required for code-type labs — look up the lab type via the
	// session before enforcing that. IDOR is enforced by GetSession itself
	// (user_id must match the caller).
	session, err := h.repo.GetSession(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	lab, err := h.repo.GetLab(r.Context(), session.LabID, claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if lab.LabType == LabTypeCode && body.Code == "" {
		httputil.WriteError(w, http.StatusBadRequest, "code is required.")
		return
	}

	result, err := h.service.VerifyTask(r.Context(), sessionID, taskID, claims.UserID, body.Code)
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
