package workspace

import (
	"context"
	"fmt"
	"hash/fnv"
	"strconv"
	"strings"
	"time"
)

// service_planning.go replaces internal/gitlab's embedded board.json/issues.json
// fixtures (contract-phase2.md "Planning fixtures"): same response shapes the
// frontend already expects (frontend/lib/server/gitlab-planning.ts AeBoard /
// AeIssuesPage), built from the caller's real assigned open work items across
// every workspace they're an active member of. Fields with no Phase 2 data
// source yet (GitLab branch/MR/discussion, per-item checklist steps, comment
// files) are left at their honest empty value rather than invented.

// ─── AeBoard (Eisenhower planning board) ───────────────────────────────────

type AeBoardUser struct {
	Name      string `json:"name"`
	Initial   string `json:"initial"`
	Workspace string `json:"workspace"`
}

type AeTaskChip struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Dot   string `json:"dot"`
}

type AeQuadrant struct {
	Key      string       `json:"key"`
	Title    string       `json:"title"`
	Subtitle string       `json:"subtitle"`
	Tone     string       `json:"tone"`
	Tasks    []AeTaskChip `json:"tasks"`
}

type AeChangeLogEntry struct {
	ID      string `json:"id"`
	Time    string `json:"time"`
	Kind    string `json:"kind"`
	Message string `json:"message"`
	Actor   string `json:"actor"`
}

type AeCountedTab struct {
	Label string `json:"label"`
	Count int    `json:"count,omitempty"`
}

type AePerson struct {
	Name    string `json:"name"`
	Initial string `json:"initial"`
}

type AeStepFile struct {
	Name     string `json:"name"`
	Markdown string `json:"markdown"`
}

type AeSubtask struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Checked  bool   `json:"checked"`
	Meta     string `json:"meta,omitempty"`
	MetaKind string `json:"meta_kind,omitempty"`
}

type AeStep struct {
	ID          string         `json:"id"`
	Title       string         `json:"title"`
	Description string         `json:"description"`
	Estimate    string         `json:"estimate"`
	SubTabs     []AeCountedTab `json:"sub_tabs"`
	Subtasks    []AeSubtask    `json:"subtasks"`
	File        *AeStepFile    `json:"file"`
}

type AeTaskDetail struct {
	ID          string         `json:"id"`
	Title       string         `json:"title"`
	Dot         string         `json:"dot"`
	Status      string         `json:"status"`
	Due         string         `json:"due"`
	Assignee    AePerson       `json:"assignee"`
	Description string         `json:"description"`
	Tabs        []AeCountedTab `json:"tabs"`
	Steps       []AeStep       `json:"steps"`
}

type AeBoard struct {
	User          AeBoardUser        `json:"user"`
	Title         string             `json:"title"`
	Subtitle      string             `json:"subtitle"`
	Quadrants     []AeQuadrant       `json:"quadrants"`
	AIPlaceholder string             `json:"ai_placeholder"`
	AISuggestions []string           `json:"ai_suggestions"`
	ChangeLog     []AeChangeLogEntry `json:"change_log"`
	Task          AeTaskDetail       `json:"task"`
}

// ─── AeIssuesPage (GitLab-style issue list) ────────────────────────────────

type AeIssueLabel struct {
	Text string `json:"text"`
	Tone string `json:"tone"`
}

type AeIssueMeta struct {
	Text string `json:"text"`
	Icon string `json:"icon,omitempty"`
	Tone string `json:"tone,omitempty"`
}

type AeIssueAssignee struct {
	Name    string `json:"name"`
	Handle  string `json:"handle"`
	Initial string `json:"initial"`
	Tone    string `json:"tone"`
}

type AeIssueStepDetail struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Checked  bool   `json:"checked"`
	Note     string `json:"note"`
	NoteIcon string `json:"note_icon"`
}

type AeComment struct {
	ID      string `json:"id"`
	Author  string `json:"author"`
	Initial string `json:"initial"`
	Tone    string `json:"tone"`
	Time    string `json:"time"`
	Body    string `json:"body"`
}

