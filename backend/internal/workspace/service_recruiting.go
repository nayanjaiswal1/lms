package workspace

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/mail"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/pagination"
)

// jobWorkspaceProjectInviteEmail must stay in sync with
// handlers.HandlerWorkspaceProjectInviteEmail in
// internal/jobs/handlers/constants.go — this package can't import that one
// back (it would import workspace to build the handler).
const jobWorkspaceProjectInviteEmail = "workspace.project_invite_email"

// controlCharPattern strips characters that have no business in free-text
// form fields (02 §4.3's "control chars stripped").
var controlCharPattern = regexp.MustCompile(`[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]`)

func stripControlChars(s string) string { return controlCharPattern.ReplaceAllString(s, "") }

// isAccepting reports whether a project's *status* currently allows public
// interest at all (recruiting, or active). accepting_interests, the
// deadline, and seats are checked separately so each can render its own
// closed reason on the public page.
func isAcceptingStatus(status string) bool {
	return status == ProjectRecruiting || status == ProjectActive
}

// GetPublicProject is the anonymous share page (02 §4.2). ErrNotFound for an
// unknown token, or a project that's draft/paused/completed/cancelled/
// archived. A recognized, live project is always shown — accepting_interests
// off, a passed deadline, or full seats are rendered as Open=false with a
// ClosedReason instead of a 404, so a shared link never just disappears out
// from under someone who already has it.
func (s *Service) GetPublicProject(ctx context.Context, shareToken string) (*PublicProject, error) {
	p, orgName, err := s.repo.GetProjectByShareToken(ctx, s.pool, shareToken)
	if err != nil {
		return nil, err
	}
	if !isAcceptingStatus(p.ProjectStatus) {
		return nil, ErrNotFound
	}

	seats, err := s.SeatsUsed(ctx, s.pool, p.ID)
	if err != nil {
		return nil, err
	}
	seatsLeft := p.TeamSizeMax - seats
	if seatsLeft < 0 {
		seatsLeft = 0
	}

	open, closedReason := true, ""
	switch {
	case !p.AcceptingInterests:
		open, closedReason = false, "not_accepting"
	case p.InterestDeadline != nil && p.InterestDeadline.Before(time.Now()):
		open, closedReason = false, "deadline_passed"
	case seatsLeft <= 0:
		open, closedReason = false, "seats_full"
	}

	return &PublicProject{
		Title: p.Title, Requirement: p.Requirement, Skills: p.Skills, InterestDeadline: p.InterestDeadline,
		TeamSizeMin: p.TeamSizeMin, TeamSizeMax: p.TeamSizeMax, SeatsLeft: seatsLeft,
		Open: open, ClosedReason: closedReason, OrgName: orgName,
	}, nil
}

// validatedInterest is a SubmitInterestRequest after trimming, normalizing
// and bounds-checking — shared by the anonymous and logged-in apply paths.
type validatedInterest struct {
	Name         string
	Email        string
	Skills       []string
	PortfolioURL *string
	Message      *string
}

// validateInterest applies the field rules to a submission; a bad field set
// comes back as *FieldError.
func validateInterest(req SubmitInterestRequest) (*validatedInterest, error) {
	fields := map[string]string{}
	name := strings.TrimSpace(stripControlChars(req.Name))
	if name == "" || len(name) > InterestNameMaxLen {
		fields["name"] = fmt.Sprintf("Name must be 1-%d characters.", InterestNameMaxLen)
	}
	var email string
	if trimmed := strings.TrimSpace(req.Email); trimmed == "" || len(trimmed) > InterestEmailMaxLen {
		fields["email"] = "A valid email address is required."
	} else if addr, err := mail.ParseAddress(trimmed); err != nil {
		fields["email"] = "A valid email address is required."
	} else {
		email = strings.ToLower(addr.Address)
	}
	skills, skillsErr := normalizeSkills(req.Skills)
	if skillsErr != "" {
		fields["skills"] = skillsErr
	}
	var portfolioURL *string
	if p := strings.TrimSpace(req.PortfolioURL); p != "" {
		if len(p) > PortfolioURLMaxLen || !(strings.HasPrefix(p, "http://") || strings.HasPrefix(p, "https://")) {
			fields["portfolio_url"] = "Portfolio link must be a valid http(s) URL."
		} else {
			portfolioURL = &p
		}
	}
	var message *string
	if m := strings.TrimSpace(stripControlChars(req.Message)); m != "" {
		if len(m) > InterestMessageMax {
			fields["message"] = fmt.Sprintf("Message must be %d characters or fewer.", InterestMessageMax)
		} else {
			message = &m
		}
	}
	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}

	return &validatedInterest{Name: name, Email: email, Skills: skills, PortfolioURL: portfolioURL, Message: message}, nil
}

