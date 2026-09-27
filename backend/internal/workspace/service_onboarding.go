package workspace

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/notifications"
)

// ─── members ────────────────────────────────────────────────────────────────

// ListMembers hides email addresses from below-manager callers (02 §3
// "Emails only for manager+").
func (s *Service) ListMembers(ctx context.Context, pc *ProjectCtx) ([]Member, error) {
	members, err := s.repo.ListMembers(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	if !RoleAtLeast(pc.Role, RoleManager) {
		for i := range members {
			members[i].Email = ""
		}
	}
	return members, nil
}

var addableRoles = map[string]bool{RoleMember: true, RoleViewer: true, RoleManager: true}

// AddMember adds an existing, active org member to the project as invited
// (they confirm via RespondToInvite). Only the owner may add someone as
// manager.
func (s *Service) AddMember(ctx context.Context, pc *ProjectCtx, req AddMemberRequest) (*Member, error) {
	if !addableRoles[req.Role] {
		return nil, fmt.Errorf("%w: role must be member, viewer, or manager", ErrInvalidInput)
	}
	if req.Role == RoleManager && pc.Role != RoleOwner {
		return nil, ErrForbidden
	}

	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		p, err := s.repo.LockProject(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		if req.UserID == "" {
			email := strings.ToLower(strings.TrimSpace(req.Email))
			if email == "" {
				return fmt.Errorf("%w: user_id or email is required", ErrInvalidInput)
			}
			err := tx.QueryRow(ctx,
				`SELECT u.id FROM users u JOIN org_members m ON m.user_id = u.id
				  WHERE m.org_id = $1 AND m.status = 'active' AND lower(u.email) = $2`,
				pc.OrgID, email,
			).Scan(&req.UserID)
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotOrgMember
			}
			if err != nil {
				return fmt.Errorf("workspace: add member: resolve email: %w", err)
			}
		}
		active, err := s.repo.IsActiveOrgMember(ctx, tx, pc.OrgID, req.UserID)
		if err != nil {
			return err
		}
		if !active {
			return ErrNotOrgMember
		}
		if req.Role != RoleViewer {
			seatMembers, err := s.repo.CountSeatMembers(ctx, tx, pc.ProjectID)
			if err != nil {
				return err
			}
			pending, err := s.repo.CountAcceptedPendingInterests(ctx, tx, pc.ProjectID)
			if err != nil {
				return err
			}
			if seatMembers+pending >= p.TeamSizeMax {
				return ErrSeatsFull
			}
		}
		addedBy := pc.UserID
		if err := s.repo.UpsertMember(ctx, tx, pc.ProjectID, req.UserID, req.Role, MemberInvited, &addedBy); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "project.member_added", "project_member", req.UserID, map[string]string{"role": req.Role})
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.repo.GetMember(ctx, s.pool, pc.ProjectID, req.UserID)
}

// RespondToInvite is the invitee's own accept/decline of a pending
// project_members row — no RequireProjectRole, since a not-yet-accepted
// invitee isn't a member yet. Accepting into a GitLab-provisioned project
// grants roster access best-effort (contract-phase4.md 4c) — declining
// leaves the invite row a plain 'left' status with nothing on GitLab to grant.
func (s *Service) RespondToInvite(ctx context.Context, orgID, userID, projectID string, accept bool) error {
	project, err := s.repo.GetProject(ctx, s.pool, orgID, projectID)
	if err != nil {
		return err
	}
	if err := s.repo.RespondToInvite(ctx, s.pool, projectID, userID, accept); err != nil {
		return err
	}
	action := "project.invite_declined"
	if accept {
		action = "project.invite_accepted"
		if project.TeamID != nil {
			if m, err := s.repo.GetMember(ctx, s.pool, projectID, userID); err == nil {
				s.grantGitlabAccess(ctx, orgID, *project.TeamID, userID, m.Role == RoleOwner || m.Role == RoleManager)
			}
		}
	}
	writeAudit(ctx, s.pool, orgID, &userID, action, "project_member", userID, nil)
	return nil
}

// ListMyInvitations lists every project the caller has a pending invite on.
func (s *Service) ListMyInvitations(ctx context.Context, orgID, userID string) ([]ProjectSummary, error) {
	return s.repo.ListInvitations(ctx, s.pool, orgID, userID)
}

