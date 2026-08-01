package gitlab

import (
	"errors"
	"net/http"
	"net/url"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// installationRequest is POST/PATCH /api/gitlab/installations(/{id})'s body.
// auth_kind selects which fields are required: "pat" needs
// personal_access_token; "oauth" needs oauth_client_id and starts a redirect
// round trip instead of completing synchronously. oauth_client_id/
// oauth_client_secret are accepted under either auth_kind — even a
// PAT-installed entry can register an OAuth Application so members can
// personally connect. name is required on create, ignored on update/PATCH
// (renaming isn't part of this surface — delete and re-add instead).
type installationRequest struct {
	Name                string `json:"name"`
	AuthKind            string `json:"auth_kind"`
	BaseURL             string `json:"base_url"`
	PersonalAccessToken string `json:"personal_access_token"`
	OAuthClientID       string `json:"oauth_client_id"`
	OAuthClientSecret   string `json:"oauth_client_secret"`
}

func validateBaseURL(raw string) bool {
	// ponytail: this is an authenticated admin's own trusted-instance config
	// value (RequireOrgRole("admin")), not an untrusted user-supplied fetch
	// target — a full SSRF denylist (private-IP/metadata-endpoint blocking)
	// belongs on any *unauthenticated or student-facing* URL intake this app
	// grows later, not here. This just rejects obviously malformed input.
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u.Host == "" {
		return false
	}
	return u.Scheme == "http" || u.Scheme == "https"
}

// InstallationsList handles GET /api/gitlab/installations — admin-only list
// backing the settings page's connection pool section.
func (h *Handler) InstallationsList(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	installations, err := h.service.ListInstallations(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	views := make([]InstallationStatusView, 0, len(installations))
	for _, inst := range installations {
		views = append(views, toInstallationView(&inst))
	}
	httputil.WriteJSON(w, http.StatusOK, views)
}

func validateInstallationRequest(req installationRequest, requireName bool) map[string]string {
	fields := map[string]string{}
	if requireName && strings.TrimSpace(req.Name) == "" {
		fields["name"] = "A name is required."
	}
	if !validateBaseURL(req.BaseURL) {
		fields["base_url"] = "A valid http(s) GitLab instance URL is required."
	}
	switch req.AuthKind {
	case AuthKindPAT:
		if strings.TrimSpace(req.PersonalAccessToken) == "" {
			fields["personal_access_token"] = "A personal access token is required."
		}
	case AuthKindOAuth:
		if strings.TrimSpace(req.OAuthClientID) == "" {
			fields["oauth_client_id"] = "An OAuth application client ID is required."
		}
	default:
		fields["auth_kind"] = "auth_kind must be 'pat' or 'oauth'."
	}
	return fields
}

// InstallationsCreate handles POST /api/gitlab/installations — adds a new
// named GitLab connection to the org's pool. A "pat" request completes
// synchronously; an "oauth" request returns an authorize_url for the
// frontend to redirect the admin's browser to next.
func (h *Handler) InstallationsCreate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req installationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if fields := validateInstallationRequest(req, true); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	if req.AuthKind == AuthKindPAT {
		inst, err := h.service.CreateInstallationPAT(r.Context(), claims.OrgID, claims.UserID, req.Name, req.BaseURL, req.PersonalAccessToken, req.OAuthClientID, req.OAuthClientSecret)
		if err != nil {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Could not verify that token against the GitLab instance. Check the URL and token and try again.")
			return
		}
		httputil.WriteJSON(w, http.StatusCreated, toInstallationView(inst))
		return
	}

	authorizeURL, err := h.service.StartInstallOAuth(r.Context(), claims.OrgID, claims.UserID, nil, req.Name, req.BaseURL, req.OAuthClientID, req.OAuthClientSecret)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"authorize_url": authorizeURL, "pending": true})
}

// InstallationUpdate handles PATCH /api/gitlab/installations/{id} —
// replaces an existing pool entry's credentials (re-verified against
// GitLab). Name and default status are untouched — see InstallationsSetDefault.
func (h *Handler) InstallationUpdate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "installationID")
	var req installationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if fields := validateInstallationRequest(req, false); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	if req.AuthKind == AuthKindPAT {
		inst, err := h.service.UpdateInstallationPAT(r.Context(), claims.OrgID, id, req.BaseURL, req.PersonalAccessToken, req.OAuthClientID, req.OAuthClientSecret)
		if err != nil {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Could not verify that token against the GitLab instance. Check the URL and token and try again.")
			return
		}
		httputil.WriteJSON(w, http.StatusOK, toInstallationView(inst))
		return
	}

	idCopy := id
	authorizeURL, err := h.service.StartInstallOAuth(r.Context(), claims.OrgID, claims.UserID, &idCopy, "", req.BaseURL, req.OAuthClientID, req.OAuthClientSecret)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"authorize_url": authorizeURL, "pending": true})
}

