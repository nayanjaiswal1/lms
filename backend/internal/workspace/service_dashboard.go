package workspace

import (
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"log/slog"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/notifications"
)

// service_dashboard.go — Phase 4 (contract-phase4.md 4d): the manager
// dashboard, its pure health evaluator, and the daily digest job. See
// repo_dashboard.go's own doc comment for which metrics are real this phase
// and which are deliberately zero-valued placeholders (`ponytail:` marks
// each one, at the query that would fill it in).

// GetDashboard is GET …/dashboard?from=&to=&track=&user=&release= (viewer;
// visibility narrowed per 02 §7.2 / D15 below release= is ignored — Release
// stays nil until Phase 5).
func (s *Service) GetDashboard(ctx context.Context, pc *ProjectCtx, f DashboardFilter) (*Dashboard, error) {
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	now := s.now()
	from, to := f.From, f.To
	if from.IsZero() || to.IsZero() {
		to = now
		from = now.Add(-DashboardDefaultRange)
	}

	isManagerPlus := RoleAtLeast(pc.Role, RoleManager)
	ledTrackIDs, err := s.repo.ListLedTrackIDs(ctx, s.pool, pc.ProjectID, pc.UserID)
	if err != nil {
		return nil, err
	}
	isTrackLead := len(ledTrackIDs) > 0

	if f.UserID != "" && !isManagerPlus && f.UserID != pc.UserID {
		return nil, ErrForbidden
	}
	if f.TrackID != "" && !isManagerPlus {
		inScope := false
		for _, t := range ledTrackIDs {
			if t == f.TrackID {
				inScope = true
				break
			}
		}
		if !inScope {
			return nil, ErrForbidden
		}
	}

	d, err := s.buildDashboard(ctx, project, now, from, to)
	if err != nil {
		return nil, err
	}

	switch {
	case isManagerPlus:
		people, err := s.repo.PersonMetricsRows(ctx, s.pool, pc.ProjectID, f.UserID, project.WipLimit, now)
		if err != nil {
			return nil, err
		}
		d.People = people
	case isTrackLead:
		trackID := f.TrackID
		if trackID == "" {
			trackID = ledTrackIDs[0]
		}
		memberIDs, err := s.repo.ListApprovedTrackMemberIDs(ctx, s.pool, trackID)
		if err != nil {
			return nil, err
		}
		all, err := s.repo.PersonMetricsRows(ctx, s.pool, pc.ProjectID, "", project.WipLimit, now)
		if err != nil {
			return nil, err
		}
		inTrack := map[string]bool{}
		for _, id := range memberIDs {
			inTrack[id] = true
		}
		people := make([]PersonMetrics, 0, len(memberIDs))
		for _, p := range all {
			if inTrack[p.Person.UserID] {
				people = append(people, p)
			}
		}
		d.People = people
	case pc.Role == RoleMember:
		people, err := s.repo.PersonMetricsRows(ctx, s.pool, pc.ProjectID, pc.UserID, project.WipLimit, now)
		if err != nil {
			return nil, err
		}
		d.People = people
	default: // viewer
		d.People = []PersonMetrics{}
	}

	if err := s.applyReleaseSprintDashboard(ctx, pc, project, f, d, now); err != nil {
		return nil, err
	}
	if isManagerPlus {
		var cached WeeklySummary
		if found, err := s.repo.GetAICache(ctx, s.pool, pc.ProjectID, "weekly_summary", isoWeek(now), &cached); err == nil && found {
			d.AISummary = &cached
		}
	}

	d.Header.Health = s.EvaluateHealth(project, d)
	return d, nil
}

