package diary

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/habit"
)

// Service holds the diary domain's AI-backed behavior: the on-demand Fix
// English review, and the Preview/Apply pair that detects, then (once the
// writer has reviewed/edited the result) resolves, habit/task/learning
// mentions against the writer's real habit records, diary-owned task list,
// and self-course "Learning Log". Diary owns its own task data (see
// repo.go's Task methods) — it has no dependency on internal/whatnow.
type Service struct {
	repo       *Repo
	provider   ai.LLMProvider
	habits     *habit.Service
	courseRepo *courses.Repo
}

// NewService constructs a Service. habits is the same stateless wrapper over
// the shared pool that habit.New already constructs. courseRepo is used
// directly (not courses.Service) since only a handful of self-course CRUD
// methods are needed here and courses.Service's constructor pulls in
// storage/AI/rewards dependencies diary has no use for.
func NewService(repo *Repo, provider ai.LLMProvider, habits *habit.Service, courseRepo *courses.Repo) *Service {
	return &Service{repo: repo, provider: provider, habits: habits, courseRepo: courseRepo}
}

// ErrAIUnavailable is returned by FixEnglish/Preview when no LLM provider is configured.
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

// ReviewDump runs FixEnglish then Preview over the corrected text in one
// round trip, so the frontend's single "AI" button gets a minimal-change
// correction and the detected highlights together instead of two separate
// clicks. Both underlying calls are unchanged and still synchronous/
// unpersisted; this only composes their results.
func (s *Service) ReviewDump(ctx context.Context, userID, orgID, entryDate, content string) (string, []Highlight, error) {
	segments, err := s.FixEnglish(ctx, content)
	if err != nil {
		return "", nil, err
	}
	corrected := acceptAllSegments(segments)
	highlights, err := s.Preview(ctx, userID, entryDate, corrected)
	if err != nil {
		return "", nil, err
	}
	return corrected, highlights, nil
}

// acceptAllSegments reconstructs the fully-corrected text from a FixEnglish
// diff by keeping "same" as-is and, per del/add pair, always the "add" side
// — the server-side equivalent of the frontend's "Accept All".
func acceptAllSegments(segments []FixEnglishSegment) string {
	var sb strings.Builder
	for _, seg := range segments {
		if seg.Kind == SegmentDel {
			continue
		}
		sb.WriteString(seg.Text)
	}
	return sb.String()
}

