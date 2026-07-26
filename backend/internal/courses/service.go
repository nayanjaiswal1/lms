package courses

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"regexp"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/rewards"
	"github.com/mindforge/backend/internal/storage"
)

type Service struct {
	repo       *Repo
	store      storage.StorageClient
	ai         ai.LLMProvider
	cfg        *config.Config
	rewardsSvc *rewards.Service
}

func NewService(repo *Repo, store storage.StorageClient, aiProvider ai.LLMProvider, cfg *config.Config, rewardsSvc *rewards.Service) *Service {
	return &Service{repo: repo, store: store, ai: aiProvider, cfg: cfg, rewardsSvc: rewardsSvc}
}

// CompleteModule marks a module completed for a user and awards the module
// (and, if this finishes the course, course-completion) XP. This is the single
// path that writes a "completed" module_progress row — used both by the
// client-facing progress endpoint (self-paced content: notes, video, pdf) and
// by server-verified completion events (lab session finished, assessment
// passed), so a client can never fabricate completion of verified work.
func (s *Service) CompleteModule(ctx context.Context, userID, orgID, moduleID, courseID string) (ModuleProgress, *rewards.AwardResult, error) {
	now := time.Now()
	updated, err := s.repo.UpsertProgress(ctx, ModuleProgress{
		UserID:      userID,
		ModuleID:    moduleID,
		CourseID:    courseID,
		Status:      ProgressCompleted,
		CompletedAt: &now,
	})
	if err != nil {
		return ModuleProgress{}, nil, err
	}

	if s.rewardsSvc == nil {
		return updated, nil, nil
	}

	refType := "module"
	result := s.rewardsSvc.AwardXP(ctx, rewards.AwardXPRequest{
		UserID:   userID,
		OrgID:    orgID,
		CourseID: &courseID,
		Reason:   "module_completed",
		RefID:    &moduleID,
		RefType:  &refType,
		XP:       rewards.XPModuleCompleted,
	})

	streakResult := s.rewardsSvc.UpdateStreakAndCheckMilestones(ctx, userID, orgID)
	result.XPGained += streakResult.XPGained
	result.NewAchievements = append(result.NewAchievements, streakResult.NewAchievements...)
	if streakResult.NewLevel != nil {
		result.NewLevel = streakResult.NewLevel
	}

	cp, cpErr := s.repo.GetCourseProgress(ctx, userID, courseID)
	if cpErr != nil {
		slog.Error("courses: check completion for rewards", "course", courseID, "err", cpErr)
	} else if cp.Total > 0 && cp.Completed == cp.Total {
		refTypeCourse := "course"
		courseResult := s.rewardsSvc.AwardXP(ctx, rewards.AwardXPRequest{
			UserID:   userID,
			OrgID:    orgID,
			CourseID: &courseID,
			Reason:   "course_completed",
			RefID:    &courseID,
			RefType:  &refTypeCourse,
			XP:       rewards.XPCourseCompleted,
		})
		result.XPGained += courseResult.XPGained
		result.NewAchievements = append(result.NewAchievements, courseResult.NewAchievements...)
		if courseResult.NewLevel != nil {
			result.NewLevel = courseResult.NewLevel
		}
	}

	return updated, &result, nil
}

// CompleteModuleForAssessment completes the course module wrapping the given
// assessment, if one exists. Standalone assessments (not embedded in a course)
// are a no-op — there is no module to mark complete.
func (s *Service) CompleteModuleForAssessment(ctx context.Context, orgID, userID, assessmentID string) (*rewards.AwardResult, error) {
	module, err := s.repo.GetModuleByAssessmentID(ctx, orgID, assessmentID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, nil
		}
		return nil, err
	}
	_, result, err := s.CompleteModule(ctx, userID, orgID, module.ID, module.CourseID)
	return result, err
}