// applyReleaseSprintDashboard is Phase 5's own dashboard extension
// (contract-phase5.md 5a): burndown over the active sprint when
// sprints_enabled, ReleaseMetrics for the f.ReleaseID filter or the nearest
// planned/frozen release, the forecast's target date, and scope-churn counts
// since the sprint started / the release froze.
func (s *Service) applyReleaseSprintDashboard(ctx context.Context, pc *ProjectCtx, project *Project, f DashboardFilter, d *Dashboard, now time.Time) error {
	if project.SprintsEnabled {
		active, err := s.repo.ActiveSprint(ctx, s.pool, pc.ProjectID)
		if err != nil && err != ErrNotFound {
			return err
		}
		if active != nil {
			startsOn, sErr := time.Parse("2006-01-02", active.StartsOn)
			endsOn, eErr := time.Parse("2006-01-02", active.EndsOn)
			if sErr == nil && eErr == nil {
				if burndown, err := s.repo.SprintBurndown(ctx, s.pool, active.ID, startsOn, endsOn); err == nil {
					d.Delivery.Burndown = burndown
				}
			}
			if active.Committed > 0 {
				pct := float64(active.Done) / float64(active.Committed)
				d.Delivery.SprintCommitment = &pct
			}
			if startedAt, err := s.repo.SprintStartedAt(ctx, s.pool, active.ID); err == nil {
				if added, removed, err := s.repo.ScopeChurnAfterSprintStart(ctx, s.pool, active.ID, startedAt); err == nil {
					d.Delivery.ScopeChurn.AddedAfterStart = added
					d.Delivery.ScopeChurn.RemovedAfterStart = removed
				}
			}
		}
	}

	releaseID := f.ReleaseID
	if releaseID == "" {
		nearest, err := s.repo.NearestRelease(ctx, s.pool, pc.ProjectID)
		if err != nil && err != ErrNotFound {
			return err
		}
		if nearest != nil {
			releaseID = nearest.ID
		}
	}
	if releaseID == "" {
		return nil
	}
	rel, err := s.repo.GetRelease(ctx, s.pool, pc.ProjectID, releaseID)
	if err == ErrNotFound {
		return nil
	}
	if err != nil {
		return err
	}

	openBugs, err := s.repo.OpenBugsBySeverityInRelease(ctx, s.pool, rel.ID)
	if err != nil {
		return err
	}
	docsNotApproved, err := s.repo.CountDocsNotApprovedInRelease(ctx, s.pool, rel.ID)
	if err != nil {
		return err
	}
	rm := &ReleaseMetrics{
		ReleaseID: rel.ID, Version: rel.Version, Status: rel.Status,
		FeaturesDone: rel.FeaturesDone, FeaturesTotal: rel.FeaturesTotal,
		OpenBugsBySeverity: openBugs, DocsNotApproved: docsNotApproved,
		Readiness: map[string]bool{
			"all_features_done": rel.FeaturesTotal == 0 || rel.FeaturesDone == rel.FeaturesTotal,
			"no_docs_pending":   docsNotApproved == 0,
		},
	}
	if rel.TargetAt != nil {
		days := int(time.Until(*rel.TargetAt).Hours() / 24)
		rm.DaysToTarget = &days
	}
	if rel.FrozenAt != nil {
		scopeAdded, err := s.repo.ScopeAddedAfterFreeze(ctx, s.pool, rel.ID, *rel.FrozenAt)
		if err != nil {
			return err
		}
		rm.ScopeAddedAfterFreeze = scopeAdded
		if d.Delivery.SprintCommitment == nil {
			// Only surface release-level churn on the top scope-churn card when
			// no active sprint already claimed it above — a project can't be
			// mid-sprint AND have this be the churn signal worth leading with.
			d.Delivery.ScopeChurn.AddedAfterStart = scopeAdded
		}
	}
	rm.ForecastFinish = d.Delivery.Forecast.ProjectedFinish

	// ponytail: OverTargetPct is a simple "how far past target, as a share of
	// the time that was left to it" heuristic, not a statistically rigorous
	// projection — good enough to drive EvaluateHealth's red/yellow forecast
	// thresholds; revisit if a PM asks for something more precise.
	if rel.TargetAt != nil {
		d.Delivery.Forecast.Target = rel.TargetAt
		if pf := d.Delivery.Forecast.ProjectedFinish; pf != nil {
			overBy := pf.Sub(*rel.TargetAt)
			pct := 0.0
			if overBy > 0 {
				remaining := rel.TargetAt.Sub(now)
				if remaining > 0 {
					pct = overBy.Hours() / remaining.Hours() * 100
				} else {
					pct = 100
				}
			}
			d.Delivery.Forecast.OverTargetPct = &pct
		}
	}
	d.Release = rm
	return nil
}

