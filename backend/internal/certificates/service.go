package certificates

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/courses"
)

var (
	ErrCourseNotFound      = errors.New("certificates: course not found")
	ErrNotEnrolled         = errors.New("certificates: not enrolled in this course")
	ErrCourseNotComplete   = errors.New("certificates: course modules are not all completed yet")
	ErrNoFinalTest         = errors.New("certificates: this course has no final test")
	ErrAttemptsExhausted   = errors.New("certificates: no attempts remaining")
	ErrInvalidQuestions    = errors.New("certificates: final test must have at least one question")
	ErrInvalidTimeLimit    = errors.New("certificates: time limit must be positive")
	ErrInvalidPassingScore = errors.New("certificates: passing score must be between 1 and 100")
	ErrInvalidMaxAttempts  = errors.New("certificates: max attempts must be positive")
)

type Service struct {
	repo        *Repo
	coursesRepo *courses.Repo
	executor    assessment.CodeExecutor
}

func NewService(repo *Repo, coursesRepo *courses.Repo, executor assessment.CodeExecutor) *Service {
	return &Service{repo: repo, coursesRepo: coursesRepo, executor: executor}
}

// ─── Instructor authoring ──────────────────────────────────────────────────────

func (s *Service) UpsertFinalTest(ctx context.Context, orgID, courseID string, req UpsertFinalTestRequest) (FinalTest, error) {
	if _, err := s.coursesRepo.GetCourse(ctx, orgID, courseID); err != nil {
		if errors.Is(err, courses.ErrNotFound) {
			return FinalTest{}, ErrCourseNotFound
		}
		return FinalTest{}, fmt.Errorf("certificates: load course: %w", err)
	}
	if len(req.Questions) == 0 {
		return FinalTest{}, ErrInvalidQuestions
	}
	if req.TimeLimitMinutes <= 0 {
		return FinalTest{}, ErrInvalidTimeLimit
	}
	if req.PassingScorePercent < 1 || req.PassingScorePercent > 100 {
		return FinalTest{}, ErrInvalidPassingScore
	}
	if req.MaxAttempts <= 0 {
		return FinalTest{}, ErrInvalidMaxAttempts
	}
	for i := range req.Questions {
		if req.Questions[i].ID == "" {
			req.Questions[i].ID = fmt.Sprintf("q%d", i+1)
		}
	}
	return s.repo.UpsertFinalTest(ctx, courseID, orgID, req)
}

// GetFinalTestForEdit returns the full, unstripped FinalTest (including
// correct answers) for the instructor authoring form — never expose this via
// a student-facing route.
func (s *Service) GetFinalTestForEdit(ctx context.Context, orgID, courseID string) (FinalTest, error) {
	if _, err := s.coursesRepo.GetCourse(ctx, orgID, courseID); err != nil {
		if errors.Is(err, courses.ErrNotFound) {
			return FinalTest{}, ErrCourseNotFound
		}
		return FinalTest{}, fmt.Errorf("certificates: load course: %w", err)
	}
	return s.repo.GetFinalTestByCourse(ctx, courseID)
}

// ─── Student flow ──────────────────────────────────────────────────────────────

// completionGate confirms the learner is enrolled and has completed every
// module in the course — reuses the existing enrollment/progress tracking
// rather than introducing a second completion signal.
func (s *Service) completionGate(ctx context.Context, userID, courseID string) error {
	enrolled, err := s.coursesRepo.IsEnrolled(ctx, userID, courseID)
	if err != nil {
		return fmt.Errorf("certificates: check enrollment: %w", err)
	}
	if !enrolled {
		return ErrNotEnrolled
	}
	progress, err := s.coursesRepo.GetCourseProgress(ctx, userID, courseID)
	if err != nil {
		return fmt.Errorf("certificates: check progress: %w", err)
	}
	if progress.Total == 0 || progress.Completed != progress.Total {
		return ErrCourseNotComplete
	}
	return nil
}

func (s *Service) GetFinalTestForStudent(ctx context.Context, userID, courseID string) (StudentFinalTest, error) {
	if err := s.completionGate(ctx, userID, courseID); err != nil {
		return StudentFinalTest{}, err
	}
	ft, err := s.repo.GetFinalTestByCourse(ctx, courseID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return StudentFinalTest{}, ErrNoFinalTest
		}
		return StudentFinalTest{}, err
	}
	used, err := s.repo.CountAttempts(ctx, userID, ft.ID)
	if err != nil {
		return StudentFinalTest{}, err
	}
	passed, err := s.repo.HasPassedAttempt(ctx, userID, ft.ID)
	if err != nil {
		return StudentFinalTest{}, err
	}
	result := StudentFinalTest{
		ID:                  ft.ID,
		CourseID:            ft.CourseID,
		Questions:           toStudentQuestions(ft.Questions),
		TimeLimitMinutes:    ft.TimeLimitMinutes,
		PassingScorePercent: ft.PassingScorePercent,
		MaxAttempts:         ft.MaxAttempts,
		AttemptsUsed:        used,
		AlreadyPassed:       passed,
	}
	if passed {
		cert, err := s.repo.GetCertificateForCourse(ctx, userID, courseID)
		if err != nil {
			return StudentFinalTest{}, err
		}
		result.CertUUID = &cert.CertUUID
	}
	return result, nil
}

