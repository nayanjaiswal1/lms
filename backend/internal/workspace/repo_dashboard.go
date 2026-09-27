package workspace

import (
	"context"
	"fmt"
	"time"
)

// repo_dashboard.go — Phase 4 (contract-phase4.md 4d) read-only aggregation
// queries over work_items/work_item_events/assignees/time logs/
// work_item_gitlab/gitlab_* mirrors/reviews/standups. No aggregation tables
// (per the contract) — every read here is a plain query run at request time.
// Several metrics are deliberately shallow for this phase (documented inline
// with `ponytail:`) — the Dashboard struct has more columns than a first
// pass can responsibly fill with real signal; the ones that drive
// "needs attention" and health are real, the deep percentile/AI ones are
// zero-valued until there's a concrete need to spend the query budget on them.

// ─── totals / progress ──────────────────────────────────────────────────────

// ProjectItemTotals returns the non-archived item count and how many are done.
func (r *Repo) ProjectItemTotals(ctx context.Context, db DBTX, projectID string) (total, done int, err error) {
	err = db.QueryRow(ctx,
		`SELECT count(*), count(*) FILTER (WHERE status = 'done') FROM work_items WHERE project_id = $1 AND archived_at IS NULL`,
		projectID,
	).Scan(&total, &done)
	if err != nil {
		return 0, 0, fmt.Errorf("workspace: project item totals: %w", err)
	}
	return total, done, nil
}

// ─── needs attention ────────────────────────────────────────────────────────

