package courses

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

const (
	defaultTrendDays      = 30
	minTrendDays          = 7
	maxTrendDays          = 180
	defaultInactiveDays   = 14
	maxInactiveDays       = 365
	defaultMaxProgressPct = 25
	defaultMinAnswers     = 5
	maxMinAnswers         = 1000
	maxAnalyticsLimit     = 200
	maxOffset             = 1_000_000
	activeWindowDays      = 7

	// RiskInactive / RiskLowProgress are the values of StudentRisk.RiskReasons.
	RiskInactive    = "inactive"
	RiskLowProgress = "low_progress"

	// RiskFilterAtRisk / RiskFilterAll are the accepted StudentFilter.Risk values.
	RiskFilterAtRisk = "at_risk"
	RiskFilterAll    = "all"

	trendDateLayout = "2006-01-02"
)

// Funnel counts enrolled students by the furthest progress stage they reached.
type Funnel struct {
	Enrolled  int `json:"enrolled"`
	Started   int `json:"started"`
	Reached25 int `json:"reached_25"`
	Reached50 int `json:"reached_50"`
	Reached75 int `json:"reached_75"`
	Completed int `json:"completed"`
}

// LessonStat is one lesson's reach, completion and drop-off versus its predecessor.
type LessonStat struct {
	ModuleID       string  `json:"module_id"`
	Title          string  `json:"title"`
	Type           string  `json:"type"`
	SectionTitle   string  `json:"section_title"`
	Position       int     `json:"position"`
	Started        int     `json:"started"`
	Completed      int     `json:"completed"`
	CompletionRate float64 `json:"completion_rate"`
	DropOff        int     `json:"drop_off"`
}

// HardQuestion is a quiz question ranked by how rarely it is answered correctly.
type HardQuestion struct {
	AssessmentQuestionID string  `json:"assessment_question_id"`
	QuestionID           string  `json:"question_id"`
	Title                string  `json:"title"`
	Type                 string  `json:"type"`
	ModuleID             string  `json:"module_id"`
	ModuleTitle          string  `json:"module_title"`
	Answered             int     `json:"answered"`
	Students             int     `json:"students"`
	CorrectRate          float64 `json:"correct_rate"`
}

// StudentRisk is one enrolled student with the reasons they are flagged.
type StudentRisk struct {
	UserID           string    `json:"user_id"`
	Name             string    `json:"name"`
	Email            string    `json:"email"`
	EnrolledAt       time.Time `json:"enrolled_at"`
	CompletedModules int       `json:"completed_modules"`
	TotalModules     int       `json:"total_modules"`
	ProgressPct      float64   `json:"progress_pct"`
	LastActiveAt     time.Time `json:"last_active_at"`
	DaysInactive     int       `json:"days_inactive"`
	RiskReasons      []string  `json:"risk_reasons"`
}

// StudentFilter narrows CourseStudents.
type StudentFilter struct {
	Risk           string
	InactiveDays   int
	MaxProgressPct int
	Limit          int
	Offset         int
}

// CourseSummary is one row of the org-wide course table.
type CourseSummary struct {
	CourseID       string  `json:"course_id"`
	Title          string  `json:"title"`
	Slug           string  `json:"slug"`
	Status         string  `json:"status"`
	Enrolled       int     `json:"enrolled"`
	Completed      int     `json:"completed"`
	AvgProgressPct float64 `json:"avg_progress_pct"`
	ActiveLast7d   int     `json:"active_last_7d"`
}

// TrendPoint is the number of enrollments on one UTC day.
type TrendPoint struct {
	Date        string `json:"date"`
	Enrollments int    `json:"enrollments"`
}

