package gitlab

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
)

type createTeamRequest struct {
	Name string `json:"name"`
	Slug string `json:"slug"`
}

// CreateTeam handles POST /api/projects/assignments/{assignmentID}/teams.
func (h *Handler) CreateTeam(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	assignmentID := chi.URLParam(r, "assignmentID")
	var req createTeamRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	fields := map[string]string{}
	if strings.TrimSpace(req.Name) == "" {
		fields["name"] = "A team name is required."
	}
	if strings.TrimSpace(req.Slug) == "" {
		fields["slug"] = "A team slug is required."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	team, err := h.service.CreateTeam(r.Context(), claims.OrgID, claims.UserID, assignmentID, req.Name, req.Slug)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, team)
}

// ListTeams handles GET /api/projects/assignments/{assignmentID}/teams.
func (h *Handler) ListTeams(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	teams, err := h.service.ListTeams(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, teams)
}

// UpdateTeam handles PATCH /api/projects/teams/{teamID}.
func (h *Handler) UpdateTeam(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var patch TeamPatch
	if !decodeJSON(w, r, &patch) {
		return
	}
	team, err := h.service.UpdateTeam(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"), patch)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, team)
}

// DeleteTeam handles DELETE /api/projects/teams/{teamID}. Only removes
// MindForge's own rows — see Repo.DeleteTeam's own doc comment for why the
// underlying GitLab project is left untouched.
func (h *Handler) DeleteTeam(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteTeam(r.Context(), claims.OrgID, chi.URLParam(r, "teamID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Team deleted."})
}

// ReprovisionTeam handles POST /api/projects/teams/{teamID}/reprovision —
// force-enqueues a fresh gitlab.provision_team job, e.g. after a failure.
func (h *Handler) ReprovisionTeam(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.ReprovisionTeam(r.Context(), claims.OrgID, chi.URLParam(r, "teamID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, map[string]any{"reprovisioning": true})
}

type addMemberRequest struct {
	Role              string `json:"role"`
	GitlabAccessLevel int    `json:"gitlab_access_level"`
}

// AddTeamMember handles POST /api/projects/teams/{teamID}/members/{userID}.
func (h *Handler) AddTeamMember(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req addMemberRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Role == "" {
		req.Role = MemberRoleMember
	}
	if req.Role != MemberRoleLead && req.Role != MemberRoleMember {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"role": "role must be 'lead' or 'member'."})
		return
	}
	if req.GitlabAccessLevel == 0 {
		req.GitlabAccessLevel = AccessLevelDeveloper
	}
	if req.GitlabAccessLevel != AccessLevelReporter && req.GitlabAccessLevel != AccessLevelDeveloper && req.GitlabAccessLevel != AccessLevelMaintainer {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"gitlab_access_level": "gitlab_access_level must be 20, 30, or 40."})
		return
	}

	member, err := h.service.AddTeamMember(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"), chi.URLParam(r, "userID"), req.Role, req.GitlabAccessLevel, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, member)
}

// RemoveTeamMember handles DELETE /api/projects/teams/{teamID}/members/{userID}.
func (h *Handler) RemoveTeamMember(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.RemoveTeamMember(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"), chi.URLParam(r, "userID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Member removed."})
}

// ListTeamMembers handles GET /api/projects/teams/{teamID}/members.
func (h *Handler) ListTeamMembers(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	members, err := h.service.ListTeamMembers(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, members)
}

// GetTeamActivity handles GET /api/projects/teams/{teamID}/activity — recent
// commits/merge requests plus the latest pipeline for the team detail page's
// read-only activity feed (see Service.GetTeamActivity's own doc comment for
// why this stays unaggregated).
func (h *Handler) GetTeamActivity(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	activity, err := h.service.GetTeamActivity(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, activity)
}

// SyncTeam handles POST /api/projects/teams/{teamID}/sync — an on-demand
// roster reconciliation, the same job the 30-min cron sweep and every
// add/remove-member call already enqueue automatically.
func (h *Handler) SyncTeam(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.RequestSync(r.Context(), claims.OrgID, chi.URLParam(r, "teamID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, map[string]any{"syncing": true})
}
