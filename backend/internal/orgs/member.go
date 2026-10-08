package orgs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/pagination"
	"github.com/mindforge/backend/internal/session"
)

// MemberService manages org membership records.
type MemberService struct {
	pool  *pgxpool.Pool
	cache *session.Cache
	// invalidatePerms drops the cached RBAC permission set for (user, org).
	// Wired from authz.Service.InvalidateUser when routes are registered; nil
	// in tests that don't exercise RBAC.
	invalidatePerms func(ctx context.Context, userID, orgID string) error
}

func NewMemberService(pool *pgxpool.Pool, cache *session.Cache) *MemberService {
	return &MemberService{pool: pool, cache: cache}
}

// invalidateSession drops the cached session_version for a user so a role or
// status change is picked up on the next request rather than up to the cache
// TTL later.
func (s *MemberService) invalidateSession(ctx context.Context, userID string) {
	if s.cache == nil {
		return
	}
	s.cache.InvalidateVersionCache(ctx, userID)
}

// invalidatePermissions flushes the user's cached permissions in orgID so a
// role/status change or removal is enforced immediately, not after the 5-minute
// RBAC cache TTL.
func (s *MemberService) invalidatePermissions(ctx context.Context, userID, orgID string) {
	if s.invalidatePerms == nil {
		return
	}
	if err := s.invalidatePerms(ctx, userID, orgID); err != nil {
		slog.Warn("orgs: invalidate permission cache", "user_id", userID, "org_id", orgID, "error", err)
	}
}

// outranks reports whether the actor may manage a member of targetRole: owners
// manage anyone, everyone else only strictly lower ranks, so an admin cannot
// demote, suspend or remove a peer admin. Acting on oneself is always allowed.
func outranks(actorRole, targetRole, actorUserID, targetUserID string) bool {
	if actorUserID == targetUserID || actorRole == RoleOwner {
		return true
	}
	return roleRank[actorRole] > roleRank[targetRole]
}