// courseProgressCTE derives per-enrollment progress for course $1 in org $2.
// enrollments.completed_at is never written, so "completed" means every
// non-deleted module is completed; a course with no modules has no completers.
// last_active is the later of enrollment and the newest module_progress touch.
const courseProgressCTE = `
WITH mods AS (
	SELECT id FROM course_modules WHERE course_id = $1 AND deleted_at IS NULL
), prog AS (
	SELECT mp.user_id,
	       count(*) FILTER (WHERE mp.status = 'completed')    AS completed,
	       count(*) FILTER (WHERE mp.status <> 'not_started') AS touched,
	       max(mp.updated_at)                                  AS last_at
	FROM module_progress mp JOIN mods ON mods.id = mp.module_id
	GROUP BY mp.user_id
), ep AS (
	SELECT e.user_id,
	       COALESCE(e.enrolled_at, now())                      AS enrolled_at,
	       COALESCE(p.completed, 0)                            AS completed,
	       COALESCE(p.touched, 0)                              AS touched,
	       (SELECT count(*) FROM mods)                         AS total,
	       GREATEST(COALESCE(e.enrolled_at, now()), p.last_at) AS last_active
	FROM enrollments e
	JOIN courses c ON c.id = e.course_id AND c.org_id = $2
	LEFT JOIN prog p ON p.user_id = e.user_id
	WHERE e.course_id = $1
)`

// ownsCourse reports ErrNotFound unless the course belongs to orgID. Every
// per-course analytics query calls it first so a foreign course ID can never
// surface another tenant's numbers.
func (r *Repo) ownsCourse(ctx context.Context, orgID, courseID string) error {
	var one int
	err := r.pool.QueryRow(ctx, `SELECT 1 FROM courses WHERE id = $1 AND org_id = $2`, courseID, orgID).Scan(&one)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("courses: analytics ownsCourse: %w", err)
	}
	return nil
}

// CourseFunnel returns the completion funnel for one course.
func (r *Repo) CourseFunnel(ctx context.Context, orgID, courseID string) (Funnel, error) {
	if err := r.ownsCourse(ctx, orgID, courseID); err != nil {
		return Funnel{}, err
	}
	var f Funnel
	err := r.pool.QueryRow(ctx, courseProgressCTE+`
SELECT count(*),
       count(*) FILTER (WHERE touched > 0),
       count(*) FILTER (WHERE total > 0 AND 100.0 * completed / NULLIF(total, 0) >= 25),
       count(*) FILTER (WHERE total > 0 AND 100.0 * completed / NULLIF(total, 0) >= 50),
       count(*) FILTER (WHERE total > 0 AND 100.0 * completed / NULLIF(total, 0) >= 75),
       count(*) FILTER (WHERE total > 0 AND completed = total)
FROM ep`, courseID, orgID).Scan(&f.Enrolled, &f.Started, &f.Reached25, &f.Reached50, &f.Reached75, &f.Completed)
	if err != nil {
		return Funnel{}, fmt.Errorf("courses: analytics CourseFunnel: %w", err)
	}
	return f, nil
}

// LessonStats returns every lesson in course order with reach and drop-off.
// drop_off is how many more students completed the previous lesson than this
// one, floored at 0.
// ponytail: unpaginated — a course has tens to low hundreds of lessons; page it if that ever changes.
func (r *Repo) LessonStats(ctx context.Context, orgID, courseID string) ([]LessonStat, error) {
	if err := r.ownsCourse(ctx, orgID, courseID); err != nil {
		return nil, err
	}
	rows, err := r.pool.Query(ctx, `
WITH enrolled AS (
	SELECT user_id FROM enrollments WHERE course_id = $1
), agg AS (
	SELECT cm.id, cm.title, cm.type, cs.title AS section_title, cm.position,
	       cs.position AS section_pos,
	       count(mp.user_id) FILTER (WHERE mp.status <> 'not_started') AS started,
	       count(mp.user_id) FILTER (WHERE mp.status = 'completed')    AS completed
	FROM course_modules cm
	JOIN course_sections cs ON cs.id = cm.section_id
	LEFT JOIN module_progress mp ON mp.module_id = cm.id AND mp.user_id IN (SELECT user_id FROM enrolled)
	WHERE cm.course_id = $1 AND cm.deleted_at IS NULL
	GROUP BY cm.id, cs.id
)
SELECT id, title, type, section_title, position, started, completed,
       COALESCE(ROUND(100.0 * completed / NULLIF((SELECT count(*) FROM enrolled), 0), 1), 0)::float8,
       GREATEST(COALESCE(LAG(completed) OVER (ORDER BY section_pos, position, id) - completed, 0), 0)::int
FROM agg
ORDER BY section_pos, position, id`, courseID)
	if err != nil {
		return nil, fmt.Errorf("courses: analytics LessonStats: %w", err)
	}
	defer rows.Close()
	out := []LessonStat{}
	for rows.Next() {
		var l LessonStat
		if err := rows.Scan(&l.ModuleID, &l.Title, &l.Type, &l.SectionTitle, &l.Position,
			&l.Started, &l.Completed, &l.CompletionRate, &l.DropOff); err != nil {
			return nil, fmt.Errorf("courses: analytics LessonStats scan: %w", err)
		}
		out = append(out, l)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("courses: analytics LessonStats: %w", err)
	}
	return out, nil
}