// SubmitInterest validates the public form and upserts an interest row.
// Every accepted-shape outcome — new, duplicate, already a member, inside
// the reject cooldown, honeypot, or the project being closed — returns nil
// (D14): the public form never reveals which case it hit. Only a malformed
// token (ErrNotFound) or a genuinely invalid submission (*FieldError) differ.
func (s *Service) SubmitInterest(ctx context.Context, shareToken string, req SubmitInterestRequest) error {
	if req.Website != "" {
		return nil // honeypot: silently drop, still 202
	}

	v, err := validateInterest(req)
	if err != nil {
		return err
	}

	p, _, err := s.repo.GetProjectByShareToken(ctx, s.pool, shareToken)
	if err != nil {
		return err
	}
	if !isAcceptingStatus(p.ProjectStatus) {
		return ErrNotFound
	}

	deadlinePassed := p.InterestDeadline != nil && p.InterestDeadline.Before(time.Now())
	seats, err := s.SeatsUsed(ctx, s.pool, p.ID)
	if err != nil {
		return err
	}
	if !p.AcceptingInterests || deadlinePassed || seats >= p.TeamSizeMax {
		return nil // page already shows this as closed; the submission is a silent no-op
	}

	if _, err := s.repo.UpsertInterest(ctx, s.pool, p.ID, nil, v.Name, v.Email, v.Skills, v.PortfolioURL, v.Message, ReapplyCooldown); err != nil {
		return err
	}
	return nil
}

