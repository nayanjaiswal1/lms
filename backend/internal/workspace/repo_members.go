package workspace

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// ─── members ────────────────────────────────────────────────────────────────

const memberColumns = `pm.project_id, pm.user_id, u.name, u.email, u.avatar_url, pm.role, pm.status,
	pm.added_by, pm.joined_at, pm.left_at,
	COALESCE(array_agg(DISTINCT tm.track_id) FILTER (WHERE tm.track_id IS NOT NULL), '{}') AS track_ids,
	COALESCE((SELECT (100 * count(*) FILTER (WHERE op.step_id IS NOT NULL)) / NULLIF(count(*), 0)
	            FROM onboarding_steps os
	            LEFT JOIN onboarding_progress op ON op.step_id = os.id AND op.user_id = pm.user_id
	           WHERE os.project_id = pm.project_id AND os.required = true), 0) AS onboarding_pct`

func scanMember(row pgx.Row) (*Member, error) {
	var m Member
	err := row.Scan(&m.ProjectID, &m.UserID, &m.Name, &m.Email, &m.AvatarURL, &m.Role, &m.Status,
		&m.AddedBy, &m.JoinedAt, &m.LeftAt, &m.TrackIDs, &m.OnboardingPct)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan member: %w", err)
	}
	return &m, nil
}

// ListMembers returns every non-removed member of a project.
func (r *Repo) ListMembers(ctx context.Context, db DBTX, projectID string) ([]Member, error) {
	rows, err := db.Query(ctx,
		`SELECT `+memberColumns+`
		   FROM project_members pm
		   JOIN users u ON u.id = pm.user_id
		   LEFT JOIN project_track_members tm ON tm.project_id = pm.project_id AND tm.user_id = pm.user_id AND tm.status = 'approved'
		  WHERE pm.project_id = $1 AND pm.status <> 'removed'
		  GROUP BY pm.project_id, pm.user_id, u.name, u.email, u.avatar_url, pm.role, pm.status, pm.added_by, pm.joined_at, pm.left_at
		  ORDER BY pm.joined_at ASC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list members: %w", err)
	}
	defer rows.Close()

	out := []Member{}
	for rows.Next() {
		m, err := scanMember(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *m)
	}
	return out, rows.Err()
}

// GetMember returns one project's member row for userID, including left/removed.
func (r *Repo) GetMember(ctx context.Context, db DBTX, projectID, userID string) (*Member, error) {
	return scanMember(db.QueryRow(ctx,
		`SELECT `+memberColumns+`
		   FROM project_members pm
		   JOIN users u ON u.id = pm.user_id
		   LEFT JOIN project_track_members tm ON tm.project_id = pm.project_id AND tm.user_id = pm.user_id AND tm.status = 'approved'
		  WHERE pm.project_id = $1 AND pm.user_id = $2
		  GROUP BY pm.project_id, pm.user_id, u.name, u.email, u.avatar_url, pm.role, pm.status, pm.added_by, pm.joined_at, pm.left_at`,
		projectID, userID))
}

// ListManagerUserIDs returns the active owner+manager user ids on a project —
// the standard recipient set for a manager-escalation notification (brief/doc
// review reminders, S1 bug triage, last-reviewer-removed).
func (r *Repo) ListManagerUserIDs(ctx context.Context, db DBTX, projectID string) ([]string, error) {
	rows, err := db.Query(ctx,
		`SELECT user_id FROM project_members WHERE project_id = $1 AND status = 'active' AND role IN ('owner','manager')`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list manager ids: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("workspace: scan manager id: %w", err)
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// IsActiveOrgMember reports whether userID is an active member of orgID —
// AddMember and interest-accept both require this before adding someone.
func (r *Repo) IsActiveOrgMember(ctx context.Context, db DBTX, orgID, userID string) (bool, error) {
	var active bool
	err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM org_members WHERE org_id = $1 AND user_id = $2 AND status = 'active')`,
		orgID, userID,
	).Scan(&active)
	if err != nil {
		return false, fmt.Errorf("workspace: check org membership: %w", err)
	}
	return active, nil
}