// HardestQuestions ranks the course's quiz questions (assessment modules and
// knowledge checks) by ascending correct rate, counting only evaluated answers
// from students enrolled in this course. The rate is per submitted answer, not
// per student. Returns the page and the total number of qualifying questions.
func (r *Repo) HardestQuestions(ctx context.Context, orgID, courseID string, minAnswers, limit, offset int) ([]HardQuestion, int, error) {
	if err := r.ownsCourse(ctx, orgID, courseID); err != nil {
		return nil, 0, err
	}
	rows, err := r.pool.Query(ctx, `
WITH course_assessments AS (
	SELECT cm.assessment_id AS assessment_id, cm.id AS module_id
	FROM course_modules cm
	JOIN assessments a ON a.id = cm.assessment_id AND a.org_id = $2
	WHERE cm.course_id = $1 AND cm.deleted_at IS NULL
	UNION
	SELECT a.id, cm.id
	FROM course_modules cm
	JOIN assessments a ON a.parent_type = 'module' AND a.parent_id = cm.id
	                  AND a.type = 'knowledge_check' AND a.org_id = $2
	WHERE cm.course_id = $1 AND cm.deleted_at IS NULL
)
SELECT aq.id, q.id, q.title, q.type, ca.module_id, cm.title,
       count(*)::int AS answered,
       count(DISTINCT att.user_id)::int AS students,
       ROUND(100.0 * count(*) FILTER (WHERE aa.is_correct) / count(*), 1)::float8 AS correct_rate,
       (count(*) OVER())::int AS total
FROM course_assessments ca
JOIN assessment_questions aq ON aq.assessment_id = ca.assessment_id
JOIN questions q ON q.id = aq.question_id AND q.org_id = $2
JOIN attempt_answers aa ON aa.assessment_question_id = aq.id AND aa.evaluated_at IS NOT NULL
JOIN assessment_attempts att ON att.id = aa.attempt_id AND att.org_id = $2
JOIN enrollments e ON e.user_id = att.user_id AND e.course_id = $1
JOIN course_modules cm ON cm.id = ca.module_id
GROUP BY aq.id, q.id, ca.module_id, cm.id
HAVING count(*) >= $3
ORDER BY correct_rate ASC, answered DESC, aq.id
LIMIT $4 OFFSET $5`, courseID, orgID, minAnswers, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("courses: analytics HardestQuestions: %w", err)
	}
	defer rows.Close()
	out := []HardQuestion{}
	total := 0
	for rows.Next() {
		var h HardQuestion
		if err := rows.Scan(&h.AssessmentQuestionID, &h.QuestionID, &h.Title, &h.Type, &h.ModuleID,
			&h.ModuleTitle, &h.Answered, &h.Students, &h.CorrectRate, &total); err != nil {
			return nil, 0, fmt.Errorf("courses: analytics HardestQuestions scan: %w", err)
		}
		out = append(out, h)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("courses: analytics HardestQuestions: %w", err)
	}
	return out, total, nil
}

