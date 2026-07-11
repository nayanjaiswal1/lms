package whatnow

import (
	"context"
	"errors"
	"fmt"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

const (
	planCap     = 3
	pinDuration = 4 * time.Hour
)

// Service holds the deterministic What Now? business logic — a direct port
// of frontend/lib/whatnow/store.ts. No AI calls: parsing is regex, scoring is
// a fixed table, and breakdown/stuck resolutions are canned templates.
type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

var (
	weekdays  = []string{"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
	vagueRe   = regexp.MustCompile(`(?i)\b(figure out|look into|think about|research|explore|someday|maybe|eventually|sort out|deal with)\b`)
	durationRe = regexp.MustCompile(`(?i)\b(\d+(?:\.\d+)?)\s*(h|hr|hrs|hours?|m|min|mins|minutes?)\b`)
	deadlineRe = regexp.MustCompile(`(?i)\b(?:by\s+)?(today|tonight|tomorrow|sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b`)
	categoryRe = regexp.MustCompile(`#([\w-]+)`)
	hourUnitRe = regexp.MustCompile(`(?i)^h`)
	multiSpaceRe    = regexp.MustCompile(`\s{2,}`)
	trailingPunctRe = regexp.MustCompile(`[,;]\s*$`)
)

func isoDate(t time.Time) string { return t.Format("2006-01-02") }

func nextWeekday(name string, from time.Time) time.Time {
	target := -1
	for i, w := range weekdays {
		if w == name {
			target = i
			break
		}
	}
	delta := (target - int(from.Weekday()) + 7) % 7
	if delta == 0 {
		delta = 7
	}
	return from.AddDate(0, 0, delta)
}

func deadlineLabel(deadline string, now time.Time) string {
	d, err := time.Parse("2006-01-02", deadline)
	if err != nil {
		return deadline
	}
	days := math.Round(d.Sub(now).Hours() / 24)
	if days <= 0 {
		return "today"
	}
	if days == 1 {
		return "tomorrow"
	}
	return d.Format("Mon")
}

// ParsedCapture is parseCapture's return shape in store.ts (everything but
// id/status/createdAt, which the repo assigns on insert).
type ParsedCapture struct {
	Title       string
	Chips       []Chip
	DurationMin *int
	Deadline    string
	Category    string
	Vague       bool
}

// ParseCapture extracts duration, deadline, and #category from raw capture
// text and flags vague phrasing — same 3 regexes and vague-phrase list as
// store.ts's parseCapture, applied in the same order (duration, deadline,
// category) so overlapping matches behave identically.
func ParseCapture(raw string) ParsedCapture {
	now := time.Now()
	title := strings.TrimSpace(raw)
	var durationMin *int
	var deadline, category string

	if m := durationRe.FindStringSubmatch(title); m != nil {
		n, _ := strconv.ParseFloat(m[1], 64)
		var mins int
		if hourUnitRe.MatchString(m[2]) {
			mins = int(math.Round(n * 60))
		} else {
			mins = int(math.Round(n))
		}
		durationMin = &mins
		title = strings.TrimSpace(strings.Replace(title, m[0], "", 1))
	}

	if m := deadlineRe.FindStringSubmatch(title); m != nil {
		word := strings.ToLower(m[1])
		switch word {
		case "today", "tonight":
			deadline = isoDate(now)
		case "tomorrow":
			deadline = isoDate(now.Add(24 * time.Hour))
		default:
			deadline = isoDate(nextWeekday(word, now))
		}
		title = strings.TrimSpace(strings.Replace(title, m[0], "", 1))
	}

	if m := categoryRe.FindStringSubmatch(title); m != nil {
		category = m[1]
		title = strings.TrimSpace(strings.Replace(title, m[0], "", 1))
	}

	title = multiSpaceRe.ReplaceAllString(title, " ")
	title = trailingPunctRe.ReplaceAllString(title, "")
	title = strings.TrimSpace(title)

	vague := vagueRe.MatchString(title) || len(strings.Fields(title)) <= 2

	var chips []Chip
	if deadline != "" {
		chips = append(chips, Chip{ID: uuid.NewString(), Kind: ChipDeadline, Label: deadlineLabel(deadline, now), Value: deadline})
	}
	if durationMin != nil {
		chips = append(chips, Chip{ID: uuid.NewString(), Kind: ChipDuration, Label: fmt.Sprintf("%dm", *durationMin), Value: strconv.Itoa(*durationMin)})
	}
	if category != "" {
		chips = append(chips, Chip{ID: uuid.NewString(), Kind: ChipCategory, Label: "#" + category})
	}
	if vague {
		chips = append(chips, Chip{ID: uuid.NewString(), Kind: ChipVague, Label: "vague"})
	}

	return ParsedCapture{Title: title, Chips: chips, DurationMin: durationMin, Deadline: deadline, Category: category, Vague: vague}
}

type scoredTask struct {
	task  Task
	score int
	why   []string
}

// scoreCandidates mirrors store.ts's pickNow scoring table exactly: paused
// resumable tasks, deadline proximity, planned bonus, and energy-dependent
// sharp/tired adjustments.
func scoreCandidates(candidates []Task, energy Energy, now time.Time) []scoredTask {
	out := make([]scoredTask, 0, len(candidates))
	for _, t := range candidates {
		score := 0
		var why []string

		if t.Status == StatusPaused && t.ResumeNote != "" {
			score += 30
			why = append(why, "you already started it — finishing beats starting")
		}
		if t.Deadline != "" {
			if d, err := time.Parse("2006-01-02", t.Deadline); err == nil {
				days := math.Round(d.Sub(now).Hours() / 24)
				switch {
				case days <= 1:
					score += 40
					why = append(why, "its deadline is right on top of you")
				case days <= 3:
					score += 25
					why = append(why, "the deadline is close")
				case days <= 7:
					score += 10
					why = append(why, "the deadline is this week")
				}
			}
		}
		if t.Status == StatusPlanned {
			score += 15
			why = append(why, "you chose it for today")
		}
		if energy == EnergySharp {
			if !t.Vague && (t.DurationMin == nil || *t.DurationMin >= 25) {
				score += 10
				why = append(why, "you're sharp — good time for the real work")
			}
			if t.Vague {
				score -= 15
			}
		} else {
			if t.DurationMin != nil && *t.DurationMin <= 25 {
				score += 20
				why = append(why, "it's small enough for a tired brain")
			}
			if t.Vague {
				score -= 25
			}
			if t.DurationMin != nil && *t.DurationMin > 60 {
				score -= 10
			}
		}
		out = append(out, scoredTask{task: t, score: score, why: why})
	}
	return out
}

func parseCreatedAt(t Task) time.Time {
	ts, _ := time.Parse(time.RFC3339, t.CreatedAt)
	return ts
}

// PickNow picks the primary task + up to 2 alternatives. A task with
// pinned_until still in the future (see Part 3 promote-to-Now) is forced as
// primary ahead of the score sort; otherwise the highest-scoring candidate
// wins, tie-broken by oldest createdAt.
func (s *Service) PickNow(ctx context.Context, userID string, energy Energy, availableMin *int) (NowResponse, error) {
	candidates, err := s.repo.ListByStatuses(ctx, userID, []TaskStatus{StatusInbox, StatusPlanned, StatusPaused})
	if err != nil {
		return NowResponse{}, fmt.Errorf("whatnow: pick now: %w", err)
	}

	now := time.Now()

	filtered := make([]Task, 0, len(candidates))
	var pinned *Task
	for _, t := range candidates {
		if t.pinnedUntil != nil && t.pinnedUntil.After(now) && pinned == nil {
			p := t
			pinned = &p
		}
		switch {
		case availableMin == nil:
			filtered = append(filtered, t)
		case t.DurationMin == nil:
			if *availableMin >= 15 {
				filtered = append(filtered, t)
			}
		case *t.DurationMin <= *availableMin:
			filtered = append(filtered, t)
		}
	}

	scored := scoreCandidates(filtered, energy, now)
	sort.SliceStable(scored, func(i, j int) bool {
		if scored[i].score != scored[j].score {
			return scored[i].score > scored[j].score
		}
		return parseCreatedAt(scored[i].task).Before(parseCreatedAt(scored[j].task))
	})

	if pinned != nil {
		rationale := "This one because you pinned it — it's next."
		primary := *pinned
		primary.Rationale = rationale
		alternatives := make([]Task, 0, 2)
		for _, sc := range scored {
			if sc.task.ID == primary.ID {
				continue
			}
			alternatives = append(alternatives, sc.task)
			if len(alternatives) == 2 {
				break
			}
		}
		return NowResponse{Primary: &primary, Alternatives: alternatives, Rationale: rationale}, nil
	}

	if len(scored) == 0 {
		return NowResponse{Alternatives: []Task{}, Rationale: "Nothing on deck. Capture one thing below — that's enough."}, nil
	}

	first := scored[0]
	rationale := "This one because it's been waiting the longest."
	if len(first.why) > 0 {
		rationale = fmt.Sprintf("This one because %s.", first.why[0])
	}
	primary := first.task
	primary.Rationale = rationale

	rest := scored[1:]
	alternatives := make([]Task, 0, 2)
	for i, sc := range rest {
		if i == 2 {
			break
		}
		alternatives = append(alternatives, sc.task)
	}

	return NowResponse{Primary: &primary, Alternatives: alternatives, Rationale: rationale}, nil
}

func (s *Service) GetNow(ctx context.Context, userID string, q NowQuery) (NowResponse, error) {
	if err := s.repo.SweepDecayed(ctx, userID); err != nil {
		return NowResponse{}, err
	}
	return s.PickNow(ctx, userID, q.Energy, q.AvailableMin)
}

func (s *Service) GetInbox(ctx context.Context, userID string) ([]Task, error) {
	if err := s.repo.SweepDecayed(ctx, userID); err != nil {
		return nil, err
	}
	return s.repo.ListByStatuses(ctx, userID, []TaskStatus{StatusInbox, StatusPaused})
}

func (s *Service) CaptureTask(ctx context.Context, userID, raw string) (Task, error) {
	parsed := ParseCapture(raw)
	t := Task{
		Title:       parsed.Title,
		Status:      StatusInbox,
		DurationMin: parsed.DurationMin,
		Deadline:    parsed.Deadline,
		Category:    parsed.Category,
		Vague:       parsed.Vague,
		Chips:       parsed.Chips,
	}
	return s.repo.InsertTask(ctx, userID, t)
}

// applyPatch merges a TaskPatch onto t, matching store.ts's
// Object.assign(t, patch) semantics field-by-field, plus the Part 3 pin
// toggle (default 4h expiry when pinned=true, cleared when pinned=false).
func applyPatch(t *Task, patch TaskPatch) {
	if patch.Title != nil {
		t.Title = *patch.Title
	}
	if patch.Status != nil {
		t.Status = *patch.Status
	}
	if patch.Trigger != nil {
		t.Trigger = *patch.Trigger
	}
	if patch.DurationMin != nil {
		t.DurationMin = patch.DurationMin
	}
	if patch.Deadline != nil {
		t.Deadline = *patch.Deadline
	}
	if patch.Category != nil {
		t.Category = *patch.Category
	}
	if patch.Chips != nil {
		t.Chips = patch.Chips
	}
	if patch.ResumeNote != nil {
		t.ResumeNote = *patch.ResumeNote
	}
	if patch.Pinned != nil {
		if *patch.Pinned {
			until := time.Now().Add(pinDuration)
			t.pinnedUntil = &until
		} else {
			t.pinnedUntil = nil
		}
	}
	if patch.ScheduledStart != nil {
		if *patch.ScheduledStart == "" {
			t.scheduledStart = nil
			t.ScheduledStart = ""
		} else if parsed, err := time.Parse(time.RFC3339, *patch.ScheduledStart); err == nil {
			t.scheduledStart = &parsed
			// Keep the exported wire field in sync — it is only populated by the
			// repo scan, so without this the PATCH response would omit the new
			// schedule and clients would file the task as unscheduled.
			t.ScheduledStart = parsed.Format(time.RFC3339)
		}
	}
	t.touchedAt = time.Now()
}

func (s *Service) PatchTask(ctx context.Context, userID, id string, patch TaskPatch) (Task, error) {
	t, err := s.repo.GetTask(ctx, id, userID)
	if err != nil {
		return Task{}, err
	}
	applyPatch(&t, patch)
	if err := s.repo.UpdateTask(ctx, t); err != nil {
		return Task{}, err
	}
	return t, nil
}

func containsString(list []string, target string) bool {
	for _, v := range list {
		if v == target {
			return true
		}
	}
	return false
}

func (s *Service) CompleteTask(ctx context.Context, userID, id string) (CompleteResponse, error) {
	t, err := s.repo.GetTask(ctx, id, userID)
	if err != nil {
		return CompleteResponse{}, err
	}
	now := time.Now()
	t.Status = StatusDone
	t.CompletedAt = now.Format(time.RFC3339)
	t.touchedAt = now
	t.pinnedUntil = nil
	if err := s.repo.UpdateTask(ctx, t); err != nil {
		return CompleteResponse{}, err
	}

	doneIDs, err := s.repo.ListDoneIDs(ctx, userID)
	if err != nil {
		return CompleteResponse{}, fmt.Errorf("whatnow: complete task: %w", err)
	}
	candidates, err := s.repo.ListByStatuses(ctx, userID, []TaskStatus{StatusInbox, StatusPlanned, StatusActive, StatusPaused})
	if err != nil {
		return CompleteResponse{}, fmt.Errorf("whatnow: complete task: %w", err)
	}

	unlocked := make([]Task, 0)
	for _, x := range candidates {
		if !containsString(x.DependsOn, id) {
			continue
		}
		allDone := true
		for _, dep := range x.DependsOn {
			if !doneIDs[dep] {
				allDone = false
				break
			}
		}
		if allDone {
			unlocked = append(unlocked, x)
		}
	}
	return CompleteResponse{UnlockedTasks: unlocked}, nil
}

func (s *Service) PauseTask(ctx context.Context, userID, id, resumeNote string) (Task, error) {
	t, err := s.repo.GetTask(ctx, id, userID)
	if err != nil {
		return Task{}, err
	}
	t.Status = StatusPaused
	t.ResumeNote = resumeNote
	t.touchedAt = time.Now()
	t.pinnedUntil = nil
	if err := s.repo.UpdateTask(ctx, t); err != nil {
		return Task{}, err
	}
	return t, nil
}

// StuckTask applies one of the 4 canned resolutions from store.ts's
// stuckTask — deterministic templates, not AI calls.
func (s *Service) StuckTask(ctx context.Context, userID, id string, reason StuckReason) (StuckResolution, error) {
	t, err := s.repo.GetTask(ctx, id, userID)
	if err != nil {
		return StuckResolution{}, err
	}
	now := time.Now()
	t.touchedAt = now
	t.pinnedUntil = nil

	var res StuckResolution
	switch reason {
	case StuckTooBig:
		res = StuckResolution{Message: "It's carrying too much. Break it into steps — the first one should take under fifteen minutes."}
	case StuckNotSureItMatters:
		t.Status = StatusDecayed
		decayedAt := now
		t.decayedAt = &decayedAt
		res = StuckResolution{Message: "Released. If it really matters, it will come back — that's what the amnesty shelf is for."}
	case StuckDeadlineUnreal:
		base := now
		if t.Deadline != "" {
			if d, err := time.Parse("2006-01-02", t.Deadline); err == nil {
				base = d
			}
		}
		t.Deadline = isoDate(base.AddDate(0, 0, 7))
		newChips := make([]Chip, 0, len(t.Chips)+1)
		for _, c := range t.Chips {
			if c.Kind != ChipDeadline {
				newChips = append(newChips, c)
			}
		}
		newChips = append(newChips, Chip{ID: uuid.NewString(), Kind: ChipDeadline, Label: deadlineLabel(t.Deadline, now), Value: t.Deadline})
		t.Chips = newChips
		res = StuckResolution{Message: "Deadline moved a week out. A real date beats a noble one.", Task: &t}
	case StuckCantFocus:
		t.Trigger = "Do only the first ten minutes, then decide again."
		ten := 10
		t.DurationMin = &ten
		res = StuckResolution{Message: "Shrink it: ten minutes, then you're allowed to stop.", Task: &t}
	}

	if err := s.repo.UpdateTask(ctx, t); err != nil {
		return StuckResolution{}, err
	}
	return res, nil
}

func (s *Service) ReviveTask(ctx context.Context, userID, id string) (Task, error) {
	t, err := s.repo.GetTask(ctx, id, userID)
	if err != nil {
		return Task{}, err
	}
	now := time.Now()
	t.Status = StatusInbox
	t.revivedAt = &now
	t.touchedAt = now
	if err := s.repo.UpdateTask(ctx, t); err != nil {
		return Task{}, err
	}
	return t, nil
}

// ProposeBreakdown returns a fixed 3-step template — not an AI call.
func (s *Service) ProposeBreakdown(ctx context.Context, userID, id string) (BreakdownProposal, error) {
	t, err := s.repo.GetTask(ctx, id, userID)
	if err != nil {
		return BreakdownProposal{}, err
	}
	runes := []rune(t.Title)
	short := t.Title
	if len(runes) > 40 {
		short = string(runes[:40]) + "…"
	}
	ten, twentyFiveA, twentyFiveB := 10, 25, 25
	return BreakdownProposal{
		TaskID: id,
		Steps: []BreakdownStep{
			{ID: uuid.NewString(), Title: fmt.Sprintf("Write the one-sentence outcome for \"%s\"", short), DurationMin: &ten},
			{ID: uuid.NewString(), Title: fmt.Sprintf("Do the first concrete piece of \"%s\"", short), DurationMin: &twentyFiveA},
			{ID: uuid.NewString(), Title: fmt.Sprintf("Close the loop: finish and tidy \"%s\"", short), DurationMin: &twentyFiveB},
		},
	}, nil
}

// ConfirmBreakdown deletes the parent task and inserts the confirmed steps
// as a dependency chain (each depends on the previous), all in one
// transaction.
func (s *Service) ConfirmBreakdown(ctx context.Context, userID, id string, proposal BreakdownProposal) ([]Task, error) {
	parent, err := s.repo.GetTask(ctx, id, userID)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return nil, fmt.Errorf("whatnow: confirm breakdown: %w", err)
	}

	var created []Task
	err = s.repo.WithTx(ctx, func(tx pgx.Tx) error {
		if delErr := s.repo.DeleteTaskTx(ctx, tx, id, userID); delErr != nil && !errors.Is(delErr, ErrNotFound) {
			return delErr
		}
		var prevID string
		for _, step := range proposal.Steps {
			newTask := Task{
				Title:       step.Title,
				Status:      StatusPlanned,
				DurationMin: step.DurationMin,
				Deadline:    parent.Deadline,
				Category:    parent.Category,
			}
			if prevID != "" {
				newTask.DependsOn = []string{prevID}
			}
			if step.DurationMin != nil {
				newTask.Chips = []Chip{{ID: uuid.NewString(), Kind: ChipDuration, Label: fmt.Sprintf("%dm", *step.DurationMin), Value: strconv.Itoa(*step.DurationMin)}}
			}
			inserted, insErr := s.repo.InsertBreakdownStep(ctx, tx, userID, newTask)
			if insErr != nil {
				return insErr
			}
			created = append(created, inserted)
			prevID = inserted.ID
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("whatnow: confirm breakdown: %w", err)
	}
	return created, nil
}

func (s *Service) GetPlanToday(ctx context.Context, userID string) (PlanToday, error) {
	if err := s.repo.SweepDecayed(ctx, userID); err != nil {
		return PlanToday{}, err
	}
	tasks, err := s.repo.ListPlanned(ctx, userID)
	if err != nil {
		return PlanToday{}, err
	}
	stats, err := s.repo.GetWeeklyStats(ctx, userID)
	if err != nil {
		return PlanToday{}, err
	}
	return PlanToday{Tasks: tasks, Cap: planCap, Throughput: stats.Throughput}, nil
}

// GetDayPlan returns the Plan Day view for dateStr ("2006-01-02"): tasks
// time-blocked that day, plus the unscheduled backlog ranked by
// plan_position. Falls back to today when dateStr is empty or unparseable.
//
// tzOffsetMin is the client's UTC offset in minutes east of UTC (JS:
// -Date.getTimezoneOffset()). The day window must be the *client's*
// midnight-to-midnight: with a plain UTC window, a block at 01:00 in a
// positive-offset zone is stored on the previous UTC day and silently
// vanishes from the day it was created on.
func (s *Service) GetDayPlan(ctx context.Context, userID, dateStr string, tzOffsetMin int) (DayPlan, error) {
	loc := time.FixedZone("client", tzOffsetMin*60)
	day, err := time.ParseInLocation("2006-01-02", dateStr, loc)
	if err != nil {
		day = time.Now().In(loc)
	}
	dayStart := time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, loc)
	dayEnd := dayStart.AddDate(0, 0, 1)

	if err := s.repo.SweepDecayed(ctx, userID); err != nil {
		return DayPlan{}, err
	}
	scheduled, err := s.repo.ListScheduledForDay(ctx, userID, dayStart, dayEnd)
	if err != nil {
		return DayPlan{}, fmt.Errorf("whatnow: get day plan: %w", err)
	}
	unscheduled, err := s.repo.ListPlannedUnscheduled(ctx, userID)
	if err != nil {
		return DayPlan{}, fmt.Errorf("whatnow: get day plan: %w", err)
	}
	return DayPlan{Date: isoDate(dayStart), Scheduled: scheduled, Unscheduled: unscheduled}, nil
}

// PostPlanToday sets the chosen tasks to planned (persisting plan_position
// from array order, per Part 3 reorder support) and demotes any
// previously-planned task that was dropped from the selection.
func (s *Service) PostPlanToday(ctx context.Context, userID string, taskIDs []string) (PlanToday, error) {
	limit := planCap + 2
	if len(taskIDs) > limit {
		taskIDs = taskIDs[:limit]
	}
	chosen := make(map[string]int, len(taskIDs))
	for i, id := range taskIDs {
		chosen[id] = i
	}

	all, err := s.repo.ListByStatuses(ctx, userID, []TaskStatus{StatusInbox, StatusPlanned})
	if err != nil {
		return PlanToday{}, fmt.Errorf("whatnow: post plan today: %w", err)
	}
	now := time.Now()
	for _, t := range all {
		pos, isChosen := chosen[t.ID]
		switch {
		case isChosen:
			t.Status = StatusPlanned
			t.touchedAt = now
			p := pos
			t.planPosition = &p
		case t.Status == StatusPlanned:
			t.Status = StatusInbox
			t.planPosition = nil
		default:
			continue
		}
		if err := s.repo.UpdateTask(ctx, t); err != nil {
			return PlanToday{}, fmt.Errorf("whatnow: post plan today: %w", err)
		}
	}
	return s.GetPlanToday(ctx, userID)
}

func (s *Service) GetDecayed(ctx context.Context, userID string) ([]Task, error) {
	return s.repo.ListByStatuses(ctx, userID, []TaskStatus{StatusDecayed})
}

func (s *Service) GetWeeklyRecap(ctx context.Context, userID string) (WeeklyRecap, error) {
	stats, err := s.repo.GetWeeklyStats(ctx, userID)
	if err != nil {
		return WeeklyRecap{}, err
	}
	summary := "A quiet week. That's allowed."
	if stats.Completed > 0 {
		plural := "s"
		if stats.Completed == 1 {
			plural = ""
		}
		summary = fmt.Sprintf("You finished %d thing%s this week", stats.Completed, plural)
		if stats.Released > 0 {
			summary += fmt.Sprintf(" and let %d go. Both count.", stats.Released)
		} else {
			summary += ". Steady."
		}
	}
	return WeeklyRecap{Completed: stats.Completed, Revived: stats.Revived, Released: stats.Released, Summary: summary}, nil
}

func (s *Service) PutEnergy(ctx context.Context, userID string, energy Energy) error {
	return s.repo.UpsertUserState(ctx, userID, energy)
}
