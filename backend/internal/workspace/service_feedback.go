package workspace

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
)

// service_feedback.go — Phase 5 (contract-phase5.md 5b): peer feedback, the
// auto-built member outcome report, project-completion certificates, and the
// showcase opt-in.

// GetFeedback is GET …/feedback (member, no status gate).
func (s *Service) GetFeedback(ctx context.Context, pc *ProjectCtx) (*FeedbackView, error) {
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	view := &FeedbackView{WindowClosesAt: project.FeedbackClosesAt}
	view.Open = project.ProjectStatus == ProjectCompleted && project.FeedbackClosesAt != nil && s.now().Before(*project.FeedbackClosesAt)

	rateable, err := s.repo.ListRateableMembers(ctx, s.pool, pc.ProjectID, pc.UserID)
	if err != nil {
		return nil, err
	}
	view.Rateable = rateable

	given, err := s.repo.ListGivenFeedback(ctx, s.pool, pc.ProjectID, pc.UserID)
	if err != nil {
		return nil, err
	}
	view.Given = given

	avg, comments, raters, err := s.repo.FeedbackReceivedStats(ctx, s.pool, pc.ProjectID, pc.UserID)
	if err != nil {
		return nil, err
	}
	windowClosed := project.FeedbackClosesAt != nil && !s.now().Before(*project.FeedbackClosesAt)
	if windowClosed && raters >= FeedbackMinRaters {
		view.Mine = MyFeedback{Available: true, Average: &avg, Comments: comments}
	} else {
		view.Mine = MyFeedback{Available: false}
	}

	if pc.Role == RoleOwner || pc.Overseer {
		all, err := s.repo.ListAllFeedback(ctx, s.pool, pc.ProjectID)
		if err != nil {
			return nil, err
		}
		view.All = all
	}
	return view, nil
}

// SubmitPeerFeedback is POST …/feedback (member, StatusesFeedback): only
// while completed and before feedback_closes_at (ErrFeedbackClosed), only
// between two people who shared at least one item (ErrNoSharedWork), upsert
// (editable until the window closes).
func (s *Service) SubmitPeerFeedback(ctx context.Context, pc *ProjectCtx, req PeerFeedbackRequest) error {
	if req.ToUserID == pc.UserID {
		return fmt.Errorf("%w: you can't rate yourself", ErrInvalidInput)
	}
	if req.Rating < 1 || req.Rating > 5 {
		return &FieldError{Fields: map[string]string{"rating": "Rating must be between 1 and 5."}}
	}
	var comment *string
	if req.Comment != nil {
		c := strings.TrimSpace(*req.Comment)
		if len(c) > FeedbackCommentMaxLen {
			return &FieldError{Fields: map[string]string{"comment": fmt.Sprintf("Comment must be %d characters or fewer.", FeedbackCommentMaxLen)}}
		}
		if c != "" {
			comment = &c
		}
	}

	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return err
	}
	if project.ProjectStatus != ProjectCompleted || project.FeedbackClosesAt == nil || !s.now().Before(*project.FeedbackClosesAt) {
		return ErrFeedbackClosed
	}

	shared, err := s.repo.HasSharedWork(ctx, s.pool, pc.ProjectID, pc.UserID, req.ToUserID)
	if err != nil {
		return err
	}
	if !shared {
		return ErrNoSharedWork
	}

	return s.repo.InTx(ctx, func(tx pgx.Tx) error {
		if err := s.repo.UpsertPeerFeedback(ctx, tx, pc.ProjectID, pc.UserID, req.ToUserID, req.Rating, comment); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_feedback.submitted", "workspace_project", pc.ProjectID,
			map[string]string{"to_user_id": req.ToUserID})
		return nil
	})
}