type AeActivity struct {
	ID   string `json:"id"`
	Time string `json:"time"`
	Text string `json:"text"`
}

// AeIssueDetail is currently always nil on every issue — the GitLab branch/MR/
// discussion data it carries doesn't exist until Phase 4's linking lands. The
// type stays defined so that phase only has to fill it in, not invent the shape.
type AeIssueDetail struct {
	Markdown     string              `json:"markdown"`
	Steps        []AeIssueStepDetail `json:"steps"`
	Branch       string              `json:"branch"`
	MergeRequest string              `json:"merge_request"`
	Discussion   []AeComment         `json:"discussion"`
	Activity     []AeActivity        `json:"activity"`
}

type AeIssue struct {
	ID            int              `json:"id"`
	Title         string           `json:"title"`
	Status        string           `json:"status"`
	StatusIcon    string           `json:"status_icon"`
	StatusTitle   string           `json:"status_title"`
	Quadrant      string           `json:"quadrant"`
	Labels        []AeIssueLabel   `json:"labels"`
	Opened        string           `json:"opened"`
	OpenedShort   string           `json:"opened_short"`
	Author        *string          `json:"author"`
	Meta          []AeIssueMeta    `json:"meta"`
	StepsDone     int              `json:"steps_done"`
	StepsTotal    int              `json:"steps_total"`
	ProgressTone  string           `json:"progress_tone"`
	Estimate      string           `json:"estimate"`
	EstimateTitle string           `json:"estimate_title"`
	Comments      int              `json:"comments"`
	Files         int              `json:"files"`
	Assignee      *AeIssueAssignee `json:"assignee"`
	Milestone     string           `json:"milestone"`
	Due           string           `json:"due"`
	Selected      bool             `json:"selected"`
	Detail        *AeIssueDetail   `json:"detail"`
}

type AeIssueTab struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	Count int    `json:"count"`
}

type AeIssueFilterChip struct {
	Key   string `json:"key"`
	Value string `json:"value"`
	Tone  string `json:"tone"`
}

type AeQuickFilter struct {
	Label string `json:"label"`
	Dot   string `json:"dot,omitempty"`
}

type AeIssuesPagination struct {
	From    int      `json:"from"`
	To      int      `json:"to"`
	Total   int      `json:"total"`
	Pages   []string `json:"pages"`
	Current string   `json:"current"`
}

type AeIssuesPage struct {
	OpenCountLabel string              `json:"open_count_label"`
	SyncLabel      string              `json:"sync_label"`
	Tabs           []AeIssueTab        `json:"tabs"`
	Filters        []AeIssueFilterChip `json:"filters"`
	SortOptions    []string            `json:"sort_options"`
	QuickFilters   []AeQuickFilter     `json:"quick_filters"`
	Issues         []AeIssue           `json:"issues"`
	Pagination     AeIssuesPagination  `json:"pagination"`
}

// planningItemLimit caps the cross-project scan — plenty for a personal
// planning view; a heavier paginated version can follow if this is ever
// measured to be too small.
const planningItemLimit = 200

// planningQuadrant buckets an item into one of the board's four fixed
// quadrants (contract-phase2.md): urgent/high priority due within 3 days is
// "do_now"; urgent/high otherwise is "plan" (schedule for later); anything
// else due within 3 days is "park" (delegate); everything remaining is
// "eliminate". Quadrant keys match the ones the original board.json fixture
// used, not the generic Eisenhower labels contract-phase2.md names them by.
func planningQuadrant(priority string, dueAt *time.Time, now time.Time) string {
	urgentHigh := priority == "urgent" || priority == "high"
	dueSoon := dueAt != nil && !dueAt.After(now.AddDate(0, 0, 3))
	switch {
	case urgentHigh && dueSoon:
		return "do_now"
	case urgentHigh:
		return "plan"
	case dueSoon:
		return "park"
	default:
		return "eliminate"
	}
}

func priorityDot(priority string) string {
	switch priority {
	case "urgent":
		return "rose"
	case "high":
		return "amber"
	case "low":
		return "slate"
	default:
		return "blue"
	}
}