// InstallationDelete handles DELETE /api/gitlab/installations/{id} —
// removes one connection from the org's pool. See
// Repo.DeleteInstallationByID's own doc comment for the default/in-use guards.
func (h *Handler) InstallationDelete(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteInstallation(r.Context(), claims.OrgID, chi.URLParam(r, "installationID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "GitLab connection disconnected."})
}

// InstallationVerify handles POST /api/gitlab/installations/{id}/verify —
// re-checks that connection's stored token against GitLab and records the result.
func (h *Handler) InstallationVerify(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	inst, err := h.service.VerifyInstallation(r.Context(), claims.OrgID, chi.URLParam(r, "installationID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, toInstallationView(inst))
}

// InstallationSetDefault handles POST /api/gitlab/installations/{id}/set-default —
// moves the org's default flag onto this connection.
func (h *Handler) InstallationSetDefault(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	inst, err := h.service.SetDefaultInstallation(r.Context(), claims.OrgID, chi.URLParam(r, "installationID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, toInstallationView(inst))
}

// OrgConfigGet handles GET /api/gitlab/org-config — the
// allow_project_override policy the assignment form reads to decide whether
// to show its GitLab-connection override field at all.
func (h *Handler) OrgConfigGet(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	cfg, err := h.service.GetOrgConfig(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cfg)
}

type orgConfigRequest struct {
	AllowProjectOverride bool `json:"allow_project_override"`
}

// OrgConfigPut handles PUT /api/gitlab/org-config.
func (h *Handler) OrgConfigPut(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req orgConfigRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	cfg, err := h.service.SetOrgConfig(r.Context(), claims.OrgID, req.AllowProjectOverride)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cfg)
}

// Connect handles GET /api/gitlab/connect — any authenticated org member
// starts their own OAuth+PKCE connection flow. A plain top-level redirect
// (like auth.HandleOAuthRedirect for Google/GitHub) rather than a JSON
// response, since the frontend link is a real page navigation, not a fetch.
func (h *Handler) Connect(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	authorizeURL, err := h.service.StartConnect(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	http.Redirect(w, r, authorizeURL, http.StatusFound)
}

// Status handles GET /api/gitlab/status — any authenticated org member gets
// the combined installation + personal-connection picture for the settings page.
func (h *Handler) Status(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	status, err := h.service.GetStatus(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, status)
}

// Disconnect handles POST /api/gitlab/disconnect — any authenticated org
// member disconnects their own personal GitLab connection.
func (h *Handler) Disconnect(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.Disconnect(r.Context(), claims.OrgID, claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"disconnected": true})
}

// Callback handles GET /api/gitlab/callback — the GitLab instance's redirect
// back after consent. Authenticated via the gitlab_oauth_states row matched
// by the state param (not a session cookie), since PKCE's verifier must
// survive a cross-site top-level redirect. Public route — see routes.go.
func (h *Handler) Callback(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	state := q.Get("state")
	code := q.Get("code")

	errRedirect := func(reason string) {
		http.Redirect(w, r, h.service.cfg.FrontendURL+"/settings/integrations?gitlab_error="+url.QueryEscape(reason), http.StatusTemporaryRedirect)
	}

	if q.Get("error") != "" {
		errRedirect(q.Get("error"))
		return
	}
	if state == "" || code == "" {
		errRedirect("missing_code_or_state")
		return
	}

	purpose, err := h.service.CompleteCallback(r.Context(), state, code)
	if err != nil {
		reason := "connection_failed"
		if errors.Is(err, ErrNotFound) || errors.Is(err, ErrStateExpired) {
			reason = "expired_or_invalid_request"
		}
		errRedirect(reason)
		return
	}

	param := "gitlab_connected"
	if purpose == OAuthPurposeInstallation {
		param = "gitlab_installed"
	}
	http.Redirect(w, r, h.service.cfg.FrontendURL+"/settings/integrations?"+param+"=1", http.StatusTemporaryRedirect)
}

func toInstallationView(inst *GitlabInstallation) InstallationStatusView {
	view := InstallationStatusView{
		ID:             inst.ID,
		Name:           inst.Name,
		IsDefault:      inst.IsDefault,
		Connected:      true,
		BaseURL:        inst.BaseURL,
		Tier:           inst.Tier,
		AuthKind:       inst.AuthKind,
		Status:         inst.Status,
		HasOAuthApp:    inst.OAuthClientID != nil && *inst.OAuthClientID != "",
		LastError:      inst.LastError,
		LastVerifiedAt: inst.LastVerifiedAt,
		CreatedAt:      &inst.CreatedAt,
	}
	if inst.GitlabUsername != nil {
		view.GitlabUsername = *inst.GitlabUsername
	}
	return view
}
