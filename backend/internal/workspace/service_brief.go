package workspace

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/wiki"
)

// service_brief.go — the project brief page and its two-person sign-off
// (contract-phase3.md, D13).

// approverRoleFor resolves the role tag ApproveBrief/CreateBriefPage records
// for the caller: 'owner'/'manager' from their project role, or 'track_lead'
// if they lead at least one track. Empty string means neither — the caller
// isn't eligible for either action.
func (s *Service) approverRoleFor(ctx context.Context, db DBTX, pc *ProjectCtx) (string, error) {
	if pc.Role == RoleOwner {
		return RoleOwner, nil
	}
	if pc.Role == RoleManager {
		return RoleManager, nil
	}
	led, err := s.repo.ListLedTrackIDs(ctx, db, pc.ProjectID, pc.UserID)
	if err != nil {
		return "", err
	}
	if len(led) > 0 {
		return "track_lead", nil
	}
	return "", nil
}

// briefTemplateContent seeds the "Project Brief" wiki page: the requirement
// as written, then a Q&A log built from every answered question at the
// current requirement version (contract-phase3.md "CreateBriefPage").
func briefTemplateContent(requirement string, answered []RequirementQuestion) json.RawMessage {
	nodes := []map[string]any{
		{"type": "heading", "attrs": map[string]any{"level": 2}, "content": []map[string]any{{"type": "text", "text": "Requirement"}}},
		{"type": "paragraph", "content": []map[string]any{{"type": "text", "text": requirement}}},
		{"type": "heading", "attrs": map[string]any{"level": 2}, "content": []map[string]any{{"type": "text", "text": "Q&A Log"}}},
	}
	if len(answered) == 0 {
		nodes = append(nodes, map[string]any{"type": "paragraph", "content": []map[string]any{{"type": "text", "text": "No questions answered yet."}}})
	}
	for _, q := range answered {
		answer := ""
		if q.Answer != nil {
			answer = *q.Answer
		}
		if q.IsAssumption {
			answer = "(assumption) " + answer
		}
		nodes = append(nodes,
			map[string]any{"type": "paragraph", "content": []map[string]any{{"type": "text", "marks": []map[string]any{{"type": "bold"}}, "text": "Q: " + q.Question}}},
			map[string]any{"type": "paragraph", "content": []map[string]any{{"type": "text", "text": "A: " + answer}}},
		)
	}
	doc := map[string]any{"type": "doc", "content": nodes}
	raw, _ := json.Marshal(doc)
	return raw
}

func briefSearchText(requirement string, answered []RequirementQuestion) string {
	text := requirement
	for _, q := range answered {
		text += " " + q.Question
		if q.Answer != nil {
			text += " " + *q.Answer
		}
	}
	return text
}

// GetBrief is GET …/brief.
func (s *Service) GetBrief(ctx context.Context, pc *ProjectCtx) (*BriefView, error) {
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	view := &BriefView{BriefStatus: project.BriefStatus, RequirementVersion: project.RequirementVersion, Approvals: []BriefApproval{}}

	approverRole, err := s.approverRoleFor(ctx, s.pool, pc)
	if err != nil {
		return nil, err
	}
	if approverRole == "" {
		view.ApproveBlocker = "Only the owner, a manager, or a track lead can approve the brief."
	}

	if project.BriefWikiPageID == nil {
		if view.ApproveBlocker == "" {
			view.ApproveBlocker = "Write the project brief page first."
		}
		return view, nil
	}
	view.PageID = project.BriefWikiPageID
	slug, spaceSlug, version, err := s.repo.GetWikiPageInfo(ctx, s.pool, *project.BriefWikiPageID)
	if err != nil {
		return nil, err
	}
	view.PageSlug = &slug
	view.PageVersion = version
	_ = spaceSlug

	approvals, err := s.repo.ListBriefApprovals(ctx, s.pool, pc.ProjectID, project.RequirementVersion)
	if err != nil {
		return nil, err
	}
	view.Approvals = approvals

	if view.ApproveBlocker == "" && project.BriefStatus != BriefClarifying {
		view.ApproveBlocker = "The brief must be under clarification to approve it."
	}
	if view.ApproveBlocker == "" {
		view.CanApprove = true
	}
	return view, nil
}

// CreateBriefPage provisions the project's brief wiki page from the seeded
// "Project Brief" template — manager+ or any track lead, once (subsequent
// calls are a conflict; edit the page directly instead).
func (s *Service) CreateBriefPage(ctx context.Context, pc *ProjectCtx) (*BriefView, error) {
	approverRole, err := s.approverRoleFor(ctx, s.pool, pc)
	if err != nil {
		return nil, err
	}
	if approverRole == "" {
		return nil, ErrForbidden
	}

	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		project, err := s.repo.LockProject(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		if project.BriefWikiPageID != nil {
			return ErrConflict
		}
		spaceID, _, err := s.repo.GetProjectWikiSpace(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		if spaceID == nil {
			return fmt.Errorf("workspace: create brief page: %w", ErrNotFound)
		}
		answered, err := s.repo.ListAnsweredQuestions(ctx, tx, pc.ProjectID, project.RequirementVersion)
		if err != nil {
			return err
		}
		content := briefTemplateContent(project.Requirement, answered)
		searchText := briefSearchText(project.Requirement, answered)
		slug := courses.Slugify(ProjectBriefTemplateTitle)
		page, err := wiki.CreatePageTx(ctx, tx, *spaceID, ProjectBriefTemplateTitle, slug, nil, nil, content, searchText, pc.UserID)
		if err != nil {
			return fmt.Errorf("workspace: create brief page: %w", err)
		}
		if err := s.repo.SetBriefWikiPageID(ctx, tx, pc.ProjectID, page.ID); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_brief.page_created", "wiki_page", page.ID, nil)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.GetBrief(ctx, pc)
}

// ApproveBrief records the caller's approval at the brief page's current
// version and, once the D13 two-person rule is met, marks the brief agreed.
func (s *Service) ApproveBrief(ctx context.Context, pc *ProjectCtx) (*BriefView, error) {
	approverRole, err := s.approverRoleFor(ctx, s.pool, pc)
	if err != nil {
		return nil, err
	}
	if approverRole == "" {
		return nil, ErrForbidden
	}

	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		project, err := s.repo.LockProject(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		if project.BriefWikiPageID == nil {
			return ErrBriefMissing
		}
		if project.BriefStatus != BriefClarifying {
			return fmt.Errorf("%w: the brief must be under clarification to approve it", ErrInvalidState)
		}
		_, _, wikiVersion, err := s.repo.GetWikiPageInfo(ctx, tx, *project.BriefWikiPageID)
		if err != nil {
			return err
		}
		if err := s.repo.UpsertBriefApproval(ctx, tx, pc.ProjectID, project.RequirementVersion, pc.UserID, approverRole, wikiVersion); err != nil {
			return err
		}
		approvals, err := s.repo.ListBriefApprovals(ctx, tx, pc.ProjectID, project.RequirementVersion)
		if err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_brief.approved", "workspace_project", pc.ProjectID,
			map[string]any{"requirement_version": project.RequirementVersion, "wiki_version": wikiVersion})
		if IsBriefAgreed(approvals, wikiVersion) {
			if _, err := s.repo.SetBriefStatus(ctx, tx, pc.ProjectID, BriefAgreed); err != nil {
				return err
			}
			writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_brief.agreed", "workspace_project", pc.ProjectID, nil)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.GetBrief(ctx, pc)
}