// UpdateMemberRole: a manager may only set member/viewer; only the owner may
// grant or revoke manager; the owner role itself never changes here
// (TransferOwner is the only path to it).
func (s *Service) UpdateMemberRole(ctx context.Context, pc *ProjectCtx, userID, role string) (*Member, error) {
	if !addableRoles[role] {
		return nil, fmt.Errorf("%w: role must be member, viewer, or manager", ErrInvalidInput)
	}
	if role == RoleManager && pc.Role != RoleOwner {
		return nil, ErrForbidden
	}
	target, err := s.repo.GetMember(ctx, s.pool, pc.ProjectID, userID)
	if err != nil {
		return nil, err
	}
	if target.Role == RoleOwner {
		return nil, ErrForbidden
	}
	if target.Role == RoleManager && pc.Role != RoleOwner {
		return nil, ErrForbidden
	}
	if err := s.repo.UpdateMemberRole(ctx, s.pool, pc.ProjectID, userID, role); err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.member_role_changed", "project_member", userID, map[string]string{"role": role})
	return s.repo.GetMember(ctx, s.pool, pc.ProjectID, userID)
}

// RemoveMember: nobody removes the owner; managers remove member/viewer;
// only the owner removes a manager; anyone may remove themselves (leave).
// Phase 4 (contract-phase4.md 4c) extends this with the leave/removal
// cascade: every open item's assignments for this user are dropped (an
// owner drop is a real unassign event, managers are notified), a track this
// user led becomes leaderless, and GitLab access is revoked best-effort
// after commit. Re-adding a left/removed row (AddMember) reactivates it in
// place — history (past events, past reviews) is never deleted.
func (s *Service) RemoveMember(ctx context.Context, pc *ProjectCtx, userID string) error {
	target, err := s.repo.GetMember(ctx, s.pool, pc.ProjectID, userID)
	if err != nil {
		return err
	}
	if target.Role == RoleOwner {
		return ErrOwnerCantLeave
	}
	isSelf := userID == pc.UserID
	if !isSelf {
		managerOrAbove := pc.Role == RoleManager || pc.Role == RoleOwner
		if !managerOrAbove {
			return ErrForbidden
		}
		if target.Role == RoleManager && pc.Role != RoleOwner {
			return ErrForbidden
		}
	}
	status := MemberRemoved
	action := "project.member_removed"
	if isSelf {
		status, action = MemberLeft, "project.member_left"
	}
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return err
	}

	var droppedAssignments []LeavingItemAssignment
	var leaderlessTrackIDs []string
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		if err := s.repo.SetMemberStatus(ctx, tx, pc.ProjectID, userID, status); err != nil {
			return err
		}
		if err := s.repo.DeleteTrackMembersOfUser(ctx, tx, pc.ProjectID, userID); err != nil {
			return err
		}

		assignments, err := s.repo.ListOpenAssignmentsForUser(ctx, tx, pc.ProjectID, userID)
		if err != nil {
			return err
		}
		for _, a := range assignments {
			if err := s.repo.DeleteAssignee(ctx, tx, a.ItemID, userID, a.Role); err != nil {
				return err
			}
			if a.Role == AssigneeOwner {
				actor := pc.UserID
				reason := "member left the project"
				if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
					ProjectID: pc.ProjectID, ItemID: a.ItemID, ActorID: &actor, Source: SourceSystem, Kind: EventUnassign,
					FromValue: strPtr(userID), Reason: &reason,
				}); err != nil {
					return err
				}
			}
		}
		droppedAssignments = assignments

		cleared, err := s.repo.ClearTrackLeadIfUser(ctx, tx, pc.ProjectID, userID)
		if err != nil {
			return err
		}
		leaderlessTrackIDs = cleared

		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, action, "project_member", userID, nil)
		return nil
	})
	if err != nil {
		return err
	}

	s.notifyMemberLeftCascade(ctx, project, userID, droppedAssignments, leaderlessTrackIDs)
	if project.TeamID != nil {
		s.revokeGitlabAccess(ctx, pc.OrgID, *project.TeamID, userID)
	}
	return nil
}

// notifyMemberLeftCascade tells the project's managers what the leave/removal
// disturbed — best-effort, after commit, never fails the removal itself.
func (s *Service) notifyMemberLeftCascade(ctx context.Context, project *Project, userID string, dropped []LeavingItemAssignment, leaderlessTrackIDs []string) {
	var lostOwner []string
	for _, a := range dropped {
		if a.Role == AssigneeOwner {
			lostOwner = append(lostOwner, a.ItemKey)
		}
	}
	if len(lostOwner) == 0 && len(leaderlessTrackIDs) == 0 {
		return
	}
	managers, err := s.repo.ListManagerUserIDs(ctx, s.pool, project.ID)
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify member left cascade: list managers", "error", err)
		return
	}
	if len(managers) == 0 {
		return
	}
	body := "A member left the project."
	if len(lostOwner) > 0 {
		body += fmt.Sprintf(" These items lost their owner: %s.", strings.Join(lostOwner, ", "))
	}
	if len(leaderlessTrackIDs) > 0 {
		body += fmt.Sprintf(" %d track(s) now have no lead — new assignments are blocked until one is set.", len(leaderlessTrackIDs))
	}
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		return s.notif.NotifyMany(ctx, tx, notifications.New{
			OrgID: project.OrgID, Type: "workspace_member_left", Title: "A member left the project", Body: &body,
			EntityType: strPtr("workspace_project"), EntityID: &project.ID,
			DedupeKey: fmt.Sprintf("workspace_member_left:%s:%s", project.ID, userID),
		}, managers)
	})
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify member left cascade", "error", err)
	}
}

