package orgs

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
)

// pgxRows is a local alias for the pgx.Rows interface so audit log query
// branches can share a variable without importing pgx at every call site.
type pgxRows = pgx.Rows

// Handler wires all org-related HTTP handlers.
type Handler struct {
	cfg     *config.Config
	pool    *pgxpool.Pool
	orgSvc  *OrgService
	onboSvc *OrgOnboardingService
	invSvc  *InviteService
	memSvc  *MemberService
	domSvc  *DomainService
}

func NewHandler(cfg *config.Config, pool *pgxpool.Pool) *Handler {
	return &Handler{
		cfg:     cfg,
		pool:    pool,
		orgSvc:  NewOrgService(pool, cfg),
		onboSvc: NewOrgOnboardingService(pool),
		invSvc:  NewInviteService(pool, cfg),
		memSvc:  NewMemberService(pool),
		domSvc:  NewDomainService(pool),
	}
}

// RegisterRoutes mounts all org routes. Callers must have already applied
// RequireAuth and RequireCSRF on the parent router.
func (h *Handler) RegisterRoutes(r chi.Router) {
	idem := apimiddleware.Idempotency(h.pool)

	r.With(idem).Post("/api/orgs", h.handleCreate)
	r.Get("/api/orgs/me", h.handleMe)
	r.With(idem).Post("/api/orgs/switch", h.handleSwitch)
	r.With(idem).Post("/api/orgs/join", h.handleJoin)

	r.Route("/api/orgs/{id}", func(r chi.Router) {
		r.Use(apimiddleware.RequireOrgMember(h.pool))
		r.Use(idem)

		r.Get("/", h.handleGet)
		r.Patch("/", h.handleUpdate)
		r.Post("/activate", h.handleActivate)

		r.Get("/onboarding", h.handleGetOnboarding)
		r.Patch("/onboarding", h.handleSaveOnboarding)

		r.Get("/auth-config", h.handleGetAuthConfig)
		r.Patch("/auth-config", h.handleUpdateAuthConfig)

		r.Post("/domains", h.handleAddDomain)
		r.Post("/domains/verify", h.handleVerifyDomain)
		r.Post("/domains/{domain_id}/auto-join", h.handleSetAutoJoin)
		r.Delete("/domains/{domain_id}", h.handleRemoveDomain)

		r.Post("/invites", h.handleCreateInvite)
		r.Get("/invites", h.handleListInvites)
		r.Post("/invites/{invite_id}/resend", h.handleResendInvite)
		r.Delete("/invites/{invite_id}", h.handleRevokeInvite)

		r.Get("/members", h.handleListMembers)
		r.Patch("/members/{member_id}", h.handleUpdateMember)
		r.Delete("/members/{member_id}", h.handleRemoveMember)

		r.Get("/audit-logs", h.handleListAuditLogs)
	})
}

// ─── org CRUD ─────────────────────────────────────────────────────────────────

func (h *Handler) handleCreate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	var req CreateOrgRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	org, err := h.orgSvc.Create(r.Context(), claims.UserID, req)
	if err != nil {
		h.mapOrgError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, org)
}

func (h *Handler) handleMe(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	orgs, err := h.orgSvc.GetMyOrgs(r.Context(), claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch organizations.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, orgs)
}

func (h *Handler) handleGet(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	org, err := h.orgSvc.GetByID(r.Context(), orgCtx.OrgID, claims.UserID)
	if err != nil {
		h.mapOrgError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, org)
}

func (h *Handler) handleUpdate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	var req UpdateOrgRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	org, err := h.orgSvc.Update(r.Context(), orgCtx.OrgID, claims.UserID, orgCtx.CallerRole, req)
	if err != nil {
		h.mapOrgError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, org)
}

func (h *Handler) handleActivate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	if orgCtx.CallerRole != RoleOwner {
		httputil.WriteError(w, http.StatusForbidden, "Only the org owner can activate the organization.")
		return
	}

	org, err := h.orgSvc.Activate(r.Context(), orgCtx.OrgID, claims.UserID)
	if err != nil {
		h.mapOrgError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, org)
}

