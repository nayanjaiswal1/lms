package workspace

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/jobs"
)

// service_ai_suggest.go — Phase 5 (contract-phase5.md 5c): the six new AI
// suggestion methods plus the weekly-summary job. Every method (SuggestAssignees
// excepted, D20) follows service_requirement.go's RequirementGaps convention
// exactly: cache-before-call in workspace_ai_cache, delimited untrusted
// inputs, JSON mode, and a per-project AIPerProjectDay cap. Results are
// suggest-only prose/data — nothing here writes a work item, assignee, or
// spec change on its own.

// jobWorkspaceAIWeeklySummaryProject must stay in sync with
// handlers.HandlerWorkspaceAIWeeklySummaryProject (internal/jobs/handlers/
// constants.go) — a plain string literal for the same reason
// jobWorkspaceGitlabSync is (service_gitlab.go): internal/jobs/handlers
// imports this package, so this package can't import handlers back.
const jobWorkspaceAIWeeklySummaryProject = "workspace.ai_weekly_summary_project"

// isoWeek formats t as the AI cache/idempotency key convention this file
// uses for weekly data: "2026-W39".
func isoWeek(t time.Time) string {
	y, w := t.ISOWeek()
	return fmt.Sprintf("%04d-W%02d", y, w)
}

// suggestItems runs the shared cache/rate-limit/complete/parse pipeline every
// "type": "epic"|"feature"|"task" suggestion endpoint uses (SuggestEpics,
// SuggestTaskBreakdown) — RequirementGaps' own convention, factored out since
// only the prompt/cache-key differ between the two callers.
func (s *Service) suggestItems(ctx context.Context, pc *ProjectCtx, kind, cacheKey, systemPrompt, userPrompt, auditAction string) (*ItemSuggestions, error) {
	var cached ItemSuggestions
	if found, err := s.repo.GetAICache(ctx, s.pool, pc.ProjectID, kind, cacheKey, &cached); err != nil {
		return nil, err
	} else if found {
		return &cached, nil
	}
	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:ai:"+pc.ProjectID, s.cfg.Workspace.AIPerProjectDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: systemPrompt, UserPrompt: userPrompt, MaxTokens: 900, Temperature: 0.3, JSONMode: true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: %s: %w", kind, err)
	}
	var raw struct {
		Items []SuggestedItem `json:"items"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &raw); err != nil {
		return nil, fmt.Errorf("workspace: %s: parse response: %w", kind, err)
	}
	if raw.Items == nil {
		raw.Items = []SuggestedItem{}
	}
	result := ItemSuggestions{Items: raw.Items, CachedAt: s.now()}
	if err := s.repo.SetAICache(ctx, s.pool, pc.ProjectID, kind, cacheKey, result); err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, auditAction, "workspace_project", pc.ProjectID, nil)
	return &result, nil
}

// SuggestEpics is POST …/ai/epics (manager+, StatusesPlanning): once the
// brief is agreed, a first pass at epic/feature breakdown from the
// requirement text and its answered questions.
func (s *Service) SuggestEpics(ctx context.Context, pc *ProjectCtx) (*ItemSuggestions, error) {
	if !RoleAtLeast(pc.Role, RoleManager) {
		return nil, ErrForbidden
	}
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	if project.BriefStatus != BriefAgreed {
		return nil, ErrBriefNotAgreed
	}

	wikiVersion := 0
	if project.BriefWikiPageID != nil {
		_, _, v, err := s.repo.GetWikiPageInfo(ctx, s.pool, *project.BriefWikiPageID)
		if err != nil {
			return nil, err
		}
		wikiVersion = v
	}
	cacheKey := fmt.Sprintf("brief:req%d:wiki%d", project.RequirementVersion, wikiVersion)

	answered, err := s.repo.ListAnsweredQuestions(ctx, s.pool, pc.ProjectID, project.RequirementVersion)
	if err != nil {
		return nil, err
	}
	var b strings.Builder
	fmt.Fprintf(&b, "Requirement: %s\n", delimited(project.Requirement))
	if len(answered) > 0 {
		b.WriteString("\nAnswered questions:\n")
		for _, q := range answered {
			ans := ""
			if q.Answer != nil {
				ans = *q.Answer
			}
			fmt.Fprintf(&b, "- Q: %s\n  A: %s\n", delimited(q.Question), delimited(ans))
		}
	}

	return s.suggestItems(ctx, pc, "epic_suggestions", cacheKey, ai.WorkspaceEpicSuggestSystemPrompt, b.String(), "workspace_ai.epics_suggested")
}

// SuggestTaskBreakdown is POST …/items/{itemID}/ai/breakdown (route min
// member; service: manager+ or the feature's own track lead), only once the
// feature's spec doc is approved.
func (s *Service) SuggestTaskBreakdown(ctx context.Context, pc *ProjectCtx, featureID string) (*ItemSuggestions, error) {
	feature, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, featureID)
	if err != nil {
		return nil, err
	}
	if feature.Type != ItemTypeFeature {
		return nil, fmt.Errorf("%w: not a feature", ErrInvalidInput)
	}
	if !RoleAtLeast(pc.Role, RoleManager) {
		lead := false
		if feature.TrackID != nil {
			lead, err = s.repo.IsTrackLead(ctx, s.pool, pc.ProjectID, *feature.TrackID, pc.UserID)
			if err != nil {
				return nil, err
			}
		}
		if !lead {
			return nil, ErrForbidden
		}
	}
	if feature.DocStatus == nil || *feature.DocStatus != DocApproved || feature.DocWikiPageID == nil {
		return nil, ErrDocNotApproved
	}

	_, docText, docVersion, err := s.repo.GetWikiPageText(ctx, s.pool, *feature.DocWikiPageID)
	if err != nil {
		return nil, err
	}
	cacheKey := fmt.Sprintf("item:%s:doc%d", featureID, docVersion)

	var b strings.Builder
	fmt.Fprintf(&b, "Feature: %s\n\nSpecification:\n%s\n", delimited(feature.Title), delimited(docText))

	return s.suggestItems(ctx, pc, "task_breakdown", cacheKey, ai.WorkspaceTaskBreakdownSystemPrompt, b.String(), "workspace_ai.breakdown_suggested")
}

// SuggestAssignees is POST …/items/{itemID}/ai/assignees (route min member;
// service: manager+ or the item's track lead). Deliberately not cached
// (D20): live WIP changes constantly, and this is per-user rate limited
// instead (AssigneeSuggestPerMinute), never per-project.
func (s *Service) SuggestAssignees(ctx context.Context, pc *ProjectCtx, itemID string) ([]AssigneeSuggestion, error) {
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	if !RoleAtLeast(pc.Role, RoleManager) {
		lead := false
		if item.TrackID != nil {
			lead, err = s.repo.IsTrackLead(ctx, s.pool, pc.ProjectID, *item.TrackID, pc.UserID)
			if err != nil {
				return nil, err
			}
		}
		if !lead {
			return nil, ErrForbidden
		}
	}
	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, fmt.Sprintf("rl:pw:assignee:%s:%s", pc.UserID, itemID), s.cfg.Workspace.AssigneeSuggestPerMinute, time.Minute); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	candidates, err := s.repo.ListAssigneeCandidates(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	if len(candidates) == 0 {
		return []AssigneeSuggestion{}, nil
	}
	trackName := ""
	if item.TrackID != nil {
		if track, err := s.repo.GetTrack(ctx, s.pool, pc.ProjectID, *item.TrackID); err == nil {
			trackName = track.Name
		}
	}

	firstNames := make(map[string]*AssigneeCandidate, len(candidates))
	var b strings.Builder
	fmt.Fprintf(&b, "Item: %s\n", delimited(item.Title))
	if item.Description != nil {
		fmt.Fprintf(&b, "Description: %s\n", delimited(*item.Description))
	}
	fmt.Fprintf(&b, "Track: %s\n\nCandidates:\n", delimited(trackName))
	for i := range candidates {
		c := &candidates[i]
		first := strings.TrimSpace(strings.SplitN(c.Person.Name, " ", 2)[0])
		if first == "" {
			first = c.Person.Name
		}
		firstNames[strings.ToLower(first)] = c
		fmt.Fprintf(&b, "- Name: %s, Skills: %s, Current WIP: %d\n", delimited(first), delimited(strings.Join(c.Skills, ", ")), c.WIP)
	}

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.WorkspaceAssigneeSuggestSystemPrompt, UserPrompt: b.String(), MaxTokens: 500, Temperature: 0.2, JSONMode: true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: suggest assignees: %w", err)
	}
	var parsed struct {
		Suggestions []struct {
			Name   string `json:"name"`
			Reason string `json:"reason"`
		} `json:"suggestions"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("workspace: suggest assignees: parse response: %w", err)
	}

	out := make([]AssigneeSuggestion, 0, len(parsed.Suggestions))
	used := map[string]bool{}
	for _, sug := range parsed.Suggestions {
		key := strings.ToLower(strings.TrimSpace(stripRankDelimiter(sug.Name)))
		c, ok := firstNames[key]
		if !ok || used[c.Person.UserID] {
			continue
		}
		used[c.Person.UserID] = true
		out = append(out, AssigneeSuggestion{Person: c.Person, WIP: c.WIP, Reason: sug.Reason})
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_ai.assignees_suggested", "work_item", itemID, nil)
	return out, nil
}

