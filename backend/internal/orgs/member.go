package orgs

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/session"
)

// MemberService manages org membership records.
type MemberService struct {
	pool  *pgxpool.Pool
	cache *session.Cache
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

// List returns cursor-paginated members with user info joined.
// Excludes members with status='removed'.
func (s *MemberService) List(ctx context.Context, orgID, cursor string, limit int) (*MemberPage, error) {
	cursorCreatedAt, cursorID, err := decodeCursor(cursor)
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
		page.NextCursor = encodeCursor(last.JoinedAt, last.ID)
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

	// Owners can only be managed by other owners.
	if target.Role == RoleOwner && actorRole != RoleOwner {
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
	}

	// Re-fetch with user info for full response.
	result, err := s.fetchMember(ctx, orgID, memberID)
	if err != nil {
		return nil, err
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "member.updated",
		TargetType: "member",
		TargetID:   &memberID,
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

	if _, err := s.pool.Exec(ctx,
		`UPDATE org_members SET status = 'removed', updated_at = now() WHERE id = $1 AND org_id = $2`,
		memberID, orgID,
	); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23514" && strings.Contains(pgErr.ConstraintName, "last_owner") {
			return ErrLastOwner
		}
		return fmt.Errorf("orgs: remove member: %w", err)
	}

	// Revoke tenant_admin so a future re-add (e.g. as a plain learner) doesn't
	// silently inherit admin.* permissions from a role grant that predates it.
	if target.Role == RoleOwner || target.Role == RoleAdmin {
		if err := syncTenantAdminRole(ctx, s.pool, orgID, target.UserID, "removed"); err != nil {
			return fmt.Errorf("orgs: remove member: sync tenant_admin role: %w", err)
		}
	}

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
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "member.removed",
		TargetType: "member",
		TargetID:   &memberID,
		BeforeState: target,
	})
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

