package activity

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the activity feed.
type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// feedQuery unions every activity source into one (occurred_at, kind, key,
// title, summary, ref_id, ref_type, ref_slug) row set, ordered newest first.
//
// Org scoping: module_progress/enrollments (via courses.org_id),
// assessment_attempts, and lesson_reflections all carry org_id and are
// filtered to the caller's active org. user_problem_progress (sheets) and
// srs_cards/srs_reviews have no org_id — they're per-user personal data by
// design, not per-tenant, so they appear regardless of the caller's active
// org; that is intentional, not a leak.
//
// Performance: ORDER BY occurred_at DESC over a UNION ALL lets Postgres use
// a MergeAppend (pulling only ~limit rows per branch) as long as each branch
// can be produced pre-sorted — see migration 014's per-branch
// (user_id, ts DESC) indexes. If EXPLAIN ever shows a full Sort as a branch
// grows, push `ORDER BY ... LIMIT $6` into that branch subquery: the global
// top-N is always a subset of each branch's own top-N.
//
// eventsCTE is shared by feedQuery (cursor-paginated feed, $3/$4 = cursor
// position) and windowQuery (ListWindow's fixed [from, to) range, $3/$4 =
// bounds) — same event union, two different WHERE clauses layered on top in
// each query's own final SELECT, so the source list is defined exactly once.
const eventsCTE = `
WITH ev AS (
	SELECT mp.completed_at AS occurred_at, '` + KindModuleCompleted + `' AS kind,
	       '` + KindModuleCompleted + `:'||mp.id AS key,
	       cm.title AS title, c.title AS summary,
	       mp.module_id::text AS ref_id, 'module' AS ref_type, c.slug AS ref_slug
	  FROM module_progress mp
	  JOIN course_modules cm ON cm.id = mp.module_id
	  JOIN courses c         ON c.id  = mp.course_id
	 WHERE mp.user_id = $1 AND mp.status = 'completed' AND mp.completed_at IS NOT NULL AND c.org_id = $2

	UNION ALL
	SELECT e.completed_at, '` + KindCourseCompleted + `', '` + KindCourseCompleted + `:'||e.id,
	       c.title, NULL, e.course_id::text, 'course', c.slug
	  FROM enrollments e JOIN courses c ON c.id = e.course_id
	 WHERE e.user_id = $1 AND e.completed_at IS NOT NULL AND c.org_id = $2

	UNION ALL
	SELECT aa.submitted_at, '` + KindQuizAttempt + `', '` + KindQuizAttempt + `:'||aa.id,
	       a.title,
	       COALESCE(aa.percentage::text || '%', '') ||
	         CASE WHEN aa.passed IS TRUE THEN ' - Passed' WHEN aa.passed IS FALSE THEN ' - Not passed' ELSE '' END,
	       aa.id::text, 'assessment_attempt', NULL
	  FROM assessment_attempts aa JOIN assessments a ON a.id = aa.assessment_id
	 WHERE aa.user_id = $1 AND aa.org_id = $2 AND aa.submitted_at IS NOT NULL

	UNION ALL
	SELECT lr.created_at, '` + KindReflection + `', '` + KindReflection + `:'||lr.id,
	       cm.title, left(lr.text, 200), lr.source_id::text, 'module', c.slug
	  FROM learning_annotations lr
	  JOIN course_modules cm ON cm.id = lr.source_id
	  JOIN courses c         ON c.id  = cm.course_id
	 WHERE lr.user_id = $1 AND lr.org_id = $2 AND lr.source_type = 'module' AND lr.annotation_type = 'reflection'

	UNION ALL
	SELECT upp.solved_at, '` + KindSheetSolved + `', '` + KindSheetSolved + `:'||upp.topic_tag,
	       upp.topic_tag, NULL, NULL, 'sheet_item', NULL
	  FROM user_problem_progress upp
	 WHERE upp.user_id = $1 AND upp.solved_at IS NOT NULL

	UNION ALL
	SELECT ls.completed_at, '` + KindLabCompleted + `', '` + KindLabCompleted + `:'||ls.id,
	       ld.title, ls.score::text || ' pts', ls.lab_id::text, 'lab', NULL
	  FROM lab_sessions ls JOIN lab_definitions ld ON ld.id = ls.lab_id
	 WHERE ls.user_id = $1 AND ls.org_id = $2 AND ls.completed_at IS NOT NULL

	UNION ALL
	SELECT sr.reviewed_at, '` + KindCardReviewed + `', '` + KindCardReviewed + `:'||sr.id,
	       sc.front, 'Next review in ' || sr.interval_days || 'd', sr.card_id::text, 'srs_card', NULL
	  FROM srs_reviews sr JOIN srs_cards sc ON sc.id = sr.card_id
	 WHERE sr.user_id = $1

	UNION ALL
	SELECT la.created_at, 'annotation:' || la.annotation_type, 'annotation:' || la.annotation_type || ':' || la.id,
	       la.text, CASE WHEN la.annotation_type = 'mistake' THEN (la.meta->>'corrected_text')::text ELSE (la.meta->>'note')::text END,
	       la.source_id::text, la.source_type, NULL
	  FROM learning_annotations la
	 WHERE la.user_id = $1 AND la.annotation_type IN ('highlight', 'mistake')
)
`