// ListInterests is the manager+ review list.
func (s *Service) ListInterests(ctx context.Context, pc *ProjectCtx, status, cursor string, limit int) (Page[Interest], error) {
	limit = clampLimit(limit)
	cursorAt, cursorID, err := pagination.DecodeCursor(cursor, "workspace")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	items, err := s.repo.ListInterests(ctx, s.pool, pc.ProjectID, status, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[Interest]{}, err
	}
	page := Page[Interest]{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

// ReviewInterest accepts or rejects a pending interest.
func (s *Service) ReviewInterest(ctx context.Context, pc *ProjectCtx, interestID, decision string) (*ReviewInterestResult, error) {
	switch decision {
	case "accept":
		return s.acceptInterest(ctx, pc, interestID)
	case "reject":
		i, err := s.repo.RejectInterest(ctx, s.pool, pc.ProjectID, interestID, pc.UserID)
		if err != nil {
			return nil, err
		}
		writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.interest_rejected", "project_interest", interestID, nil)
		return &ReviewInterestResult{Interest: *i, Outcome: "rejected"}, nil
	default:
		return nil, fmt.Errorf("%w: decision must be \"accept\" or \"reject\"", ErrInvalidInput)
	}
}

// acceptInterest locks the project row, checks the seat cap, and either adds
// an existing org member directly (status invited) or issues a pending org
// invite — all inside one transaction, per contract-phase1.md.
func (s *Service) acceptInterest(ctx context.Context, pc *ProjectCtx, interestID string) (*ReviewInterestResult, error) {
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:accept:"+pc.ProjectID, s.cfg.Workspace.AcceptPerProjectDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	var (
		result       *ReviewInterestResult
		projectTitle string
		inviteID     string
		notifyUser   string
	)
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		p, err := s.repo.LockProject(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		projectTitle = p.Title

		interest, err := s.repo.GetInterest(ctx, tx, pc.ProjectID, interestID)
		if err != nil {
			return err
		}
		if interest.Status != InterestNew {
			return ErrAlreadyReviewed
		}

		seatMembers, err := s.repo.CountSeatMembers(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		pendingInterests, err := s.repo.CountAcceptedPendingInterests(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		if seatMembers+pendingInterests >= p.TeamSizeMax {
			return ErrSeatsFull
		}

		existingUserID, isMember, err := s.repo.FindActiveOrgMemberByEmail(ctx, tx, pc.OrgID, interest.Email)
		if err != nil {
			return err
		}

		var outcome string
		if isMember {
			if err := s.repo.UpsertMember(ctx, tx, pc.ProjectID, existingUserID, RoleMember, MemberInvited, &pc.UserID); err != nil {
				return fmt.Errorf("workspace: accept interest: add member: %w", err)
			}
			accepted, err := s.repo.AcceptInterest(ctx, tx, pc.ProjectID, interestID, pc.UserID, nil)
			if err != nil {
				return err
			}
			interest = accepted
			outcome = "member_invited"
			notifyUser = existingUserID
		} else {
			newInviteID, err := s.invites.CreateForProject(ctx, tx, pc.OrgID, pc.UserID, interest.Email)
			if err != nil {
				return fmt.Errorf("workspace: accept interest: create invite: %w", err)
			}
			accepted, err := s.repo.AcceptInterest(ctx, tx, pc.ProjectID, interestID, pc.UserID, &newInviteID)
			if err != nil {
				return err
			}
			interest = accepted
			outcome = "invited"
			inviteID = newInviteID
		}

		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "project.interest_accepted", "project_interest", interestID,
			map[string]string{"outcome": outcome})
		result = &ReviewInterestResult{Interest: *interest, Outcome: outcome}
		return nil
	})
	if err != nil {
		return nil, err
	}

	if notifyUser != "" {
		s.notifyAddedToProject(ctx, pc.OrgID, notifyUser, pc.ProjectID, projectTitle)
	}
	if inviteID != "" {
		s.enqueueInviteEmail(ctx, pc.OrgID, inviteID, projectTitle)
	}
	return result, nil
}

// notifyAddedToProject best-effort notifies an existing org member they were
// added to a project — a notification failure never fails the accept itself.
func (s *Service) notifyAddedToProject(ctx context.Context, orgID, userID, projectID, projectTitle string) {
	if s.notif == nil {
		return
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "workspace: begin notify tx", "error", err)
		return
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	err = s.notif.Notify(ctx, tx, notifications.New{
		OrgID: orgID, UserID: userID, Type: "workspace.added_to_project",
		Title:      fmt.Sprintf("You've been added to %q", projectTitle),
		LinkURL:    strPtrWS("/workspaces/" + projectID),
		EntityType: strPtrWS("workspace_project"), EntityID: &projectID,
		Priority:  notifications.PriorityNormal,
		DedupeKey: fmt.Sprintf("workspace.added_to_project:%s:%s", projectID, userID),
	})
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify added to project", "error", err)
		return
	}
	if err := tx.Commit(ctx); err != nil {
		slog.ErrorContext(ctx, "workspace: commit notify tx", "error", err)
	}
}

func strPtrWS(s string) *string { return &s }

// enqueueInviteEmail fires the one-time invite-email job after commit — the
// invite token itself is minted later, inside the job, so a plaintext
// credential never sits in a job payload.
func (s *Service) enqueueInviteEmail(ctx context.Context, orgID, inviteID, projectTitle string) {
	if s.jobs == nil {
		return
	}
	idempotencyKey := "workspace.project_invite_email:" + inviteID
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobs, jobs.EnqueueParams{
		Handler:        jobWorkspaceProjectInviteEmail,
		Priority:       jobs.PriorityHigh,
		Payload:        map[string]string{"org_id": orgID, "invite_id": inviteID, "project_title": projectTitle},
		OrgID:          &orgID,
		IdempotencyKey: &idempotencyKey,
	}); err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		slog.ErrorContext(ctx, "workspace: enqueue invite email", "invite_id", inviteID, "error", err)
	}
}