// buildDashboard fills every role-independent section (totals, needs
// attention, delivery, quality, plan tree, tracks) — People/Header.Health are
// layered on by GetDashboard (role-scoped) and SendDigests (health only)
// respectively, since neither needs the other's redaction rules.
func (s *Service) buildDashboard(ctx context.Context, project *Project, now, from, to time.Time) (*Dashboard, error) {
	d := &Dashboard{Header: DashboardHeader{Status: project.ProjectStatus, From: from, To: to}}

	var err error
	d.NeedsAttention.BlockedItems, err = s.repo.ListBlockedItems(ctx, s.pool, project.ID)
	if err != nil {
		return nil, err
	}
	d.NeedsAttention.OverdueItems, err = s.repo.ListOverdueItems(ctx, s.pool, project.ID, now)
	if err != nil {
		return nil, err
	}
	d.NeedsAttention.StaleReviews, err = s.repo.ListStaleReviewItems(ctx, s.pool, project.ID, now.Add(-DocReviewReminderAfter))
	if err != nil {
		return nil, err
	}
	d.NeedsAttention.OpenS1S2Bugs, err = s.repo.ListOpenS1S2Bugs(ctx, s.pool, project.ID)
	if err != nil {
		return nil, err
	}
	d.NeedsAttention.StuckOnboarding, err = s.repo.ListStuckOnboardingPeople(ctx, s.pool, project.ID, now.Add(-7*24*time.Hour))
	if err != nil {
		return nil, err
	}
	d.NeedsAttention.InactiveMembers, err = s.repo.ListInactiveMembers(ctx, s.pool, project.ID, now.Add(-InactivityAlertAfter))
	if err != nil {
		return nil, err
	}
	d.NeedsAttention.LeaderlessTracks, err = s.repo.ListLeaderlessTracks(ctx, s.pool, project.ID)
	if err != nil {
		return nil, err
	}
	d.NeedsAttention.StandupBlockers = s.todaysStandupBlockers(ctx, project)

	total, done, err := s.repo.ProjectItemTotals(ctx, s.pool, project.ID)
	if err != nil {
		return nil, err
	}
	if total > 0 {
		d.Delivery.ProgressPct = float64(done) * 100 / float64(total)
	}
	d.Delivery.Burndown, err = s.repo.Burndown(ctx, s.pool, project.ID, from, to)
	if err != nil {
		return nil, err
	}
	d.Delivery.Throughput, err = s.repo.WeeklyDoneThroughput(ctx, s.pool, project.ID, from, to)
	if err != nil {
		return nil, err
	}
	leadHours, err := s.repo.LeadTimeHours(ctx, s.pool, project.ID, from, to)
	if err != nil {
		return nil, err
	}
	d.Delivery.LeadTime = percentileStat(leadHours)
	// ponytail: cycle time (first in_progress -> done) needs a "first entered
	// in_progress" timestamp this schema doesn't materialize separately from
	// the full event log; approximated as lead time until that's worth a
	// dedicated query. StageTime/ScopeChurn/RequirementClarity/
	// SprintCommitment/DocTurnaround/DocReviewRounds are the same kind of
	// deferral — zero-valued rather than guessed at.
	d.Delivery.CycleTime = d.Delivery.LeadTime
	d.Delivery.StageTime = map[string]PercentileStat{}
	d.Delivery.BlockedHours, err = s.repo.BlockedHoursTotal(ctx, s.pool, project.ID, now)
	if err != nil {
		return nil, err
	}
	d.Delivery.TopBlockers = d.NeedsAttention.BlockedItems
	d.Delivery.Forecast = computeForecast(total, done, d.Delivery.Throughput, now)

	d.Quality.BugsBySeverity, err = s.repo.BugsBySeverity(ctx, s.pool, project.ID, now)
	if err != nil {
		return nil, err
	}
	d.Quality.BugInflowVsFix, err = s.repo.BugInflowVsFix(ctx, s.pool, project.ID, from, to)
	if err != nil {
		return nil, err
	}
	reopens, everDone, err := s.repo.ReopenStats(ctx, s.pool, project.ID)
	if err != nil {
		return nil, err
	}
	if everDone > 0 {
		d.Quality.ReopenRatePct = float64(reopens) * 100 / float64(everDone)
	}
	d.Quality.EscapedBugs, err = s.repo.EscapedBugsCount(ctx, s.pool, project.ID)
	if err != nil {
		return nil, err
	}
	d.Quality.BugDensity = []FeatureDensity{}
	d.Quality.MRReviewRounds = PercentileStat{}
	if project.TeamID != nil {
		ciPass, mrSize, largeMRs, err := s.repo.GitlabQualitySignals(ctx, s.pool, *project.TeamID)
		if err != nil {
			return nil, err
		}
		d.Quality.CIPassRatePct = ciPass
		d.Quality.MRSizeMedian = mrSize
		d.Quality.LargeMRs = largeMRs
	}

	planRows, err := s.repo.PlanTreeRows(ctx, s.pool, project.ID)
	if err != nil {
		return nil, err
	}
	d.PlanTree = buildPlanTree(planRows)

	d.Tracks, err = s.repo.TrackMetricsRows(ctx, s.pool, project.ID, now)
	if err != nil {
		return nil, err
	}

	d.Release = nil   // Phase 5
	d.AISummary = nil // Phase 5
	return d, nil
}