func priorityTone(priority string) string {
	switch priority {
	case "urgent":
		return "error"
	case "high":
		return "primary"
	case "low":
		return "muted"
	default:
		return "secondary"
	}
}

func humanizeStatus(status string) string {
	parts := strings.Split(status, "_")
	for i, p := range parts {
		if p == "" {
			continue
		}
		parts[i] = strings.ToUpper(p[:1]) + p[1:]
	}
	return strings.Join(parts, " ")
}

func initialOf(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "?"
	}
	return strings.ToUpper(string([]rune(name)[0]))
}

func toHandle(name string) string {
	h := strings.ToLower(strings.Join(strings.Fields(name), ""))
	if h == "" {
		return ""
	}
	return "@" + h
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

func agoLong(d time.Duration) string {
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		n := int(d.Minutes())
		return fmt.Sprintf("%d minute%s ago", n, plural(n))
	case d < 24*time.Hour:
		n := int(d.Hours())
		return fmt.Sprintf("%d hour%s ago", n, plural(n))
	case d < 7*24*time.Hour:
		n := int(d.Hours() / 24)
		return fmt.Sprintf("%d day%s ago", n, plural(n))
	default:
		n := int(d.Hours() / 24 / 7)
		return fmt.Sprintf("%d week%s ago", n, plural(n))
	}
}

func agoShort(d time.Duration) string {
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		return fmt.Sprintf("%dm ago", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh ago", int(d.Hours()))
	case d < 7*24*time.Hour:
		return fmt.Sprintf("%dd ago", int(d.Hours()/24))
	default:
		return fmt.Sprintf("%dw ago", int(d.Hours()/24/7))
	}
}

func formatMinutes(m int) string {
	if m < 60 {
		return fmt.Sprintf("%dm", m)
	}
	h, rem := m/60, m%60
	if rem == 0 {
		return fmt.Sprintf("%dh", h)
	}
	return fmt.Sprintf("%dh%dm", h, rem)
}

// stableIntID derives a small stable int from an item's uuid — AeIssue.ID's
// GitLab-style numeric id has no real backing before Phase 4 links items to
// GitLab issues, so this stands in as a collision-resistant placeholder
// rather than the project-local key_num (which can repeat across projects).
func stableIntID(id string) int {
	h := fnv.New32a()
	_, _ = h.Write([]byte(id))
	return int(h.Sum32() & 0x7fffffff)
}

func eventLogKind(kind string) string {
	switch kind {
	case EventCreate:
		return "added"
	case EventStatus, EventParent:
		return "moved"
	default:
		return "updated"
	}
}

func eventLogMessage(ev ItemEvent) string {
	switch ev.Kind {
	case EventCreate:
		return "Item created"
	case EventStatus:
		if ev.ToValue != nil {
			return "Moved to " + humanizeStatus(*ev.ToValue)
		}
		return "Status changed"
	case EventParent:
		return "Moved to a new parent"
	case EventAssign:
		return "Assignee added"
	case EventUnassign:
		return "Assignee removed"
	case EventField:
		if ev.Field != nil {
			return "Updated " + *ev.Field
		}
		return "Item updated"
	case EventLink:
		return "Linked to another item"
	case EventUnlink:
		return "Link removed"
	case EventArchive:
		return "Archived"
	default:
		return "Item updated"
	}
}

