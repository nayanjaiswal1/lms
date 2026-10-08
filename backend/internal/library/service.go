package library

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/labs"
)

// Service implements Attach (the one shared insert path — docs/debug-labs.md
// L3) plus the read paths (List/Preview/Try) behind it. It holds its own
// Repo for the union search query, and reuses courses/labs/assessment's own
// repos/service directly for everything else rather than re-implementing
// their access rules.
type Service struct {
	pool           *pgxpool.Pool
	repo           *Repo
	coursesRepo    *courses.Repo
	labsRepo       *labs.Repo
	labsSvc        *labs.Service
	assessmentRepo *assessment.Repo
}

func NewService(pool *pgxpool.Pool, repo *Repo, coursesRepo *courses.Repo, labsRepo *labs.Repo, labsSvc *labs.Service, assessmentRepo *assessment.Repo) *Service {
	return &Service{
		pool: pool, repo: repo, coursesRepo: coursesRepo,
		labsRepo: labsRepo, labsSvc: labsSvc, assessmentRepo: assessmentRepo,
	}
}

// List returns the paginated library listing for orgID, validating the
// requested kinds (empty/invalid entries are dropped rather than erroring —
// a stale filter chip in the UI shouldn't 400 the whole search).
func (s *Service) List(ctx context.Context, orgID string, f ListFilter) (ItemPage, error) {
	kinds := make([]string, 0, len(f.Kinds))
	for _, k := range f.Kinds {
		if validKinds[k] {
			kinds = append(kinds, k)
		}
	}
	f.Kinds = kinds
	return s.repo.List(ctx, orgID, f)
}

// Preview returns the student-safe projection for one item — the same shape
// its normal "view" endpoint would return (docs/debug-labs.md L4).
func (s *Service) Preview(ctx context.Context, orgID, kind, itemID string) (any, error) {
	switch kind {
	case KindLab, KindDebug:
		lab, err := s.labsRepo.GetLabForPlacement(ctx, itemID, orgID)
		if err != nil {
			return nil, mapNotFound(err)
		}
		var tasks []labs.TaskSnapshot
		if lab.IsPublished && lab.PublishedVersionID != nil {
			tasks, err = s.labsRepo.GetPublishedVersion(ctx, *lab.PublishedVersionID)
			if err != nil {
				return nil, fmt.Errorf("library.Service.Preview: get published version: %w", err)
			}
		}
		return labs.BuildStudentPreview(lab, tasks), nil
	case KindQuiz:
		a, err := s.assessmentRepo.GetAssessment(ctx, orgID, itemID)
		if err != nil {
			return nil, mapNotFound(err)
		}
		questions, err := s.assessmentRepo.ListAssessmentQuestions(ctx, a.ID, assessment.AssessmentQuestionFilter{})
		if err != nil {
			return nil, fmt.Errorf("library.Service.Preview: list questions: %w", err)
		}
		return map[string]any{"assessment": a, "questions": questions}, nil
	case KindNotes:
		m, err := s.coursesRepo.GetModule(ctx, orgID, itemID)
		if err != nil {
			return nil, mapNotFound(err)
		}
		if m.Type != courses.ModuleTypeNotes {
			return nil, ErrItemNotEligible
		}
		return map[string]any{
			"id": m.ID, "title": m.Title, "content_body": m.ContentBody,
			"estimated_minutes": m.EstimatedMinutes,
		}, nil
	default:
		return nil, ErrInvalidKind
	}
}

// Try starts a student ("is_test") session for a lab/debug item, reusing the
// exact StartSession path an instructor's own lab test button already goes
// through — no separate try-session code (docs/debug-labs.md L4). Quiz/notes
// have no "session" concept, so Try only applies to kind=lab.
func (s *Service) Try(ctx context.Context, orgID, userID, kind, itemID string) (*labs.LabSession, error) {
	if !isLabKind(kind) {
		return nil, ErrInvalidKind
	}
	if _, err := s.labsRepo.GetLabForPlacement(ctx, itemID, orgID); err != nil {
		return nil, mapNotFound(err)
	}
	session, err := s.labsSvc.StartSession(ctx, itemID, userID, orgID, true, "", nil)
	if err != nil {
		return nil, fmt.Errorf("library.Try: %w", err)
	}
	return session, nil
}