// CourseStudents lists enrolled students who are still active org members,
// least recently active first. With Risk=at_risk only students who are not
// finished, past the inactivity grace period since enrollment, and either
// inactive or below MaxProgressPct are returned.
func (r *Repo) CourseStudents(ctx context.Context, orgID, courseID string, f StudentFilter) ([]StudentRisk, int, error) {
	if err := r.ownsCourse(ctx, orgID, courseID); err != nil {
		return nil, 0, err
	}
	rows, err := r.pool.Query(ctx, courseProgressCTE+`
, scored AS (
	SELECT ep.*,
	       COALESCE(100.0 * ep.completed / NULLIF(ep.total, 0), 0) AS pct,
	       (NOT (ep.total > 0 AND ep.completed = ep.total)
	         AND ep.enrolled_at <= now() - make_interval(days => $3::int))        AS eligible,
	       (ep.last_active < now() - make_interval(days => $3::int))              AS inactive,
	       (COALESCE(100.0 * ep.completed / NULLIF(ep.total, 0), 0) < $4::int)    AS low
	FROM ep
)
SELECT u.id, u.name, u.email, s.enrolled_at, s.completed::int, s.total::int, ROUND(s.pct, 1)::float8,
       s.last_active,
       GREATEST(floor(extract(epoch FROM now() - s.last_active) / 86400), 0)::int,
       array_remove(ARRAY[
           CASE WHEN s.eligible AND s.inactive THEN $8::text END,
           CASE WHEN s.eligible AND s.low THEN $9::text END], NULL),
       (count(*) OVER())::int
FROM scored s
JOIN users u ON u.id = s.user_id
WHERE EXISTS (SELECT 1 FROM org_members om
              WHERE om.org_id = $2 AND om.user_id = s.user_id AND om.status = 'active')
  AND ($5::text = $10::text OR (s.eligible AND (s.inactive OR s.low)))
ORDER BY s.last_active ASC, u.id
LIMIT $6 OFFSET $7`, courseID, orgID, f.InactiveDays, f.MaxProgressPct, f.Risk, f.Limit, f.Offset,
		RiskInactive, RiskLowProgress, RiskFilterAll)
	if err != nil {
		return nil, 0, fmt.Errorf("courses: analytics CourseStudents: %w", err)
	}
	defer rows.Close()
	out := []StudentRisk{}
	total := 0
	for rows.Next() {
		var s StudentRisk
		if err := rows.Scan(&s.UserID, &s.Name, &s.Email, &s.EnrolledAt, &s.CompletedModules, &s.TotalModules,
			&s.ProgressPct, &s.LastActiveAt, &s.DaysInactive, &s.RiskReasons, &total); err != nil {
			return nil, 0, fmt.Errorf("courses: analytics CourseStudents scan: %w", err)
		}
		out = append(out, s)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("courses: analytics CourseStudents: %w", err)
	}
	return out, total, nil
}

