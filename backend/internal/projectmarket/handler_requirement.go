package projectmarket

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// requirementRequest is POST/PATCH .../requirements(/{id})'s body.
type requirementRequest struct {
	Title               string    `json:"title"`
	Brief               string    `json:"brief"`
	RequiredSkills      []string  `json:"required_skills"`
	TeamSizeMin         int       `json:"team_size_min"`
	TeamSizeMax         int       `json:"team_size_max"`
	ApplicationDeadline time.Time `json:"application_deadline"`
}

// CreateRequirement handles POST /api/project-marketplace/requirements —
// staff posts a new draft requirement.
func (h *Handler) CreateRequirement(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req requirementRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.TeamSizeMin == 0 {
		req.TeamSizeMin = 1
	}
	if req.TeamSizeMax == 0 {
		req.TeamSizeMax = req.TeamSizeMin
	}
	if fields := validateRequirementRequest(&req); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	created, err := h.service.CreateRequirement(r.Context(), claims.OrgID, claims.UserID, ProjectRequirement{
		Title:               req.Title,
		Brief:               req.Brief,
		RequiredSkills:      req.RequiredSkills,
		TeamSizeMin:         req.TeamSizeMin,
		TeamSizeMax:         req.TeamSizeMax,
		ApplicationDeadline: req.ApplicationDeadline,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

// ListRequirements handles GET /api/project-marketplace/requirements — staff
// management list, every status.
func (h *Handler) ListRequirements(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	reqs, err := h.service.ListRequirements(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, reqs)
}

// GetRequirement handles GET /api/project-marketplace/requirements/{id}
// (staff) and GET /api/project-marketplace/board/{id} (any org member) — the
// same read, no staff-only fields to hide from the board view.
func (h *Handler) GetRequirement(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	req, err := h.service.GetRequirement(r.Context(), claims.OrgID, chi.URLParam(r, "requirementID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, req)
}

// UpdateRequirement handles PATCH /api/project-marketplace/requirements/{id}.
func (h *Handler) UpdateRequirement(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		Title               *string    `json:"title"`
		Brief               *string    `json:"brief"`
		RequiredSkills      *[]string  `json:"required_skills"`
		TeamSizeMin         *int       `json:"team_size_min"`
		TeamSizeMax         *int       `json:"team_size_max"`
		ApplicationDeadline *time.Time `json:"application_deadline"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	updated, err := h.service.UpdateRequirement(r.Context(), claims.OrgID, chi.URLParam(r, "requirementID"), RequirementPatch{
		Title:               body.Title,
		Brief:               body.Brief,
		RequiredSkills:      body.RequiredSkills,
		TeamSizeMin:         body.TeamSizeMin,
		TeamSizeMax:         body.TeamSizeMax,
		ApplicationDeadline: body.ApplicationDeadline,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

// PublishRequirement handles POST .../requirements/{id}/publish — draft -> open.
func (h *Handler) PublishRequirement(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	req, err := h.service.PublishRequirement(r.Context(), claims.OrgID, chi.URLParam(r, "requirementID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, req)
}

// CloseRequirement handles POST .../requirements/{id}/close — open -> closed.
func (h *Handler) CloseRequirement(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	req, err := h.service.CloseRequirement(r.Context(), claims.OrgID, chi.URLParam(r, "requirementID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, req)
}

// RequestScoring handles POST .../requirements/{id}/score — staff asks the
// AI to rank every not-yet-scored application.
func (h *Handler) RequestScoring(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.RequestScoring(r.Context(), claims.OrgID, chi.URLParam(r, "requirementID"), claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, map[string]string{"message": "Scoring started — refresh in a moment to see results."})
}

// CreateTeamFromSelection handles POST
// .../requirements/{id}/create-team — staff points an already-created
// assignment at this requirement's selected applicants; every one of them is
// added to a new team under it.
func (h *Handler) CreateTeamFromSelection(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req TeamFromSelectionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.AssignmentID) == "" || strings.TrimSpace(req.TeamName) == "" || strings.TrimSpace(req.TeamSlug) == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"assignment_id": "assignment_id, team_name, and team_slug are all required.",
		})
		return
	}
	team, addedUserIDs, err := h.service.CreateTeamFromSelection(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "requirementID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, map[string]any{"team": team, "added_user_ids": addedUserIDs})
}

// ListApplicationsForRequirement handles GET
// .../requirements/{id}/applications — staff review list.
func (h *Handler) ListApplicationsForRequirement(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	apps, err := h.service.ListApplicationsForStaff(r.Context(), claims.OrgID, chi.URLParam(r, "requirementID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, apps)
}

// GetBoard handles GET /api/project-marketplace/board — any org member
// browses open requirements, with their own application status attached.
func (h *Handler) GetBoard(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	board, err := h.service.ListBoard(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, board)
}
