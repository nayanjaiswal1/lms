package learnhub

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the Learn hub aggregator.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// statsQuery computes every Learn hub card's count in a single round trip.
// Each subquery mirrors the WHERE-clause scoping of the domain's own
// existing list endpoint (see the comment above each block) so the numbers
// shown here always agree with what that endpoint would return — this
// query only replaces "fetch every row" with "count the rows", it does not
// change which rows count.
//
//   - enrollments: courses.Repo.GetMyEnrollments's WHERE (user + course org)
//   - roadmap: roadmap.Repo.ListForUser's WHERE, then picks the same
//     roadmap the frontend used to pick via `find(status==='active') ??
//     roadmaps[0]` out of a DESC-by-created_at list — ORDER BY
//     (status='active') DESC, created_at DESC LIMIT 1 is exactly that.
//   - prep plans: interviewprep.Repo.ListPlans's WHERE (user only)
//   - pending assessments: assessment.Repo.ListAssignedForUser's WHERE,
//     plus the same "fully spent and passed" exclusion the frontend applied
//     client-side (attempts_used >= max_attempts && best_passed)
//   - highlights: highlights.Repo.ListByUser's WHERE with savedOnly=true
//     (the hub always calls getMyHighlights(true))
//   - due cards: srs.Repo.GetDueCards's WHERE, but a true COUNT instead of
//     LIMIT 20 — GetDueCards caps at 20 rows for the review queue UI, which
//     silently undercounted the hub's "N due" stat once a user had more
//     than 20 cards due; counting instead of listing fixes that for free
//   - sheets: sheets.Repo.ListUserSheets's WHERE/JOINs, summed across sheets
//   - wiki spaces: wiki.Repo.ListSpaces's WHERE (org only)
//   - interview-exp posts: interviewexp.Repo.ListPosts's WHERE with no
//     filters applied (the hub always calls listPosts({}))
const statsQuery = `
WITH target_roadmap AS (
	SELECT id FROM roadmaps
	 WHERE user_id = $1 AND deleted_at IS NULL
	 ORDER BY (status = 'active') DESC, created_at DESC
	 LIMIT 1
),
sheet_counts AS (
	SELECT COUNT(si.id) AS item_count,
	       COUNT(si.id) FILTER (WHERE upp.status = 'done') AS solved_count
	  FROM user_sheets us
	  JOIN sheets s ON s.id = us.sheet_id
	  LEFT JOIN sheet_items si ON si.sheet_id = s.id
	  LEFT JOIN user_problem_progress upp ON upp.topic_tag = si.topic_tag AND upp.user_id = us.user_id
	 WHERE us.user_id = $1
	 GROUP BY s.id
)
SELECT
	(SELECT COUNT(*) FROM enrollments e JOIN courses c ON c.id = e.course_id
	  WHERE e.user_id = $1 AND c.org_id = $2),

	(SELECT COUNT(*) > 0 FROM target_roadmap),
	COALESCE((SELECT COUNT(*) FROM roadmap_modules mo
	            JOIN roadmap_milestones m ON m.id = mo.milestone_id
	            JOIN roadmap_phases p ON p.id = m.phase_id
	           WHERE p.roadmap_id = (SELECT id FROM target_roadmap)), 0),
	COALESCE((SELECT COUNT(*) FROM roadmap_modules mo
	            JOIN roadmap_milestones m ON m.id = mo.milestone_id
	            JOIN roadmap_phases p ON p.id = m.phase_id
	           WHERE p.roadmap_id = (SELECT id FROM target_roadmap) AND mo.completed_at IS NOT NULL), 0),

	(SELECT COUNT(*) FROM interview_prep_plans WHERE user_id = $1),

	(SELECT COUNT(*) FROM assessments a
	  WHERE a.org_id = $2
	    AND a.status IN ('published','scheduled','active')
	    AND EXISTS (
	      SELECT 1 FROM assessment_assignments aa
	      WHERE aa.assessment_id = a.id
	        AND ((aa.assignee_type = 'student' AND aa.assignee_id = $1)
	          OR (aa.assignee_type = 'batch' AND aa.assignee_id IN
	              (SELECT batch_id FROM batch_members WHERE user_id = $1)))
	    )
	    AND NOT (
	      (SELECT COUNT(*) FROM assessment_attempts at
	         WHERE at.assessment_id = a.id AND at.user_id = $1
	           AND at.status IN ('submitted','evaluating','evaluated','eval_failed','expired')) >= a.max_attempts
	      AND COALESCE((SELECT bool_or(at.passed) FROM assessment_attempts at
	             WHERE at.assessment_id = a.id AND at.user_id = $1 AND at.status = 'evaluated'), FALSE)
	    )
	),

	(SELECT COUNT(*) FROM highlights WHERE user_id = $1 AND saved_for_revision = TRUE),

	(SELECT COUNT(*) FROM srs_cards WHERE user_id = $1 AND due_date <= CURRENT_DATE),

	COALESCE((SELECT SUM(item_count) FROM sheet_counts), 0),
	COALESCE((SELECT SUM(solved_count) FROM sheet_counts), 0),

	(SELECT COUNT(*) FROM wiki_spaces WHERE org_id = $2),

	(SELECT COUNT(*) FROM interview_exp_posts WHERE deleted_at IS NULL)
`

// GetStats computes every Learn hub card's count for userID/orgID in one
// query — see statsQuery's doc comment for how each subquery maps back to
// the domain endpoint it replaces.
func (r *Repo) GetStats(ctx context.Context, userID, orgID string) (Stats, error) {
	var s Stats
	err := r.pool.QueryRow(ctx, statsQuery, userID, orgID).Scan(
		&s.EnrollmentCount,
		&s.HasRoadmap, &s.RoadmapModuleCount, &s.RoadmapCompletedCount,
		&s.PrepPlanCount,
		&s.PendingAssessmentCount,
		&s.SavedHighlightCount,
		&s.DueCardCount,
		&s.SheetTotalCount, &s.SheetSolvedCount,
		&s.WikiSpaceCount,
		&s.InterviewExpPostCount,
	)
	if err != nil {
		return Stats{}, fmt.Errorf("learnhub: get stats: %w", err)
	}
	return s, nil
}
