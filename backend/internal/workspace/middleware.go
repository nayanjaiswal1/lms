package workspace

import (
	"context"
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// PermissionChecker is the slice of *authz.Service the project-role lookup
// needs (the projects.oversee check). An interface so the middleware matrix
// tests can run against testdb without Redis.
type PermissionChecker interface {
	HasPermission(ctx context.Context, userID, tenantID, code string) (bool, error)
}

// ProjectCtx is what RequireProjectRole resolved for this request. Handlers
// and services read the project id / org id / role from here, never from the
// request body.
type ProjectCtx struct {
	ProjectID     string
	OrgID         string
	UserID        string
	ProjectStatus string
	BriefStatus   string
	GitlabEnabled bool
	OrgStatus     string
	// Role is the effective role: the member row's role, or owner for an
	// overseer who is not a member (or is a member below the route minimum).
	Role string
	// MemberRole/MemberStatus are the raw project_members row ("" if none).
	MemberRole   string
	MemberStatus string
	// Overseer is true when Role came from projects.oversee rather than the
	// member row. Overseers never bypass separation of duties (sod.go).
	Overseer bool
}

type projectCtxKey struct{}

// GetProjectCtx returns the ProjectCtx set by RequireProjectRole.
func GetProjectCtx(ctx context.Context) (*ProjectCtx, bool) {
	pc, ok := ctx.Value(projectCtxKey{}).(*ProjectCtx)
	return pc, ok
}

// WithProjectCtx stores pc on ctx (used by the middleware and by tests).
func WithProjectCtx(ctx context.Context, pc *ProjectCtx) context.Context {
	return context.WithValue(ctx, projectCtxKey{}, pc)
}

// ResolveProjectRole reads the caller's role on projectID live from the
// database — one indexed query, never cached, so a removed member loses
// access on their very next request (02 §2).
//
// Returns ErrNotFound for: bad id, other org, no row, caller not an active
// org member, caller not an active project member and not an overseer.
// Returns ErrForbidden when the caller is an active member below min and not
// an overseer.
func ResolveProjectRole(ctx context.Context, pool *pgxpool.Pool, perms PermissionChecker, projectID, userID, orgID, min string) (*ProjectCtx, error) {
	if _, err := uuid.Parse(projectID); err != nil || orgID == "" || userID == "" {
		return nil, ErrNotFound
	}

	pc := &ProjectCtx{ProjectID: projectID, OrgID: orgID, UserID: userID}
	var memberRole, memberStatus *string
	err := pool.QueryRow(ctx,
		`SELECT p.project_status, p.brief_status, p.gitlab_enabled, o.status, pm.role, pm.status
		   FROM workspace_projects p
		   JOIN organizations o ON o.id = p.org_id
		   JOIN org_members om ON om.org_id = p.org_id AND om.user_id = $2 AND om.status = 'active'
		   LEFT JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $2
		  WHERE p.id = $1 AND p.org_id = $3`,
		projectID, userID, orgID,
	).Scan(&pc.ProjectStatus, &pc.BriefStatus, &pc.GitlabEnabled, &pc.OrgStatus, &memberRole, &memberStatus)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if memberRole != nil {
		pc.MemberRole, pc.MemberStatus = *memberRole, *memberStatus
	}

	activeMember := pc.MemberStatus == MemberActive
	if activeMember && RoleAtLeast(pc.MemberRole, min) {
		pc.Role = pc.MemberRole
		return pc, nil
	}

	oversee, err := perms.HasPermission(ctx, userID, orgID, PermProjectsOversee)
	if err != nil {
		return nil, err
	}
	if oversee {
		pc.Role, pc.Overseer = RoleOwner, true
		return pc, nil
	}
	if !activeMember {
		return nil, ErrNotFound
	}
	return nil, ErrForbidden
}

// RequireProjectRole resolves {workspaceID} for the authenticated caller and
// enforces a minimum project role: non-member → 404 (no existence leak),
// member below min → 403. Must run after RequireAuth.
func RequireProjectRole(pool *pgxpool.Pool, perms PermissionChecker, min string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
				return
			}
			pc, err := ResolveProjectRole(r.Context(), pool, perms,
				chi.URLParam(r, "workspaceID"), claims.UserID, claims.OrgID, min)
			switch {
			case errors.Is(err, ErrNotFound):
				httputil.WriteError(w, http.StatusNotFound, "Project not found.")
				return
			case errors.Is(err, ErrForbidden):
				httputil.WriteError(w, http.StatusForbidden, "Your project role does not allow this action.")
				return
			case err != nil:
				slog.ErrorContext(r.Context(), "workspace: resolve project role", "error", err)
				httputil.WriteError(w, http.StatusInternalServerError, "Internal server error.")
				return
			}
			next.ServeHTTP(w, r.WithContext(WithProjectCtx(r.Context(), pc)))
		})
	}
}

// ProjectStatusGate allows the request only while the project is in one of
// allowed statuses and its org is active (409 otherwise). Chain after
// RequireProjectRole.
func ProjectStatusGate(allowed ...string) func(http.Handler) http.Handler {
	permitted := make(map[string]bool, len(allowed))
	for _, s := range allowed {
		permitted[s] = true
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			pc, ok := GetProjectCtx(r.Context())
			if !ok {
				slog.ErrorContext(r.Context(), "workspace: ProjectStatusGate without RequireProjectRole")
				httputil.WriteError(w, http.StatusInternalServerError, "Internal server error.")
				return
			}
			if pc.OrgStatus != "active" {
				httputil.WriteError(w, http.StatusConflict, "This organization is not active.")
				return
			}
			if !permitted[pc.ProjectStatus] {
				httputil.WriteError(w, http.StatusConflict, "Not allowed while the project is "+pc.ProjectStatus+".")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