// EnrollmentTrend returns exactly `days` zero-filled daily enrollment counts
// ending today, for one course (courseID != nil) or the whole org.
// ponytail: days are cut at UTC midnight, not the viewer's timezone; add a tz param if per-org zones matter.
func (r *Repo) EnrollmentTrend(ctx context.Context, orgID string, courseID *string, days int) ([]TrendPoint, error) {
	if courseID != nil {
		if err := r.ownsCourse(ctx, orgID, *courseID); err != nil {
			return nil, err
		}
	}
	rows, err := r.pool.Query(ctx, `
WITH today AS (SELECT (now() AT TIME ZONE 'UTC')::date AS d)
SELECT gs::date, COALESCE(n.c, 0)::int
FROM today,
     generate_series((today.d - ($1::int - 1))::timestamp, today.d::timestamp, interval '1 day') gs
LEFT JOIN (
	SELECT (e.enrolled_at AT TIME ZONE 'UTC')::date AS day, count(*) AS c
	FROM enrollments e
	JOIN courses c ON c.id = e.course_id AND c.org_id = $2
	WHERE ($3::uuid IS NULL OR e.course_id = $3::uuid)
	  AND e.enrolled_at >= (((now() AT TIME ZONE 'UTC')::date - ($1::int - 1))::timestamp AT TIME ZONE 'UTC')
	GROUP BY 1
) n ON n.day = gs::date
ORDER BY gs`, days, orgID, courseID)
	if err != nil {
		return nil, fmt.Errorf("courses: analytics EnrollmentTrend: %w", err)
	}
	defer rows.Close()
	out := make([]TrendPoint, 0, days)
	for rows.Next() {
		var d time.Time
		var p TrendPoint
		if err := rows.Scan(&d, &p.Enrollments); err != nil {
			return nil, fmt.Errorf("courses: analytics EnrollmentTrend scan: %w", err)
		}
		p.Date = d.Format(trendDateLayout)
		out = append(out, p)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("courses: analytics EnrollmentTrend: %w", err)
	}
	return out, nil
}

// CourseSummaries pages the org's courses (newest first) and attaches
// per-course enrollment, completion, average progress and 7-day activity.
// total is 0 when offset is past the last row.
func (r *Repo) CourseSummaries(ctx context.Context, orgID string, limit, offset int) ([]CourseSummary, int, error) {
	rows, err := r.pool.Query(ctx, `
WITH page AS (
	SELECT c.id, c.title, c.slug, c.status, c.created_at, (count(*) OVER())::int AS total
	FROM courses c WHERE c.org_id = $1
	ORDER BY c.created_at DESC, c.id
	LIMIT $2 OFFSET $3
)
SELECT page.id, page.title, page.slug, page.status, page.total,
       s.enrolled, s.completed, s.avg_pct, s.active
FROM page
CROSS JOIN LATERAL (
	SELECT count(e.user_id)::int AS enrolled,
	       (count(*) FILTER (WHERE e.user_id IS NOT NULL AND t.total > 0 AND COALESCE(p.done, 0) = t.total))::int AS completed,
	       COALESCE(ROUND(avg(100.0 * COALESCE(p.done, 0) / NULLIF(t.total, 0)) FILTER (WHERE e.user_id IS NOT NULL), 1), 0)::float8 AS avg_pct,
	       (count(*) FILTER (WHERE GREATEST(COALESCE(e.enrolled_at, now()), p.last_at)
	                              >= now() - make_interval(days => $4::int)))::int AS active
	FROM (SELECT count(*) AS total FROM course_modules WHERE course_id = page.id AND deleted_at IS NULL) t
	LEFT JOIN enrollments e ON e.course_id = page.id
	LEFT JOIN (
		SELECT mp.user_id,
		       count(*) FILTER (WHERE mp.status = 'completed') AS done,
		       max(mp.updated_at) AS last_at
		FROM module_progress mp
		JOIN course_modules cm ON cm.id = mp.module_id AND cm.course_id = page.id AND cm.deleted_at IS NULL
		GROUP BY mp.user_id
	) p ON p.user_id = e.user_id
) s
ORDER BY page.created_at DESC, page.id`, orgID, limit, offset, activeWindowDays)
	if err != nil {
		return nil, 0, fmt.Errorf("courses: analytics CourseSummaries: %w", err)
	}
	defer rows.Close()
	out := []CourseSummary{}
	total := 0
	for rows.Next() {
		var c CourseSummary
		if err := rows.Scan(&c.CourseID, &c.Title, &c.Slug, &c.Status, &total,
			&c.Enrolled, &c.Completed, &c.AvgProgressPct, &c.ActiveLast7d); err != nil {
			return nil, 0, fmt.Errorf("courses: analytics CourseSummaries scan: %w", err)
		}
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("courses: analytics CourseSummaries: %w", err)
	}
	return out, total, nil
}