// ─── tracks ─────────────────────────────────────────────────────────────────

func (s *Service) ListTracks(ctx context.Context, pc *ProjectCtx) ([]Track, error) {
	return s.repo.ListTracks(ctx, s.pool, pc.ProjectID)
}

func (s *Service) validateTrackLead(ctx context.Context, pc *ProjectCtx, leadUserID *string) error {
	if leadUserID == nil {
		return nil
	}
	lead, err := s.repo.GetMember(ctx, s.pool, pc.ProjectID, *leadUserID)
	if err != nil {
		return err
	}
	if lead.Status != MemberActive {
		return fmt.Errorf("%w: track lead must be an active member", ErrInvalidInput)
	}
	return nil
}

func (s *Service) CreateTrack(ctx context.Context, pc *ProjectCtx, req CreateTrackRequest) (*Track, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" || len(name) > TrackNameMaxLen {
		return nil, &FieldError{Fields: map[string]string{"name": fmt.Sprintf("Name must be 1-%d characters.", TrackNameMaxLen)}}
	}
	taken, err := s.repo.TrackNameTaken(ctx, s.pool, pc.ProjectID, name, "")
	if err != nil {
		return nil, err
	}
	if taken {
		return nil, ErrConflict
	}
	if err := s.validateTrackLead(ctx, pc, req.LeadUserID); err != nil {
		return nil, err
	}
	t, err := s.repo.InsertTrack(ctx, s.pool, pc.ProjectID, name, req.LeadUserID, pc.UserID)
	if err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.track_created", "project_track", t.ID, map[string]string{"name": name})
	return t, nil
}

func (s *Service) UpdateTrack(ctx context.Context, pc *ProjectCtx, trackID string, req UpdateTrackRequest) (*Track, error) {
	var namePtr *string
	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if name == "" || len(name) > TrackNameMaxLen {
			return nil, &FieldError{Fields: map[string]string{"name": fmt.Sprintf("Name must be 1-%d characters.", TrackNameMaxLen)}}
		}
		taken, err := s.repo.TrackNameTaken(ctx, s.pool, pc.ProjectID, name, trackID)
		if err != nil {
			return nil, err
		}
		if taken {
			return nil, ErrConflict
		}
		namePtr = &name
	}
	if !req.ClearLead {
		if err := s.validateTrackLead(ctx, pc, req.LeadUserID); err != nil {
			return nil, err
		}
	}
	t, err := s.repo.UpdateTrack(ctx, s.pool, pc.ProjectID, trackID, namePtr, req.LeadUserID, req.ClearLead)
	if err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.track_updated", "project_track", trackID, nil)
	return t, nil
}