// SeatsUsed = active/invited manager+member rows, plus accepted interests
// whose linked invite hasn't resolved yet (contract-phase1.md).
func (s *Service) SeatsUsed(ctx context.Context, db DBTX, projectID string) (int, error) {
	members, err := s.repo.CountSeatMembers(ctx, db, projectID)
	if err != nil {
		return 0, err
	}
	pending, err := s.repo.CountAcceptedPendingInterests(ctx, db, projectID)
	if err != nil {
		return 0, err
	}
	return members + pending, nil
}

// ExpireInvitedInterests is the daily job's first step: release seats an
// invite can no longer claim (revoked or expired).
func (s *Service) ExpireInvitedInterests(ctx context.Context) (int64, error) {
	return s.repo.ExpireInvitedInterests(ctx)
}

// PurgeInterests is the daily job's second step (02 §4.7).
func (s *Service) PurgeInterests(ctx context.Context) (int64, error) {
	return s.repo.PurgeInterests(ctx, InterestRetention)
}

// ListDiscoverable is GET /api/workspaces/discover.
func (s *Service) ListDiscoverable(ctx context.Context, orgID, userID, cursor string, limit int) (Page[DiscoverProject], error) {
	limit = clampLimit(limit)
	cursorAt, cursorID, err := pagination.DecodeCursor(cursor, "workspace")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	items, err := s.repo.ListDiscoverable(ctx, orgID, userID, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[DiscoverProject]{}, err
	}
	page := Page[DiscoverProject]{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

// ApplyInterest is the logged-in apply: name/email come from the user row,
// user_id is recorded, the honeypot is skipped, and validation, the per-email
// limit and the open/seat checks match the anonymous path. Unlike the public
// form it can say why it failed — the caller is authenticated, so there is no
// enumeration risk.
func (s *Service) ApplyInterest(ctx context.Context, orgID, userID, projectID string, req SubmitInterestRequest) error {
	p, err := s.repo.GetProject(ctx, s.pool, orgID, projectID)
	if err != nil {
		return err
	}
	if !isAcceptingStatus(p.ProjectStatus) {
		return ErrNotFound
	}
	name, email, err := s.repo.GetUserNameEmail(ctx, s.pool, userID)
	if err != nil {
		return err
	}
	req.Name, req.Email = name, email
	v, err := validateInterest(req)
	if err != nil {
		return err
	}

	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:int:userday:"+userID, s.cfg.Workspace.InterestPerEmailDay, 24*time.Hour); !allowed {
		return &RateLimitError{RetryAfter: retryAfter}
	}

	if member, err := s.repo.IsActiveOrInvitedMember(ctx, s.pool, projectID, userID); err != nil {
		return err
	} else if member {
		return ErrAlreadyMember
	}
	seats, err := s.SeatsUsed(ctx, s.pool, projectID)
	if err != nil {
		return err
	}
	if !p.AcceptingInterests || (p.InterestDeadline != nil && p.InterestDeadline.Before(time.Now())) || seats >= p.TeamSizeMax {
		return fmt.Errorf("%w: this workspace is not accepting interests", ErrConflict)
	}
	if exists, err := s.repo.InterestExistsForEmail(ctx, s.pool, projectID, v.Email); err != nil {
		return err
	} else if exists {
		return fmt.Errorf("%w: you have already applied to this workspace", ErrConflict)
	}
	ok, err := s.repo.UpsertInterest(ctx, s.pool, projectID, &userID, v.Name, v.Email, v.Skills, v.PortfolioURL, v.Message, ReapplyCooldown)
	if err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("%w: you can reapply once the cooldown has passed", ErrConflict)
	}
	return nil
}

// WithdrawInterest removes the caller's own interest while it is still new.
func (s *Service) WithdrawInterest(ctx context.Context, orgID, userID, projectID string) error {
	if _, err := s.repo.GetProject(ctx, s.pool, orgID, projectID); err != nil {
		return err
	}
	return s.repo.WithdrawInterest(ctx, s.pool, projectID, userID)
}

// ListMyInterests is GET /api/my/workspace-interests.
func (s *Service) ListMyInterests(ctx context.Context, orgID, userID string) ([]MyInterest, error) {
	return s.repo.ListMyInterests(ctx, orgID, userID)
}