func (h *Handler) handleSwitch(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	var req struct {
		OrgID string `json:"org_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.OrgID == "" {
		httputil.WriteError(w, http.StatusBadRequest, "org_id is required.")
		return
	}

	summary, err := h.orgSvc.SwitchOrg(r.Context(), claims.UserID, req.OrgID)
	if err != nil {
		if errors.Is(err, ErrForbidden) {
			httputil.WriteError(w, http.StatusForbidden, "Not a member of that organization.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to switch organization.")
		return
	}

	newToken, err := auth.CreateAccessToken(h.cfg, auth.Claims{
		UserID:         claims.UserID,
		OrgID:          summary.ID,
		OrgRole:        summary.Role,
		AuthMethod:     "switch",
		SessionVersion: claims.SessionVersion,
	})
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to issue access token.")
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "access_token",
		Value:    newToken,
		Path:     "/",
		MaxAge:   15 * 60,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   h.cfg.IsProd(),
	})
	httputil.WriteJSON(w, http.StatusOK, map[string]string{
		"org_id": summary.ID,
		"role":   summary.Role,
	})
}

func (h *Handler) handleJoin(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	var req JoinOrgRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		httputil.WriteError(w, http.StatusBadRequest, "token is required.")
		return
	}

	inv, err := h.invSvc.Join(r.Context(), req, claims.UserID)
	if err != nil {
		switch err.Error() {
		case "invalid_token":
			httputil.WriteError(w, http.StatusBadRequest, "Invalid or malformed invite token.")
		case "invite_expired":
			httputil.WriteError(w, http.StatusGone, "This invite has expired.")
		case "invite_revoked":
			httputil.WriteError(w, http.StatusGone, "This invite has been revoked.")
		case "invite_already_accepted":
			httputil.WriteError(w, http.StatusConflict, "This invite has already been accepted.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to join organization.")
		}
		return
	}
	httputil.WriteJSON(w, http.StatusOK, inv)
}

// ─── onboarding ───────────────────────────────────────────────────────────────

func (h *Handler) handleGetOnboarding(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	state, err := h.onboSvc.GetState(r.Context(), orgCtx.OrgID)
	if err != nil {
		h.mapOrgError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, state)
}

func (h *Handler) handleSaveOnboarding(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}
	_ = claims

	stepStr := r.URL.Query().Get("step")
	step, err := strconv.Atoi(stepStr)
	if err != nil || step < 1 || step > 4 {
		httputil.WriteError(w, http.StatusBadRequest, "step query param must be 1–4.")
		return
	}

	var req SaveOnboardingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	state, err := h.onboSvc.SaveStep(r.Context(), orgCtx.OrgID, step, req)
	if err != nil {
		switch err.Error() {
		case "invalid_slug", "reserved_slug", "invalid_name":
			httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to save onboarding step.")
		}
		return
	}
	httputil.WriteJSON(w, http.StatusOK, state)
}

// ─── auth config ─────────────────────────────────────────────────────────────

func (h *Handler) handleGetAuthConfig(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	cfg := &OrgAuthConfig{OrgID: orgCtx.OrgID}
	var allowedDomains []string
	err := h.pool.QueryRow(r.Context(),
		`SELECT sso_enabled, sso_provider, password_policy, allowed_domains
		 FROM org_auth_config WHERE org_id = $1`,
		orgCtx.OrgID,
	).Scan(&cfg.SSOEnabled, &cfg.SSOProvider, &cfg.PasswordPolicy, &allowedDomains)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load auth configuration.")
		return
	}
	if allowedDomains == nil {
		allowedDomains = []string{}
	}
	cfg.AllowedDomains = allowedDomains
	httputil.WriteJSON(w, http.StatusOK, cfg)
}

func (h *Handler) handleUpdateAuthConfig(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	var req struct {
		SSOEnabled     *bool    `json:"sso_enabled"`
		SSOProvider    *string  `json:"sso_provider"`
		AllowedDomains []string `json:"allowed_domains"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	_, err := h.pool.Exec(r.Context(),
		`INSERT INTO org_auth_config (org_id, sso_enabled, sso_provider, allowed_domains)
		 VALUES ($1, COALESCE($2, false), $3, COALESCE($4, '{}'))
		 ON CONFLICT (org_id) DO UPDATE
		   SET sso_enabled    = COALESCE(EXCLUDED.sso_enabled, org_auth_config.sso_enabled),
		       sso_provider   = COALESCE(EXCLUDED.sso_provider, org_auth_config.sso_provider),
		       allowed_domains = COALESCE(EXCLUDED.allowed_domains, org_auth_config.allowed_domains),
		       updated_at     = now()`,
		orgCtx.OrgID, req.SSOEnabled, req.SSOProvider, req.AllowedDomains,
	)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to update auth configuration.")
		return
	}

	writeAuditLog(r.Context(), h.pool, auditEntry{
		OrgID:      orgCtx.OrgID,
		ActorUserID: func() *string { s := orgCtx.MemberID; return &s }(),
		Action:     "org_auth_config.updated",
		TargetType: "org_auth_config",
		TargetID:   &orgCtx.OrgID,
	})

	cfg := &OrgAuthConfig{OrgID: orgCtx.OrgID}
	var domains []string
	if scanErr := h.pool.QueryRow(r.Context(),
		`SELECT sso_enabled, sso_provider, password_policy, allowed_domains
		 FROM org_auth_config WHERE org_id = $1`, orgCtx.OrgID,
	).Scan(&cfg.SSOEnabled, &cfg.SSOProvider, &cfg.PasswordPolicy, &domains); scanErr == nil {
		if domains != nil {
			cfg.AllowedDomains = domains
		} else {
			cfg.AllowedDomains = []string{}
		}
	}
	httputil.WriteJSON(w, http.StatusOK, cfg)
}