// ExplainLate is POST …/items/{itemID}/ai/why-late (manager+, no status
// gate): a plain-language explanation of why a feature is running late, from
// its own event history — cached per calendar day.
func (s *Service) ExplainLate(ctx context.Context, pc *ProjectCtx, featureID string) (*LateExplanation, error) {
	if !RoleAtLeast(pc.Role, RoleManager) {
		return nil, ErrForbidden
	}
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, featureID)
	if err != nil {
		return nil, err
	}
	cacheKey := fmt.Sprintf("item:%s:%s", featureID, s.now().Format("2006-01-02"))

	var cached LateExplanation
	if found, err := s.repo.GetAICache(ctx, s.pool, pc.ProjectID, "late_explanation", cacheKey, &cached); err != nil {
		return nil, err
	} else if found {
		return &cached, nil
	}
	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:ai:"+pc.ProjectID, s.cfg.Workspace.AIPerProjectDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	events, err := s.repo.ListItemEvents(ctx, s.pool, pc.ProjectID, featureID, 0, 100)
	if err != nil {
		return nil, err
	}

	var b strings.Builder
	fmt.Fprintf(&b, "Feature: %s\n", delimited(item.Title))
	if item.DueAt != nil {
		fmt.Fprintf(&b, "Due: %s\n", item.DueAt.Format("2006-01-02"))
	}
	b.WriteString("\nEvent history (oldest first):\n")
	for i := len(events) - 1; i >= 0; i-- {
		e := events[i]
		reason := ""
		if e.Reason != nil {
			reason = *e.Reason
		}
		fmt.Fprintf(&b, "- %s: %s%s\n", e.Kind, delimited(valueOrEmpty(e.ToValue)), optionalReason(reason))
	}

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.WorkspaceExplainLateSystemPrompt, UserPrompt: b.String(), MaxTokens: 400, Temperature: 0.3, JSONMode: true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: explain late: %w", err)
	}
	var parsed LateExplanation
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("workspace: explain late: parse response: %w", err)
	}
	parsed.CachedAt = s.now()
	if err := s.repo.SetAICache(ctx, s.pool, pc.ProjectID, "late_explanation", cacheKey, parsed); err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_ai.explain_late", "work_item", featureID, nil)
	return &parsed, nil
}