// Attach runs docs/debug-labs.md L3's one shared insert path: lock the
// section, check the actor can edit the course (same org — the rule
// CreateModule's route middleware + org-scoped queries already apply),
// check the item is eligible for its kind, shift positions, insert, audit
// log, commit.
func (s *Service) Attach(ctx context.Context, orgID, actorUserID string, req AttachReq) (courses.CourseModule, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return courses.CourseModule{}, fmt.Errorf("library.Service.Attach: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	inserted, err := s.AttachTx(ctx, tx, orgID, actorUserID, req)
	if err != nil {
		return courses.CourseModule{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return courses.CourseModule{}, fmt.Errorf("library.Service.Attach: commit: %w", err)
	}
	return inserted, nil
}

// AttachTx is the single insert path, run inside the caller's transaction (and
// not committed here). Attach wraps it in its own transaction; build publish
// calls it inside the transaction that creates the lab, so a lab is published
// and placed atomically.
func (s *Service) AttachTx(ctx context.Context, tx pgx.Tx, orgID, actorUserID string, req AttachReq) (courses.CourseModule, error) {
	if !validKinds[req.Kind] {
		return courses.CourseModule{}, ErrInvalidKind
	}

	// 1+2. Lock the section; its own org-scoped query IS the "actor can edit
	// this course" check (the same rule CreateModule's route already applies
	// via GetSectionForOrg — org membership + the instructor route guard).
	section, err := s.coursesRepo.LockSectionForOrg(ctx, tx, orgID, req.SectionID)
	if err != nil {
		return courses.CourseModule{}, fmt.Errorf("library.AttachTx: %w", err)
	}

	// 3. Per-kind eligibility + build the module to insert.
	mod, err := s.resolveAttachModule(ctx, tx, orgID, section, req)
	if err != nil {
		return courses.CourseModule{}, fmt.Errorf("library.AttachTx: %w", err)
	}

	// Position: append after the section's current last module when the
	// caller didn't ask for a specific index (Phase A's course-builder
	// integration always appends — see AttachReq.Position's doc comment).
	position := req.Position
	if position == nil {
		var count int
		if err := tx.QueryRow(ctx,
			`SELECT COALESCE(MAX(position) + 1, 0) FROM course_modules WHERE section_id = $1 AND deleted_at IS NULL`,
			section.ID,
		).Scan(&count); err != nil {
			return courses.CourseModule{}, fmt.Errorf("library.Service.Attach: compute append position: %w", err)
		}
		position = &count
	}
	mod.Position = *position

	// 4. Shift positions >= the insert point (safe: course_modules_section_id_position_key is DEFERRABLE INITIALLY DEFERRED).
	if err := s.coursesRepo.ShiftModulePositionsTx(ctx, tx, section.ID, *position); err != nil {
		return courses.CourseModule{}, fmt.Errorf("library.AttachTx: %w", err)
	}

	// 5. Insert through the shared column-list path.
	inserted, err := s.coursesRepo.InsertModuleTx(ctx, tx, mod)
	if err != nil {
		return courses.CourseModule{}, fmt.Errorf("library.AttachTx: %w", err)
	}

	// 6. Audit log, same table/shape orgs.writeAuditLog uses, written inside
	// this tx so it commits atomically with the insert.
	afterState, _ := json.Marshal(map[string]any{
		"kind": req.Kind, "item_id": req.ItemID, "section_id": section.ID, "position": inserted.Position,
	})
	if _, err := tx.Exec(ctx,
		`INSERT INTO audit_logs (org_id, actor_user_id, action, target_type, target_id, after_state)
		 VALUES ($1, $2, 'library.attach', 'course_module', $3, $4)`,
		orgID, actorUserID, inserted.ID, afterState,
	); err != nil {
		return courses.CourseModule{}, fmt.Errorf("library.Service.Attach: write audit log: %w", err)
	}

	return inserted, nil
}

// resolveAttachModule runs the per-kind eligibility check (docs/debug-labs.md
// L3 step 3) and returns the course_modules row to insert, with
// CourseID/SectionID/Type set and Position left zero (Attach fills it in
// after computing/shifting).
func (s *Service) resolveAttachModule(ctx context.Context, tx pgx.Tx, orgID string, section courses.CourseSection, req AttachReq) (courses.CourseModule, error) {
	base := courses.CourseModule{CourseID: section.CourseID, SectionID: section.ID}

	switch req.Kind {
	case KindLab, KindDebug:
		lab, err := s.labsRepo.GetLabForPlacementTx(ctx, tx, req.ItemID, orgID)
		if err != nil {
			return courses.CourseModule{}, mapNotFound(err)
		}
		if !lab.IsPublished {
			return courses.CourseModule{}, ErrItemNotEligible
		}
		// ponytail: skips re-checking lab_org_config.allowed_images here —
		// StartSession already enforces it at the point that actually
		// matters (session start), so an instructor placing a disallowed
		// image just gets ErrImageNotAllowed when a student tries to launch
		// it, same as today. Add a duplicate check here only if instructors
		// need that feedback earlier, at placement time.
		base.Type = courses.ModuleTypeLab
		base.Title = titleOr(req.Title, lab.Title)
		base.LabID = &lab.ID
		base.LabIsRequired = req.IsRequired
		return base, nil

	case KindQuiz:
		a, err := s.assessmentRepo.GetAssessment(ctx, orgID, req.ItemID)
		if err != nil {
			return courses.CourseModule{}, mapNotFound(err)
		}
		if a.Status != assessment.StatusPublished {
			return courses.CourseModule{}, ErrItemNotEligible
		}
		base.Type = courses.ModuleTypeAssessment
		base.Title = titleOr(req.Title, a.Title)
		base.AssessmentID = &a.ID
		return base, nil

	case KindNotes:
		src, err := s.coursesRepo.GetModule(ctx, orgID, req.ItemID)
		if err != nil {
			return courses.CourseModule{}, mapNotFound(err)
		}
		if src.Type != courses.ModuleTypeNotes {
			return courses.CourseModule{}, ErrItemNotEligible
		}
		base.Type = courses.ModuleTypeNotes
		base.Title = titleOr(req.Title, src.Title)
		base.ContentBody = src.ContentBody
		base.EstimatedMinutes = src.EstimatedMinutes
		base.CopiedFromModuleID = &src.ID
		return base, nil

	default:
		return courses.CourseModule{}, ErrInvalidKind
	}
}

func titleOr(override *string, fallback string) string {
	if override != nil && strings.TrimSpace(*override) != "" {
		return *override
	}
	return fallback
}

// mapNotFound normalizes courses/labs/assessment's own ErrNotFound into
// library's, so handler.go only has one sentinel to map to 404 regardless of
// which domain's lookup missed.
func mapNotFound(err error) error {
	if errors.Is(err, courses.ErrNotFound) || errors.Is(err, labs.ErrNotFound) || errors.Is(err, assessment.ErrNotFound) {
		return ErrNotFound
	}
	return err
}
