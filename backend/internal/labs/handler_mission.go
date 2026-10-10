package labs

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// HandleStartMission serves POST /api/labs/sessions/{sessionID}/mission/start.
func (h *Handler) HandleStartMission(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	session, err := h.service.StartMission(r.Context(), chi.URLParam(r, "sessionID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"session": session})
}

// HandleRecordActivity serves POST /api/labs/sessions/{sessionID}/activity.
func (h *Handler) HandleRecordActivity(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		Events []ActivityEventInput `json:"events"`
	}
	if !httputil.DecodeJSON(w, r, &body) {
		return
	}
	if err := h.service.RecordActivity(r.Context(), chi.URLParam(r, "sessionID"), claims.UserID, body.Events); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// HandleGetActivity serves GET /api/labs/sessions/{sessionID}/activity — what
// was recorded about the caller's own session.
func (h *Handler) HandleGetActivity(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	summary, err := h.service.GetActivity(r.Context(), chi.URLParam(r, "sessionID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, summary)
}

// HandleAdminActivity serves GET /api/admin/labs/sessions/{sessionID}/activity
// (admin.manage_org) — the same summary for any session of the caller's org.
func (h *Handler) HandleAdminActivity(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	summary, err := h.service.GetOrgActivity(r.Context(), chi.URLParam(r, "sessionID"), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, summary)
}

// labSettingsResponse is the org's lab interface settings.
type labSettingsResponse struct {
	DebugUI string `json:"debug_ui"`
}

// HandleGetLabSettings serves GET /api/admin/labs/settings (admin.manage_org).
func (h *Handler) HandleGetLabSettings(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	mode, err := h.service.DebugUIFor(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, labSettingsResponse{DebugUI: mode})
}

// HandleSetLabSettings serves PATCH /api/admin/labs/settings (admin.manage_org).
func (h *Handler) HandleSetLabSettings(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var body labSettingsResponse
	if !httputil.DecodeJSON(w, r, &body) {
		return
	}
	if err := h.service.SetDebugUI(r.Context(), claims.OrgID, body.DebugUI); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, labSettingsResponse{DebugUI: body.DebugUI})
}