// todaysStandupBlockers resolves every ticket key mentioned in today's
// standup blockers, deduped — best-effort (a resolve failure just means an
// empty list, never fails the whole dashboard read).
func (s *Service) todaysStandupBlockers(ctx context.Context, project *Project) []ItemRef {
	standups, err := s.repo.ListStandups(ctx, s.pool, project.ID, s.now().Format("2006-01-02"))
	if err != nil {
		slog.ErrorContext(ctx, "workspace: dashboard: list today's standups", "error", err)
		return []ItemRef{}
	}
	seen := map[string]bool{}
	out := []ItemRef{}
	pc := &ProjectCtx{ProjectID: project.ID, OrgID: project.OrgID}
	for _, st := range standups {
		if st.Blockers == nil {
			continue
		}
		for _, ref := range s.resolveBlockerKeys(ctx, pc, project.KeyPrefix, *st.Blockers) {
			if !seen[ref.ID] {
				seen[ref.ID] = true
				out = append(out, ref)
			}
		}
	}
	return out
}

// percentileStat builds a PercentileStat from a raw hours sample.
func percentileStat(hours []float64) PercentileStat {
	stat := PercentileStat{Count: len(hours)}
	if len(hours) == 0 {
		return stat
	}
	median := percentile(hours, 0.5)
	p85 := percentile(hours, 0.85)
	stat.MedianHrs = &median
	stat.P85Hrs = &p85
	return stat
}

// computeForecast projects a finish date from the trailing weeks' throughput.
// Target/OverTargetPct stay nil until Phase 5 gives a project/release a real
// target date to compare against.
func computeForecast(total, done int, throughput []WeekPoint, now time.Time) Forecast {
	remaining := total - done
	if remaining < 0 {
		remaining = 0
	}
	f := Forecast{Remaining: remaining}
	if len(throughput) == 0 {
		return f
	}
	sum := 0
	for _, wp := range throughput {
		sum += wp.Count
	}
	f.WeeklyThroughput = float64(sum) / float64(len(throughput))
	if f.WeeklyThroughput > 0 && remaining > 0 {
		weeksLeft := float64(remaining) / f.WeeklyThroughput
		finish := now.Add(time.Duration(weeksLeft*7*24) * time.Hour)
		f.ProjectedFinish = &finish
	}
	return f
}

// buildPlanTree assembles the epic->feature->task/bug/subtask hierarchy from
// a flat row list — every non-archived item, so a track's cross-links (a bug
// filed directly under an epic, no feature) render as their own top-level
// entries too.
func buildPlanTree(rows []planTreeRow) []PlanTreeNode {
	nodes := make(map[string]*PlanTreeNode, len(rows))
	for _, r := range rows {
		n := &PlanTreeNode{Item: r.ItemRef, DocStatus: r.DocStatus, Children: []PlanTreeNode{}}
		if r.Status == ItemDone {
			n.ProgressPct = 100
		}
		if r.OwnerID != nil {
			n.Owner = &PersonRef{UserID: *r.OwnerID, Name: *r.OwnerName}
		}
		nodes[r.ID] = n
	}
	var roots []PlanTreeNode
	for _, r := range rows {
		n := nodes[r.ID]
		if r.ParentID != nil {
			if parent, ok := nodes[*r.ParentID]; ok {
				parent.Children = append(parent.Children, *n)
				continue
			}
		}
		roots = append(roots, *n)
	}
	for i := range roots {
		fillRollupProgress(&roots[i])
	}
	return roots
}

// fillRollupProgress recomputes a parent's ProgressPct from its (already
// rolled-up) children's — leaves keep the 0/100 set above.
func fillRollupProgress(n *PlanTreeNode) {
	if len(n.Children) == 0 {
		return
	}
	sum := 0.0
	for i := range n.Children {
		fillRollupProgress(&n.Children[i])
		sum += n.Children[i].ProgressPct
	}
	n.ProgressPct = sum / float64(len(n.Children))
	n.AtRisk = n.Item.Status == ItemBlocked
}