func (s *Service) DeleteTrack(ctx context.Context, pc *ProjectCtx, trackID string) error {
	if err := s.repo.DeleteTrack(ctx, s.pool, pc.ProjectID, trackID); err != nil {
		return err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.track_deleted", "project_track", trackID, nil)
	return nil
}

// trackPrivilege reports whether the caller may act on a track without
// being the target themselves — manager+, or that track's own lead.
func (s *Service) trackPrivilege(ctx context.Context, pc *ProjectCtx, trackID string) (bool, error) {
	if pc.Role == RoleManager || pc.Role == RoleOwner {
		return true, nil
	}
	return s.repo.IsTrackLead(ctx, s.pool, pc.ProjectID, trackID, pc.UserID)
}

// JoinTrack: a self pick lands pending; a manager/lead pick (of self or
// someone else) is approved immediately.
func (s *Service) JoinTrack(ctx context.Context, pc *ProjectCtx, trackID, userID string) error {
	privileged, err := s.trackPrivilege(ctx, pc, trackID)
	if err != nil {
		return err
	}
	if !privileged && userID != pc.UserID {
		return ErrForbidden
	}
	status := TrackMemberPending
	var approvedBy *string
	if privileged {
		status, approvedBy = TrackMemberApproved, &pc.UserID
	}
	return s.repo.UpsertTrackMember(ctx, s.pool, trackID, pc.ProjectID, userID, status, approvedBy)
}

// ApproveTrackMember flips a pending pick to approved — manager+ or that
// track's lead only.
func (s *Service) ApproveTrackMember(ctx context.Context, pc *ProjectCtx, trackID, userID string) error {
	privileged, err := s.trackPrivilege(ctx, pc, trackID)
	if err != nil {
		return err
	}
	if !privileged {
		return ErrForbidden
	}
	return s.repo.ApproveTrackMember(ctx, s.pool, trackID, userID, pc.UserID)
}

// LeaveTrack: self, that track's lead, or manager+.
func (s *Service) LeaveTrack(ctx context.Context, pc *ProjectCtx, trackID, userID string) error {
	if userID != pc.UserID {
		privileged, err := s.trackPrivilege(ctx, pc, trackID)
		if err != nil {
			return err
		}
		if !privileged {
			return ErrForbidden
		}
	}
	return s.repo.DeleteTrackMember(ctx, s.pool, trackID, userID)
}

// IsTrackLead delegates to the repo — kept on Service per the contract so
// callers never reach into s.Repo() for this one check.
func (s *Service) IsTrackLead(ctx context.Context, db DBTX, projectID, trackID, userID string) (bool, error) {
	return s.repo.IsTrackLead(ctx, db, projectID, trackID, userID)
}

// ─── onboarding ─────────────────────────────────────────────────────────────

func (s *Service) ListOnboarding(ctx context.Context, pc *ProjectCtx) ([]OnboardingStep, error) {
	return s.repo.ListOnboardingSteps(ctx, s.pool, pc.ProjectID, pc.UserID)
}

func (s *Service) CreateOnboardingStep(ctx context.Context, pc *ProjectCtx, req CreateOnboardingStepRequest) (*OnboardingStep, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" || len(title) > OnboardingTitleMax {
		return nil, &FieldError{Fields: map[string]string{"title": fmt.Sprintf("Title must be 1-%d characters.", OnboardingTitleMax)}}
	}
	required := true
	if req.Required != nil {
		required = *req.Required
	}
	position := 0
	if req.Position != nil {
		position = *req.Position
	} else {
		p, err := s.repo.NextStepPosition(ctx, s.pool, pc.ProjectID)
		if err != nil {
			return nil, err
		}
		position = p
	}
	step, err := s.repo.InsertOnboardingStep(ctx, s.pool, pc.ProjectID, title, req.WikiPageID, required, position)
	if err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.onboarding_step_created", "onboarding_step", step.ID, nil)
	return step, nil
}

func (s *Service) UpdateOnboardingStep(ctx context.Context, pc *ProjectCtx, stepID string, req UpdateOnboardingStepRequest) (*OnboardingStep, error) {
	current, err := s.repo.GetOnboardingStep(ctx, s.pool, pc.ProjectID, stepID)
	if err != nil {
		return nil, err
	}
	title, wikiPageID, required, position := current.Title, current.WikiPageID, current.Required, current.Position
	if req.Title != nil {
		title = strings.TrimSpace(*req.Title)
		if title == "" || len(title) > OnboardingTitleMax {
			return nil, &FieldError{Fields: map[string]string{"title": fmt.Sprintf("Title must be 1-%d characters.", OnboardingTitleMax)}}
		}
	}
	if req.WikiPageID != nil {
		wikiPageID = req.WikiPageID
	}
	if req.Required != nil {
		required = *req.Required
	}
	if req.Position != nil {
		position = *req.Position
	}
	step, err := s.repo.UpdateOnboardingStep(ctx, s.pool, pc.ProjectID, stepID, title, wikiPageID, required, position)
	if err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.onboarding_step_updated", "onboarding_step", stepID, nil)
	return step, nil
}

func (s *Service) DeleteOnboardingStep(ctx context.Context, pc *ProjectCtx, stepID string) error {
	if err := s.repo.DeleteOnboardingStep(ctx, s.pool, pc.ProjectID, stepID); err != nil {
		return err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.onboarding_step_deleted", "onboarding_step", stepID, nil)
	return nil
}

// SetOnboardingStepDone always acts on the caller's own progress.
func (s *Service) SetOnboardingStepDone(ctx context.Context, pc *ProjectCtx, stepID string, done bool) error {
	if _, err := s.repo.GetOnboardingStep(ctx, s.pool, pc.ProjectID, stepID); err != nil {
		return err
	}
	return s.repo.SetOnboardingStepDone(ctx, s.pool, stepID, pc.UserID, done)
}

// CanSelfAssign reports whether userID has completed every required
// onboarding step of projectID — Phase 2's self-assign gate.
func (s *Service) CanSelfAssign(ctx context.Context, db DBTX, projectID, userID string) (bool, error) {
	return s.repo.IsOnboardingComplete(ctx, db, projectID, userID)
}