// BuildMemberReport is GET …/members/{userID}/report (member, no status
// gate): self, manager+ (any member), or a track lead (own track's members
// only). Individual peer ratings stay hidden from everyone but the owner/
// overseer or the reported-on member themself (D15).
func (s *Service) BuildMemberReport(ctx context.Context, pc *ProjectCtx, userID string) (*MemberReport, error) {
	isSelf := pc.UserID == userID
	isManagerPlus := RoleAtLeast(pc.Role, RoleManager)
	if !isSelf && !isManagerPlus {
		ledTrackIDs, err := s.repo.ListLedTrackIDs(ctx, s.pool, pc.ProjectID, pc.UserID)
		if err != nil {
			return nil, err
		}
		targetTrackIDs, err := s.repo.ListMyTrackIDs(ctx, s.pool, pc.ProjectID, userID)
		if err != nil {
			return nil, err
		}
		inLedTrack := false
		for _, led := range ledTrackIDs {
			for _, t := range targetTrackIDs {
				if led == t {
					inLedTrack = true
				}
			}
		}
		if !inLedTrack {
			return nil, ErrForbidden
		}
	}

	base, err := s.repo.GetMemberReportBase(ctx, s.pool, pc.ProjectID, userID)
	if err != nil {
		return nil, err
	}
	counts, err := s.repo.MemberReportCounts(ctx, s.pool, pc.ProjectID, userID)
	if err != nil {
		return nil, err
	}
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	mrOpened, mrMerged := 0, 0
	if project.TeamID != nil {
		mrOpened, mrMerged, err = s.repo.MemberReportGitlabCounts(ctx, s.pool, *project.TeamID, userID)
		if err != nil {
			return nil, err
		}
	}

	report := &MemberReport{
		Person: base.Person, Role: base.Role, ItemsOwned: counts.ItemsOwned, ItemsDoneOwned: counts.ItemsDoneOwned,
		ItemsReviewed: counts.ItemsReviewed, ItemsTested: counts.ItemsTested, ReopensCaused: counts.ReopensCaused,
		DocApprovals: counts.DocApprovals, MRsOpened: mrOpened, MRsMerged: mrMerged, ReviewComments: counts.ReviewComments,
		MinutesLogged: counts.MinutesLogged, MeetingsAttended: counts.MeetingsAttended, MeetingsMissed: counts.MeetingsMissed,
		StandupsPosted: counts.StandupsPosted, ShowcaseOptIn: base.ShowcaseOptIn,
	}

	// PeerRating (D15): the owner/overseer sees it unconditionally; the
	// member sees their own once ≥3 raters have rated them after the window
	// closes; nobody else (a manager or track lead viewing someone else's
	// report) sees it at all.
	switch {
	case pc.Role == RoleOwner || pc.Overseer:
		avg, _, raters, err := s.repo.FeedbackReceivedStats(ctx, s.pool, pc.ProjectID, userID)
		if err != nil {
			return nil, err
		}
		if raters > 0 {
			report.PeerRating = &avg
		}
	case isSelf:
		windowClosed := project.FeedbackClosesAt != nil && !s.now().Before(*project.FeedbackClosesAt)
		if windowClosed {
			avg, _, raters, err := s.repo.FeedbackReceivedStats(ctx, s.pool, pc.ProjectID, userID)
			if err != nil {
				return nil, err
			}
			if raters >= FeedbackMinRaters {
				report.PeerRating = &avg
			}
		}
	}

	if s.certs != nil {
		if cert, err := s.certs.GetCertificateForProject(ctx, userID, pc.ProjectID); err == nil {
			report.CertificateID = &cert.CertUUID
		}
	}
	return report, nil
}

// IssueCertificate is POST …/certificates (owner, StatusesFeedback): a
// deliberate human award for a member's work on this completed project,
// reusing certificates.Service's additive project-completion path.
func (s *Service) IssueCertificate(ctx context.Context, pc *ProjectCtx, req IssueCertificateRequest) (*MemberReport, error) {
	if s.certs == nil {
		return nil, fmt.Errorf("%w: certificates are not configured for this deployment", ErrInvalidState)
	}
	if _, err := s.repo.GetMemberReportBase(ctx, s.pool, pc.ProjectID, req.UserID); err != nil {
		return nil, err
	}
	note := strings.TrimSpace(req.ExperienceNote)
	if len(note) > ExperienceNoteMaxLen {
		return nil, &FieldError{Fields: map[string]string{"experience_note": fmt.Sprintf("Must be %d characters or fewer.", ExperienceNoteMaxLen)}}
	}
	if _, err := s.certs.IssueProjectCompletion(ctx, req.UserID, pc.ProjectID, pc.UserID, note); err != nil {
		return nil, fmt.Errorf("workspace: issue certificate: %w", err)
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_member.certificate_issued", "workspace_project", pc.ProjectID,
		map[string]string{"user_id": req.UserID})
	return s.BuildMemberReport(ctx, pc, req.UserID)
}

// SetShowcaseOptIn is PUT …/membership/showcase (member, self only).
func (s *Service) SetShowcaseOptIn(ctx context.Context, pc *ProjectCtx, optIn bool) error {
	if err := s.repo.SetShowcaseOptIn(ctx, s.pool, pc.ProjectID, pc.UserID, optIn); err != nil {
		return err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_member.showcase_opt_in_set", "workspace_project", pc.ProjectID,
		map[string]bool{"opt_in": optIn})
	return nil
}