// EvaluateHealth is a pure function over an already-built Dashboard —
// contract-phase4.md 4d's thresholds table, read from the project's own
// health_thresholds (owner-configurable, models.go's HealthThreshold).
func (s *Service) EvaluateHealth(p *Project, d *Dashboard) HealthReport {
	th := p.HealthThresholds
	var reasons []string
	red, yellow := false, false

	for _, sc := range d.Quality.BugsBySeverity {
		if sc.Severity == "S1" && sc.Open > 0 && sc.OldestAgeHrs > float64(th.S1OpenHours) {
			red = true
			reasons = append(reasons, fmt.Sprintf("An S1 bug has been open %.0fh (limit %dh)", sc.OldestAgeHrs, th.S1OpenHours))
		}
	}
	if d.Delivery.Forecast.OverTargetPct != nil {
		switch {
		case *d.Delivery.Forecast.OverTargetPct > float64(th.ForecastRedPct):
			red = true
			reasons = append(reasons, "Forecast is significantly behind target")
		case *d.Delivery.Forecast.OverTargetPct > 0:
			yellow = true
			reasons = append(reasons, "Forecast is behind target")
		}
	}
	if openCount := latestOpenCount(d.Delivery.Burndown); openCount > 0 {
		blockedPct := float64(len(d.NeedsAttention.BlockedItems)) * 100 / float64(openCount)
		if blockedPct > float64(th.BlockedRedPct) {
			red = true
			reasons = append(reasons, fmt.Sprintf("%.0f%% of open work is blocked (limit %d%%)", blockedPct, th.BlockedRedPct))
		}
	}
	if len(d.NeedsAttention.StaleReviews) > 0 {
		yellow = true
		reasons = append(reasons, "Spec reviews are waiting")
	}
	if d.Quality.ReopenRatePct > float64(th.ReopenYellowPct) {
		yellow = true
		reasons = append(reasons, fmt.Sprintf("Reopen rate is %.0f%% (limit %d%%)", d.Quality.ReopenRatePct, th.ReopenYellowPct))
	}
	if len(d.NeedsAttention.InactiveMembers) > 0 {
		yellow = true
		reasons = append(reasons, "At least one member has been inactive")
	}

	color := HealthGreen
	if yellow {
		color = HealthYellow
	}
	if red {
		color = HealthRed
	}
	if reasons == nil {
		reasons = []string{}
	}
	return HealthReport{Color: color, Reasons: reasons}
}

func latestOpenCount(burndown []DayPoint) int {
	if len(burndown) == 0 {
		return 0
	}
	return burndown[len(burndown)-1].Open
}

// SendDigests is the workspace.manager_digest daily 08:00 job: one digest per
// active project per day, idempotent (INSERT ... ON CONFLICT DO NOTHING
// first — 0 rows means it already ran today for this project). Notifies the
// owner+managers with what changed since yesterday.
func (s *Service) SendDigests(ctx context.Context, day time.Time) (int, error) {
	projectIDs, err := s.repo.ListActiveProjectIDs(ctx)
	if err != nil {
		return 0, err
	}
	now := s.now()
	sent := 0
	for _, projectID := range projectIDs {
		project, err := s.repo.GetProject(ctx, s.pool, "", projectID)
		if err != nil {
			// GetProject is org-scoped; resolve org first when scanning across
			// every project regardless of org (same shape as GetProjectOrgID's
			// own cross-org lookup).
			orgID, oerr := s.repo.GetProjectOrgID(ctx, s.pool, projectID)
			if oerr != nil {
				slog.ErrorContext(ctx, "workspace: send digests: resolve org", "project_id", projectID, "error", oerr)
				continue
			}
			project, err = s.repo.GetProject(ctx, s.pool, orgID, projectID)
			if err != nil {
				slog.ErrorContext(ctx, "workspace: send digests: get project", "project_id", projectID, "error", err)
				continue
			}
		}
		from := now.Add(-DashboardDefaultRange)
		d, err := s.buildDashboard(ctx, project, now, from, now)
		if err != nil {
			slog.ErrorContext(ctx, "workspace: send digests: build dashboard", "project_id", projectID, "error", err)
			continue
		}
		health := s.EvaluateHealth(project, d)

		inserted, err := s.repo.InsertDigestIfAbsent(ctx, projectID, day, health.Color)
		if err != nil {
			slog.ErrorContext(ctx, "workspace: send digests: insert digest", "project_id", projectID, "error", err)
			continue
		}
		if !inserted {
			continue // already sent today
		}

		prevHealth, err := s.repo.PreviousDigestHealth(ctx, projectID, day)
		if err != nil {
			slog.ErrorContext(ctx, "workspace: send digests: previous health", "project_id", projectID, "error", err)
		}
		if err := s.notifyDigest(ctx, project, d, health, prevHealth); err != nil {
			slog.ErrorContext(ctx, "workspace: send digests: notify", "project_id", projectID, "error", err)
			continue
		}
		sent++
	}
	return sent, nil
}