// GetModuleContent verifies access and returns module content + presigned URL when needed.
func (s *Service) GetModuleContent(ctx context.Context, orgID, userID, moduleID string) (ModuleContent, error) {
	m, err := s.repo.GetModule(ctx, orgID, moduleID)
	if err != nil {
		return ModuleContent{}, err
	}

	if !m.IsFreePreview {
		enrolled, err := s.repo.IsEnrolled(ctx, userID, m.CourseID)
		if err != nil {
			return ModuleContent{}, err
		}
		if !enrolled {
			return ModuleContent{}, ErrForbidden
		}
	}

	mc := ModuleContent{Module: m}

	if m.StorageKey != nil && *m.StorageKey != "" {
		url, err := s.store.PresignedGetURL(ctx, *m.StorageKey, time.Hour)
		if err == nil {
			mc.ContentURL = &url
		}
	}

	return mc, nil
}

// checkEnrolled returns ErrForbidden unless the user is enrolled in the
// module's course (or the module is a free preview) — the same rule
// GetModuleContent applies, factored out so other per-module student actions
// (lesson notes, AI-logged understanding) share one authorization path.
func (s *Service) checkEnrolled(ctx context.Context, orgID, userID, moduleID string) (CourseModule, error) {
	m, err := s.repo.GetModule(ctx, orgID, moduleID)
	if err != nil {
		return CourseModule{}, err
	}
	if m.IsFreePreview {
		return m, nil
	}
	enrolled, err := s.repo.IsEnrolled(ctx, userID, m.CourseID)
	if err != nil {
		return CourseModule{}, err
	}
	if !enrolled {
		return CourseModule{}, ErrForbidden
	}
	return m, nil
}

// GetMyLessonNote returns the caller's personal note for a module, requiring
// the same enrollment as viewing the lesson itself.
func (s *Service) GetMyLessonNote(ctx context.Context, orgID, userID, moduleID string) (LessonNote, error) {
	if _, err := s.checkEnrolled(ctx, orgID, userID, moduleID); err != nil {
		return LessonNote{}, err
	}
	return s.repo.GetMyLessonNote(ctx, userID, moduleID)
}

// GetMyReflection returns the caller's existing reflection for a module, if
// any, requiring the same enrollment as viewing the lesson itself — mirrors
// GetMyLessonNote. Used to capture the before-state of an MCP
// log_understanding call so it can be reverted.
func (s *Service) GetMyReflection(ctx context.Context, orgID, userID, moduleID string) (LessonReflection, error) {
	if _, err := s.checkEnrolled(ctx, orgID, userID, moduleID); err != nil {
		return LessonReflection{}, err
	}
	return s.repo.GetMyReflection(ctx, userID, moduleID)
}

// SaveLessonNote creates or updates the caller's personal note for a module.
// source is "manual" for the in-app Edit/Update button, "ai" when written by
// the caller's connected MCP client via the save_my_lesson_note tool.
func (s *Service) SaveLessonNote(ctx context.Context, orgID, userID, moduleID, content, source string) (LessonNote, error) {
	if _, err := s.checkEnrolled(ctx, orgID, userID, moduleID); err != nil {
		return LessonNote{}, err
	}
	return s.repo.UpsertLessonNote(ctx, LessonNote{
		OrgID: orgID, UserID: userID, ModuleID: moduleID, Content: content, Source: source,
	})
}

// LogUnderstanding records what the caller's connected MCP client observed
// they understood (or struggled with) about a module, into the same
// lesson_reflections row the in-app "Reflect" box writes to, tagged
// source="ai" so revisionplan can weight it separately from a student's own
// words.
func (s *Service) LogUnderstanding(ctx context.Context, orgID, userID, moduleID, summary string) (LessonReflection, error) {
	if _, err := s.checkEnrolled(ctx, orgID, userID, moduleID); err != nil {
		return LessonReflection{}, err
	}
	return s.repo.UpsertReflection(ctx, LessonReflection{
		OrgID: orgID, UserID: userID, ModuleID: moduleID, Response: summary, Source: "ai",
	})
}

