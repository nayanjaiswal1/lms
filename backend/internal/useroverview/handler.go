package useroverview

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	authzSvc     *authz.Service
	adminRepo    *authz.AdminRepo
	coursesRepo  *courses.Repo
	activityRepo *activity.Repo
}

// New wires the Handler. coursesRepo is accepted rather than constructed here
// to reuse the exact instance router.go already built for the self-service
// routes; the rest are cheap stateless wrappers over pool, built fresh here
// the same way privacy.New builds its own authz.AdminRepo.
func New(pool *pgxpool.Pool, authzSvc *authz.Service, coursesRepo *courses.Repo) *Handler {
	return &Handler{
		authzSvc:     authzSvc,
		adminRepo:    authz.NewAdminRepo(pool),
		coursesRepo:  coursesRepo,
		activityRepo: activity.NewRepo(pool),
	}
}

// RegisterRoutes mounts the overview endpoint under the same
// /api/admin/rbac/users/{userID} resource internal/authz already gates on
// admin.manage_members/admin.view_members, so this package needs no
// permission code of its own. The caller must have already applied
// requireAuth + requireCSRF, same precondition every other RegisterRoutes in
// this codebase documents.
//
// This MUST be a flat .Get() call, not r.Route("/api/admin/rbac/users/{userID}",
// ...) — chi's Route() creates a new Mount at that pattern, and a second
// Mount at a path internal/authz already owns (its own nested
// r.Route("/api/admin/rbac", ...) registers /users/{userID},
// /users/{userID}/roles, /permissions, etc.) shadows that entire subtree,
// leaving only the routes this package itself defines reachable. Found by
// hand: after adding this package, every authz user-detail endpoint 404'd
// except this one.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.With(authz.RequireAnyPermission(h.authzSvc,
		"admin.manage_members",
		"admin.view_members",
	)).Get("/api/admin/rbac/users/{userID}/overview", h.HandleGetOverview)
}

// HandleGetOverview returns the org-scoped progress/activity data backing the
// admin user detail page's Overview/Courses tabs. Personal domains with no
// org_id (journal, mistakes, habits, sheets) must never be added here: the
// adminRepo.GetUser membership check below scopes who may be read, not what
// of theirs is org business.
//
// GET /api/admin/rbac/users/{userID}/overview
func (h *Handler) HandleGetOverview(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	userID := chi.URLParam(r, "userID")
	if _, err := h.adminRepo.GetUser(r.Context(), userID, claims.OrgID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			httputil.WriteError(w, http.StatusNotFound, "User not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load user.")
		return
	}

	overview, err := h.gather(r.Context(), userID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load user overview.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, overview)
}

func (h *Handler) gather(ctx context.Context, userID, orgID string) (Overview, error) {
	enrollments, err := h.coursesRepo.GetMyEnrollments(ctx, userID, orgID)
	if err != nil {
		return Overview{}, fmt.Errorf("enrollments: %w", err)
	}
	recentActivity, err := h.activityRepo.List(ctx, userID, orgID, 0, nil, "", recentActivityLimit)
	if err != nil {
		return Overview{}, fmt.Errorf("activity: %w", err)
	}
	return Overview{
		Enrollments:    enrollments,
		RecentActivity: recentActivity,
	}, nil
}