// notifyDigest composes and sends one project's daily digest to its
// owner+managers.
func (s *Service) notifyDigest(ctx context.Context, project *Project, d *Dashboard, health HealthReport, prevHealth string) error {
	recipients, err := s.repo.ListManagerUserIDs(ctx, s.pool, project.ID)
	if err != nil {
		return err
	}
	if len(recipients) == 0 {
		return nil
	}
	lines := []string{fmt.Sprintf("Health: %s", health.Color)}
	if prevHealth != "" && prevHealth != health.Color {
		lines[0] += fmt.Sprintf(" (was %s)", prevHealth)
	}
	if n := len(d.NeedsAttention.BlockedItems); n > 0 {
		lines = append(lines, fmt.Sprintf("%d item(s) blocked", n))
	}
	if n := len(d.NeedsAttention.OverdueItems); n > 0 {
		lines = append(lines, fmt.Sprintf("%d item(s) overdue", n))
	}
	if n := len(d.NeedsAttention.StaleReviews); n > 0 {
		lines = append(lines, fmt.Sprintf("%d spec review(s) waiting", n))
	}
	if n := len(d.NeedsAttention.InactiveMembers); n > 0 {
		lines = append(lines, fmt.Sprintf("%d inactive member(s)", n))
	}
	if n := len(d.NeedsAttention.OpenS1S2Bugs); n > 0 {
		lines = append(lines, fmt.Sprintf("%d open S1/S2 bug(s)", n))
	}
	body := joinLines(lines)
	return s.repo.InTx(ctx, func(tx pgx.Tx) error {
		return s.notif.NotifyMany(ctx, tx, notifications.New{
			OrgID: project.OrgID, Type: "workspace_manager_digest", Title: fmt.Sprintf("%s daily digest", project.Title), Body: &body,
			EntityType: strPtr("workspace_project"), EntityID: &project.ID,
			Priority:  digestPriority(health.Color),
			AlsoEmail: health.Color == HealthRed,
			DedupeKey: fmt.Sprintf("workspace_manager_digest:%s:%s", project.ID, s.now().Format("2006-01-02")),
		}, recipients)
	})
}

func digestPriority(color string) string {
	if color == HealthRed {
		return notifications.PriorityHigh
	}
	return notifications.PriorityNormal
}

func joinLines(lines []string) string {
	out := ""
	for i, l := range lines {
		if i > 0 {
			out += " · "
		}
		out += l
	}
	return out
}

// csvCell guards against formula injection when a spreadsheet app opens the
// export (contract-phase5.md 5d): a cell whose first character would launch
// a formula in Excel/Sheets/LibreOffice gets a leading apostrophe, which
// every one of them renders as literal text instead of evaluating it.
func csvCell(s string) string {
	if len(s) > 0 {
		switch s[0] {
		case '=', '+', '-', '@':
			return "'" + s
		}
	}
	return s
}

// ExportCSV is GET …/export/{kind}.csv (manager+): items | time_logs |
// members, streamed as text/csv straight to w.
func (s *Service) ExportCSV(ctx context.Context, pc *ProjectCtx, kind string, w io.Writer) error {
	cw := csv.NewWriter(w)
	var err error
	switch kind {
	case ExportKindItems:
		err = s.exportItemsCSV(ctx, pc, cw)
	case ExportKindTimeLogs:
		err = s.exportTimeLogsCSV(ctx, pc, cw)
	case ExportKindMembers:
		err = s.exportMembersCSV(ctx, pc, cw)
	default:
		return fmt.Errorf("%w: unknown export kind %q", ErrInvalidInput, kind)
	}
	if err != nil {
		return err
	}
	cw.Flush()
	return cw.Error()
}