// SubmitAttempt grades every question inline (MCQ synchronously, coding via
// the injected executor — same Piston/Judge0 path assessment attempts use),
// then issues a certificate the first time a learner passes. A learner who
// already has a certificate for this course is not re-issued a second one on
// a later passing attempt (ON CONFLICT-free by construction: the caller
// checks GetCertificateForCourse first).
func (s *Service) SubmitAttempt(ctx context.Context, orgID, userID, courseID string, req SubmitAttemptRequest) (SubmitAttemptResponse, error) {
	if err := s.completionGate(ctx, userID, courseID); err != nil {
		return SubmitAttemptResponse{}, err
	}
	ft, err := s.repo.GetFinalTestByCourse(ctx, courseID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return SubmitAttemptResponse{}, ErrNoFinalTest
		}
		return SubmitAttemptResponse{}, err
	}

	used, err := s.repo.CountAttempts(ctx, userID, ft.ID)
	if err != nil {
		return SubmitAttemptResponse{}, err
	}
	if used >= ft.MaxAttempts {
		return SubmitAttemptResponse{}, ErrAttemptsExhausted
	}

	totalPoints := 0.0
	scoredPoints := 0.0
	resolve := func(assessment.CodingContent) assessment.CodeExecutor { return s.executor }

	for _, q := range ft.Questions {
		totalPoints += q.Points
		answer := req.Answers[q.ID]

		switch q.Type {
		case QuestionMCQ:
			if q.MCQ == nil {
				continue
			}
			content, err := json.Marshal(q.MCQ)
			if err != nil {
				return SubmitAttemptResponse{}, fmt.Errorf("certificates: marshal mcq content: %w", err)
			}
			_, pts, err := assessment.GradeMCQ(content, answer, q.Points)
			if err != nil {
				return SubmitAttemptResponse{}, fmt.Errorf("certificates: grade mcq %s: %w", q.ID, err)
			}
			scoredPoints += pts

		case QuestionCoding:
			if q.Coding == nil {
				continue
			}
			content, err := json.Marshal(q.Coding)
			if err != nil {
				return SubmitAttemptResponse{}, fmt.Errorf("certificates: marshal coding content: %w", err)
			}
			_, _, pts, _, _, _, err := assessment.GradeCoding(ctx, resolve, content, answer, q.Points)
			if err != nil {
				return SubmitAttemptResponse{}, fmt.Errorf("certificates: grade coding %s: %w", q.ID, err)
			}
			scoredPoints += pts
		}
	}

	score := 0
	total := 100
	if totalPoints > 0 {
		score = int((scoredPoints / totalPoints) * 100)
	}
	passed := score >= ft.PassingScorePercent

	answersRaw, err := json.Marshal(req.Answers)
	if err != nil {
		return SubmitAttemptResponse{}, fmt.Errorf("certificates: marshal answers: %w", err)
	}
	attempt, err := s.repo.CreateAttempt(ctx, userID, ft.ID, answersRaw, score, total, passed)
	if err != nil {
		return SubmitAttemptResponse{}, err
	}

	resp := SubmitAttemptResponse{Attempt: attempt}
	if passed {
		existing, err := s.repo.GetCertificateForCourse(ctx, userID, courseID)
		switch {
		case errors.Is(err, ErrNotFound):
			cert, err := s.repo.IssueCertificate(ctx, userID, courseID, attempt.ID)
			if err != nil {
				return SubmitAttemptResponse{}, err
			}
			resp.Certificate = &cert
		case err != nil:
			return SubmitAttemptResponse{}, err
		default:
			resp.Certificate = &existing
		}
	}
	return resp, nil
}

func (s *Service) ListMyCertificates(ctx context.Context, userID string) ([]CertificateView, error) {
	return s.repo.ListMyCertificates(ctx, userID)
}

func (s *Service) VerifyCertificate(ctx context.Context, certUUID string) (CertificateView, error) {
	return s.repo.GetByUUID(ctx, certUUID)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// toStudentQuestions strips every server-only grading field before a
// question set is sent to the client — MCQOption.IsCorrect, hidden
// TestCase.Stdin/Expected, and CodingContent's VerifyFiles/VerifyCommand.
func toStudentQuestions(qs []Question) []StudentQuestion {
	out := make([]StudentQuestion, len(qs))
	for i, q := range qs {
		sq := StudentQuestion{ID: q.ID, Type: q.Type, Points: q.Points}
		if q.MCQ != nil {
			options := make([]assessment.MCQOption, len(q.MCQ.Options))
			for j, o := range q.MCQ.Options {
				options[j] = assessment.MCQOption{ID: o.ID, Text: o.Text}
			}
			mcq := *q.MCQ
			mcq.Options = options
			sq.MCQ = &mcq
		}
		if q.Coding != nil {
			cases := make([]assessment.TestCase, 0, len(q.Coding.TestCases))
			for _, tc := range q.Coding.TestCases {
				if tc.Hidden {
					cases = append(cases, assessment.TestCase{ID: tc.ID, Hidden: true, Weight: tc.Weight})
					continue
				}
				cases = append(cases, tc)
			}
			coding := *q.Coding
			coding.TestCases = cases
			coding.VerifyFiles = nil
			coding.VerifyCommand = ""
			sq.Coding = &coding
		}
		out[i] = sq
	}
	return out
}
