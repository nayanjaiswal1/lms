package gitlab

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
)

// Job handler key for this file's job — see service_provision.go's own
// jobProvisionTeam doc comment for why these are plain string literals
// rather than a shared constants import. MUST stay in sync with
// handlers.HandlerGitlabOriginalityScan in
// internal/jobs/handlers/constants.go.
const jobOriginalityScan = "gitlab.originality_scan"

// originalityScanTimeoutMS is generous — downloading every team's (+ the
// template's) repository archive and running the pairwise shingle/Jaccard
// comparison can run long for an assignment with many teams. Raised from
// 300000 (300s) to 900000 (900s) alongside originality.go's
// maxOriginalityFileBytes (512KB -> 2MB) and maxOriginalityFilesPerProject
// (300 -> 600): both the pairwise file-compare count (files^2) and the
// per-file shingle-set size scale with those caps, so the worst-case
// comparison cost can grow well beyond the 4x a naive "doubled both caps"
// estimate suggests — 900s covers that with headroom. There is no
// job-queue-level ceiling on TimeoutMS (internal/jobs/worker.go applies it
// directly as the job's context deadline), so raising this is safe.
const originalityScanTimeoutMS = 900000

// RequestOriginalityScan creates a pending report row for assignmentID and
// enqueues the gitlab.originality_scan job to actually run it — the same
// synchronous-request/async-run shape every other long-running GitLab
// operation in this package uses (ProvisionTeam, handoff).
func (s *Service) RequestOriginalityScan(ctx context.Context, orgID, assignmentID, requestedBy string) (*ProjectOriginalityReport, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, fmt.Errorf("gitlab: request originality scan: %w", err)
	}
	report, err := s.repo.CreateOriginalityReport(ctx, orgID, assignmentID, requestedBy)
	if err != nil {
		return nil, fmt.Errorf("gitlab: request originality scan: %w", err)
	}
	timeout := originalityScanTimeoutMS
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler: jobOriginalityScan, Priority: jobs.PriorityBackground,
		Payload: map[string]string{"report_id": report.ID}, OrgID: &orgID, TimeoutMS: &timeout,
	}); err != nil {
		return nil, fmt.Errorf("gitlab: enqueue originality scan: %w", err)
	}
	return report, nil
}

// ListOriginalityReports lists every scan run for an assignment (newest
// first), each with its own matches inlined — GET .../originality.
func (s *Service) ListOriginalityReports(ctx context.Context, orgID, assignmentID string) ([]OriginalityReportView, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, err
	}
	reports, err := s.repo.ListOriginalityReports(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list originality reports: %w", err)
	}
	out := make([]OriginalityReportView, 0, len(reports))
	for _, rpt := range reports {
		matches, err := s.repo.ListOriginalityMatches(ctx, rpt.ID)
		if err != nil {
			return nil, fmt.Errorf("gitlab: list originality matches for report %s: %w", rpt.ID, err)
		}
		out = append(out, OriginalityReportView{ProjectOriginalityReport: rpt, Matches: matches})
	}
	return out, nil
}

// originalitySource is one project's extracted source, pre-shingled once per
// file — either a real team (TeamID set) or the assignment's template
// project (TeamID nil, matching project_originality_matches.team_b_id's own
// nullable-means-template convention).
type originalitySource struct {
	TeamID   *string
	Files    map[string]string
	Shingles map[string]map[string]struct{} // file path -> shingle set
}

func buildOriginalitySource(teamID *string, files map[string]string) originalitySource {
	shingles := make(map[string]map[string]struct{}, len(files))
	for path, content := range files {
		shingles[path] = Shingles(NormalizeSourceLines(content), shingleK)
	}
	return originalitySource{TeamID: teamID, Files: files, Shingles: shingles}
}

// RunOriginalityScan is the gitlab.originality_scan job body: downloads
// every ready team's repository archive (plus the template's, if the
// assignment has one resolved) via Client.DownloadArchive, extracts source
// files via ExtractSourceFiles, and pairwise-compares every distinct pair
// (team vs team, and team vs template) via Shingles/JaccardSimilarity,
// persisting matches at or above originalityMatchThreshold. Idempotent to
// re-run: it deletes this report's own prior matches first, so a retried job
// (e.g. after a transient download failure mid-run) never doubles up rows.
func (s *Service) RunOriginalityScan(ctx context.Context, reportID string) error {
	report, err := s.repo.GetOriginalityReportByID(ctx, reportID)
	if err != nil {
		return fmt.Errorf("gitlab: run originality scan: get report: %w", err)
	}
	if err := s.repo.SetOriginalityReportStatus(ctx, reportID, OriginalityStatusRunning, nil); err != nil {
		return fmt.Errorf("gitlab: run originality scan: mark running: %w", err)
	}

	if runErr := s.runOriginalityScanSteps(ctx, report); runErr != nil {
		msg := runErr.Error()
		if err := s.repo.SetOriginalityReportStatus(ctx, reportID, OriginalityStatusFailed, &msg); err != nil {
			slog.ErrorContext(ctx, "gitlab: mark originality report failed", "report_id", reportID, "error", err)
		}
		return fmt.Errorf("gitlab: run originality scan: %w", runErr)
	}
	return nil
}

