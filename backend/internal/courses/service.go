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
	updated, wasAlreadyCompleted, err := s.repo.UpsertProgressCompleted(ctx, ModuleProgress{
		UserID:      userID,
		ModuleID:    moduleID,
		CourseID:    courseID,
		Status:      ProgressCompleted,
		CompletedAt: &now,
	})
	if err != nil {
		return ModuleProgress{}, nil, err
	}

	// A module already marked completed (student unmarked it, then remarked
	// it complete) must not re-award XP/streak/badges — those are one-time
	// per module, not per completion event.
	if wasAlreadyCompleted || s.rewardsSvc == nil {
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

// GetCourseDetailForViewer resolves a course by its URL slug and folds in
// the caller's own relationship to it — enrollment, progress, and star
// rating — into one response. Replaces the old frontend pattern of fetching
// the whole catalog + full enrollment list just to find one course by slug,
// then issuing two more separate per-course round trips for data that's
// already scoped to (user, course).
func (s *Service) GetCourseDetailForViewer(ctx context.Context, orgID, userID, slug string) (CourseDetailForViewer, error) {
	tree, err := s.repo.GetCourseTreeBySlug(ctx, orgID, userID, slug)
	if err != nil {
		return CourseDetailForViewer{}, err
	}
	detail := CourseDetailForViewer{CourseTree: tree}

	enrolled, err := s.repo.IsEnrolled(ctx, userID, tree.ID)
	if err != nil {
		return CourseDetailForViewer{}, fmt.Errorf("courses: check enrollment: %w", err)
	}
	detail.IsEnrolled = enrolled
	if !enrolled {
		return detail, nil
	}

	cp, err := s.repo.GetCourseProgress(ctx, userID, tree.ID)
	if err != nil {
		return CourseDetailForViewer{}, err
	}
	modules, err := s.repo.GetModuleProgressForCourse(ctx, userID, tree.ID)
	if err != nil {
		return CourseDetailForViewer{}, err
	}
	detail.Progress = &CourseProgressSummary{Completed: cp.Completed, Total: cp.Total, Pct: cp.Pct, Modules: modules}

	rev, err := s.repo.GetMyReview(ctx, userID, tree.ID)
	if err != nil {
		if !errors.Is(err, ErrNotFound) {
			return CourseDetailForViewer{}, err
		}
	} else {
		detail.MyRating = &rev.Rating
	}
	return detail, nil
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

// GetLearningContext builds the single pre-aggregated snapshot behind the
// get_learning_context MCP tool (and the equivalent in-app endpoint): every
// enrolled course's progress plus the student's most recent lesson
// reflections. It exists so a connected AI client can front-load "where does
// this student currently stand" in one call instead of piecing it together
// from several, which in practice means it either doesn't bother and asks
// the student to recap, or makes several round-trips before it can respond
// usefully.
func (s *Service) GetLearningContext(ctx context.Context, orgID, userID string) (LearningContext, error) {
	enrollments, err := s.repo.GetMyEnrollments(ctx, userID, orgID)
	if err != nil {
		return LearningContext{}, err
	}
	// GetMyEnrollments already joins per-course progress in one query, so no
	// need for a per-enrollment GetCourseProgress round trip here.
	courses := make([]CourseProgressBrief, 0, len(enrollments))
	for _, e := range enrollments {
		courses = append(courses, CourseProgressBrief{
			CourseID: e.Course.ID, Title: e.Course.Title,
			Completed: e.Progress.Completed, Total: e.Progress.Total, Pct: e.Progress.Pct,
		})
	}

	const recentLimit = 10
	reflections, err := s.repo.GetRecentReflections(ctx, orgID, userID, recentLimit)
	if err != nil {
		return LearningContext{}, err
	}

	return LearningContext{Courses: courses, RecentReflections: reflections}, nil
}

// randomTopicAttempts returns the ordered fallback tiers GetRandomTopic
// tries, each one only reached if the previous found nothing:
//  1. published courses matching the student's stated topic interests,
//     excluding ones they're already enrolled in (only when they have stated
//     interests at all)
//  2. any published course, excluding ones they're already enrolled in
//  3. any published course at all, including ones they're already enrolled
//     in — reached only once tier 2 finds nothing, i.e. the student has
//     enrolled in the entire org catalog; still surfaces something rather
//     than an empty state
//
// Extracted as a pure function (no DB) so the fallback ordering itself is
// unit-testable without the DB-backed test infra this codebase doesn't have
// for domain packages yet (see roadmap.service_test.go's precedent).
func randomTopicAttempts(interests, excludeCourseIDs []string) []RandomTopicFilter {
	attempts := make([]RandomTopicFilter, 0, 3)
	if len(interests) > 0 {
		attempts = append(attempts, RandomTopicFilter{Tags: interests, ExcludeCourseIDs: excludeCourseIDs})
	}
	attempts = append(attempts, RandomTopicFilter{ExcludeCourseIDs: excludeCourseIDs})
	attempts = append(attempts, RandomTopicFilter{})
	return attempts
}

// GetRandomTopic picks one course the student hasn't tried yet as a learning
// suggestion for the "surprise me" discovery feature, walking
// randomTopicAttempts' tiers until one finds a course. Returns ErrNotFound
// only when the org's entire published catalog is empty.
func (s *Service) GetRandomTopic(ctx context.Context, orgID, userID string) (RandomTopic, error) {
	enrollments, err := s.repo.GetMyEnrollments(ctx, userID, orgID)
	if err != nil {
		return RandomTopic{}, err
	}
	excludeIDs := make([]string, len(enrollments))
	for i, e := range enrollments {
		excludeIDs[i] = e.CourseID
	}

	interests, err := s.repo.GetTopicsInterest(ctx, userID)
	if err != nil {
		return RandomTopic{}, err
	}

	attempts := randomTopicAttempts(interests, excludeIDs)
	lastTier := len(attempts) - 1
	for i, filter := range attempts {
		c, err := s.repo.GetRandomPublishedCourse(ctx, orgID, filter)
		if err == nil {
			return RandomTopic{
				Course:          c,
				MatchedInterest: len(filter.Tags) > 0,
				AlreadyEnrolled: i == lastTier,
			}, nil
		}
		if !errors.Is(err, ErrNotFound) {
			return RandomTopic{}, err
		}
	}
	return RandomTopic{}, ErrNotFound
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