// ─── Self-courses ─────────────────────────────────────────────────────────────

// CreateSelfCourse creates a student's own private course from scratch. This
// is reachable directly from an MCP tool call with no HTTP handler in front
// of it, so unlike the org CreateCourse handler's inline checks, the
// equivalent validation has to live here — otherwise a bad field from an AI
// client would fail a DB CHECK constraint and surface as a raw, unfriendly
// 500 instead of a clean, field-attributed error.
func (s *Service) CreateSelfCourse(ctx context.Context, orgID, ownerID, title string, description *string, difficulty string, tags []string) (Course, error) {
	if len(title) < titleMinLen || len(title) > titleMaxLen {
		return Course{}, ValidationError{Field: "title", Message: "Title must be 3–200 characters."}
	}
	if description != nil && len(*description) > descriptionMaxLen {
		return Course{}, ValidationError{Field: "description", Message: "Description must be 2000 characters or fewer."}
	}
	if difficulty == "" {
		difficulty = DifficultyBeginner
	}
	if !IsValidDifficulty(difficulty) {
		return Course{}, ValidationError{Field: "difficulty", Message: "Invalid difficulty."}
	}
	return s.repo.CreateSelfCourse(ctx, orgID, ownerID, title, description, difficulty, tags)
}

// ForkSelfCourseFromOrgCourse forks a published org course into the
// student's own private copy, which their connected AI can then freely edit.
func (s *Service) ForkSelfCourseFromOrgCourse(ctx context.Context, orgID, ownerID, originalCourseID, newTitle string) (Course, error) {
	return s.repo.ForkToSelfCourse(ctx, orgID, originalCourseID, ownerID, newTitle)
}

// AddSelfCourseModule adds a notes-type module to a section of the caller's
// own self-course — the free-write path a connected AI uses to record what
// the student is learning as they go. sectionID defaults to the course's
// first section when empty (every self-course has at least the default
// "Introduction" section created at CreateSelfCourse/ForkSelfCourseFromOrgCourse
// time). Only text content is supported here (module type is always
// "notes") since the caller is always a JSON tool call with no file-upload
// transport, never a browser multipart upload.
func (s *Service) AddSelfCourseModule(ctx context.Context, orgID, ownerID, courseID, sectionID, title, contentBody string) (CourseModule, error) {
	if len(title) < moduleTitleMinLen || len(title) > moduleTitleMaxLen {
		return CourseModule{}, ValidationError{Field: "title", Message: "Title must be 1–200 characters."}
	}
	course, err := s.repo.GetOwnedSelfCourse(ctx, orgID, ownerID, courseID)
	if err != nil {
		return CourseModule{}, err
	}
	if sectionID == "" {
		sectionID, err = s.repo.GetFirstSectionID(ctx, course.ID)
		if err != nil {
			return CourseModule{}, err
		}
	} else {
		// A caller-supplied section_id must belong to THIS course — without
		// this check, GetSectionForOrg only proves the section exists
		// somewhere in the org, which would let a student attach a module to
		// a section under a different course (another student's self-course,
		// or a shared org course) while only ever proving ownership of
		// courseID.
		section, err := s.repo.GetSectionForOrg(ctx, orgID, sectionID)
		if err != nil {
			return CourseModule{}, err
		}
		if section.CourseID != course.ID {
			return CourseModule{}, ErrForbidden
		}
	}
	return s.repo.CreateModule(ctx, CourseModule{
		CourseID: course.ID, SectionID: sectionID, Title: title, Type: ModuleTypeNotes, ContentBody: &contentBody,
	})
}

