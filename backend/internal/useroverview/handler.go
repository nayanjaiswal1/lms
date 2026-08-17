package useroverview

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/journal"
	"github.com/mindforge/backend/internal/mistakes"
	"github.com/mindforge/backend/internal/sheets"
)

// Handler serves the admin user-overview endpoint.
type Handler struct {
	authzSvc     *authz.Service
	adminRepo    *authz.AdminRepo
	coursesRepo  *courses.Repo
	mistakesRepo *mistakes.Repo
	activityRepo *activity.Repo
	sheetsRepo   *sheets.Repo
	habitSvc     *habit.Service
	journalRepo  *journal.Repo
}

// New wires the Handler. coursesRepo/mistakesRepo are accepted rather than
// constructed here to reuse the exact instances router.go already built for
// the self-service routes; the rest are cheap stateless wrappers over pool,
// built fresh here the same way privacy.New builds its own authz.AdminRepo.
func New(pool *pgxpool.Pool, authzSvc *authz.Service, coursesRepo *courses.Repo, mistakesRepo *mistakes.Repo) *Handler {
	return &Handler{
		authzSvc:     authzSvc,
		adminRepo:    authz.NewAdminRepo(pool),
		coursesRepo:  coursesRepo,
		mistakesRepo: mistakesRepo,
		activityRepo: activity.NewRepo(pool),
		sheetsRepo:   sheets.NewRepo(pool),
		habitSvc:     habit.NewService(habit.NewRepo(pool)),
		journalRepo:  journal.NewRepo(pool),
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

// HandleGetOverview returns the progress/activity data backing the admin
// user detail page's Courses/Activity/Sheets/Mistakes/Habits/Journal tabs.
// Several of the underlying domains (sheets, mistakes, habits, journal) are
// personal data with no org_id column — see internal/activity's own doc
// comment on why srs/sheets rows aren't tenant-scoped — so the
// adminRepo.GetUser call below, which does scope by org, is the only thing
// standing between "admin in org A" and "another org's member's private
// journal." Every read this handler adds must keep going through it.
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
	userSheets, err := h.sheetsRepo.ListUserSheets(ctx, userID)
	if err != nil {
		return Overview{}, fmt.Errorf("sheets: %w", err)
	}
	mistakeEntries, err := h.mistakesRepo.List(ctx, userID, mistakes.ListFilter{})
	if err != nil {
		return Overview{}, fmt.Errorf("mistakes: %w", err)
	}
	mistakeSummary, err := h.mistakesRepo.Summary(ctx, userID)
	if err != nil {
		return Overview{}, fmt.Errorf("mistake summary: %w", err)
	}
	habitMonth, err := h.habitSvc.MonthView(ctx, userID, time.Now().UTC().Format("2006-01"))
	if err != nil {
		return Overview{}, fmt.Errorf("habits: %w", err)
	}
	journalEntries, err := h.journalRepo.ListEntries(ctx, userID, journal.ListEntriesFilter{})
	if err != nil {
		return Overview{}, fmt.Errorf("journal: %w", err)
	}

	return Overview{
		Enrollments:    enrollments,
		RecentActivity: recentActivity,
		Sheets:         userSheets,
		Mistakes:       mistakeEntries,
		MistakeSummary: mistakeSummary,
		HabitMonth:     habitMonth,
		JournalEntries: journalEntries,
	}, nil
}