func scanAttentionItems(rows interface {
	Next() bool
	Scan(...any) error
	Err() error
}) ([]AttentionItem, error) {
	out := []AttentionItem{}
	for rows.Next() {
		var a AttentionItem
		if err := rows.Scan(&a.Item.ID, &a.Item.Key, &a.Item.Type, &a.Item.Title, &a.Item.Status, &a.Detail, &a.Since); err != nil {
			return nil, fmt.Errorf("workspace: scan attention item: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// ListBlockedItems returns every currently-blocked item, with how long
// (since the latest transition into blocked).
func (r *Repo) ListBlockedItems(ctx context.Context, db DBTX, projectID string) ([]AttentionItem, error) {
	rows, err := db.Query(ctx,
		`SELECT w.id, p.key_prefix || '-' || w.key_num, w.type, w.title, w.status,
		        COALESCE(w.blocked_reason, 'Blocked'),
		        (SELECT max(e.created_at) FROM work_item_events e WHERE e.item_id = w.id AND e.kind = 'status' AND e.to_value = 'blocked')
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.archived_at IS NULL AND w.status = 'blocked'
		  ORDER BY w.updated_at ASC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list blocked items: %w", err)
	}
	defer rows.Close()
	return scanAttentionItems(rows)
}

// ListOverdueItems returns open items past their due date.
func (r *Repo) ListOverdueItems(ctx context.Context, db DBTX, projectID string, now time.Time) ([]AttentionItem, error) {
	rows, err := db.Query(ctx,
		`SELECT w.id, p.key_prefix || '-' || w.key_num, w.type, w.title, w.status,
		        'Due ' || to_char(w.due_at, 'YYYY-MM-DD'), w.due_at
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.archived_at IS NULL AND w.due_at IS NOT NULL AND w.due_at < $2
		    AND w.status NOT IN ('done','wont_do')
		  ORDER BY w.due_at ASC`,
		projectID, now)
	if err != nil {
		return nil, fmt.Errorf("workspace: list overdue items: %w", err)
	}
	defer rows.Close()
	return scanAttentionItems(rows)
}

// ListStaleReviewItems returns feature specs stuck in_review longer than
// DocReviewReminderAfter — the same staleness rule service_reminders.go's
// job already uses, surfaced here for the dashboard's own attention list.
func (r *Repo) ListStaleReviewItems(ctx context.Context, db DBTX, projectID string, cutoff time.Time) ([]AttentionItem, error) {
	rows, err := db.Query(ctx,
		`SELECT w.id, p.key_prefix || '-' || w.key_num, w.type, w.title, w.status,
		        'Spec review waiting', idle.idle_since
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		   CROSS JOIN LATERAL (
		     SELECT COALESCE(MAX(e.created_at), w.updated_at) AS idle_since
		       FROM work_item_events e WHERE e.item_id = w.id AND e.kind IN ('doc','review')
		   ) idle
		  WHERE w.project_id = $1 AND w.type = 'feature' AND w.doc_status = 'in_review' AND w.archived_at IS NULL
		    AND idle.idle_since < $2`,
		projectID, cutoff)
	if err != nil {
		return nil, fmt.Errorf("workspace: list stale review items: %w", err)
	}
	defer rows.Close()
	return scanAttentionItems(rows)
}

// ListOpenS1S2Bugs returns open critical/high bugs.
func (r *Repo) ListOpenS1S2Bugs(ctx context.Context, db DBTX, projectID string) ([]AttentionItem, error) {
	rows, err := db.Query(ctx,
		`SELECT w.id, p.key_prefix || '-' || w.key_num, w.type, w.title, w.status, 'Severity ' || w.severity, w.created_at
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.type = 'bug' AND w.severity IN ('S1','S2') AND w.archived_at IS NULL
		    AND w.status NOT IN ('done','wont_do')
		  ORDER BY w.severity, w.created_at ASC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list open s1/s2 bugs: %w", err)
	}
	defer rows.Close()
	return scanAttentionItems(rows)
}

// ListStuckOnboardingPeople returns active members who joined more than
// staleAfter ago and still haven't finished every required onboarding step.
func (r *Repo) ListStuckOnboardingPeople(ctx context.Context, db DBTX, projectID string, cutoff time.Time) ([]AttentionPerson, error) {
	rows, err := db.Query(ctx,
		`SELECT pm.user_id, u.name,
		        COALESCE((100 * count(*) FILTER (WHERE op.step_id IS NOT NULL)) / NULLIF(count(*), 0), 0) AS pct
		   FROM project_members pm
		   JOIN users u ON u.id = pm.user_id
		   JOIN onboarding_steps os ON os.project_id = pm.project_id AND os.required = true
		   LEFT JOIN onboarding_progress op ON op.step_id = os.id AND op.user_id = pm.user_id
		  WHERE pm.project_id = $1 AND pm.status = 'active' AND pm.joined_at < $2
		  GROUP BY pm.user_id, u.name
		 HAVING COALESCE((100 * count(*) FILTER (WHERE op.step_id IS NOT NULL)) / NULLIF(count(*), 0), 0) < 100`,
		projectID, cutoff)
	if err != nil {
		return nil, fmt.Errorf("workspace: list stuck onboarding people: %w", err)
	}
	defer rows.Close()
	out := []AttentionPerson{}
	for rows.Next() {
		var a AttentionPerson
		var pct int
		if err := rows.Scan(&a.Person.UserID, &a.Person.Name, &pct); err != nil {
			return nil, fmt.Errorf("workspace: scan stuck onboarding person: %w", err)
		}
		a.Detail = fmt.Sprintf("%d%% onboarded", pct)
		out = append(out, a)
	}
	return out, rows.Err()
}

// ListInactiveMembers returns active members of projectID whose computed
// last-activity is before cutoff — the dashboard's own use of the same
// signal RunInactivitySweep sweeps across every project with.
func (r *Repo) ListInactiveMembers(ctx context.Context, db DBTX, projectID string, cutoff time.Time) ([]AttentionPerson, error) {
	all, err := r.ListActiveMembersLastActivity(ctx)
	if err != nil {
		return nil, err
	}
	names := map[string]string{}
	out := []AttentionPerson{}
	for _, m := range all {
		if m.ProjectID != projectID || !m.LastActive.Before(cutoff) {
			continue
		}
		name, ok := names[m.UserID]
		if !ok {
			name, _ = r.GetUserName(ctx, db, m.UserID)
			names[m.UserID] = name
		}
		out = append(out, AttentionPerson{Person: PersonRef{UserID: m.UserID, Name: name}, Detail: fmt.Sprintf("Inactive since %s", m.LastActive.Format("2006-01-02"))})
	}
	return out, nil
}

// ListLeaderlessTracks returns tracks with no lead.
func (r *Repo) ListLeaderlessTracks(ctx context.Context, db DBTX, projectID string) ([]AttentionTrack, error) {
	rows, err := db.Query(ctx, `SELECT id, name FROM project_tracks WHERE project_id = $1 AND lead_user_id IS NULL`, projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list leaderless tracks: %w", err)
	}
	defer rows.Close()
	out := []AttentionTrack{}
	for rows.Next() {
		var t AttentionTrack
		if err := rows.Scan(&t.TrackID, &t.Name); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ─── delivery ───────────────────────────────────────────────────────────────

// Burndown returns one DayPoint per day in [from,to]. ponytail: Open is
// derived from cumulative created-vs-closed event counts rather than a daily
// WIP snapshot table, so a reopened-then-reclosed item can skew a single
// historical day slightly; add a nightly snapshot if exact historical WIP is
// ever needed — today's (rightmost) point is always exact.
func (r *Repo) Burndown(ctx context.Context, db DBTX, projectID string, from, to time.Time) ([]DayPoint, error) {
	rows, err := db.Query(ctx,
		`WITH days AS (SELECT generate_series($2::date, $3::date, interval '1 day')::date AS day)
		 SELECT d.day,
		        (SELECT count(*) FROM work_items w WHERE w.project_id = $1 AND w.archived_at IS NULL AND w.created_at::date <= d.day)
		          - (SELECT count(*) FROM work_item_events e WHERE e.project_id = $1 AND e.kind = 'status' AND e.to_value IN ('done','wont_do') AND e.created_at::date <= d.day) AS open,
		        COALESCE((SELECT count(*) FROM work_item_events e WHERE e.project_id = $1 AND e.kind = 'status' AND e.to_value = 'done' AND e.created_at::date = d.day), 0) AS done,
		        COALESCE((SELECT count(*) FROM work_items w WHERE w.project_id = $1 AND w.archived_at IS NULL AND w.created_at::date = d.day), 0) AS added
		   FROM days d ORDER BY d.day`,
		projectID, from, to)
	if err != nil {
		return nil, fmt.Errorf("workspace: burndown: %w", err)
	}
	defer rows.Close()
	out := []DayPoint{}
	for rows.Next() {
		var day time.Time
		var p DayPoint
		if err := rows.Scan(&day, &p.Open, &p.Done, &p.Added); err != nil {
			return nil, fmt.Errorf("workspace: scan burndown day: %w", err)
		}
		if p.Open < 0 {
			p.Open = 0
		}
		p.Day = day.Format("2006-01-02")
		out = append(out, p)
	}
	return out, rows.Err()
}

// WeeklyDoneThroughput returns one WeekPoint per ISO week in [from,to] —
// items transitioned to done that week.
func (r *Repo) WeeklyDoneThroughput(ctx context.Context, db DBTX, projectID string, from, to time.Time) ([]WeekPoint, error) {
	return r.weeklyStatusCount(ctx, db, projectID, from, to, "done", "")
}

func (r *Repo) weeklyStatusCount(ctx context.Context, db DBTX, projectID string, from, to time.Time, toValue, itemType string) ([]WeekPoint, error) {
	rows, err := db.Query(ctx,
		`SELECT to_char(date_trunc('week', e.created_at), 'IYYY-"W"IW') AS week, count(*)
		   FROM work_item_events e JOIN work_items w ON w.id = e.item_id
		  WHERE e.project_id = $1 AND e.kind = 'status' AND e.to_value = $4 AND e.created_at BETWEEN $2 AND $3
		    AND ($5 = '' OR w.type = $5)
		  GROUP BY 1 ORDER BY 1`,
		projectID, from, to, toValue, itemType)
	if err != nil {
		return nil, fmt.Errorf("workspace: weekly status count: %w", err)
	}
	defer rows.Close()
	out := []WeekPoint{}
	for rows.Next() {
		var wp WeekPoint
		if err := rows.Scan(&wp.Week, &wp.Count); err != nil {
			return nil, err
		}
		out = append(out, wp)
	}
	return out, rows.Err()
}

// LeadTimeHours returns created->done hours for every item done in
// [from,to] — the raw sample PercentileStat is computed from in Go
// (service_dashboard.go's percentile helper).
func (r *Repo) LeadTimeHours(ctx context.Context, db DBTX, projectID string, from, to time.Time) ([]float64, error) {
	rows, err := db.Query(ctx,
		`SELECT EXTRACT(EPOCH FROM (e.created_at - w.created_at)) / 3600.0
		   FROM work_item_events e JOIN work_items w ON w.id = e.item_id
		  WHERE e.project_id = $1 AND e.kind = 'status' AND e.to_value = 'done' AND e.created_at BETWEEN $2 AND $3`,
		projectID, from, to)
	if err != nil {
		return nil, fmt.Errorf("workspace: lead time hours: %w", err)
	}
	defer rows.Close()
	out := []float64{}
	for rows.Next() {
		var h float64
		if err := rows.Scan(&h); err != nil {
			return nil, err
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

// BlockedHoursTotal sums how long every currently-blocked item has been
// blocked, in hours.
func (r *Repo) BlockedHoursTotal(ctx context.Context, db DBTX, projectID string, now time.Time) (float64, error) {
	var total float64
	err := db.QueryRow(ctx,
		`SELECT COALESCE(SUM(EXTRACT(EPOCH FROM ($2 - since.blocked_at)) / 3600.0), 0)
		   FROM work_items w
		   CROSS JOIN LATERAL (
		     SELECT MAX(e.created_at) AS blocked_at FROM work_item_events e
		      WHERE e.item_id = w.id AND e.kind = 'status' AND e.to_value = 'blocked'
		   ) since
		  WHERE w.project_id = $1 AND w.status = 'blocked' AND w.archived_at IS NULL AND since.blocked_at IS NOT NULL`,
		projectID, now,
	).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("workspace: blocked hours total: %w", err)
	}
	return total, nil
}

// ListDoneItemTitles returns "[type] title" for every non-archived item
// transitioned to done since since — WeeklySummary's own "shipped" input
// (contract-phase5.md 5c), read from work_item_events rather than work_items
// so a since-reopened item still counts for the week it was actually done.
func (r *Repo) ListDoneItemTitles(ctx context.Context, db DBTX, projectID string, since time.Time) ([]string, error) {
	rows, err := db.Query(ctx,
		`SELECT DISTINCT w.type, w.title FROM work_item_events e JOIN work_items w ON w.id = e.item_id
		  WHERE e.project_id = $1 AND e.kind = 'status' AND e.to_value = 'done' AND e.created_at >= $2
		  ORDER BY w.title`,
		projectID, since)
	if err != nil {
		return nil, fmt.Errorf("workspace: list done item titles: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var itemType, title string
		if err := rows.Scan(&itemType, &title); err != nil {
			return nil, err
		}
		out = append(out, fmt.Sprintf("[%s] %s", itemType, title))
	}
	return out, rows.Err()
}

// ─── quality ────────────────────────────────────────────────────────────────

// BugsBySeverity returns open-bug counts and the oldest open bug's age, per
// severity.
func (r *Repo) BugsBySeverity(ctx context.Context, db DBTX, projectID string, now time.Time) ([]SeverityCount, error) {
	rows, err := db.Query(ctx,
		`SELECT severity, count(*), COALESCE(EXTRACT(EPOCH FROM ($2 - min(created_at))) / 3600.0, 0)
		   FROM work_items WHERE project_id = $1 AND type = 'bug' AND archived_at IS NULL AND status NOT IN ('done','wont_do')
		  GROUP BY severity ORDER BY severity`,
		projectID, now)
	if err != nil {
		return nil, fmt.Errorf("workspace: bugs by severity: %w", err)
	}
	defer rows.Close()
	out := []SeverityCount{}
	for rows.Next() {
		var sc SeverityCount
		if err := rows.Scan(&sc.Severity, &sc.Open, &sc.OldestAgeHrs); err != nil {
			return nil, err
		}
		out = append(out, sc)
	}
	return out, rows.Err()
}

// BugInflowVsFix returns weekly bug creation counts, with that same week's
// fixed (done) count folded in.
func (r *Repo) BugInflowVsFix(ctx context.Context, db DBTX, projectID string, from, to time.Time) ([]WeekPoint, error) {
	rows, err := db.Query(ctx,
		`SELECT week, created, fixed FROM (
		    SELECT to_char(date_trunc('week', w.created_at), 'IYYY-"W"IW') AS week, count(*) AS created, 0 AS fixed
		      FROM work_items w WHERE w.project_id = $1 AND w.type = 'bug' AND w.created_at BETWEEN $2 AND $3
		     GROUP BY 1
		    UNION ALL
		    SELECT to_char(date_trunc('week', e.created_at), 'IYYY-"W"IW') AS week, 0 AS created, count(*) AS fixed
		      FROM work_item_events e JOIN work_items w ON w.id = e.item_id
		     WHERE e.project_id = $1 AND w.type = 'bug' AND e.kind = 'status' AND e.to_value = 'done' AND e.created_at BETWEEN $2 AND $3
		     GROUP BY 1
		 ) x`,
		projectID, from, to)
	if err != nil {
		return nil, fmt.Errorf("workspace: bug inflow vs fix: %w", err)
	}
	defer rows.Close()
	byWeek := map[string]*WeekPoint{}
	order := []string{}
	for rows.Next() {
		var week string
		var created, fixed int
		if err := rows.Scan(&week, &created, &fixed); err != nil {
			return nil, err
		}
		wp, ok := byWeek[week]
		if !ok {
			wp = &WeekPoint{Week: week}
			byWeek[week] = wp
			order = append(order, week)
		}
		wp.Count += created
		wp.Fixed += fixed
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	out := make([]WeekPoint, 0, len(order))
	for _, w := range order {
		out = append(out, *byWeek[w])
	}
	return out, nil
}

// ReopenStats returns total reopen_count summed across items, and how many
// items ever reached done (the denominator for a reopen rate).
func (r *Repo) ReopenStats(ctx context.Context, db DBTX, projectID string) (reopens, doneCount int, err error) {
	err = db.QueryRow(ctx,
		`SELECT COALESCE(SUM(reopen_count),0), count(*) FILTER (WHERE status = 'done' OR reopen_count > 0)
		   FROM work_items WHERE project_id = $1 AND archived_at IS NULL`,
		projectID,
	).Scan(&reopens, &doneCount)
	if err != nil {
		return 0, 0, fmt.Errorf("workspace: reopen stats: %w", err)
	}
	return reopens, doneCount, nil
}

// EscapedBugsCount counts bugs flagged as a regression (a bug in something
// already shipped) — the "escaped to production" proxy this phase uses.
func (r *Repo) EscapedBugsCount(ctx context.Context, db DBTX, projectID string) (int, error) {
	var n int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_items WHERE project_id = $1 AND type = 'bug' AND is_regression = true AND archived_at IS NULL`,
		projectID,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: escaped bugs count: %w", err)
	}
	return n, nil
}

// GitlabQualitySignals reads CI pass rate and MR size stats for a
// GitLab-linked project directly off gitlab's own mirror tables — nil/zero
// when teamID is nil (no GitLab project yet).
func (r *Repo) GitlabQualitySignals(ctx context.Context, db DBTX, teamID string) (ciPassRatePct *float64, mrSizeMedian *float64, largeMRs int, err error) {
	var total, passed int
	if err = db.QueryRow(ctx,
		`SELECT count(*), count(*) FILTER (WHERE status = 'success') FROM gitlab_pipelines WHERE team_id = $1`,
		teamID,
	).Scan(&total, &passed); err != nil {
		return nil, nil, 0, fmt.Errorf("workspace: gitlab quality: pipelines: %w", err)
	}
	if total > 0 {
		pct := float64(passed) * 100 / float64(total)
		ciPassRatePct = &pct
	}

	rows, err := db.Query(ctx, `SELECT COALESCE(additions,0) + COALESCE(deletions,0) FROM gitlab_merge_requests WHERE team_id = $1`, teamID)
	if err != nil {
		return ciPassRatePct, nil, 0, fmt.Errorf("workspace: gitlab quality: mr sizes: %w", err)
	}
	defer rows.Close()
	sizes := []float64{}
	for rows.Next() {
		var n int
		if err := rows.Scan(&n); err != nil {
			return nil, nil, 0, err
		}
		sizes = append(sizes, float64(n))
		if n > MRSizeFlagLines {
			largeMRs++
		}
	}
	if len(sizes) > 0 {
		median := percentile(sizes, 0.5)
		mrSizeMedian = &median
	}
	return ciPassRatePct, mrSizeMedian, largeMRs, rows.Err()
}

// ─── people / tracks / plan tree ────────────────────────────────────────────

// PersonMetricsRows returns one row per active member (or just onlyUserID,
// when set) — WIP/completed/reviews/minutes-logged/onboarding are real;
// AttendancePct/StandupsPosted/EstimateAccuracy/ReopensCaused/
// ReviewResponseHrs stay zero-valued this phase (ponytail: coaching-only
// fields with no queries written yet — add them alongside the meeting-
// attendance and estimate-vs-actual UI that would actually surface them).
func (r *Repo) PersonMetricsRows(ctx context.Context, db DBTX, projectID, onlyUserID string, wipLimit int, now time.Time) ([]PersonMetrics, error) {
	rows, err := db.Query(ctx,
		`SELECT pm.user_id, u.name, pm.role,
		        count(*) FILTER (WHERE a.role = 'owner' AND w.status = 'in_progress') AS wip,
		        count(*) FILTER (WHERE a.role = 'owner' AND w.status = 'done') AS completed_owned,
		        count(*) FILTER (WHERE r.target = 'code') AS reviews_done,
		        count(*) FILTER (WHERE r.target = 'doc') AS tests_done,
		        COALESCE((SELECT sum(minutes) FROM work_item_time_logs t WHERE t.project_id = pm.project_id AND t.user_id = pm.user_id), 0) AS minutes_logged,
		        COALESCE((100 * count(DISTINCT os.id) FILTER (WHERE op.step_id IS NOT NULL)) / NULLIF(count(DISTINCT os.id) FILTER (WHERE os.required), 0), 100) AS onboarding_pct
		   FROM project_members pm
		   JOIN users u ON u.id = pm.user_id
		   LEFT JOIN work_item_assignees a ON a.user_id = pm.user_id
		   LEFT JOIN work_items w ON w.id = a.item_id AND w.project_id = pm.project_id AND w.archived_at IS NULL
		   LEFT JOIN work_item_reviews r ON r.reviewer_id = pm.user_id AND r.project_id = pm.project_id
		   LEFT JOIN onboarding_steps os ON os.project_id = pm.project_id
		   LEFT JOIN onboarding_progress op ON op.step_id = os.id AND op.user_id = pm.user_id
		  WHERE pm.project_id = $1 AND pm.status = 'active' AND ($2 = '' OR pm.user_id = $2)
		  GROUP BY pm.user_id, u.name, pm.role, pm.project_id
		  ORDER BY u.name`,
		projectID, onlyUserID)
	if err != nil {
		return nil, fmt.Errorf("workspace: person metrics rows: %w", err)
	}
	defer rows.Close()
	out := []PersonMetrics{}
	for rows.Next() {
		var pm PersonMetrics
		var onboardingPct int
		if err := rows.Scan(&pm.Person.UserID, &pm.Person.Name, &pm.Role, &pm.WIP, &pm.CompletedOwned,
			&pm.ReviewsDone, &pm.TestsDone, &pm.MinutesLogged, &onboardingPct); err != nil {
			return nil, fmt.Errorf("workspace: scan person metrics row: %w", err)
		}
		pm.WipLimit = wipLimit
		pm.OnboardingPct = onboardingPct
		pm.LoadByRole = map[string]int{}
		out = append(out, pm)
	}
	return out, rows.Err()
}

// PlanTreeRows returns every non-archived epic/feature/task/bug/subtask with
// just what buildPlanTree (service_dashboard.go) needs to assemble the
// nested tree in Go.
type planTreeRow struct {
	ItemRef
	ParentID  *string
	DocStatus *string
	OwnerID   *string
	OwnerName *string
}

func (r *Repo) PlanTreeRows(ctx context.Context, db DBTX, projectID string) ([]planTreeRow, error) {
	rows, err := db.Query(ctx,
		`SELECT w.id, p.key_prefix || '-' || w.key_num, w.type, w.title, w.status, w.parent_id, w.doc_status,
		        (SELECT a.user_id FROM work_item_assignees a WHERE a.item_id = w.id AND a.role = 'owner' LIMIT 1),
		        (SELECT u.name FROM work_item_assignees a JOIN users u ON u.id = a.user_id WHERE a.item_id = w.id AND a.role = 'owner' LIMIT 1)
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.archived_at IS NULL
		  ORDER BY w.created_at ASC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: plan tree rows: %w", err)
	}
	defer rows.Close()
	out := []planTreeRow{}
	for rows.Next() {
		var row planTreeRow
		if err := rows.Scan(&row.ID, &row.Key, &row.Type, &row.Title, &row.Status, &row.ParentID, &row.DocStatus, &row.OwnerID, &row.OwnerName); err != nil {
			return nil, fmt.Errorf("workspace: scan plan tree row: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// TrackMetricsRows returns one row per track with the counts
// TrackMetrics needs — CycleTime/CrossTrackBlockers stay zero (ponytail: the
// same per-track percentile/cross-track-link breakdown as the project-wide
// ones above, deferred for the same reason).
func (r *Repo) TrackMetricsRows(ctx context.Context, db DBTX, projectID string, now time.Time) ([]TrackMetrics, error) {
	rows, err := db.Query(ctx,
		`SELECT t.id, t.name, t.lead_user_id, lu.name,
		        (SELECT count(*) FROM project_track_members tm WHERE tm.track_id = t.id AND tm.status = 'approved'),
		        count(w.id) FILTER (WHERE w.status NOT IN ('done','wont_do') AND w.archived_at IS NULL),
		        count(w.id) FILTER (WHERE w.status = 'done' AND w.archived_at IS NULL),
		        count(w.id) FILTER (WHERE w.type = 'bug' AND w.archived_at IS NULL AND w.status NOT IN ('done','wont_do')),
		        count(w.id) FILTER (WHERE w.status = 'in_progress' AND w.archived_at IS NULL),
		        count(w.id) FILTER (WHERE w.type = 'feature' AND w.doc_status = 'in_review' AND w.archived_at IS NULL)
		   FROM project_tracks t
		   LEFT JOIN users lu ON lu.id = t.lead_user_id
		   LEFT JOIN work_items w ON w.track_id = t.id
		  WHERE t.project_id = $1
		  GROUP BY t.id, t.name, t.lead_user_id, lu.name
		  ORDER BY t.name`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: track metrics rows: %w", err)
	}
	defer rows.Close()
	out := []TrackMetrics{}
	for rows.Next() {
		var tm TrackMetrics
		var leadID, leadName *string
		if err := rows.Scan(&tm.TrackID, &tm.Name, &leadID, &leadName, &tm.Members, &tm.Open, &tm.Done, &tm.Bugs, &tm.WIP, &tm.FeaturesAwaitingDoc); err != nil {
			return nil, fmt.Errorf("workspace: scan track metrics row: %w", err)
		}
		if leadID != nil {
			tm.Lead = &PersonRef{UserID: *leadID, Name: *leadName}
		}
		tm.Throughput = tm.Done
		tm.Capacity = tm.Members
		out = append(out, tm)
	}
	return out, rows.Err()
}

// percentile computes the p-th percentile (0..1) of a sorted-in-place copy
// of samples via nearest-rank — small samples (a project's own item counts,
// never a huge dataset) don't need interpolation precision.
func percentile(samples []float64, p float64) float64 {
	if len(samples) == 0 {
		return 0
	}
	sorted := append([]float64(nil), samples...)
	for i := 1; i < len(sorted); i++ {
		for j := i; j > 0 && sorted[j-1] > sorted[j]; j-- {
			sorted[j-1], sorted[j] = sorted[j], sorted[j-1]
		}
	}
	idx := int(p * float64(len(sorted)-1))
	return sorted[idx]
}
