package assessment

import (
	"context"
	"fmt"
	"math"
)

// ─────────────────────────────────────────────
// Teacher dashboard analytics — class health, roster (via GetBatchProgress),
// chapter mastery heatmap, weakest/strongest chapter ranking, an estimated
// blockers breakdown, and a progress-vs-engagement scatter. All scoped to a
// batch's assigned courses (content_assignments) so numbers only reflect what this
// class is actually working through.
// ─────────────────────────────────────────────

// ClassHealth summarises a batch's roster into the three engagement buckets.
type ClassHealth struct {
	TotalStudents   int     `json:"total_students"`
	OnTrackPct      float64 `json:"on_track_pct"`
	NeedsSupportPct float64 `json:"needs_support_pct"`
	NotEngagedPct   float64 `json:"not_engaged_pct"`
}

// computeClassHealth buckets an already-fetched roster — no separate query,
// it reuses the same Status field GetBatchProgress already computes per row.
func computeClassHealth(roster []MemberProgress) ClassHealth {
	total := len(roster)
	if total == 0 {
		return ClassHealth{}
	}
	var onTrack, needsSupport, notEngaged int
	for _, m := range roster {
		switch m.Status {
		case StatusOnTrack:
			onTrack++
		case StatusNeedsSupport:
			needsSupport++
		default:
			notEngaged++
		}
	}
	return ClassHealth{
		TotalStudents:   total,
		OnTrackPct:      pct(onTrack, total),
		NeedsSupportPct: pct(needsSupport, total),
		NotEngagedPct:   pct(notEngaged, total),
	}
}

func pct(n, total int) float64 {
	if total == 0 {
		return 0
	}
	return math.Round(float64(n)/float64(total)*1000) / 10
}

// Chapter mastery status — driven entirely by average hint usage.
const (
	MasteryMastered         = "mastered"
	MasteryNeedsPractice    = "needs_practice"
	MasteryNeedsReview      = "needs_review"
	MasteryInsufficientData = "insufficient_data"
)

func masteryStatus(avgHints *float64) string {
	switch {
	case avgHints == nil:
		return MasteryInsufficientData
	case *avgHints <= 1:
		return MasteryMastered
	case *avgHints <= 3:
		return MasteryNeedsPractice
	default:
		return MasteryNeedsReview
	}
}

// ChapterMasteryCell is one (student, chapter) cell in the heatmap grid.
type ChapterMasteryCell struct {
	UserID       string   `json:"user_id"`
	UserName     string   `json:"user_name"`
	SectionID    string   `json:"section_id"`
	SectionTitle string   `json:"section_title"`
	AvgHints     *float64 `json:"avg_hints"`
	Status       string   `json:"status"`
}