// UpdateSelfCourseModule replaces a module's title/content in the caller's
// own self-course, after checking the module actually belongs to a course
// they own — reusing GetModule's org scope plus an explicit ownership check
// rather than trusting the client-supplied courseID.
func (s *Service) UpdateSelfCourseModule(ctx context.Context, orgID, ownerID, moduleID, title, contentBody string) (CourseModule, error) {
	if len(title) < moduleTitleMinLen || len(title) > moduleTitleMaxLen {
		return CourseModule{}, ValidationError{Field: "title", Message: "Title must be 1–200 characters."}
	}
	m, err := s.repo.GetModule(ctx, orgID, moduleID)
	if err != nil {
		return CourseModule{}, err
	}
	if _, err := s.repo.GetOwnedSelfCourse(ctx, orgID, ownerID, m.CourseID); err != nil {
		return CourseModule{}, err
	}
	m.Title = title
	m.ContentBody = &contentBody
	return s.repo.UpdateModule(ctx, orgID, m)
}

// GetLearningContext builds the single pre-aggregated snapshot behind the
// get_learning_context MCP tool (and the equivalent in-app endpoint): every
// enrolled course's progress, the student's most recent lesson reflections,
// and the most recently touched modules in their own self-courses. It exists
// so a connected AI client can front-load "where does this student currently
// stand" in one call instead of piecing it together from several, which in
// practice means it either doesn't bother and asks the student to recap, or
// makes several round-trips before it can respond usefully.
func (s *Service) GetLearningContext(ctx context.Context, orgID, userID string) (LearningContext, error) {
	enrollments, err := s.repo.GetMyEnrollments(ctx, userID, orgID)
	if err != nil {
		return LearningContext{}, err
	}
	courses := make([]CourseProgressBrief, 0, len(enrollments))
	for _, e := range enrollments {
		cp, err := s.repo.GetCourseProgress(ctx, userID, e.CourseID)
		if err != nil {
			return LearningContext{}, err
		}
		courses = append(courses, CourseProgressBrief{
			CourseID: e.Course.ID, Title: e.Course.Title, Kind: e.Course.Kind,
			Completed: cp.Completed, Total: cp.Total, Pct: cp.Pct,
		})
	}

	const recentLimit = 10
	reflections, err := s.repo.GetRecentReflections(ctx, orgID, userID, recentLimit)
	if err != nil {
		return LearningContext{}, err
	}
	selfActivity, err := s.repo.GetRecentSelfCourseModules(ctx, orgID, userID, recentLimit)
	if err != nil {
		return LearningContext{}, err
	}

	return LearningContext{Courses: courses, RecentReflections: reflections, RecentSelfActivity: selfActivity}, nil
}

// ─── Content proposals ────────────────────────────────────────────────────────

