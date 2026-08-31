package diary

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/whatnow"
)

// Service holds the diary domain's AI-backed behavior: the on-demand Fix
// English review, and the background analysis pass that resolves detected
// habit/task mentions against the writer's real habit/whatnow.Task records.
type Service struct {
	repo     *Repo
	provider ai.LLMProvider
	habits   *habit.Service
	tasks    *whatnow.Service
}

// NewService constructs a Service. habits/tasks are the same stateless
// wrappers over the shared pool that habit.New/whatnow.New already
// construct — journal.NewHandler stands up its own whatnow.Repo the same
// way, rather than threading the router's existing instances through.
func NewService(repo *Repo, provider ai.LLMProvider, habits *habit.Service, tasks *whatnow.Service) *Service {
	return &Service{repo: repo, provider: provider, habits: habits, tasks: tasks}
}

// ErrAIUnavailable is returned by FixEnglish when no LLM provider is configured.
var ErrAIUnavailable = errors.New("diary: AI provider not available")

// FixEnglish asks the LLM for a grammar/spelling diff of content, as an
// ordered same/del/add segment list the caller reviews and accepts/rejects
// span by span. Synchronous and unpersisted — nothing is saved here; the
// caller PATCHes the resolved content back through the normal entry update.
func (s *Service) FixEnglish(ctx context.Context, content string) ([]FixEnglishSegment, error) {
	if !s.provider.Available() {
		return nil, ErrAIUnavailable
	}
	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.DiaryFixEnglishSystemPrompt,
		UserPrompt:   content,
		MaxTokens:    4096,
		Temperature:  0.2,
		JSONMode:     true,
	})
	if err != nil {
		return nil, fmt.Errorf("diary: fix english: AI call: %w", err)
	}
	var parsed FixEnglishResponse
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("diary: fix english: parse AI response: %w", err)
	}
	return parsed.Segments, nil
}