// List returns cursor-paginated members with user info joined.
// Excludes members with status='removed'.
func (s *MemberService) List(ctx context.Context, orgID, cursor string, limit int) (*MemberPage, error) {
	cursorCreatedAt, cursorID, err := pagination.DecodeCursor(cursor, "orgs")
	if err != nil {
		cursor = "" // treat bad cursor as no cursor
	}
	var rows pgx.Rows
	if cursor == "" {
		rows, err = s.pool.Query(ctx,
			`SELECT m.id, m.user_id, u.name, u.email, u.avatar_url, m.role, m.status, m.created_at
			 FROM org_members m
			 JOIN users u ON u.id = m.user_id
			 WHERE m.org_id = $1 AND m.status <> 'removed'
			 ORDER BY m.created_at ASC, m.id ASC
			 LIMIT $2`,
			orgID, limit+1,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT m.id, m.user_id, u.name, u.email, u.avatar_url, m.role, m.status, m.created_at
			 FROM org_members m
			 JOIN users u ON u.id = m.user_id
			 WHERE m.org_id = $1 AND m.status <> 'removed'
			   AND (m.created_at, m.id) > ($2, $3)
			 ORDER BY m.created_at ASC, m.id ASC
			 LIMIT $4`,
			orgID, cursorCreatedAt, cursorID, limit+1,
		)
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: list members: query: %w", err)
	}
	defer rows.Close()

	var members []Member
	for rows.Next() {
		var m Member
		if err := rows.Scan(&m.ID, &m.UserID, &m.Name, &m.Email, &m.AvatarURL, &m.Role, &m.Status, &m.JoinedAt); err != nil {
			return nil, fmt.Errorf("orgs: list members: scan: %w", err)
		}
		members = append(members, m)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("orgs: list members: rows: %w", err)
	}

	page := &MemberPage{Members: members}
	if len(members) == 0 {
		page.Members = []Member{}
	}
	if len(members) > limit {
		page.Members = members[:limit]
		last := page.Members[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.JoinedAt, last.ID)
	}
	return page, nil
}

// Update changes role or status of a member. Enforces role hierarchy and last-owner guard.
func (s *MemberService) Update(ctx context.Context, orgID, actorUserID, actorRole, memberID string, req UpdateMemberRequest) (*Member, error) {
	// Fetch target member.
	var target Member
	err := s.pool.QueryRow(ctx,
		`SELECT m.id, m.user_id, u.name, u.email, u.avatar_url, m.role, m.status, m.created_at
		 FROM org_members m
		 JOIN users u ON u.id = m.user_id
		 WHERE m.id = $1 AND m.org_id = $2`,
		memberID, orgID,
	).Scan(&target.ID, &target.UserID, &target.Name, &target.Email, &target.AvatarURL, &target.Role, &target.Status, &target.JoinedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: update member: fetch target: %w", err)
	}

	// Owners can only be managed by other owners; peers cannot manage each other.
	if target.Role == RoleOwner && actorRole != RoleOwner {
		return nil, ErrForbidden
	}
	if !outranks(actorRole, target.Role, actorUserID, target.UserID) {
		return nil, ErrForbidden
	}

	// Role change authorization.
	if req.Role != nil {
		if !CanGrantRole(actorRole, *req.Role) {
			return nil, ErrForbidden
		}
		// Cannot assign the same or higher role than own (except owner assigns owner).
		if actorRole != RoleOwner && roleRank[*req.Role] >= roleRank[actorRole] {
			return nil, ErrForbidden
		}
	}

	setClauses := []string{"updated_at = now()"}
	args := []any{}
	argIdx := 1

	if req.Role != nil {
		setClauses = append(setClauses, fmt.Sprintf("role = $%d", argIdx))
		args = append(args, *req.Role)
		argIdx++
	}
	if req.Status != nil {
		// Only owners may suspend/remove owners.
		if target.Role == RoleOwner && actorRole != RoleOwner {
			return nil, ErrForbidden
		}
		allowed := map[string]bool{MemberActive: true, MemberSuspended: true}
		if !allowed[*req.Status] {
			return nil, fmt.Errorf("invalid_status")
		}
		setClauses = append(setClauses, fmt.Sprintf("status = $%d", argIdx))
		args = append(args, *req.Status)
		argIdx++
	}

	args = append(args, memberID, orgID)
	query := fmt.Sprintf(
		`UPDATE org_members SET %s WHERE id = $%d AND org_id = $%d
		 RETURNING id, user_id, role, status, created_at`,
		strings.Join(setClauses, ", "), argIdx, argIdx+1,
	)

	var updated Member
	err = s.pool.QueryRow(ctx, query, args...).Scan(
		&updated.ID, &updated.UserID, &updated.Role, &updated.Status, &updated.JoinedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23514" && strings.Contains(pgErr.ConstraintName, "last_owner") {
			return nil, ErrLastOwner
		}
		return nil, fmt.Errorf("orgs: update member: %w", err)
	}

	// A role or status change alters what the member may do, but every access
	// token they already hold still carries the old org_role claim and whatever
	// the frontend gated on it. Bumping session_version retires those tokens on
	// the next request instead of letting them run out the clock.
	//
	// RequireOrgRole reads the live role from the database, so this is not what
	// keeps the API safe — it is what stops the member from seeing a UI built
	// for privileges they no longer have, and what makes a suspension take
	// effect immediately rather than at token expiry.
	roleChanged := req.Role != nil && *req.Role != target.Role
	statusChanged := req.Status != nil && *req.Status != target.Status
	if roleChanged {
		if err := syncTenantAdminRole(ctx, s.pool, orgID, updated.UserID, updated.Role); err != nil {
			return nil, fmt.Errorf("orgs: update member: sync tenant_admin role: %w", err)
		}
	}

	if roleChanged || statusChanged {
		if _, err := s.pool.Exec(ctx,
			`UPDATE users SET session_version = session_version + 1 WHERE id = $1`,
			updated.UserID,
		); err != nil {
			return nil, fmt.Errorf("orgs: update member: bump session_version: %w", err)
		}
		s.invalidateSession(ctx, updated.UserID)
		s.invalidatePermissions(ctx, updated.UserID, orgID)
	}

	// Re-fetch with user info for full response.
	result, err := s.fetchMember(ctx, orgID, memberID)
	if err != nil {
		return nil, err
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:       orgID,
		ActorUserID: &actorUserID,
		Action:      "member.updated",
		TargetType:  "member",
		TargetID:    &memberID,
		BeforeState: target,
		AfterState:  result,
	})

	return result, nil
}

// Remove soft-deletes a member by setting status='removed'.
func (s *MemberService) Remove(ctx context.Context, orgID, actorUserID, actorRole, memberID string) error {
	var target Member
	err := s.pool.QueryRow(ctx,
		`SELECT m.id, m.user_id, m.role, m.status FROM org_members m WHERE m.id = $1 AND m.org_id = $2`,
		memberID, orgID,
	).Scan(&target.ID, &target.UserID, &target.Role, &target.Status)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("orgs: remove member: fetch target: %w", err)
	}
	if target.Role == RoleOwner && actorRole != RoleOwner {
		return ErrForbidden
	}
	if !outranks(actorRole, target.Role, actorUserID, target.UserID) {
		return ErrForbidden
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("orgs: remove member: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	if _, err := tx.Exec(ctx,
		`UPDATE org_members SET status = 'removed', updated_at = now() WHERE id = $1 AND org_id = $2`,
		memberID, orgID,
	); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23514" && strings.Contains(pgErr.ConstraintName, "last_owner") {
			return ErrLastOwner
		}
		return fmt.Errorf("orgs: remove member: %w", err)
	}

	// Same transaction: leave every Project Workspace this user belongs to
	// in the org (docs/project-workspace-plan/02-auth-security.md §2 "org
	// removal runs the same routine for every workspace in that org").
	if err := removeFromOrgWorkspaces(ctx, tx, orgID, target.UserID); err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("orgs: remove member: commit: %w", err)
	}

	// Revoke every RBAC role and direct permission grant in this org, not just
	// tenant_admin: a future re-add (e.g. as a plain learner) must not silently
	// inherit custom-role or override permissions that predate the removal.
	if _, err := s.pool.Exec(ctx, `DELETE FROM user_roles WHERE user_id = $1 AND org_id = $2`, target.UserID, orgID); err != nil {
		return fmt.Errorf("orgs: remove member: revoke roles: %w", err)
	}
	if _, err := s.pool.Exec(ctx, `DELETE FROM user_permission_overrides WHERE user_id = $1 AND org_id = $2`, target.UserID, orgID); err != nil {
		return fmt.Errorf("orgs: remove member: revoke permission overrides: %w", err)
	}
	s.invalidatePermissions(ctx, target.UserID, orgID)

	// Retire the removed member's outstanding access tokens rather than letting
	// them keep a working session until expiry. RequireOrgMember rejects them on
	// org-scoped routes immediately (it checks status='active'), but the tokens
	// still assert an org_role that the frontend and any non-org-scoped route
	// would otherwise honour.
	if _, err := s.pool.Exec(ctx,
		`UPDATE users SET session_version = session_version + 1 WHERE id = $1`,
		target.UserID,
	); err != nil {
		return fmt.Errorf("orgs: remove member: bump session_version: %w", err)
	}
	s.invalidateSession(ctx, target.UserID)

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:       orgID,
		ActorUserID: &actorUserID,
		Action:      "member.removed",
		TargetType:  "member",
		TargetID:    &memberID,
		BeforeState: target,
	})
	return nil
}

// removeFromOrgWorkspaces marks userID `removed` (left_at = now()) on every
// project_members row they hold across orgID's Project Workspaces, and drops
// their project_track_members rows, inside the caller's transaction (same
// tx as the org-level removal). Raw SQL against the workspace package's own
// tables rather than an import of that package: workspace already imports
// orgs (for InviteService), so the reverse import would cycle, and this is
// the only workspace state an org removal needs to touch.
//
// Rows where the user is 'owner' are left untouched — an org-level action
// has no policy for who becomes the new owner of a project, so leaving the
// project ownerless would silently orphan it. This is a deliberate gap: an
// admin must transfer ownership by hand (or the project stays owned by a
// user who is no longer an org member, which RequireProjectRole's own live
// org-membership check already turns into effective read-only access for
// them). Surfaced as a warning log so it isn't invisible.
func removeFromOrgWorkspaces(ctx context.Context, tx pgx.Tx, orgID, userID string) error {
	rows, err := tx.Query(ctx,
		`SELECT p.id FROM workspace_projects p
		   JOIN project_members pm ON pm.project_id = p.id
		  WHERE p.org_id = $1 AND pm.user_id = $2 AND pm.role = 'owner' AND pm.status = 'active'`,
		orgID, userID,
	)
	if err != nil {
		return fmt.Errorf("orgs: remove member: find owned workspaces: %w", err)
	}
	var ownedProjectIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return fmt.Errorf("orgs: remove member: scan owned workspace: %w", err)
		}
		ownedProjectIDs = append(ownedProjectIDs, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return fmt.Errorf("orgs: remove member: iterate owned workspaces: %w", err)
	}
	for _, id := range ownedProjectIDs {
		slog.WarnContext(ctx, "orgs: org member removed while still owning a project workspace; ownership left in place",
			"org_id", orgID, "user_id", userID, "project_id", id)
	}

	if _, err := tx.Exec(ctx,
		`UPDATE project_members SET status = 'removed', left_at = now(), updated_at = now()
		  WHERE user_id = $2 AND role <> 'owner' AND status IN ('invited', 'active')
		    AND project_id IN (SELECT id FROM workspace_projects WHERE org_id = $1)`,
		orgID, userID,
	); err != nil {
		return fmt.Errorf("orgs: remove member: leave workspaces: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`DELETE FROM project_track_members
		  WHERE user_id = $2 AND project_id IN (SELECT id FROM workspace_projects WHERE org_id = $1)`,
		orgID, userID,
	); err != nil {
		return fmt.Errorf("orgs: remove member: delete track memberships: %w", err)
	}

	// Project Workspace Phase 4 (docs/project-workspace-plan/contract-phase4.md
	// 4c): the same open-item unassign + leaderless-track cascade
	// workspace.Service.RemoveMember runs for a single project-level removal,
	// applied here across every workspace this org member touches at once.
	// Raw SQL for the same reason as the block above (no workspace import,
	// see this function's own doc comment) — an unassign is still logged as a
	// real event (source='system', actor NULL: there is no per-project actor
	// for an org-wide action), just without workspace's own notify-managers
	// step: this path has no notifications.Service in hand (MemberService
	// isn't constructed with one), so the resulting unassigned-owner/
	// leaderless-track state is surfaced to managers passively, the next time
	// they open the affected project's dashboard (NeedsAttention already
	// lists leaderless tracks and — once an owner-less item stops making
	// progress — it will show up there too), rather than actively pushed.
	// Documented as this decision's own follow-up rather than wiring a new
	// dependency into MemberService for one cross-cutting admin action.
	if _, err := tx.Exec(ctx,
		`INSERT INTO work_item_events (project_id, item_id, source, kind, field, from_value, reason)
		 SELECT w.project_id, w.id, 'system', 'unassign', 'owner', $2, 'member removed from organization'
		   FROM work_item_assignees wia
		   JOIN work_items w ON w.id = wia.item_id
		  WHERE wia.user_id = $2 AND wia.role = 'owner'
		    AND w.project_id IN (SELECT id FROM workspace_projects WHERE org_id = $1)
		    AND w.archived_at IS NULL AND w.status NOT IN ('done','wont_do')`,
		orgID, userID,
	); err != nil {
		return fmt.Errorf("orgs: remove member: log owner unassign events: %w", err)
	}
	if _, err := tx.Exec(ctx,
		`DELETE FROM work_item_assignees wia USING work_items w
		  WHERE wia.item_id = w.id AND wia.user_id = $2
		    AND w.project_id IN (SELECT id FROM workspace_projects WHERE org_id = $1)
		    AND w.archived_at IS NULL AND w.status NOT IN ('done','wont_do')`,
		orgID, userID,
	); err != nil {
		return fmt.Errorf("orgs: remove member: drop open item assignments: %w", err)
	}
	if _, err := tx.Exec(ctx,
		`UPDATE project_tracks SET lead_user_id = NULL, updated_at = now()
		  WHERE lead_user_id = $2 AND project_id IN (SELECT id FROM workspace_projects WHERE org_id = $1)`,
		orgID, userID,
	); err != nil {
		return fmt.Errorf("orgs: remove member: clear led tracks: %w", err)
	}
	return nil
}

func (s *MemberService) fetchMember(ctx context.Context, orgID, memberID string) (*Member, error) {
	var m Member
	err := s.pool.QueryRow(ctx,
		`SELECT m.id, m.user_id, u.name, u.email, u.avatar_url, m.role, m.status, m.created_at
		 FROM org_members m
		 JOIN users u ON u.id = m.user_id
		 WHERE m.id = $1 AND m.org_id = $2`,
		memberID, orgID,
	).Scan(&m.ID, &m.UserID, &m.Name, &m.Email, &m.AvatarURL, &m.Role, &m.Status, &m.JoinedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: fetch member: %w", err)
	}
	return &m, nil
}