// ChapterMastery returns one row per (student, chapter) pair across every
// section of every course assigned to the batch, so the frontend can render
// a dense grid without reshaping a sparse list itself.
func (r *Repo) ChapterMastery(ctx context.Context, orgID, batchID string) ([]ChapterMasteryCell, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name, sec.id, sec.title, AVG(ltc.hints_used)
		 FROM batch_members bm
		 JOIN users u ON u.id = bm.user_id
		 CROSS JOIN (
		   SELECT DISTINCT cs.id, cs.title, cs."position"
		   FROM content_assignments ca
		   JOIN course_sections cs ON cs.course_id = ca.content_id
		   WHERE ca.content_type = 'course' AND ca.assignee_type = 'batch' AND ca.assignee_id = $1
		 ) sec
		 LEFT JOIN course_modules cm ON cm.section_id = sec.id AND cm.type = 'lab'
		 LEFT JOIN lab_definitions ld ON ld.module_id = cm.id
		 LEFT JOIN lab_sessions ls ON ls.lab_id = ld.id AND ls.user_id = u.id
		 LEFT JOIN lab_task_completions ltc ON ltc.session_id = ls.id
		 WHERE bm.batch_id = $1
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)
		 GROUP BY u.id, u.name, sec.id, sec.title, sec."position"
		 ORDER BY u.name, sec."position"`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: chapter mastery: %w", err)
	}
	defer rows.Close()

	out := []ChapterMasteryCell{}
	for rows.Next() {
		var c ChapterMasteryCell
		if err := rows.Scan(&c.UserID, &c.UserName, &c.SectionID, &c.SectionTitle, &c.AvgHints); err != nil {
			return nil, fmt.Errorf("assessment: scan chapter mastery: %w", err)
		}
		c.Status = masteryStatus(c.AvgHints)
		out = append(out, c)
	}
	return out, rows.Err()
}

// ChapterHintStat ranks one chapter by class-wide average hint usage —
// the weakest/strongest chapter bar chart.
type ChapterHintStat struct {
	SectionID    string  `json:"section_id"`
	SectionTitle string  `json:"section_title"`
	AvgHints     float64 `json:"avg_hints"`
	StudentCount int     `json:"student_count"`
}

// ChapterHintRanking returns every chapter in the batch's assigned courses,
// ordered weakest (highest avg hints) first.
func (r *Repo) ChapterHintRanking(ctx context.Context, orgID, batchID string) ([]ChapterHintStat, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT sec.id, sec.title, COALESCE(AVG(ltc.hints_used), 0), COUNT(DISTINCT ls.user_id)
		 FROM content_assignments ca
		 JOIN course_sections sec ON sec.course_id = ca.content_id
		 LEFT JOIN course_modules cm ON cm.section_id = sec.id AND cm.type = 'lab'
		 LEFT JOIN lab_definitions ld ON ld.module_id = cm.id
		 LEFT JOIN lab_sessions ls ON ls.lab_id = ld.id
		   AND ls.user_id IN (SELECT user_id FROM batch_members WHERE batch_id = $1)
		 LEFT JOIN lab_task_completions ltc ON ltc.session_id = ls.id
		 WHERE ca.content_type = 'course' AND ca.assignee_type = 'batch' AND ca.assignee_id = $1
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)
		 GROUP BY sec.id, sec.title
		 ORDER BY AVG(ltc.hints_used) DESC NULLS LAST, sec.title`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: chapter hint ranking: %w", err)
	}
	defer rows.Close()

	out := []ChapterHintStat{}
	for rows.Next() {
		var s ChapterHintStat
		if err := rows.Scan(&s.SectionID, &s.SectionTitle, &s.AvgHints, &s.StudentCount); err != nil {
			return nil, fmt.Errorf("assessment: scan chapter hint stat: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// BlockerBucket is one bucket of the blockers breakdown.
type BlockerBucket struct {
	Category string `json:"category"`
	Count    int    `json:"count"`
}

// BlockersBreakdown approximates *why* students are stuck from hint-request
// escalation level (1/2/3+), since the app captures no direct signal for the
// reason behind a hint request. Estimated is always true — the frontend must
// disclose this is an approximation, not a real classification.
type BlockersBreakdown struct {
	Buckets   []BlockerBucket `json:"buckets"`
	Estimated bool            `json:"estimated"`
}

// BlockersBreakdown counts hint interactions by escalation level for the
// batch's students: level 1 → Question Understanding, 2 → Concept
// Application, 3+ → Calculation Errors.
func (r *Repo) BlockersBreakdown(ctx context.Context, orgID, batchID string) (BlockersBreakdown, error) {
	var l1, l2, l3 int
	err := r.pool.QueryRow(ctx,
		`SELECT
		   COUNT(*) FILTER (WHERE lai.hint_level = 1),
		   COUNT(*) FILTER (WHERE lai.hint_level = 2),
		   COUNT(*) FILTER (WHERE lai.hint_level >= 3)
		 FROM lab_ai_interactions lai
		 JOIN lab_sessions ls ON ls.id = lai.session_id
		 WHERE lai.interaction_type = 'hint'
		   AND ls.user_id IN (SELECT user_id FROM batch_members WHERE batch_id = $1)
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)`,
		batchID, orgID).Scan(&l1, &l2, &l3)
	if err != nil {
		return BlockersBreakdown{}, fmt.Errorf("assessment: blockers breakdown: %w", err)
	}
	return BlockersBreakdown{
		Estimated: true,
		Buckets: []BlockerBucket{
			{Category: "Question Understanding", Count: l1},
			{Category: "Concept Application", Count: l2},
			{Category: "Calculation Errors", Count: l3},
		},
	}, nil
}

// EngagementPoint is one student's plot on the progress-vs-engagement
// scatter (days active × problems solved).
type EngagementPoint struct {
	UserID         string `json:"user_id"`
	UserName       string `json:"user_name"`
	DaysActive     int    `json:"days_active"`
	ProblemsSolved int    `json:"problems_solved"`
}

// EngagementScatter returns one point per student: how many distinct days
// they showed activity (any xp_event on this batch) against how many
// problems they've solved (passed lab tasks in the batch's courses + passed
// assessment attempts, mirroring GetBatchProgress's tests_passed scoping).
func (r *Repo) EngagementScatter(ctx context.Context, orgID, batchID string) ([]EngagementPoint, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name,
		        COUNT(DISTINCT date(xe.created_at)) AS days_active,
		        COALESCE(lab_passed.cnt, 0) + COALESCE(tests_passed.cnt, 0) AS problems_solved
		 FROM batch_members bm
		 JOIN users u ON u.id = bm.user_id
		 LEFT JOIN xp_events xe ON xe.user_id = u.id AND xe.batch_id = $1
		 LEFT JOIN LATERAL (
		   SELECT COUNT(*) AS cnt
		   FROM lab_task_completions ltc
		   JOIN lab_sessions ls ON ls.id = ltc.session_id
		   WHERE ls.user_id = u.id AND ltc.status = 'passed'
		     AND ls.lab_id IN (
		       SELECT ld.id FROM lab_definitions ld
		       JOIN course_modules cm ON cm.id = ld.module_id
		       JOIN content_assignments ca ON ca.content_type = 'course' AND ca.content_id = cm.course_id
		         AND ca.assignee_type = 'batch' AND ca.assignee_id = $1
		     )
		 ) lab_passed ON true
		 LEFT JOIN LATERAL (
		   SELECT COUNT(*) AS cnt FROM assessment_attempts aa
		   WHERE aa.user_id = u.id AND aa.status = 'evaluated' AND aa.passed = true
		 ) tests_passed ON true
		 WHERE bm.batch_id = $1
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)
		 GROUP BY u.id, u.name, lab_passed.cnt, tests_passed.cnt
		 ORDER BY u.name`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: engagement scatter: %w", err)
	}
	defer rows.Close()

	out := []EngagementPoint{}
	for rows.Next() {
		var p EngagementPoint
		if err := rows.Scan(&p.UserID, &p.UserName, &p.DaysActive, &p.ProblemsSolved); err != nil {
			return nil, fmt.Errorf("assessment: scan engagement point: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// BatchAnalytics is the single composite payload behind the batch's
// Progress and Analytics tabs — one fetch instead of five.
type BatchAnalytics struct {
	Health             ClassHealth          `json:"health"`
	Roster             []MemberProgress     `json:"roster"`
	ChapterMastery     []ChapterMasteryCell `json:"chapter_mastery"`
	ChapterHintRanking []ChapterHintStat    `json:"chapter_hint_ranking"`
	Blockers           BlockersBreakdown    `json:"blockers"`
	Engagement         []EngagementPoint    `json:"engagement"`
}

// BatchAnalytics assembles the full teacher-dashboard payload for one batch.
func (r *Repo) BatchAnalytics(ctx context.Context, orgID, batchID string) (BatchAnalytics, error) {
	roster, err := r.GetBatchProgress(ctx, orgID, batchID)
	if err != nil {
		return BatchAnalytics{}, err
	}
	mastery, err := r.ChapterMastery(ctx, orgID, batchID)
	if err != nil {
		return BatchAnalytics{}, err
	}
	ranking, err := r.ChapterHintRanking(ctx, orgID, batchID)
	if err != nil {
		return BatchAnalytics{}, err
	}
	blockers, err := r.BlockersBreakdown(ctx, orgID, batchID)
	if err != nil {
		return BatchAnalytics{}, err
	}
	engagement, err := r.EngagementScatter(ctx, orgID, batchID)
	if err != nil {
		return BatchAnalytics{}, err
	}
	return BatchAnalytics{
		Health:             computeClassHealth(roster),
		Roster:             roster,
		ChapterMastery:     mastery,
		ChapterHintRanking: ranking,
		Blockers:           blockers,
		Engagement:         engagement,
	}, nil
}
