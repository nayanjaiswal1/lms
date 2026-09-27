package orgs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Project-workspace invites (docs/project-workspace-plan/02-auth-security.md
// §4.6). An accepted interest on a workspace becomes an org invite with role
// learner, linked back via project_interests.invite_id. The accept runs in the
// workspace's own transaction (seat lock → invite → interest update), so the
// invite row is written on that tx; the token is issued later by the email
// job, so a plaintext credential never sits in a job payload.

// projectInviteRole is fixed: an interest never grants more than learner.
const projectInviteRole = RoleLearner

// projectInviteTTL matches Create/Resend.
const projectInviteTTL = 7 * 24 * time.Hour

// pendingTokenHash marks an invite row whose token hasn't been issued yet.
// No hashInviteToken output can equal it, so the row is unusable until
// IssueProjectInviteToken runs.
const pendingTokenHash = "pending"

// CreateForProject issues (or reuses) the pending org invite for email on
// tx. It skips CanGrantRole: the caller is authorized by the workspace's
// RequireProjectRole(manager) gate, and the role is fixed to learner.
// Returns ErrAlreadyMember when email already belongs to an active org
// member — the caller adds them to the project directly instead.
func (s *InviteService) CreateForProject(ctx context.Context, tx pgx.Tx, orgID, actorUserID, email string) (string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return "", fmt.Errorf("invalid_email")
	}

	var member bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM org_members m JOIN users u ON u.id = m.user_id
		                WHERE m.org_id = $1 AND lower(u.email) = $2 AND m.status = 'active')`,
		orgID, email,
	).Scan(&member); err != nil {
		return "", fmt.Errorf("orgs: create project invite: check membership: %w", err)
	}
	if member {
		return "", ErrAlreadyMember
	}

	// One pending invite per org+email (uq_org_invite_pending): reuse it so a
	// person accepted onto two projects gets one invite that joins both.
	var inviteID string
	err := tx.QueryRow(ctx,
		`SELECT id FROM org_invites
		  WHERE org_id = $1 AND email = $2 AND accepted_at IS NULL AND revoked_at IS NULL
		  FOR UPDATE`,
		orgID, email,
	).Scan(&inviteID)
	if err == nil {
		return inviteID, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", fmt.Errorf("orgs: create project invite: find pending: %w", err)
	}

	if err := tx.QueryRow(ctx,
		`INSERT INTO org_invites (org_id, email, role, invited_by_user_id, token_hash, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 RETURNING id`,
		orgID, email, projectInviteRole, actorUserID, pendingTokenHash, time.Now().Add(projectInviteTTL),
	).Scan(&inviteID); err != nil {
		return "", fmt.Errorf("orgs: create project invite: insert: %w", err)
	}

	after, err := json.Marshal(map[string]string{"email": email, "role": projectInviteRole, "source": "project_interest"})
	if err != nil {
		return "", fmt.Errorf("orgs: create project invite: marshal audit: %w", err)
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO audit_logs (org_id, actor_user_id, action, target_type, target_id, after_state)
		 VALUES ($1, $2, 'invite.created', 'invite', $3, $4)`,
		orgID, actorUserID, inviteID, string(after),
	); err != nil {
		return "", fmt.Errorf("orgs: create project invite: audit: %w", err)
	}
	return inviteID, nil
}