// Preview runs the habit/task detection pass over content — the writer's
// current, possibly-unsaved text — and returns the detected spans WITHOUT
// applying anything, so the frontend can render them for review (toggle a
// span off, correct an extracted metadata value) before Apply commits them.
// Synchronous and unpersisted, same as FixEnglish.
func (s *Service) Preview(ctx context.Context, userID, entryDate, content string) ([]Highlight, error) {
	if !s.provider.Available() {
		return nil, ErrAIUnavailable
	}
	habits, openTasks, err := s.vocabulary(ctx, userID, entryDate)
	if err != nil {
		return nil, err
	}

	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.DiaryAnalyzeSystemPrompt,
		UserPrompt:   buildAnalyzePrompt(content, habits, openTasks),
		MaxTokens:    2048,
		Temperature:  0.2,
		JSONMode:     true,
	})
	if err != nil {
		return nil, fmt.Errorf("diary: preview: AI call: %w", err)
	}

	var parsed struct {
		Highlights []Highlight `json:"highlights"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("diary: preview: parse AI response: %w", err)
	}
	return cleanHighlights(parsed.Highlights, habits, openTasks), nil
}

// Apply commits a writer-reviewed highlight list (a Preview result, with any
// spans the writer unchecked already removed by the caller and any metadata
// values already corrected) against entry: applies each mutation against the
// CURRENT habit/open-task vocabulary — which may have moved since Preview
// ran — and persists the resolved list. orgID scopes the self-course a
// "learned" highlight routes into (self-courses are org-scoped; diary
// entries aren't).
func (s *Service) Apply(ctx context.Context, entry Entry, orgID string, edited []Highlight) ([]Highlight, error) {
	habits, openTasks, err := s.vocabulary(ctx, entry.UserID, entry.EntryDate)
	if err != nil {
		return nil, err
	}
	resolved, err := s.applyHighlights(ctx, entry, orgID, edited, habits, openTasks)
	if err != nil {
		return nil, err
	}
	if err := s.repo.SaveAnalysis(ctx, entry.ID, resolved, ContentHash(entry.Content)); err != nil {
		return nil, fmt.Errorf("diary: apply: save: %w", err)
	}
	return resolved, nil
}

// vocabulary loads the CLOSED habit/open-task lists a detection or apply
// pass resolves ref_ids against. Preview and Apply each call this fresh
// (rather than sharing one snapshot) since real time passes between a
// writer reviewing and confirming. Open tasks are diary's own (Task, not
// whatnow.Task) — diary owns this data directly.
func (s *Service) vocabulary(ctx context.Context, userID, entryDate string) ([]habit.Habit, []Task, error) {
	entryDay, err := time.Parse("2006-01-02", entryDate)
	if err != nil {
		return nil, nil, fmt.Errorf("diary: parse entry date: %w", err)
	}
	monthView, err := s.habits.MonthView(ctx, userID, entryDay.Format("2006-01"))
	if err != nil {
		return nil, nil, fmt.Errorf("diary: load habits: %w", err)
	}
	openTasks, err := s.repo.ListOpenTasks(ctx, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("diary: load open tasks: %w", err)
	}
	return monthView.Habits, openTasks, nil
}

// validGoalCadences are the only cadence values a "goal" highlight may carry
// — the exact wire values habit.Cadence uses.
var validGoalCadences = map[string]bool{"daily": true, "weekly": true, "monthly": true}

// cleanHighlights trims and validates a raw AI response for Preview's
// display — the same span/ref checks applyHighlights enforces before
// mutating anything, so the review UI never shows a span Apply would
// silently drop.
func cleanHighlights(detected []Highlight, habits []habit.Habit, openTasks []Task) []Highlight {
	habitByID := make(map[string]bool, len(habits))
	for _, h := range habits {
		habitByID[h.ID] = true
	}
	openTaskByID := make(map[string]bool, len(openTasks))
	for _, t := range openTasks {
		openTaskByID[t.ID] = true
	}

	cleaned := make([]Highlight, 0, len(detected))
	for _, h := range detected {
		h.Text = strings.TrimSpace(h.Text)
		if h.Text == "" || h.End <= h.Start {
			continue
		}
		switch h.Kind {
		case HighlightHabit:
			if !habitByID[h.RefID] {
				continue
			}
		case HighlightTaskDone:
			if !openTaskByID[h.RefID] {
				continue
			}
		case HighlightTaskNew, HighlightBuyNew:
			// ref_id is only assigned once Apply actually captures the task.
		case HighlightLearned:
			if strings.TrimSpace(h.Category) == "" || strings.TrimSpace(h.Title) == "" {
				continue
			}
		case HighlightGoal:
			if strings.TrimSpace(h.Title) == "" || !validGoalCadences[h.Cadence] {
				continue
			}
		default:
			continue
		}
		cleaned = append(cleaned, h)
	}
	return cleaned
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
func (s *Service) applyHighlights(ctx context.Context, entry Entry, orgID string, detected []Highlight, habits []habit.Habit, openTasks []Task) ([]Highlight, error) {
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
			period := alignPeriod(entryDate(entry), hab.Cadence)
			if !alreadyApplied {
				if err := s.habits.SetCompletion(ctx, entry.UserID, hab.ID, period.Format("2006-01-02")); err != nil {
					return nil, fmt.Errorf("diary: analyze: set habit completion: %w", err)
				}
			}
			// Metadata is applied every pass, not just !alreadyApplied — an
			// upsert is idempotent (unlike SetCompletion/CreateTask, which
			// would create a duplicate), so a re-analysis with more detail in
			// the same sentence keeps refining the stored fields.
			if meta := allowedHabitMetadata(hab, h.Metadata); len(meta) > 0 {
				if err := s.habits.SetCompletionMetadata(ctx, entry.UserID, hab.ID, period.Format("2006-01-02"), meta); err != nil {
					return nil, fmt.Errorf("diary: analyze: set habit metadata: %w", err)
				}
			}

		case HighlightTaskDone:
			if !openTaskByID[h.RefID] {
				continue
			}
			if !alreadyApplied {
				if _, err := s.repo.SetTaskDone(ctx, entry.UserID, h.RefID, true); err != nil {
					return nil, fmt.Errorf("diary: analyze: complete task: %w", err)
				}
			}

		case HighlightTaskNew:
			if alreadyApplied {
				h.RefID = prior.RefID
			} else {
				t, err := s.repo.CreateTask(ctx, entry.UserID, h.Text, string(TaskKindTodo), &entry.ID, nil)
				if err != nil {
					return nil, fmt.Errorf("diary: analyze: capture task: %w", err)
				}
				h.RefID = t.ID
			}

		case HighlightBuyNew:
			if alreadyApplied {
				h.RefID = prior.RefID
			} else {
				t, err := s.repo.CreateTask(ctx, entry.UserID, h.Text, string(TaskKindBuy), &entry.ID, nil)
				if err != nil {
					return nil, fmt.Errorf("diary: analyze: capture buy task: %w", err)
				}
				h.RefID = t.ID
			}

		case HighlightLearned:
			if alreadyApplied {
				h.RefID = prior.RefID
			} else {
				moduleID, err := s.courseRepo.FileLearningLogNote(ctx, orgID, entry.UserID, h.Category, h.Title, h.Text)
				if err != nil {
					return nil, fmt.Errorf("diary: analyze: file learned highlight: %w", err)
				}
				h.RefID = moduleID
			}

		case HighlightGoal:
			if alreadyApplied {
				h.RefID = prior.RefID
			} else if match, ok := matchExistingHabit(h.Title, habits); ok {
				// The writer actually meant an existing habit — the model
				// should have used kind:"habit", but this is a cheap
				// server-side safety net against creating a duplicate.
				h.RefID = match.ID
			} else {
				created, err := s.habits.Create(ctx, entry.UserID, habit.CreateRequest{
					Name:    h.Title,
					Cadence: habit.Cadence(h.Cadence),
				})
				if err != nil {
					return nil, fmt.Errorf("diary: analyze: create goal habit: %w", err)
				}
				h.RefID = created.ID
			}

		default:
			continue
		}

		resolved = append(resolved, h)
	}
	return resolved, nil
}

// matchExistingHabit does a cheap case-insensitive substring match of title
// against habits' names — see HighlightGoal in applyHighlights.
//
// ponytail: substring match, not the trigram similarity journal/self-courses
// use — upgrade only if this proves too strict/loose in practice.
func matchExistingHabit(title string, habits []habit.Habit) (habit.Habit, bool) {
	needle := strings.ToLower(strings.TrimSpace(title))
	if needle == "" {
		return habit.Habit{}, false
	}
	for _, h := range habits {
		name := strings.ToLower(h.Name)
		if strings.Contains(name, needle) || strings.Contains(needle, name) {
			return h, true
		}
	}
	return habit.Habit{}, false
}

// allowedHabitMetadata filters the AI-extracted metadata down to keys that
// are actually part of hab's field schema — SetCompletionMetadata rejects
// the whole call on an unknown key, and the model is only ever shown the
// schema as guidance, not a hard constraint it's guaranteed to respect.
func allowedHabitMetadata(hab habit.Habit, extracted map[string]any) map[string]any {
	if len(extracted) == 0 {
		return nil
	}
	fields := habit.FieldsForHabit(hab)
	if len(fields) == 0 {
		return nil
	}
	allowed := make(map[string]bool, len(fields))
	for _, f := range fields {
		allowed[f.Key] = true
	}
	out := make(map[string]any, len(extracted))
	for k, v := range extracted {
		if allowed[k] {
			out[k] = v
		}
	}
	return out
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
func buildAnalyzePrompt(content string, habits []habit.Habit, openTasks []Task) string {
	var sb strings.Builder
	sb.WriteString("Existing habits (id: name, cadence, optional entry fields):\n")
	if len(habits) == 0 {
		sb.WriteString("(none)\n")
	}
	for _, h := range habits {
		fmt.Fprintf(&sb, "- %s: %s (%s)", h.ID, h.Name, h.Cadence)
		if fields := habit.FieldsForHabit(h); len(fields) > 0 {
			sb.WriteString(" [fields: ")
			for i, f := range fields {
				if i > 0 {
					sb.WriteString(", ")
				}
				fmt.Fprintf(&sb, "%s (%s)", f.Key, f.Kind)
			}
			sb.WriteString("]")
		}
		sb.WriteString("\n")
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