const feedQuery = eventsCTE + `
SELECT occurred_at, kind, key, title, COALESCE(summary, ''),
       COALESCE(ref_id, ''), COALESCE(ref_type, ''), COALESCE(ref_slug, '')
  FROM ev
 WHERE ($3::timestamptz IS NULL OR (occurred_at, key) < ($3, $4))
 ORDER BY occurred_at DESC, key DESC
 LIMIT $5
`

// windowQuery is eventsCTE filtered to a fixed [$3, $4) time range instead of
// feedQuery's cursor position — ListWindow's caller (internal/digest) wants
// "everything that happened in this window", not a page of the infinite feed.
const windowQuery = eventsCTE + `
SELECT occurred_at, kind, key, title, COALESCE(summary, ''),
       COALESCE(ref_id, ''), COALESCE(ref_type, ''), COALESCE(ref_slug, '')
  FROM ev
 WHERE occurred_at >= $3 AND occurred_at < $4
 ORDER BY occurred_at DESC, key DESC
 LIMIT $5
`

// List returns up to limit entries for userID (scoped to orgID where the
// source table is org-scoped — see feedQuery), older than the cursor
// position when one is given, newest first. tzOffsetMin is the caller's UTC
// offset in minutes east of UTC, used only to compute Entry.Day.
func (r *Repo) List(ctx context.Context, userID, orgID string, tzOffsetMin int, cursorAt *time.Time, cursorKey string, limit int) ([]Entry, error) {
	rows, err := r.pool.Query(ctx, feedQuery, userID, orgID, cursorAt, cursorKey, limit)
	if err != nil {
		return nil, fmt.Errorf("activity: list: %w", err)
	}
	defer rows.Close()

	loc := time.FixedZone("client", tzOffsetMin*60)
	out, err := scanEntries(rows)
	if err != nil {
		return nil, err
	}
	for i := range out {
		out[i].Day = out[i].OccurredAt.In(loc).Format("2006-01-02")
	}
	return out, nil
}

// ListWindow returns every entry for userID in [from, to), newest first,
// scoped to orgID exactly like List. Used by internal/digest to gather a
// student's notes/reflections/mistakes/completions for a revision window
// (one night, or the last 3/7/30 days) rather than a paginated feed page, so
// it takes a fixed range instead of a cursor and has no page-size cap beyond
// limit as a sanity bound. Entry.Day is left unset — callers of ListWindow
// work from OccurredAt directly.
func (r *Repo) ListWindow(ctx context.Context, userID, orgID string, from, to time.Time, limit int) ([]Entry, error) {
	rows, err := r.pool.Query(ctx, windowQuery, userID, orgID, from, to, limit)
	if err != nil {
		return nil, fmt.Errorf("activity: list window: %w", err)
	}
	defer rows.Close()
	return scanEntries(rows)
}

func scanEntries(rows pgx.Rows) ([]Entry, error) {
	out := []Entry{}
	for rows.Next() {
		var e Entry
		if err := rows.Scan(&e.OccurredAt, &e.Kind, &e.Key, &e.Title, &e.Summary, &e.RefID, &e.RefType, &e.RefSlug); err != nil {
			return nil, fmt.Errorf("activity: scan entry: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ─── cursor pagination ─────────────────────────────────────────────────────
// Small, deliberate duplicate of mcpconnect's (created_at, id) cursor — that
// helper is unexported to its own package, and this cursor's tiebreak field
// is "key" (a synthetic "<kind>:<row id>" string), not a plain id, so it
// isn't even the same shape. See mcpconnect/action_log.go for the precedent.

func EncodeCursor(occurredAt time.Time, key string) string {
	raw := fmt.Sprintf("%d:%s", occurredAt.UnixMicro(), key)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

func DecodeCursor(cursor string) (*time.Time, string, error) {
	if cursor == "" {
		return nil, "", nil
	}
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return nil, "", fmt.Errorf("activity: decode cursor: base64: %w", err)
	}
	parts := strings.SplitN(string(b), ":", 2)
	if len(parts) != 2 {
		return nil, "", fmt.Errorf("activity: decode cursor: invalid format")
	}
	var micro int64
	if _, err := fmt.Sscanf(parts[0], "%d", &micro); err != nil {
		return nil, "", fmt.Errorf("activity: decode cursor: parse timestamp: %w", err)
	}
	at := time.UnixMicro(micro)
	return &at, parts[1], nil
}