func valueOrEmpty(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func optionalReason(reason string) string {
	if reason == "" {
		return ""
	}
	return " (" + reason + ")"
}

// ChangeImpact is POST …/items/{itemID}/ai/change-impact (manager+,
// StatusesDiscuss): which linked/related items are likely affected by a
// change to this feature's spec.
func (s *Service) ChangeImpact(ctx context.Context, pc *ProjectCtx, featureID string) (*ChangeImpact, error) {
	if !RoleAtLeast(pc.Role, RoleManager) {
		return nil, ErrForbidden
	}
	feature, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, featureID)
	if err != nil {
		return nil, err
	}
	if feature.DocWikiPageID == nil {
		return nil, fmt.Errorf("%w: this feature has no spec page", ErrInvalidState)
	}
	_, docText, docVersion, err := s.repo.GetWikiPageText(ctx, s.pool, *feature.DocWikiPageID)
	if err != nil {
		return nil, err
	}
	cacheKey := fmt.Sprintf("item:%s:doc%d", featureID, docVersion)

	var cached ChangeImpact
	if found, err := s.repo.GetAICache(ctx, s.pool, pc.ProjectID, "change_impact", cacheKey, &cached); err != nil {
		return nil, err
	} else if found {
		return &cached, nil
	}
	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:ai:"+pc.ProjectID, s.cfg.Workspace.AIPerProjectDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	links, err := s.repo.ListItemLinks(ctx, s.pool, pc.ProjectID, featureID)
	if err != nil {
		return nil, err
	}

	var b strings.Builder
	fmt.Fprintf(&b, "Feature: %s\n\nSpecification:\n%s\n\nRelated items:\n", delimited(feature.Title), delimited(docText))
	for _, l := range links {
		fmt.Fprintf(&b, "- [%s/%s] %s (%s)\n", l.Kind, l.Direction, delimited(l.Other.Title), l.Other.Type)
	}

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.WorkspaceChangeImpactSystemPrompt, UserPrompt: b.String(), MaxTokens: 500, Temperature: 0.3, JSONMode: true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: change impact: %w", err)
	}
	var parsed struct {
		AffectedTitles []string `json:"affected_titles"`
		Summary        string   `json:"summary"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("workspace: change impact: parse response: %w", err)
	}

	result := ChangeImpact{Summary: parsed.Summary, AffectedItemIDs: []string{}, CachedAt: s.now()}
	for _, title := range parsed.AffectedTitles {
		norm := strings.TrimSpace(stripRankDelimiter(title))
		for _, l := range links {
			if l.Other.Title == norm {
				result.AffectedItemIDs = append(result.AffectedItemIDs, l.Other.ID)
				break
			}
		}
	}
	if err := s.repo.SetAICache(ctx, s.pool, pc.ProjectID, "change_impact", cacheKey, result); err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_ai.change_impact", "work_item", featureID, nil)
	return &result, nil
}

// WeeklySummary is POST …/ai/weekly-summary?regenerate= (manager+, no status
// gate): cached per ISO week, regeneration capped at SummaryRegenPerDay/day.
func (s *Service) WeeklySummary(ctx context.Context, pc *ProjectCtx, regenerate bool) (*WeeklySummary, error) {
	if !RoleAtLeast(pc.Role, RoleManager) {
		return nil, ErrForbidden
	}
	week := isoWeek(s.now())
	if !regenerate {
		var cached WeeklySummary
		if found, err := s.repo.GetAICache(ctx, s.pool, pc.ProjectID, "weekly_summary", week, &cached); err != nil {
			return nil, err
		} else if found {
			return &cached, nil
		}
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:summary:"+pc.ProjectID, s.cfg.Workspace.SummaryRegenPerDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}
	actor := pc.UserID
	return s.computeWeeklySummary(ctx, pc.ProjectID, pc.OrgID, &actor, week, regenerate)
}

// computeWeeklySummary is the one real AI call WeeklySummary and the
// per-project cron job (ComputeWeeklySummaryForJob) both make.
// forceOverwrite is only ever true for an explicit manager regenerate — the
// scheduled job always leaves an already-cached week alone.
func (s *Service) computeWeeklySummary(ctx context.Context, projectID, orgID string, actorID *string, week string, forceOverwrite bool) (*WeeklySummary, error) {
	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	now := s.now()
	since := now.AddDate(0, 0, -7)

	shipped, err := s.repo.ListDoneItemTitles(ctx, s.pool, projectID, since)
	if err != nil {
		return nil, err
	}
	blocked, err := s.repo.ListBlockedItems(ctx, s.pool, projectID)
	if err != nil {
		return nil, err
	}
	openBugs, err := s.repo.ListOpenS1S2Bugs(ctx, s.pool, projectID)
	if err != nil {
		return nil, err
	}
	overdue, err := s.repo.ListOverdueItems(ctx, s.pool, projectID, now)
	if err != nil {
		return nil, err
	}
	staleReviews, err := s.repo.ListStaleReviewItems(ctx, s.pool, projectID, now.Add(-DocReviewReminderAfter))
	if err != nil {
		return nil, err
	}

	var b strings.Builder
	b.WriteString("Shipped this week:\n")
	for _, t := range shipped {
		fmt.Fprintf(&b, "- %s\n", delimited(t))
	}
	writeAttention := func(label string, items []AttentionItem) {
		if len(items) == 0 {
			return
		}
		fmt.Fprintf(&b, "\n%s:\n", label)
		for _, it := range items {
			fmt.Fprintf(&b, "- [%s] %s: %s\n", it.Item.Type, delimited(it.Item.Title), delimited(it.Detail))
		}
	}
	writeAttention("Currently blocked", blocked)
	writeAttention("Open S1/S2 bugs", openBugs)
	writeAttention("Overdue", overdue)
	writeAttention("Spec reviews waiting", staleReviews)

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.WorkspaceWeeklySummarySystemPrompt, UserPrompt: b.String(), MaxTokens: 700, Temperature: 0.3, JSONMode: true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: weekly summary: %w", err)
	}
	var parsed WeeklySummary
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("workspace: weekly summary: parse response: %w", err)
	}
	if parsed.Shipped == nil {
		parsed.Shipped = []string{}
	}
	if parsed.Risks == nil {
		parsed.Risks = []string{}
	}
	if parsed.NeedsHelp == nil {
		parsed.NeedsHelp = []string{}
	}
	parsed.Week = week
	parsed.CreatedAt = now

	if forceOverwrite {
		err = s.repo.SetAICacheForce(ctx, s.pool, projectID, "weekly_summary", week, parsed)
	} else {
		err = s.repo.SetAICache(ctx, s.pool, projectID, "weekly_summary", week, parsed)
	}
	if err != nil {
		return nil, err
	}
	if actorID != nil {
		writeAudit(ctx, s.pool, orgID, actorID, "workspace_ai.weekly_summary_generated", "workspace_project", projectID, nil)
	}
	return &parsed, nil
}

// ComputeWeeklySummaryForJob is the workspace.ai_weekly_summary_project job
// body: skip silently if this project's week is already cached (a manager
// may have already regenerated it), otherwise spend the one AI call.
func (s *Service) ComputeWeeklySummaryForJob(ctx context.Context, projectID string) error {
	orgID, err := s.repo.GetProjectOrgID(ctx, s.pool, projectID)
	if err != nil {
		return err
	}
	week := isoWeek(s.now())
	var cached WeeklySummary
	if found, err := s.repo.GetAICache(ctx, s.pool, projectID, "weekly_summary", week, &cached); err != nil {
		return err
	} else if found {
		return nil
	}
	_, err = s.computeWeeklySummary(ctx, projectID, orgID, nil, week, false)
	return err
}

// RunWeeklySummaries is the workspace.ai_weekly_summary Monday-06:00 cron
// job's own body: fan out one workspace.ai_weekly_summary_project job per
// active project, idempotency-keyed on project+ISO week so a redelivered or
// re-run cron tick never double-enqueues the same project's same week (the
// same fan-out shape digest.nightly/digest.user use).
func (s *Service) RunWeeklySummaries(ctx context.Context) (int, error) {
	projectIDs, err := s.repo.ListActiveProjectIDs(ctx)
	if err != nil {
		return 0, err
	}
	week := isoWeek(s.now())
	enqueued := 0
	for _, projectID := range projectIDs {
		idemKey := fmt.Sprintf("workspace_ai_weekly_summary:%s:%s", projectID, week)
		timeout := 60000
		_, err := jobs.Enqueue(ctx, s.pool, s.jobs, jobs.EnqueueParams{
			Handler:        jobWorkspaceAIWeeklySummaryProject,
			Priority:       jobs.PriorityBackground,
			Payload:        map[string]string{"project_id": projectID},
			IdempotencyKey: &idemKey,
			TimeoutMS:      &timeout,
		})
		if err != nil {
			if errors.Is(err, jobs.ErrDuplicateKey) {
				continue
			}
			slog.ErrorContext(ctx, "workspace: run weekly summaries: enqueue", "project_id", projectID, "error", err)
			continue
		}
		enqueued++
	}
	return enqueued, nil
}