// FindActiveOrgMemberByEmail resolves email to an active org member's user
// id — ReviewInterest's accept path uses this to decide direct-add vs.
// invite-issue without ever telling the caller which branch it took (02 §4.4).
func (r *Repo) FindActiveOrgMemberByEmail(ctx context.Context, db DBTX, orgID, email string) (string, bool, error) {
	var userID string
	err := db.QueryRow(ctx,
		`SELECT u.id FROM users u JOIN org_members m ON m.user_id = u.id
		  WHERE m.org_id = $1 AND lower(u.email) = lower($2) AND m.status = 'active'`,
		orgID, email,
	).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("workspace: find org member by email: %w", err)
	}
	return userID, true, nil
}

// UpsertMember inserts a member row, or re-activates a left/removed row as
// status (never touching an already active/invited row — ON CONFLICT DO
// NOTHING lets the caller detect "already on this project" itself).
func (r *Repo) UpsertMember(ctx context.Context, db DBTX, projectID, userID, role, status string, addedBy *string) error {
	tag, err := db.Exec(ctx,
		`INSERT INTO project_members (project_id, user_id, role, status, added_by)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (project_id, user_id) DO UPDATE
		    SET role = $3, status = $4, added_by = $5, left_at = NULL, updated_at = now()
		  WHERE project_members.status IN ('left', 'removed')`,
		projectID, userID, role, status, addedBy,
	)
	if err != nil {
		return fmt.Errorf("workspace: upsert member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrAlreadyMember
	}
	return nil
}

// UpdateMemberRole changes an active member's role.
func (r *Repo) UpdateMemberRole(ctx context.Context, db DBTX, projectID, userID, role string) error {
	tag, err := db.Exec(ctx,
		`UPDATE project_members SET role = $3, updated_at = now()
		  WHERE project_id = $1 AND user_id = $2 AND status IN ('active', 'invited')`,
		projectID, userID, role,
	)
	if err != nil {
		return fmt.Errorf("workspace: update member role: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetMemberStatus moves a member to left/removed, stamping left_at, in the
// caller's transaction — leave/remove also deletes track memberships (a
// separate call, see DeleteTrackMembersOfUser) in the same tx.
func (r *Repo) SetMemberStatus(ctx context.Context, tx pgx.Tx, projectID, userID, status string) error {
	tag, err := tx.Exec(ctx,
		`UPDATE project_members SET status = $3, left_at = now(), updated_at = now()
		  WHERE project_id = $1 AND user_id = $2 AND status IN ('active', 'invited')`,
		projectID, userID, status,
	)
	if err != nil {
		return fmt.Errorf("workspace: set member status: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// RespondToInvite accepts (status active) or declines (status left, since the
// invite never became real membership) a pending invited row.
func (r *Repo) RespondToInvite(ctx context.Context, db DBTX, projectID, userID string, accept bool) error {
	status := MemberActive
	if !accept {
		status = MemberLeft
	}
	tag, err := db.Exec(ctx,
		`UPDATE project_members SET status = $3, left_at = CASE WHEN $3 = 'left' THEN now() ELSE NULL END, updated_at = now()
		  WHERE project_id = $1 AND user_id = $2 AND status = 'invited'`,
		projectID, userID, status,
	)
	if err != nil {
		return fmt.Errorf("workspace: respond to invite: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SwapOwner transfers ownership in one statement pair: whoever currently
// holds role='owner' (there is exactly one, by the partial unique index)
// becomes a manager, and the target (an active manager) becomes owner. Both
// rows are touched inside the caller's transaction, which must already hold
// the project's lock. Looking the current owner up by role, rather than
// trusting a caller-supplied id, keeps this correct even when the caller is
// an overseer acting as owner without actually holding the row.
func (r *Repo) SwapOwner(ctx context.Context, tx pgx.Tx, projectID, newOwnerID string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE project_members SET role = 'manager', updated_at = now() WHERE project_id = $1 AND role = 'owner'`,
		projectID,
	); err != nil {
		return fmt.Errorf("workspace: transfer owner: demote old owner: %w", err)
	}
	tag, err := tx.Exec(ctx,
		`UPDATE project_members SET role = 'owner', updated_at = now()
		  WHERE project_id = $1 AND user_id = $2 AND role = 'manager' AND status = 'active'`,
		projectID, newOwnerID,
	)
	if err != nil {
		return fmt.Errorf("workspace: transfer owner: promote new owner: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrInvalidInput
	}
	return nil
}

// CountSeatMembers counts active/invited manager+member rows — the
// membership half of the seat definition (SeatsUsed adds pending-accepted
// interests on top).
func (r *Repo) CountSeatMembers(ctx context.Context, db DBTX, projectID string) (int, error) {
	var n int
	err := db.QueryRow(ctx,
		`SELECT count(*) FROM project_members
		  WHERE project_id = $1 AND status IN ('active', 'invited') AND role IN ('manager', 'member')`,
		projectID,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("workspace: count seat members: %w", err)
	}
	return n, nil
}

// CountActiveManagersAndMembers counts active-only (not invited) manager+
// member rows — SetProjectStatus's recruiting->active precondition
// ("active manager/member count >= team_size_min").
func (r *Repo) CountActiveManagersAndMembers(ctx context.Context, db DBTX, projectID string) (int, error) {
	var n int
	err := db.QueryRow(ctx,
		`SELECT count(*) FROM project_members WHERE project_id = $1 AND status = 'active' AND role IN ('manager', 'member')`,
		projectID,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("workspace: count active members: %w", err)
	}
	return n, nil
}

// ─── tracks ─────────────────────────────────────────────────────────────────

func scanTrack(row pgx.Row) (*Track, error) {
	var t Track
	err := row.Scan(&t.ID, &t.ProjectID, &t.Name, &t.LeadUserID, &t.LeadName, &t.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan track: %w", err)
	}
	t.Members = []TrackMember{}
	return &t, nil
}

const trackColumns = `t.id, t.project_id, t.name, t.lead_user_id, lu.name, t.created_at`

// ListTracks returns every track in a project with its members attached.
func (r *Repo) ListTracks(ctx context.Context, db DBTX, projectID string) ([]Track, error) {
	rows, err := db.Query(ctx,
		`SELECT `+trackColumns+`
		   FROM project_tracks t
		   LEFT JOIN users lu ON lu.id = t.lead_user_id
		  WHERE t.project_id = $1
		  ORDER BY t.name ASC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list tracks: %w", err)
	}
	defer rows.Close()

	byID := map[string]*Track{}
	out := []Track{}
	for rows.Next() {
		t, err := scanTrack(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
		byID[t.ID] = &out[len(out)-1]
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	memberRows, err := db.Query(ctx,
		`SELECT tm.track_id, tm.user_id, u.name, tm.status, tm.approved_by
		   FROM project_track_members tm JOIN users u ON u.id = tm.user_id
		  WHERE tm.project_id = $1`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list track members: %w", err)
	}
	defer memberRows.Close()
	for memberRows.Next() {
		var trackID string
		var tm TrackMember
		if err := memberRows.Scan(&trackID, &tm.UserID, &tm.Name, &tm.Status, &tm.ApprovedBy); err != nil {
			return nil, fmt.Errorf("workspace: scan track member: %w", err)
		}
		if t, ok := byID[trackID]; ok {
			t.Members = append(t.Members, tm)
		}
	}
	return out, memberRows.Err()
}

// GetTrack returns one track (with members) scoped to its project.
func (r *Repo) GetTrack(ctx context.Context, db DBTX, projectID, trackID string) (*Track, error) {
	t, err := scanTrack(db.QueryRow(ctx,
		`SELECT `+trackColumns+` FROM project_tracks t LEFT JOIN users lu ON lu.id = t.lead_user_id
		  WHERE t.id = $1 AND t.project_id = $2`,
		trackID, projectID))
	if err != nil {
		return nil, err
	}
	rows, err := db.Query(ctx,
		`SELECT tm.user_id, u.name, tm.status, tm.approved_by FROM project_track_members tm
		   JOIN users u ON u.id = tm.user_id WHERE tm.track_id = $1`,
		trackID)
	if err != nil {
		return nil, fmt.Errorf("workspace: get track members: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var tm TrackMember
		if err := rows.Scan(&tm.UserID, &tm.Name, &tm.Status, &tm.ApprovedBy); err != nil {
			return nil, fmt.Errorf("workspace: scan track member: %w", err)
		}
		t.Members = append(t.Members, tm)
	}
	return t, rows.Err()
}

// TrackNameTaken reports whether name (case-insensitive) is already used by
// another track in the project.
func (r *Repo) TrackNameTaken(ctx context.Context, db DBTX, projectID, name, excludeTrackID string) (bool, error) {
	var taken bool
	err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM project_tracks WHERE project_id = $1 AND lower(name) = lower($2) AND id <> $3)`,
		projectID, name, excludeTrackID,
	).Scan(&taken)
	if err != nil {
		return false, fmt.Errorf("workspace: check track name: %w", err)
	}
	return taken, nil
}

func (r *Repo) InsertTrack(ctx context.Context, db DBTX, projectID, name string, leadUserID *string, createdBy string) (*Track, error) {
	var id string
	if err := db.QueryRow(ctx,
		`INSERT INTO project_tracks (project_id, name, lead_user_id, created_by) VALUES ($1,$2,$3,$4) RETURNING id`,
		projectID, name, leadUserID, createdBy,
	).Scan(&id); err != nil {
		return nil, fmt.Errorf("workspace: insert track: %w", err)
	}
	return r.GetTrack(ctx, db, projectID, id)
}

// UpdateTrack applies a partial patch.
func (r *Repo) UpdateTrack(ctx context.Context, db DBTX, projectID, trackID string, name *string, leadUserID *string, clearLead bool) (*Track, error) {
	tag, err := db.Exec(ctx,
		`UPDATE project_tracks SET
			name = COALESCE($3, name),
			lead_user_id = CASE WHEN $4::boolean THEN NULL WHEN $5::uuid IS NOT NULL THEN $5::uuid ELSE lead_user_id END,
			updated_at = now()
		 WHERE id = $1 AND project_id = $2`,
		trackID, projectID, name, clearLead, leadUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("workspace: update track: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return nil, ErrNotFound
	}
	return r.GetTrack(ctx, db, projectID, trackID)
}

// DeleteTrack removes a track (project_track_members cascades; work_items in
// Phase 2+ hold the track via a non-cascading FK, so a track in use there
// will fail with a foreign-key error surfaced as a 500 until Phase 2 adds its
// own "track in use" check).
func (r *Repo) DeleteTrack(ctx context.Context, db DBTX, projectID, trackID string) error {
	tag, err := db.Exec(ctx, `DELETE FROM project_tracks WHERE id = $1 AND project_id = $2`, trackID, projectID)
	if err != nil {
		return fmt.Errorf("workspace: delete track: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpsertTrackMember adds userID to a track at status (pending for self-join,
// approved for a manager/lead add), re-approving a previously-left pick.
func (r *Repo) UpsertTrackMember(ctx context.Context, db DBTX, trackID, projectID, userID, status string, approvedBy *string) error {
	if _, err := db.Exec(ctx,
		`INSERT INTO project_track_members (track_id, project_id, user_id, status, approved_by)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (track_id, user_id) DO UPDATE SET status = $4, approved_by = $5`,
		trackID, projectID, userID, status, approvedBy,
	); err != nil {
		return fmt.Errorf("workspace: upsert track member: %w", err)
	}
	return nil
}

// ApproveTrackMember flips a pending pick to approved.
func (r *Repo) ApproveTrackMember(ctx context.Context, db DBTX, trackID, userID, approvedBy string) error {
	tag, err := db.Exec(ctx,
		`UPDATE project_track_members SET status = 'approved', approved_by = $3 WHERE track_id = $1 AND user_id = $2`,
		trackID, userID, approvedBy,
	)
	if err != nil {
		return fmt.Errorf("workspace: approve track member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) DeleteTrackMember(ctx context.Context, db DBTX, trackID, userID string) error {
	tag, err := db.Exec(ctx, `DELETE FROM project_track_members WHERE track_id = $1 AND user_id = $2`, trackID, userID)
	if err != nil {
		return fmt.Errorf("workspace: delete track member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteTrackMembersOfUser removes every track membership a leaving/removed
// user holds in a project, in the caller's transaction.
func (r *Repo) DeleteTrackMembersOfUser(ctx context.Context, tx pgx.Tx, projectID, userID string) error {
	if _, err := tx.Exec(ctx,
		`DELETE FROM project_track_members WHERE project_id = $1 AND user_id = $2`,
		projectID, userID,
	); err != nil {
		return fmt.Errorf("workspace: delete track memberships: %w", err)
	}
	return nil
}

// ClearTrackLeadIfUser nulls lead_user_id on every track userID currently
// leads (RemoveMember's cascade, contract-phase4.md 4c: "track becomes
// leaderless — new assignments blocked until a lead is set") and returns
// which track ids were cleared, in the caller's transaction.
func (r *Repo) ClearTrackLeadIfUser(ctx context.Context, tx pgx.Tx, projectID, userID string) ([]string, error) {
	rows, err := tx.Query(ctx,
		`UPDATE project_tracks SET lead_user_id = NULL, updated_at = now()
		  WHERE project_id = $1 AND lead_user_id = $2 RETURNING id`,
		projectID, userID)
	if err != nil {
		return nil, fmt.Errorf("workspace: clear track lead: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// ListApprovedTrackMemberIDs returns the approved members of one track — the
// dashboard's own track-lead visibility scope (D15: "track lead: project
// totals + own track rows/people").
// AssigneeCandidate is one SuggestAssignees candidate — an active member's
// name, self-reported skills (from user_profiles.skills), and current
// owned-in-progress WIP.
type AssigneeCandidate struct {
	Person PersonRef
	Skills []string
	WIP    int
}

// ListAssigneeCandidates returns every active member of projectID with their
// profile skills and live WIP — SuggestAssignees' own candidate pool
// (contract-phase5.md 5c; D20 — the caller never caches this).
func (r *Repo) ListAssigneeCandidates(ctx context.Context, db DBTX, projectID string) ([]AssigneeCandidate, error) {
	rows, err := db.Query(ctx,
		`SELECT pm.user_id, u.name, COALESCE(up.skills, '[]'::jsonb),
		        (SELECT count(*) FROM work_item_assignees a JOIN work_items w ON w.id = a.item_id
		           WHERE a.user_id = pm.user_id AND a.role = 'owner' AND w.project_id = pm.project_id
		             AND w.status = 'in_progress' AND w.archived_at IS NULL)
		   FROM project_members pm
		   JOIN users u ON u.id = pm.user_id
		   LEFT JOIN user_profiles up ON up.user_id = pm.user_id
		  WHERE pm.project_id = $1 AND pm.status = 'active'
		  ORDER BY u.name`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list assignee candidates: %w", err)
	}
	defer rows.Close()
	out := []AssigneeCandidate{}
	for rows.Next() {
		var c AssigneeCandidate
		var skillsRaw []byte
		if err := rows.Scan(&c.Person.UserID, &c.Person.Name, &skillsRaw, &c.WIP); err != nil {
			return nil, fmt.Errorf("workspace: scan assignee candidate: %w", err)
		}
		var skills []struct {
			SkillName string `json:"skill_name"`
		}
		if len(skillsRaw) > 0 {
			if err := json.Unmarshal(skillsRaw, &skills); err != nil {
				return nil, fmt.Errorf("workspace: unmarshal candidate skills: %w", err)
			}
		}
		for _, sk := range skills {
			if sk.SkillName != "" {
				c.Skills = append(c.Skills, sk.SkillName)
			}
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *Repo) ListApprovedTrackMemberIDs(ctx context.Context, db DBTX, trackID string) ([]string, error) {
	rows, err := db.Query(ctx, `SELECT user_id FROM project_track_members WHERE track_id = $1 AND status = 'approved'`, trackID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list approved track member ids: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// IsTrackLead reports whether userID leads trackID.
func (r *Repo) IsTrackLead(ctx context.Context, db DBTX, projectID, trackID, userID string) (bool, error) {
	var lead bool
	err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM project_tracks WHERE id = $1 AND project_id = $2 AND lead_user_id = $3)`,
		trackID, projectID, userID,
	).Scan(&lead)
	if err != nil {
		return false, fmt.Errorf("workspace: check track lead: %w", err)
	}
	return lead, nil
}

// IsAnyTrackLead reports whether userID leads any track in the project —
// GetProject's LedTrackIDs, and IsTrackLeadOfProject-style checks.
func (r *Repo) ListLedTrackIDs(ctx context.Context, db DBTX, projectID, userID string) ([]string, error) {
	rows, err := db.Query(ctx, `SELECT id FROM project_tracks WHERE project_id = $1 AND lead_user_id = $2`, projectID, userID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list led tracks: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// ListMyTrackIDs returns the tracks userID is an approved member of.
func (r *Repo) ListMyTrackIDs(ctx context.Context, db DBTX, projectID, userID string) ([]string, error) {
	rows, err := db.Query(ctx,
		`SELECT track_id FROM project_track_members WHERE project_id = $1 AND user_id = $2 AND status = 'approved'`,
		projectID, userID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list my tracks: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}