func (s *Service) exportItemsCSV(ctx context.Context, pc *ProjectCtx, cw *csv.Writer) error {
	if err := cw.Write([]string{"key", "type", "title", "status", "priority", "severity", "track", "release_id", "sprint_id",
		"assignees", "estimate_minutes", "due_at", "created_at"}); err != nil {
		return fmt.Errorf("workspace: export items csv: header: %w", err)
	}
	cursorAt, cursorID := time.Time{}, ""
	for {
		items, err := s.repo.ListWorkItems(ctx, s.pool, pc.ProjectID, ItemFilter{IncludeArchived: true}, cursorAt, cursorID, PageSizeMax)
		if err != nil {
			return err
		}
		if len(items) == 0 {
			return nil
		}
		ids := make([]string, len(items))
		for i := range items {
			ids[i] = items[i].ID
		}
		byItem, err := s.repo.ListAssigneesForItems(ctx, s.pool, ids)
		if err != nil {
			return err
		}
		for _, it := range items {
			severity, track, dueAt := "", "", ""
			if it.Severity != nil {
				severity = *it.Severity
			}
			if it.TrackID != nil {
				track = *it.TrackID
			}
			if it.DueAt != nil {
				dueAt = it.DueAt.UTC().Format(time.RFC3339)
			}
			estimate := ""
			if it.EstimateMinutes != nil {
				estimate = strconv.Itoa(*it.EstimateMinutes)
			}
			names := make([]string, 0, len(byItem[it.ID]))
			for _, a := range byItem[it.ID] {
				names = append(names, a.Name+" ("+a.Role+")")
			}
			row := []string{it.Key, it.Type, it.Title, it.Status, it.Priority, severity, track,
				valueOrEmpty(it.ReleaseID), valueOrEmpty(it.SprintID), strings.Join(names, "; "),
				estimate, dueAt, it.CreatedAt.UTC().Format(time.RFC3339)}
			for i := range row {
				row[i] = csvCell(row[i])
			}
			if err := cw.Write(row); err != nil {
				return fmt.Errorf("workspace: export items csv: row: %w", err)
			}
		}
		if len(items) < PageSizeMax {
			return nil
		}
		last := items[len(items)-1]
		cursorAt, cursorID = last.CreatedAt, last.ID
	}
}

func (s *Service) exportTimeLogsCSV(ctx context.Context, pc *ProjectCtx, cw *csv.Writer) error {
	if err := cw.Write([]string{"item_key", "user", "minutes", "note", "logged_on", "created_at"}); err != nil {
		return fmt.Errorf("workspace: export time logs csv: header: %w", err)
	}
	cursorAt, cursorID := time.Time{}, ""
	for {
		logs, err := s.repo.ListTimeLogs(ctx, s.pool, pc.ProjectID, "", "", pc.UserID, cursorAt, cursorID, PageSizeMax)
		if err != nil {
			return err
		}
		if len(logs) == 0 {
			return nil
		}
		for _, l := range logs {
			note := ""
			if l.Note != nil {
				note = *l.Note
			}
			row := []string{l.ItemKey, l.UserName, strconv.Itoa(l.Minutes), note, l.LoggedOn, l.CreatedAt.UTC().Format(time.RFC3339)}
			for i := range row {
				row[i] = csvCell(row[i])
			}
			if err := cw.Write(row); err != nil {
				return fmt.Errorf("workspace: export time logs csv: row: %w", err)
			}
		}
		if len(logs) < PageSizeMax {
			return nil
		}
		last := logs[len(logs)-1]
		cursorAt, cursorID = last.CreatedAt, last.ID
	}
}

func (s *Service) exportMembersCSV(ctx context.Context, pc *ProjectCtx, cw *csv.Writer) error {
	if err := cw.Write([]string{"name", "email", "role", "status", "joined_at", "onboarding_pct"}); err != nil {
		return fmt.Errorf("workspace: export members csv: header: %w", err)
	}
	members, err := s.repo.ListMembers(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return err
	}
	for _, m := range members {
		row := []string{m.Name, m.Email, m.Role, m.Status, m.JoinedAt.UTC().Format(time.RFC3339), strconv.Itoa(m.OnboardingPct)}
		for i := range row {
			row[i] = csvCell(row[i])
		}
		if err := cw.Write(row); err != nil {
			return fmt.Errorf("workspace: export members csv: row: %w", err)
		}
	}
	return nil
}