func (s *Service) runOriginalityScanSteps(ctx context.Context, report *ProjectOriginalityReport) error {
	assignment, err := s.repo.GetAssignmentByID(ctx, report.AssignmentID)
	if err != nil {
		return fmt.Errorf("get assignment: %w", err)
	}
	client, err := s.clientFor(ctx, report.OrgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("resolve installation client: %w", err)
	}
	teams, err := s.repo.ListTeams(ctx, report.OrgID, report.AssignmentID)
	if err != nil {
		return fmt.Errorf("list teams: %w", err)
	}
	if err := s.repo.DeleteOriginalityMatches(ctx, report.ID); err != nil {
		return fmt.Errorf("clear prior matches: %w", err)
	}

	sources := make([]originalitySource, 0, len(teams)+1)
	filesScanned := 0

	if assignment.TemplateProjectID != nil {
		files, err := s.downloadAndExtract(ctx, client, *assignment.TemplateProjectID)
		if err != nil {
			slog.WarnContext(ctx, "gitlab: originality scan: download template archive failed (continuing without template comparison)",
				"assignment_id", assignment.ID, "error", err)
		} else {
			sources = append(sources, buildOriginalitySource(nil, files))
			filesScanned += len(files)
		}
	}

	teamsScanned := 0
	for _, team := range teams {
		if team.GitlabProjectID == nil {
			continue // unprovisioned team — nothing to download yet
		}
		files, err := s.downloadAndExtract(ctx, client, *team.GitlabProjectID)
		if err != nil {
			slog.WarnContext(ctx, "gitlab: originality scan: download team archive failed (skipping this team)",
				"team_id", team.ID, "error", err)
			continue
		}
		teamID := team.ID
		sources = append(sources, buildOriginalitySource(&teamID, files))
		filesScanned += len(files)
		teamsScanned++
	}

	for i := 0; i < len(sources); i++ {
		for j := i + 1; j < len(sources); j++ {
			a, b := sources[i], sources[j]
			// team_a_id must be non-null (migration 023's NOT NULL) —
			// whichever side of the pair is a real team goes there; when
			// both are real teams the assignment is arbitrary, since the
			// comparison itself is symmetric.
			teamAID, teamBID := a.TeamID, b.TeamID
			if teamAID == nil {
				teamAID, teamBID = b.TeamID, a.TeamID
			}
			if err := s.compareOriginalitySourcePair(ctx, report.ID, *teamAID, teamBID, a, b); err != nil {
				return fmt.Errorf("compare pair: %w", err)
			}
		}
	}

	return s.repo.CompleteOriginalityReport(ctx, report.ID, teamsScanned, filesScanned)
}

func (s *Service) downloadAndExtract(ctx context.Context, client *Client, projectID int64) (map[string]string, error) {
	archive, err := client.DownloadArchive(ctx, projectID, "")
	if err != nil {
		return nil, fmt.Errorf("download archive for project %d: %w", projectID, err)
	}
	files, err := ExtractSourceFiles(archive)
	if err != nil {
		return nil, fmt.Errorf("extract archive for project %d: %w", projectID, err)
	}
	return files, nil
}

// compareOriginalitySourcePair runs every fileA x fileB comparison between
// two projects' pre-shingled source and persists any match at or above
// originalityMatchThreshold. O(|filesA| * |filesB|) — bounded on each side by
// ExtractSourceFiles' own maxOriginalityFilesPerProject cap.
func (s *Service) compareOriginalitySourcePair(ctx context.Context, reportID, teamAID string, teamBID *string, a, b originalitySource) error {
	for pathA, setA := range a.Shingles {
		for pathB, setB := range b.Shingles {
			similarity := JaccardSimilarity(setA, setB)
			if similarity < originalityMatchThreshold {
				continue
			}
			matched := IntersectionSize(setA, setB)
			sample := sampleSnippet(a.Files[pathA])
			if err := s.repo.InsertOriginalityMatch(ctx, ProjectOriginalityMatch{
				ReportID: reportID, TeamAID: teamAID, TeamBID: teamBID,
				FilePathA: pathA, FilePathB: pathB, Similarity: similarity,
				MatchedLines: &matched, Sample: &sample,
			}); err != nil {
				return fmt.Errorf("insert originality match: %w", err)
			}
		}
	}
	return nil
}

// sampleSnippet keeps a short preview of a matched file for the instructor
// report UI — not the whole file (some run hundreds of lines), just enough
// to recognize it at a glance.
func sampleSnippet(content string) string {
	const maxLen = 400
	if len(content) <= maxLen {
		return content
	}
	return content[:maxLen]
}