// BuildPlanningBoard assembles GET /api/gitlab/planning/board from userID's
// real assigned open work items.
func (s *Service) BuildPlanningBoard(ctx context.Context, userID string) (*AeBoard, error) {
	userName, err := s.repo.GetUserName(ctx, s.pool, userID)
	if err != nil {
		return nil, err
	}
	items, err := s.repo.ListAssignedOpenItems(ctx, s.pool, userID, planningItemLimit)
	if err != nil {
		return nil, err
	}
	now := s.now()

	quadrantOrder := []string{"plan", "do_now", "park", "eliminate"}
	titles := map[string][2]string{
		"plan":      {"Plan / Delegate", "Important but can wait"},
		"do_now":    {"Do it Now", "Important and urgent"},
		"park":      {"Park it", "Unimportant and can wait"},
		"eliminate": {"Eliminate / Ignore", "Unimportant and not urgent"},
	}
	tones := map[string]string{"plan": "blue", "do_now": "emerald", "park": "purple", "eliminate": "rose"}
	byQuadrant := map[string][]AeTaskChip{"plan": {}, "do_now": {}, "park": {}, "eliminate": {}}

	itemIDs := make([]string, 0, len(items))
	workspaceTitle := ""
	for _, it := range items {
		q := planningQuadrant(it.Priority, it.DueAt, now)
		byQuadrant[q] = append(byQuadrant[q], AeTaskChip{ID: it.Key, Title: it.Title, Dot: priorityDot(it.Priority)})
		itemIDs = append(itemIDs, it.ID)
		switch {
		case workspaceTitle == "":
			workspaceTitle = it.ProjectTitle
		case workspaceTitle != it.ProjectTitle:
			workspaceTitle = "All workspaces"
		}
	}
	if workspaceTitle == "" {
		workspaceTitle = "No active workspace"
	}

	quadrants := make([]AeQuadrant, 0, len(quadrantOrder))
	for _, key := range quadrantOrder {
		quadrants = append(quadrants, AeQuadrant{
			Key: key, Title: titles[key][0], Subtitle: titles[key][1], Tone: tones[key], Tasks: byQuadrant[key],
		})
	}

	recentEvents, err := s.repo.ListRecentEventsForItems(ctx, s.pool, itemIDs, 5)
	if err != nil {
		return nil, err
	}
	changeLog := make([]AeChangeLogEntry, 0, len(recentEvents))
	for _, ev := range recentEvents {
		changeLog = append(changeLog, AeChangeLogEntry{
			ID: strconv.FormatInt(ev.ID, 10), Time: ev.CreatedAt.Format("3:04 PM"),
			Kind: eventLogKind(ev.Kind), Message: eventLogMessage(ev), Actor: ev.ActorName,
		})
	}

	task := AeTaskDetail{
		Dot: "slate", Status: "—", Due: "—", Assignee: AePerson{Name: userName, Initial: initialOf(userName)},
		Description: "Nothing assigned to you right now.", Tabs: []AeCountedTab{}, Steps: []AeStep{},
	}
	if len(items) > 0 {
		it := items[0]
		logs, err := s.repo.CountItemEvents(ctx, s.pool, it.ID)
		if err != nil {
			return nil, err
		}
		due := "—"
		if it.DueAt != nil {
			due = it.DueAt.Format("Jan 2, 2006")
		}
		desc := ""
		if it.Description != nil {
			desc = *it.Description
		}
		task = AeTaskDetail{
			ID: it.Key, Title: it.Title, Dot: priorityDot(it.Priority), Status: humanizeStatus(it.Status), Due: due,
			Assignee: AePerson{Name: userName, Initial: initialOf(userName)}, Description: desc,
			Tabs: []AeCountedTab{
				{Label: "Steps"}, {Label: "Details"}, {Label: "Files"}, {Label: "Notes (MD)"}, {Label: "Logs", Count: logs},
			},
			Steps: []AeStep{},
		}
	}

	return &AeBoard{
		User:          AeBoardUser{Name: userName, Initial: initialOf(userName), Workspace: workspaceTitle},
		Title:         "Planning Board",
		Subtitle:      "Your assigned work across every workspace",
		Quadrants:     quadrants,
		AIPlaceholder: "Ask AI to break this down, draft a plan, or summarize progress...",
		AISuggestions: []string{"Break into sub-steps", "Summarize this item", "Suggest next step"},
		ChangeLog:     changeLog,
		Task:          task,
	}, nil
}