// ProposeModuleToOrgCourse lets a student propose content as a contribution
// to a shared org course. This never writes to the org course directly — it
// only queues a pending proposal for that course's instructor/admin to
// approve or reject.
//
// sourceModuleID is optional. When given, it must be a module in one of the
// proposer's own self-courses (ownership checked the same way
// UpdateSelfCourseModule does) — its current title/content_body are copied
// server-side into the proposal, and SourceCourseID/SourceModuleID are
// recorded so the reviewing instructor can see exactly which lesson this
// came from. This is preferred over trusting client-supplied title/
// contentBody verbatim, since it ties the proposal back to real, ownership-
// verified content instead of arbitrary retyped text. When sourceModuleID is
// nil, title/contentBody are used as given (e.g. content composed fresh in
// conversation, with no backing self-course lesson).
func (s *Service) ProposeModuleToOrgCourse(ctx context.Context, orgID, proposerID, targetCourseID string, targetSectionID, sourceModuleID *string, title, contentBody string) (CourseContentProposal, error) {
	target, err := s.repo.GetCourse(ctx, orgID, targetCourseID)
	if err != nil {
		return CourseContentProposal{}, err
	}
	if target.Kind != KindOrg {
		return CourseContentProposal{}, ErrForbidden
	}
	if targetSectionID != nil {
		// Same cross-ownership check as AddSelfCourseModule: the section must
		// belong to targetCourseID, not just exist somewhere in the org —
		// otherwise ApproveProposal would later insert the resulting module
		// under a section that belongs to a different course entirely.
		section, err := s.repo.GetSectionForOrg(ctx, orgID, *targetSectionID)
		if err != nil {
			return CourseContentProposal{}, err
		}
		if section.CourseID != targetCourseID {
			return CourseContentProposal{}, ErrForbidden
		}
	}

	proposal := CourseContentProposal{
		OrgID: orgID, ProposerID: proposerID, TargetCourseID: targetCourseID, TargetSectionID: targetSectionID,
		Title: title, Type: ModuleTypeNotes, ContentBody: contentBody,
	}
	if sourceModuleID != nil {
		m, err := s.repo.GetModule(ctx, orgID, *sourceModuleID)
		if err != nil {
			return CourseContentProposal{}, err
		}
		if _, err := s.repo.GetOwnedSelfCourse(ctx, orgID, proposerID, m.CourseID); err != nil {
			return CourseContentProposal{}, err
		}
		if m.ContentBody == nil {
			return CourseContentProposal{}, fmt.Errorf("courses: propose from module %s: no content_body", m.ID)
		}
		proposal.SourceCourseID = &m.CourseID
		proposal.SourceModuleID = &m.ID
		proposal.Title = m.Title
		proposal.ContentBody = *m.ContentBody
	}
	if proposal.Title == "" || proposal.ContentBody == "" {
		return CourseContentProposal{}, fmt.Errorf("courses: propose module: title and content_body are required when source_module_id is not given")
	}
	return s.repo.CreateProposal(ctx, proposal)
}

// PresignedUploadURL returns a presigned PUT URL and the resulting storage key for a course asset.
func (s *Service) PresignedUploadURL(ctx context.Context, orgID, courseID, moduleID, mimeType string) (string, string, error) {
	ext := mimeExtension(mimeType)
	key := "orgs/" + orgID + "/courses/" + courseID + "/modules/" + moduleID + "/" + randomHex(8) + ext
	url, err := s.store.PresignedPutURL(ctx, key, mimeType, 2*1024*1024*1024)
	if err != nil {
		return "", "", err
	}
	return url, key, nil
}

// UploadAsset stores an uploaded file and returns its public URL and storage key.
func (s *Service) UploadAsset(ctx context.Context, orgID, filename, contentType string, size int64, r io.Reader) (string, string, error) {
	ext := mimeExtension(contentType)
	if ext == "" {
		if i := strings.LastIndex(filename, "."); i >= 0 && i < len(filename)-1 {
			ext = filename[i:]
		}
	}
	key := "orgs/" + orgID + "/uploads/" + randomHex(16) + ext
	url, err := s.store.Upload(ctx, key, contentType, r, size)
	if err != nil {
		return "", "", fmt.Errorf("upload asset: %w", err)
	}
	return url, key, nil
}

var mimeExtMap = map[string]string{
	"video/mp4":       ".mp4",
	"video/webm":      ".webm",
	"application/pdf": ".pdf",
	"image/jpeg":      ".jpg",
	"image/png":       ".png",
	"image/webp":      ".webp",
}

func mimeExtension(mimeType string) string {
	if ext, ok := mimeExtMap[strings.ToLower(mimeType)]; ok {
		return ext
	}
	return ""
}

func randomHex(n int) string {
	buf := make([]byte, n)
	rand.Read(buf)
	return hex.EncodeToString(buf)
}

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

// Slugify produces a URL-safe slug with a random suffix to avoid collisions.
func Slugify(s string) string {
	base := slugRe.ReplaceAllString(strings.ToLower(strings.TrimSpace(s)), "-")
	base = strings.Trim(base, "-")
	if base == "" {
		base = "course"
	}
	if len(base) > 60 {
		base = base[:60]
	}
	return base + "-" + randomHex(4)
}
