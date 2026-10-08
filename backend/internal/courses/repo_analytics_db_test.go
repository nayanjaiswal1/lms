package courses

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

type analyticsFixture struct {
	t    *testing.T
	ctx  context.Context
	pool *pgxpool.Pool
}

func (f analyticsFixture) one(dst *string, sql string, args ...any) {
	f.t.Helper()
	if err := f.pool.QueryRow(f.ctx, sql, args...).Scan(dst); err != nil {
		f.t.Fatalf("seed (%s): %v", sql, err)
	}
}

func (f analyticsFixture) exec(sql string, args ...any) {
	f.t.Helper()
	if _, err := f.pool.Exec(f.ctx, sql, args...); err != nil {
		f.t.Fatalf("seed (%s): %v", sql, err)
	}
}

// student creates a user, org membership (with status) and enrollment whose
// enrolled_at is daysAgo days in the past.
func (f analyticsFixture) student(orgID, courseID, name, memberStatus string, daysAgo int) string {
	var uid string
	f.one(&uid, `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`, name+"@"+testdomain.Domain, name)
	f.exec(`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, 'learner', $3)`, orgID, uid, memberStatus)
	f.exec(`INSERT INTO enrollments (user_id, course_id, enrolled_at) VALUES ($1, $2, now() - make_interval(days => $3))`, uid, courseID, daysAgo)
	return uid
}

// progress marks a module with a status last touched daysAgo days ago.
func (f analyticsFixture) progress(userID, courseID, moduleID, status string, daysAgo int) {
	f.exec(`INSERT INTO module_progress (user_id, module_id, course_id, status, updated_at)
	        VALUES ($1, $2, $3, $4, now() - make_interval(days => $5))`, userID, moduleID, courseID, status, daysAgo)
}

func (f analyticsFixture) answer(attemptID, aqID, qID string, correct bool) {
	f.exec(`INSERT INTO attempt_answers (attempt_id, assessment_question_id, question_id, is_correct, evaluated_at)
	        VALUES ($1, $2, $3, $4, now())`, attemptID, aqID, qID, correct)
}