// BuildPlanningIssues assembles GET /api/gitlab/planning/issues from userID's
// real assigned open work items.
func (s *Service) BuildPlanningIssues(ctx context.Context, userID string) (*AeIssuesPage, error) {
	items, err := s.repo.ListAssignedOpenItems(ctx, s.pool, userID, planningItemLimit)
	if err != nil {
		return nil, err
	}
	now := s.now()

	itemIDs := make([]string, len(items))
	for i, it := range items {
		itemIDs[i] = it.ID
	}
	commentCounts, err := s.repo.CountCommentsByItem(ctx, s.pool, itemIDs)
	if err != nil {
		return nil, err
	}

	issues := make([]AeIssue, 0, len(items))
	openCount, inProgressCount := 0, 0
	for i, it := range items {
		var statusIcon string
		switch it.Status {
		case ItemBlocked:
			statusIcon = "critical"
		case ItemInProgress, ItemInReview, ItemTesting, ItemReopened:
			statusIcon, inProgressCount = "in_progress", inProgressCount+1
		default:
			openCount++
			if it.Priority == "urgent" {
				statusIcon = "urgent"
			} else {
				statusIcon = "open"
			}
		}

		labels := []AeIssueLabel{
			{Text: "~" + it.Priority, Tone: priorityTone(it.Priority)},
			{Text: "~" + it.Type, Tone: "neutral"},
		}
		if it.Severity != nil {
			labels = append(labels, AeIssueLabel{Text: "~" + *it.Severity, Tone: "error"})
		}

		due := "—"
		if it.DueAt != nil {
			due = it.DueAt.Format("Jan 2, 2006")
		}
		estimate, estimateTitle := "—", ""
		if it.EstimateMinutes != nil {
			estimate = formatMinutes(*it.EstimateMinutes)
			estimateTitle = "Estimated " + estimate
		}

		var assignee *AeIssueAssignee
		if it.OwnerName != nil {
			assignee = &AeIssueAssignee{Name: *it.OwnerName, Handle: toHandle(*it.OwnerName), Initial: initialOf(*it.OwnerName), Tone: "primary"}
		}
		var author *string
		if it.CreatedByName != nil {
			h := toHandle(*it.CreatedByName)
			author = &h
		}

		status := humanizeStatus(it.Status)
		issues = append(issues, AeIssue{
			ID: stableIntID(it.ID), Title: it.Title, Status: status, StatusIcon: statusIcon, StatusTitle: status,
			Quadrant: planningQuadrant(it.Priority, it.DueAt, now), Labels: labels,
			Opened: "opened " + agoLong(now.Sub(it.CreatedAt)), OpenedShort: "opened " + agoShort(now.Sub(it.CreatedAt)),
			Author: author, Meta: []AeIssueMeta{{Text: "updated " + agoShort(now.Sub(it.UpdatedAt))}},
			StepsDone: 0, StepsTotal: 0, ProgressTone: "outline",
			Estimate: estimate, EstimateTitle: estimateTitle, Comments: commentCounts[it.ID], Files: 0,
			Assignee: assignee, Milestone: "—", Due: due, Selected: i == 0, Detail: nil,
		})
	}

	from := 0
	if len(issues) > 0 {
		from = 1
	}
	return &AeIssuesPage{
		OpenCountLabel: fmt.Sprintf("%d open issues", len(issues)),
		SyncLabel:      "Live from your workspaces",
		Tabs: []AeIssueTab{
			{Key: "open", Label: "Open", Count: openCount},
			{Key: "in_progress", Label: "In Progress", Count: inProgressCount},
			{Key: "done", Label: "Merged / Done", Count: 0},
			{Key: "all", Label: "All", Count: len(issues)},
		},
		Filters: []AeIssueFilterChip{},
		SortOptions: []string{
			"Updated date (newest first)", "Created date (newest first)",
			"Weight / Priority (highest)", "Due date (soonest)",
		},
		QuickFilters: []AeQuickFilter{
			{Label: "Author"}, {Label: "Assignee"}, {Label: "Milestone"},
			{Label: "Quadrant / Priority", Dot: "error"}, {Label: "Label"}, {Label: "Weight / Est"},
		},
		Issues:     issues,
		Pagination: AeIssuesPagination{From: from, To: len(issues), Total: len(issues), Pages: []string{"1"}, Current: "1"},
	}, nil
}