// Analyze is the diary_analyze background job's body (dispatched from
// internal/jobs/handlers/llm.go). It re-scans entry.Content for habit/task
// mentions against the writer's current habit/open-task vocabulary, applies
// the resulting mutations (habit completion / task completion / new task
// capture), and persists the resolved highlight list.
//
// A missing/unavailable AI provider is a no-op skip, not a failure — the
// entry itself already saved fine; analysis just enriches it.
func (s *Service) Analyze(ctx context.Context, entry Entry) error {
	if !s.provider.Available() {
		return nil
	}

	entryDay, err := time.Parse("2006-01-02", entry.EntryDate)
	if err != nil {
		return fmt.Errorf("diary: analyze: parse entry date: %w", err)
	}

	monthView, err := s.habits.MonthView(ctx, entry.UserID, entryDay.Format("2006-01"))
	if err != nil {
		return fmt.Errorf("diary: analyze: load habits: %w", err)
	}
	openTasks, err := s.tasks.GetInbox(ctx, entry.UserID)
	if err != nil {
		return fmt.Errorf("diary: analyze: load open tasks: %w", err)
	}

	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.DiaryAnalyzeSystemPrompt,
		UserPrompt:   buildAnalyzePrompt(entry.Content, monthView.Habits, openTasks),
		MaxTokens:    2048,
		Temperature:  0.2,
		JSONMode:     true,
	})
	if err != nil {
		return fmt.Errorf("diary: analyze: AI call: %w", err)
	}

	var parsed struct {
		Highlights []Highlight `json:"highlights"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return fmt.Errorf("diary: analyze: parse AI response: %w", err)
	}

	resolved, err := s.applyHighlights(ctx, entry, parsed.Highlights, monthView.Habits, openTasks)
	if err != nil {
		return err
	}

	if err := s.repo.SaveAnalysis(ctx, entry.ID, resolved, ContentHash(entry.Content)); err != nil {
		return fmt.Errorf("diary: analyze: save: %w", err)
	}
	return nil
}

// applyHighlights resolves each AI-detected span against the closed
// habit/task vocabulary, applies the corresponding mutation, and returns the
// full highlight list to persist.
//
// ponytail: dedup against re-analysis (an edit that re-triggers analysis
// shouldn't recreate a task/habit-completion for a sentence already
// processed) is exact case-insensitive text match against entry.Highlights
// from the PRIOR analysis — not semantic. Upgrade only if real duplicates
// show up in practice (e.g. the writer rephrases the same sentence).
func (s *Service) applyHighlights(ctx context.Context, entry Entry, detected []Highlight, habits []habit.Habit, openTasks []whatnow.Task) ([]Highlight, error) {
	habitByID := make(map[string]habit.Habit, len(habits))
	for _, h := range habits {
		habitByID[h.ID] = h
	}
	openTaskByID := make(map[string]bool, len(openTasks))
	for _, t := range openTasks {
		openTaskByID[t.ID] = true
	}

	already := make(map[string]Highlight, len(entry.Highlights))
	for _, h := range entry.Highlights {
		already[dedupKey(h.Kind, h.Text)] = h
	}

	resolved := make([]Highlight, 0, len(detected))
	for _, h := range detected {
		h.Text = strings.TrimSpace(h.Text)
		if h.Text == "" || h.End <= h.Start {
			continue
		}
		prior, alreadyApplied := already[dedupKey(h.Kind, h.Text)]

		switch h.Kind {
		case HighlightHabit:
			hab, ok := habitByID[h.RefID]
			if !ok {
				continue // model referenced an id outside the given vocabulary
			}
			if !alreadyApplied {
				period := alignPeriod(entryDate(entry), hab.Cadence)
				if err := s.habits.SetCompletion(ctx, entry.UserID, hab.ID, period.Format("2006-01-02")); err != nil {
					return nil, fmt.Errorf("diary: analyze: set habit completion: %w", err)
				}
			}

		case HighlightTaskDone:
			if !openTaskByID[h.RefID] {
				continue
			}
			if !alreadyApplied {
				if _, err := s.tasks.CompleteTask(ctx, entry.UserID, h.RefID); err != nil {
					return nil, fmt.Errorf("diary: analyze: complete task: %w", err)
				}
			}

		case HighlightTaskNew:
			if alreadyApplied {
				h.RefID = prior.RefID
			} else {
				t, err := s.tasks.CaptureTask(ctx, entry.UserID, h.Text)
				if err != nil {
					return nil, fmt.Errorf("diary: analyze: capture task: %w", err)
				}
				h.RefID = t.ID
			}

		case HighlightBuyNew:
			if alreadyApplied {
				h.RefID = prior.RefID
			} else {
				// Reuses ParseCapture's existing "#category" inline-tag
				// convention (whatnow.service.go categoryRe) instead of a
				// second category mechanism.
				t, err := s.tasks.CaptureTask(ctx, entry.UserID, h.Text+" #buy")
				if err != nil {
					return nil, fmt.Errorf("diary: analyze: capture buy task: %w", err)
				}
				h.RefID = t.ID
			}

		default:
			continue
		}

		resolved = append(resolved, h)
	}
	return resolved, nil
}

func dedupKey(kind HighlightKind, text string) string {
	return string(kind) + "|" + strings.ToLower(strings.TrimSpace(text))
}

// entryDate re-parses entry.EntryDate — cheap enough not to thread the
// already-parsed time.Time through applyHighlights' signature.
func entryDate(e Entry) time.Time {
	t, _ := time.Parse("2006-01-02", e.EntryDate)
	return t
}

// alignPeriod maps entryDate onto the period_start a habit of the given
// cadence tracks completions under — daily habits track the day itself;
// weekly/monthly mirror the exact Monday-of-week / first-of-month alignment
// habit.Service.MonthView already uses internally, so a diary-driven
// completion lands in the same period the habit grid would show for today.
func alignPeriod(entryDate time.Time, cadence habit.Cadence) time.Time {
	switch cadence {
	case habit.CadenceWeekly:
		offset := (int(entryDate.Weekday()) + 6) % 7 // days since Monday; Sunday=0 -> 6
		return entryDate.AddDate(0, 0, -offset)
	case habit.CadenceMonthly:
		return time.Date(entryDate.Year(), entryDate.Month(), 1, 0, 0, 0, 0, entryDate.Location())
	default:
		return entryDate
	}
}

// buildAnalyzePrompt lists the closed habit/task vocabulary the model must
// resolve against, then the entry content verbatim — content is NOT
// sanitized/transformed here (unlike most other AI prompts in this
// codebase) because the model's returned start/end offsets must index into
// exactly this same string on the way back out.
func buildAnalyzePrompt(content string, habits []habit.Habit, openTasks []whatnow.Task) string {
	var sb strings.Builder
	sb.WriteString("Existing habits (id: name, cadence):\n")
	if len(habits) == 0 {
		sb.WriteString("(none)\n")
	}
	for _, h := range habits {
		fmt.Fprintf(&sb, "- %s: %s (%s)\n", h.ID, h.Name, h.Cadence)
	}
	sb.WriteString("\nExisting open tasks (id: title):\n")
	if len(openTasks) == 0 {
		sb.WriteString("(none)\n")
	}
	for _, t := range openTasks {
		fmt.Fprintf(&sb, "- %s: %s\n", t.ID, t.Title)
	}
	sb.WriteString("\nDiary entry (analyze exactly as given; offsets must index into this exact text):\n")
	sb.WriteString(content)
	return sb.String()
}