// IssueProjectInviteToken mints a fresh deliverable token for a pending
// invite and resets its expiry — called by the invite-email job right before
// sending. Any previously issued link for the invite stops working.
func (s *InviteService) IssueProjectInviteToken(ctx context.Context, orgID, inviteID string) (*Invite, string, error) {
	rawToken, err := generateRawToken()
	if err != nil {
		return nil, "", fmt.Errorf("orgs: issue project invite token: %w", err)
	}
	deliverable := inviteID + ":" + rawToken

	var inv Invite
	err = s.pool.QueryRow(ctx,
		`UPDATE org_invites
		    SET token_hash = $1, expires_at = $2, updated_at = now()
		  WHERE id = $3 AND org_id = $4 AND accepted_at IS NULL AND revoked_at IS NULL
		  RETURNING id, org_id, email, role, invited_by_user_id, expires_at, accepted_at, revoked_at, created_at`,
		hashInviteToken(deliverable), time.Now().Add(projectInviteTTL), inviteID, orgID,
	).Scan(&inv.ID, &inv.OrgID, &inv.Email, &inv.Role, &inv.InvitedByID,
		&inv.ExpiresAt, &inv.AcceptedAt, &inv.RevokedAt, &inv.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, "", ErrNotFound
	}
	if err != nil {
		return nil, "", fmt.Errorf("orgs: issue project invite token: %w", err)
	}
	return &inv, deliverable, nil
}

// inviteHasProjectInterests reports whether any workspace interest points at
// this invite.
func inviteHasProjectInterests(ctx context.Context, tx pgx.Tx, inviteID string) (bool, error) {
	var linked bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM project_interests WHERE invite_id = $1)`, inviteID,
	).Scan(&linked); err != nil {
		return false, fmt.Errorf("orgs: join: check project interests: %w", err)
	}
	return linked, nil
}

// joinLinkedProjects adds the joining user to every workspace that accepted
// them through this invite, inside Join's transaction. Lock order matches the
// workspace package: project row first, then member/interest rows. Projects
// no longer recruiting/active are skipped and their titles returned so the
// user sees "project no longer active".
func joinLinkedProjects(ctx context.Context, tx pgx.Tx, inviteID, userID string) ([]string, error) {
	rows, err := tx.Query(ctx,
		`SELECT p.id, p.title, p.project_status
		   FROM workspace_projects p
		  WHERE p.id IN (SELECT project_id FROM project_interests WHERE invite_id = $1 AND status = 'accepted')
		  ORDER BY p.id
		  FOR UPDATE OF p`,
		inviteID,
	)
	if err != nil {
		return nil, fmt.Errorf("orgs: join: lock linked projects: %w", err)
	}
	type linked struct{ id, title, status string }
	var projects []linked
	for rows.Next() {
		var l linked
		if err := rows.Scan(&l.id, &l.title, &l.status); err != nil {
			rows.Close()
			return nil, fmt.Errorf("orgs: join: scan linked project: %w", err)
		}
		projects = append(projects, l)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("orgs: join: iterate linked projects: %w", err)
	}

	var inactive []string
	for _, p := range projects {
		if p.status != "recruiting" && p.status != "active" {
			inactive = append(inactive, p.title)
			if _, err := tx.Exec(ctx,
				`UPDATE project_interests SET user_id = $3, updated_at = now()
				  WHERE project_id = $1 AND invite_id = $2 AND status = 'accepted'`,
				p.id, inviteID, userID,
			); err != nil {
				return nil, fmt.Errorf("orgs: join: link inactive interest: %w", err)
			}
			continue
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO project_members (project_id, user_id, role, status, added_by)
			 SELECT $1, $2, 'member', 'active', i.reviewed_by
			   FROM project_interests i WHERE i.project_id = $1 AND i.invite_id = $3 AND i.status = 'accepted'
			 ON CONFLICT (project_id, user_id) DO UPDATE
			    SET status = 'active', left_at = NULL, updated_at = now()
			  WHERE project_members.status <> 'active'`,
			p.id, userID, inviteID,
		); err != nil {
			return nil, fmt.Errorf("orgs: join: add project member: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`UPDATE project_interests SET status = 'joined', user_id = $3, updated_at = now()
			  WHERE project_id = $1 AND invite_id = $2 AND status = 'accepted'`,
			p.id, inviteID, userID,
		); err != nil {
			return nil, fmt.Errorf("orgs: join: mark interest joined: %w", err)
		}
	}
	return inactive, nil
}