// ─── domains ──────────────────────────────────────────────────────────────────

func (h *Handler) handleAddDomain(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	var req AddDomainRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	domain, err := h.domSvc.Add(r.Context(), orgCtx.OrgID, claims.UserID, req)
	if err != nil {
		switch err.Error() {
		case "invalid_domain":
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Invalid domain name.")
		case "public_email_domain":
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Public email domains cannot be used for org verification.")
		case "invalid_verification_method":
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Verification method is required.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to add domain.")
		}
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, domain)
}

func (h *Handler) handleVerifyDomain(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	var req VerifyDomainRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}
	if req.DomainID == "" || req.Token == "" {
		httputil.WriteError(w, http.StatusBadRequest, "domain_id and token are required.")
		return
	}

	domain, err := h.domSvc.Verify(r.Context(), orgCtx.OrgID, req.DomainID, req.Token)
	if err != nil {
		switch err.Error() {
		case "invalid_token":
			httputil.WriteError(w, http.StatusBadRequest, "Verification token does not match.")
		default:
			h.mapOrgError(w, err)
		}
		return
	}
	httputil.WriteJSON(w, http.StatusOK, domain)
}

func (h *Handler) handleSetAutoJoin(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	domainID := chi.URLParam(r, "domain_id")
	var req struct {
		Enabled bool `json:"enabled"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	domain, err := h.domSvc.SetAutoJoin(r.Context(), orgCtx.OrgID, domainID, req.Enabled)
	if err != nil {
		switch err.Error() {
		case "domain_not_verified_or_not_found":
			httputil.WriteError(w, http.StatusNotFound, "Domain not found or not yet verified.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to update auto-join.")
		}
		return
	}
	httputil.WriteJSON(w, http.StatusOK, domain)
}

func (h *Handler) handleRemoveDomain(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	domainID := chi.URLParam(r, "domain_id")
	if err := h.domSvc.Remove(r.Context(), orgCtx.OrgID, domainID); err != nil {
		h.mapOrgError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── invites ──────────────────────────────────────────────────────────────────

func (h *Handler) handleCreateInvite(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	var req CreateInviteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	inv, token, err := h.invSvc.Create(r.Context(), orgCtx.OrgID, claims.UserID, orgCtx.CallerRole, req)
	if err != nil {
		switch {
		case errors.Is(err, ErrForbidden):
			httputil.WriteError(w, http.StatusForbidden, "You cannot invite someone with an equal or higher role.")
		case errors.Is(err, ErrAlreadyMember):
			httputil.WriteError(w, http.StatusConflict, "already_member")
		case errors.Is(err, ErrInvitePending):
			httputil.WriteError(w, http.StatusConflict, "invite_pending")
		case err.Error() == "invalid_email":
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Invalid email address.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to create invite.")
		}
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]any{
		"invite": inv,
		"token":  token, // caller sends this to the invitee via email
	})
}

func (h *Handler) handleListInvites(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	cursor := r.URL.Query().Get("cursor")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	page, err := h.invSvc.List(r.Context(), orgCtx.OrgID, cursor, limit)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to list invites.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

func (h *Handler) handleResendInvite(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	inviteID := chi.URLParam(r, "invite_id")
	inv, token, err := h.invSvc.Resend(r.Context(), orgCtx.OrgID, claims.UserID, orgCtx.CallerRole, inviteID)
	if err != nil {
		switch {
		case errors.Is(err, ErrNotFound):
			httputil.WriteError(w, http.StatusNotFound, "Invite not found.")
		case errors.Is(err, ErrForbidden):
			httputil.WriteError(w, http.StatusForbidden, "You cannot resend this invite.")
		case errors.Is(err, ErrInvalidStatus):
			httputil.WriteError(w, http.StatusConflict, "Invite has already been accepted or revoked.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to resend invite.")
		}
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"invite": inv,
		"token":  token,
	})
}

func (h *Handler) handleRevokeInvite(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	inviteID := chi.URLParam(r, "invite_id")
	if err := h.invSvc.Revoke(r.Context(), orgCtx.OrgID, claims.UserID, inviteID, orgCtx.CallerRole); err != nil {
		switch {
		case errors.Is(err, ErrNotFound):
			httputil.WriteError(w, http.StatusNotFound, "Invite not found.")
		case errors.Is(err, ErrForbidden):
			httputil.WriteError(w, http.StatusForbidden, "You cannot revoke this invite.")
		case errors.Is(err, ErrInvalidStatus):
			httputil.WriteError(w, http.StatusConflict, "Invite has already been accepted or revoked.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to revoke invite.")
		}
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── members ──────────────────────────────────────────────────────────────────

func (h *Handler) handleListMembers(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	cursor := r.URL.Query().Get("cursor")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	page, err := h.memSvc.List(r.Context(), orgCtx.OrgID, cursor, limit)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to list members.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

func (h *Handler) handleUpdateMember(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	memberID := chi.URLParam(r, "member_id")
	var req UpdateMemberRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	member, err := h.memSvc.Update(r.Context(), orgCtx.OrgID, claims.UserID, orgCtx.CallerRole, memberID, req)
	if err != nil {
		switch {
		case errors.Is(err, ErrNotFound):
			httputil.WriteError(w, http.StatusNotFound, "Member not found.")
		case errors.Is(err, ErrForbidden):
			httputil.WriteError(w, http.StatusForbidden, "You cannot modify this member.")
		case errors.Is(err, ErrLastOwner):
			httputil.WriteError(w, http.StatusConflict, "last_owner")
		case err.Error() == "invalid_status":
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Invalid status value.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to update member.")
		}
		return
	}
	httputil.WriteJSON(w, http.StatusOK, member)
}

func (h *Handler) handleRemoveMember(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	memberID := chi.URLParam(r, "member_id")
	if err := h.memSvc.Remove(r.Context(), orgCtx.OrgID, claims.UserID, orgCtx.CallerRole, memberID); err != nil {
		switch {
		case errors.Is(err, ErrNotFound):
			httputil.WriteError(w, http.StatusNotFound, "Member not found.")
		case errors.Is(err, ErrForbidden):
			httputil.WriteError(w, http.StatusForbidden, "You cannot remove this member.")
		case errors.Is(err, ErrLastOwner):
			httputil.WriteError(w, http.StatusConflict, "last_owner")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to remove member.")
		}
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── audit logs ───────────────────────────────────────────────────────────────

func (h *Handler) handleListAuditLogs(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}
	if orgCtx.CallerRole != RoleOwner && orgCtx.CallerRole != RoleAdmin {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return
	}

	cursor := r.URL.Query().Get("cursor")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	cursorCreatedAt, cursorID, decErr := decodeCursor(cursor)
	if decErr != nil {
		cursor = ""
	}

	var qErr error
	var logRows pgxRows
	if cursor == "" {
		logRows, qErr = h.pool.Query(r.Context(),
			`SELECT id, org_id, actor_user_id, action, target_type, target_id,
			        before_state, after_state, ip_address, created_at
			 FROM audit_logs
			 WHERE org_id = $1
			 ORDER BY created_at DESC, id DESC
			 LIMIT $2`,
			orgCtx.OrgID, limit+1,
		)
	} else {
		logRows, qErr = h.pool.Query(r.Context(),
			`SELECT id, org_id, actor_user_id, action, target_type, target_id,
			        before_state, after_state, ip_address, created_at
			 FROM audit_logs
			 WHERE org_id = $1
			   AND (created_at, id) < ($2, $3)
			 ORDER BY created_at DESC, id DESC
			 LIMIT $4`,
			orgCtx.OrgID, cursorCreatedAt, cursorID, limit+1,
		)
	}
	if qErr != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch audit logs.")
		return
	}
	defer logRows.Close()

	var logs []AuditLog
	for logRows.Next() {
		var l AuditLog
		if err := logRows.Scan(
			&l.ID, &l.OrgID, &l.ActorUserID, &l.Action, &l.TargetType, &l.TargetID,
			&l.BeforeState, &l.AfterState, &l.IPAddress, &l.CreatedAt,
		); err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to read audit logs.")
			return
		}
		logs = append(logs, l)
	}
	if err := logRows.Err(); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to read audit logs.")
		return
	}

	page := &AuditLogPage{Logs: logs}
	if len(logs) == 0 {
		page.Logs = []AuditLog{}
	}
	if len(logs) > limit {
		page.Logs = logs[:limit]
		last := page.Logs[limit-1]
		page.NextCursor = encodeCursor(last.CreatedAt, last.ID)
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// ─── error mapping ────────────────────────────────────────────────────────────

func (h *Handler) mapOrgError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrSlugTaken):
		httputil.WriteError(w, http.StatusConflict, "slug_taken")
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, "Forbidden.")
	case errors.Is(err, ErrLastOwner):
		httputil.WriteError(w, http.StatusConflict, "last_owner")
	case errors.Is(err, ErrAlreadyMember):
		httputil.WriteError(w, http.StatusConflict, "already_member")
	case errors.Is(err, ErrInvitePending):
		httputil.WriteError(w, http.StatusConflict, "invite_pending")
	case errors.Is(err, ErrOnboardingIncomplete):
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Onboarding must be completed before activating.")
	case errors.Is(err, ErrInvalidStatus):
		httputil.WriteError(w, http.StatusConflict, "Operation not allowed in the current org status.")
	case err.Error() == "invalid_slug":
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Slug must be 3–63 characters, lowercase alphanumeric and hyphens.")
	case err.Error() == "reserved_slug":
		httputil.WriteError(w, http.StatusUnprocessableEntity, "That slug is reserved.")
	case err.Error() == "invalid_name":
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Name must be 2–100 characters.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "An unexpected error occurred.")
	}
}