func TestCourseAnalytics(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	f := analyticsFixture{t: t, ctx: ctx, pool: pool}

	var orgA, orgB, creator, course1, course2, sec, mod1, mod2, mod3, quizMod, asmt string
	f.one(&orgA, `INSERT INTO organizations (slug, name) VALUES ('an-a', 'A') RETURNING id`)
	f.one(&orgB, `INSERT INTO organizations (slug, name) VALUES ('an-b', 'B') RETURNING id`)
	f.one(&creator, `INSERT INTO users (email, name) VALUES ('creator@`+testdomain.Domain+`', 'Creator') RETURNING id`)
	f.one(&course1, `INSERT INTO courses (org_id, creator_id, title, slug) VALUES ($1, $2, 'One', 'one') RETURNING id`, orgA, creator)
	f.one(&course2, `INSERT INTO courses (org_id, creator_id, title, slug) VALUES ($1, $2, 'Two', 'two') RETURNING id`, orgA, creator)
	f.one(&sec, `INSERT INTO course_sections (course_id, title, position) VALUES ($1, 'S', 0) RETURNING id`, course1)
	mk := func(title string, pos int) string {
		var id string
		f.one(&id, `INSERT INTO course_modules (course_id, section_id, title, type, position, content_body)
		            VALUES ($1, $2, $3, 'notes', $4, 'x') RETURNING id`, course1, sec, title, pos)
		return id
	}
	mod1, mod2, mod3 = mk("L1", 0), mk("L2", 1), mk("L3", 2)
	f.one(&asmt, `INSERT INTO assessments (org_id, title, slug, type, created_by) VALUES ($1, 'Quiz', 'quiz', 'mcq', $2) RETURNING id`, orgA, creator)
	f.one(&quizMod, `INSERT INTO course_modules (course_id, section_id, title, type, position, assessment_id)
	                 VALUES ($1, $2, 'Quiz', 'assessment', 3, $3) RETURNING id`, course1, sec, asmt)
	// Same quiz reused by a lesson of course 2.
	var sec2 string
	f.one(&sec2, `INSERT INTO course_sections (course_id, title, position) VALUES ($1, 'S', 0) RETURNING id`, course2)
	f.exec(`INSERT INTO course_modules (course_id, section_id, title, type, position, assessment_id)
	        VALUES ($1, $2, 'Quiz2', 'assessment', 0, $3)`, course2, sec2, asmt)

	s1 := f.student(orgA, course1, "s1", "active", 0)
	s2 := f.student(orgA, course1, "s2", "active", 0)
	s3 := f.student(orgA, course1, "s3", "active", 40)
	s4 := f.student(orgA, course1, "s4", "active", 40)
	s5 := f.student(orgA, course1, "s5", "active", 0)
	f.student(orgA, course1, "s6", "removed", 40)
	outsider := f.student(orgA, course2, "outsider", "active", 0)

	for _, m := range []string{mod1, mod2, mod3, quizMod} {
		f.progress(s1, course1, m, "completed", 0)
	}
	f.progress(s2, course1, mod1, "completed", 0)
	f.progress(s2, course1, mod2, "completed", 0)
	f.progress(s3, course1, mod1, "completed", 30)

	// Questions: q1 hard (1/5 correct), q2 easy (4/5), q3 under min_answers.
	var qs, aqs [3]string
	for i := range qs {
		f.one(&qs[i], `INSERT INTO questions (org_id, type, title, created_by) VALUES ($1, 'mcq', $2, $3) RETURNING id`,
			orgA, fmt.Sprintf("Q%d", i+1), creator)
		var ver string
		f.one(&ver, `INSERT INTO question_versions (question_id, version, content, created_by) VALUES ($1, 1, '{}', $2) RETURNING id`, qs[i], creator)
		f.one(&aqs[i], `INSERT INTO assessment_questions (assessment_id, question_id, version_id, position) VALUES ($1, $2, $3, $4) RETURNING id`,
			asmt, qs[i], ver, i)
	}
	for i, u := range []string{s1, s2, s3, s4, s5, outsider} {
		var att string
		f.one(&att, `INSERT INTO assessment_attempts (assessment_id, user_id, org_id, status) VALUES ($1, $2, $3, 'evaluated') RETURNING id`, asmt, u, orgA)
		if u == outsider { // enrolled only in course 2: must not count in course 1
			f.answer(att, aqs[0], qs[0], false)
			continue
		}
		f.answer(att, aqs[0], qs[0], i == 0)
		f.answer(att, aqs[1], qs[1], i != 0)
		if i < 2 {
			f.answer(att, aqs[2], qs[2], true)
		}
	}

	t.Run("funnel", func(t *testing.T) {
		got, err := repo.CourseFunnel(ctx, orgA, course1)
		if err != nil {
			t.Fatal(err)
		}
		want := Funnel{Enrolled: 6, Started: 3, Reached25: 3, Reached50: 2, Reached75: 1, Completed: 1}
		if got != want {
			t.Fatalf("funnel = %+v, want %+v", got, want)
		}
	})

	t.Run("lessons drop-off", func(t *testing.T) {
		got, err := repo.LessonStats(ctx, orgA, course1)
		if err != nil {
			t.Fatal(err)
		}
		wantCompleted, wantDrop := []int{3, 2, 1, 1}, []int{0, 1, 1, 0}
		if len(got) != 4 {
			t.Fatalf("lessons = %d, want 4", len(got))
		}
		for i, l := range got {
			if l.Completed != wantCompleted[i] || l.DropOff != wantDrop[i] {
				t.Errorf("lesson %d (%s): completed=%d drop=%d, want %d/%d", i, l.Title, l.Completed, l.DropOff, wantCompleted[i], wantDrop[i])
			}
		}
		if got[0].CompletionRate != 50 { // 3 of 6 enrolled
			t.Errorf("completion_rate = %v, want 50", got[0].CompletionRate)
		}
	})

	t.Run("hardest questions", func(t *testing.T) {
		got, total, err := repo.HardestQuestions(ctx, orgA, course1, 5, 10, 0)
		if err != nil {
			t.Fatal(err)
		}
		if total != 2 || len(got) != 2 {
			t.Fatalf("total=%d len=%d, want 2/2 (q3 has 2 answers < min 5)", total, len(got))
		}
		if got[0].QuestionID != qs[0] || got[0].CorrectRate != 20 || got[0].Answered != 5 || got[0].Students != 5 {
			t.Errorf("hardest = %+v, want q1 20%% over 5 answers (outsider excluded)", got[0])
		}
		if got[1].QuestionID != qs[1] || got[1].CorrectRate != 80 {
			t.Errorf("second = %+v, want q2 80%%", got[1])
		}
		lowMin, _, err := repo.HardestQuestions(ctx, orgA, course1, 2, 10, 0)
		if err != nil || len(lowMin) != 3 {
			t.Fatalf("min_answers=2: len=%d err=%v, want 3", len(lowMin), err)
		}
	})

	t.Run("at-risk students", func(t *testing.T) {
		flt := StudentFilter{Risk: RiskFilterAtRisk, InactiveDays: 14, MaxProgressPct: 25, Limit: 10}
		got, total, err := repo.CourseStudents(ctx, orgA, course1, flt)
		if err != nil {
			t.Fatal(err)
		}
		if total != 2 || len(got) != 2 {
			t.Fatalf("total=%d len=%d, want 2 (s3,s4; s5 in grace, s6 removed, s1 done, s2 healthy)", total, len(got))
		}
		if got[0].UserID != s4 || len(got[0].RiskReasons) != 2 || got[0].RiskReasons[0] != RiskInactive || got[0].RiskReasons[1] != RiskLowProgress {
			t.Errorf("first = %+v, want s4 inactive+low_progress", got[0])
		}
		if got[1].UserID != s3 || len(got[1].RiskReasons) != 1 || got[1].RiskReasons[0] != RiskInactive {
			t.Errorf("second = %+v, want s3 inactive only (25%% is not < 25)", got[1])
		}

		flt.Limit = 1
		page, total, err := repo.CourseStudents(ctx, orgA, course1, flt)
		if err != nil || len(page) != 1 || total != 2 {
			t.Fatalf("limit=1: len=%d total=%d err=%v, want 1/2", len(page), total, err)
		}

		flt.Risk, flt.Limit = RiskFilterAll, 10
		all, total, err := repo.CourseStudents(ctx, orgA, course1, flt)
		if err != nil || total != 5 || len(all) != 5 {
			t.Fatalf("all: len=%d total=%d err=%v, want 5 (removed member excluded)", len(all), total, err)
		}
	})

	t.Run("trend zero-fill", func(t *testing.T) {
		pts, err := repo.EnrollmentTrend(ctx, orgA, &course1, 7)
		if err != nil {
			t.Fatal(err)
		}
		if len(pts) != 7 {
			t.Fatalf("len = %d, want 7", len(pts))
		}
		sum := 0
		for _, p := range pts {
			sum += p.Enrollments
		}
		if pts[6].Enrollments != 3 || sum != 3 || pts[0].Enrollments != 0 {
			t.Errorf("trend = %+v, want only today=3 (s1,s2,s5)", pts)
		}
		org, err := repo.EnrollmentTrend(ctx, orgA, nil, 30)
		if err != nil || len(org) != 30 || org[29].Enrollments != 4 {
			t.Fatalf("org trend len=%d today=%v err=%v, want 30 / 4", len(org), org[len(org)-1], err)
		}
	})

	t.Run("course summaries", func(t *testing.T) {
		got, total, err := repo.CourseSummaries(ctx, orgA, 10, 0)
		if err != nil || total != 2 || len(got) != 2 {
			t.Fatalf("len=%d total=%d err=%v, want 2", len(got), total, err)
		}
		for _, c := range got {
			if c.CourseID == course1 && (c.Enrolled != 6 || c.Completed != 1 || c.ActiveLast7d != 3 || c.AvgProgressPct != 29.2) {
				t.Errorf("course1 summary = %+v", c)
			}
			if c.CourseID == course2 && (c.Enrolled != 1 || c.Completed != 0) {
				t.Errorf("course2 summary = %+v", c)
			}
		}
	})

	t.Run("tenant isolation", func(t *testing.T) {
		if _, err := repo.CourseFunnel(ctx, orgB, course1); !errors.Is(err, ErrNotFound) {
			t.Errorf("funnel: %v, want ErrNotFound", err)
		}
		if _, err := repo.LessonStats(ctx, orgB, course1); !errors.Is(err, ErrNotFound) {
			t.Errorf("lessons: %v, want ErrNotFound", err)
		}
		if _, _, err := repo.HardestQuestions(ctx, orgB, course1, 1, 10, 0); !errors.Is(err, ErrNotFound) {
			t.Errorf("questions: %v, want ErrNotFound", err)
		}
		if _, _, err := repo.CourseStudents(ctx, orgB, course1, StudentFilter{Risk: RiskFilterAll, InactiveDays: 14, MaxProgressPct: 25, Limit: 10}); !errors.Is(err, ErrNotFound) {
			t.Errorf("students: %v, want ErrNotFound", err)
		}
		if _, err := repo.EnrollmentTrend(ctx, orgB, &course1, 7); !errors.Is(err, ErrNotFound) {
			t.Errorf("trend: %v, want ErrNotFound", err)
		}
		if cs, total, err := repo.CourseSummaries(ctx, orgB, 10, 0); err != nil || len(cs) != 0 || total != 0 {
			t.Errorf("summaries for empty org: %v %d %v", cs, total, err)
		}
		pts, err := repo.EnrollmentTrend(ctx, orgB, nil, 7)
		if err != nil {
			t.Fatal(err)
		}
		for _, p := range pts {
			if p.Enrollments != 0 {
				t.Errorf("org B trend leaked enrollments: %+v", pts)
			}
		}
	})
}

func TestBoundedInt(t *testing.T) {
	cases := []struct {
		query   string
		want    int
		wantErr bool
	}{
		{"", 30, false},
		{"days=45", 45, false},
		{"days=7", 7, false},
		{"days=180", 180, false},
		{"days=6", 30, true},
		{"days=181", 30, true},
		{"days=abc", 30, true},
	}
	for _, c := range cases {
		r := httptest.NewRequest(http.MethodGet, "/x?"+c.query, nil)
		errs := map[string]string{}
		if got := boundedInt(r, "days", 30, 7, 180, errs); got != c.want || (len(errs) > 0) != c.wantErr {
			t.Errorf("%q: got %d errs=%v, want %d err=%v", c.query, got, errs, c.want, c.wantErr)
		}
	}
}
