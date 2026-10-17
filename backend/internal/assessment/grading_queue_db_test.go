package assessment

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/auth"
)

// The grading queue holds submitted/eval_failed attempts with an answer no
// grader has scored; an unscoped caller sees the whole org's, a mentor only
// attempts by members of batches they mentor.
func TestGradingQueue_Scoping(t *testing.T) {
	f := newMentorFixture(t)
	ctx := context.Background()
	one := func(dst *string, q string, args ...any) {
		t.Helper()
		if err := f.pool.QueryRow(ctx, q, args...).Scan(dst); err != nil {
			t.Fatalf("seed %q: %v", q, err)
		}
	}
	exec := func(q string, args ...any) {
		t.Helper()
		if _, err := f.pool.Exec(ctx, q, args...); err != nil {
			t.Fatalf("seed %q: %v", q, err)
		}
	}

	var asmt, q, ver, aq string
	one(&asmt, `INSERT INTO assessments (org_id, title, slug, type, created_by) VALUES ($1, 'Coding', 'coding', 'coding', $2) RETURNING id`, f.orgID, f.instructor)
	one(&q, `INSERT INTO questions (org_id, type, title, created_by) VALUES ($1, 'coding', 'Q', $2) RETURNING id`, f.orgID, f.instructor)
	one(&ver, `INSERT INTO question_versions (question_id, version, content, created_by) VALUES ($1, 1, '{}', $2) RETURNING id`, q, f.instructor)
	one(&aq, `INSERT INTO assessment_questions (assessment_id, question_id, version_id, position) VALUES ($1, $2, $3, 0) RETURNING id`, asmt, q, ver)

	// attempt seeds a learner in batchID with one attempt in status whose
	// single answer is graded or not.
	attempt := func(tag, batchID, status string, graded bool) string {
		uid := mentorSeedUser(t, f.pool, f.orgID, "learner", tag)
		exec(`INSERT INTO batch_members (batch_id, user_id, role) VALUES ($1, $2, 'student')`, batchID, uid)
		var att string
		one(&att, `INSERT INTO assessment_attempts (assessment_id, user_id, org_id, status, submitted_at) VALUES ($1, $2, $3, $4, now()) RETURNING id`,
			asmt, uid, f.orgID, status)
		exec(`INSERT INTO attempt_answers (attempt_id, assessment_question_id, question_id, evaluated_at)
		      VALUES ($1, $2, $3, CASE WHEN $4 THEN now() END)`, att, aq, q, graded)
		return att
	}
	inA := attempt("sa", f.batchA, AttemptSubmitted, false)
	inB := attempt("sb", f.batchB, AttemptEvalFailed, false)
	attempt("sc", f.batchA, AttemptSubmitted, true)  // fully graded: not pending
	attempt("sd", f.batchA, AttemptEvaluated, false) // evaluated: not pending
	attempt("se", f.batchA, "evaluating", false)     // AI still owns it

	all, total, err := NewRepo(f.pool).GradingQueue(ctx, f.orgID, nil, 10)
	if err != nil {
		t.Fatalf("unscoped: %v", err)
	}
	if total != 2 || len(all) != 2 || all[0].AttemptID != inA || all[1].AttemptID != inB {
		t.Fatalf("unscoped: total=%d items=%+v, want [%s %s]", total, all, inA, inB)
	}
	if all[0].UngradedAnswers != 1 || all[0].AssessmentTitle != "Coding" {
		t.Errorf("item = %+v", all[0])
	}

	page, total, err := NewRepo(f.pool).GradingQueue(ctx, f.orgID, nil, 1)
	if err != nil || len(page) != 1 || total != 2 {
		t.Fatalf("limit=1: len=%d total=%d err=%v, want 1/2", len(page), total, err)
	}

	ids, scoped, err := mentorScopeIDs(ctx, f.pool, f.perms, &auth.Claims{UserID: f.mentorA, OrgID: f.orgID})
	if err != nil || !scoped {
		t.Fatalf("mentorScopeIDs: scoped=%v err=%v", scoped, err)
	}
	mine, total, err := NewRepo(f.pool).GradingQueue(ctx, f.orgID, ids, 10)
	if err != nil || total != 1 || len(mine) != 1 || mine[0].AttemptID != inA {
		t.Fatalf("mentorA: total=%d items=%+v err=%v, want only %s", total, mine, err, inA)
	}

	if _, scoped, err := mentorScopeIDs(ctx, f.pool, f.perms, &auth.Claims{UserID: f.instructor, OrgID: f.orgID}); err != nil || scoped {
		t.Fatalf("instructor must be unscoped: scoped=%v err=%v", scoped, err)
	}

	none, total, err := NewRepo(f.pool).GradingQueue(ctx, f.orgID, []string{}, 10)
	if err != nil || total != 0 || len(none) != 0 {
		t.Fatalf("mentor with no batches: total=%d len=%d err=%v, want empty", total, len(none), err)
	}
}

// The interview review queue (review_required evaluations) follows the same
// mentor scope: unscoped sees the org, a mentor only their batches' members.
func TestReviewQueue_Scoping(t *testing.T) {
	f := newMentorFixture(t)
	ctx := context.Background()
	var asmt string
	if err := f.pool.QueryRow(ctx, `INSERT INTO assessments (org_id, title, slug, type, created_by) VALUES ($1, 'Interview', 'interview', 'coding', $2) RETURNING id`,
		f.orgID, f.instructor).Scan(&asmt); err != nil {
		t.Fatalf("seed assessment: %v", err)
	}
	flagged := func(tag, batchID string) string {
		uid := mentorSeedUser(t, f.pool, f.orgID, "learner", tag)
		var att string
		if _, err := f.pool.Exec(ctx, `INSERT INTO batch_members (batch_id, user_id, role) VALUES ($1, $2, 'student')`, batchID, uid); err != nil {
			t.Fatalf("seed member: %v", err)
		}
		if err := f.pool.QueryRow(ctx, `INSERT INTO assessment_attempts (assessment_id, user_id, org_id, status, submitted_at) VALUES ($1, $2, $3, 'evaluated', now()) RETURNING id`,
			asmt, uid, f.orgID).Scan(&att); err != nil {
			t.Fatalf("seed attempt: %v", err)
		}
		if _, err := f.pool.Exec(ctx, `INSERT INTO interview_evaluations (attempt_id, scope, review_required) VALUES ($1, 'overall', true)`, att); err != nil {
			t.Fatalf("seed evaluation: %v", err)
		}
		return att
	}
	inA := flagged("ra", f.batchA)
	flagged("rb", f.batchB)

	repo := NewRepo(f.pool)
	all, err := repo.GetReviewQueue(ctx, f.orgID, nil, 50, 0)
	if err != nil || len(all) != 2 {
		t.Fatalf("unscoped: len=%d err=%v, want 2", len(all), err)
	}

	ids, scoped, err := mentorScopeIDs(ctx, f.pool, f.perms, &auth.Claims{UserID: f.mentorA, OrgID: f.orgID})
	if err != nil || !scoped {
		t.Fatalf("mentorScopeIDs: scoped=%v err=%v", scoped, err)
	}
	mine, err := repo.GetReviewQueue(ctx, f.orgID, ids, 50, 0)
	if err != nil || len(mine) != 1 || mine[0].AttemptID != inA {
		t.Fatalf("mentorA: items=%+v err=%v, want only %s", mine, err, inA)
	}

	none, err := repo.GetReviewQueue(ctx, f.orgID, []string{}, 50, 0)
	if err != nil || len(none) != 0 {
		t.Fatalf("mentor with no batches: len=%d err=%v, want 0", len(none), err)
	}
}
