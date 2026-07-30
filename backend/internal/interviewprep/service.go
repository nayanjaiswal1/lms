package interviewprep

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/practice"
)

var validSeniorities = []string{"beginner", "intermediate", "advanced", "expert"}

const (
	conceptualQuestionCount = 6
	// behavioralQuestionCount is larger than the technical conceptual round —
	// a non-technical plan has no coding round, so its single round carries
	// the full assessment on its own.
	behavioralQuestionCount = 9
	maxJDChars              = 4000
	// maxJDInputChars bounds the raw jd_text a caller may submit, before
	// extractProfile truncates it further (maxJDChars) for the prompt itself.
	maxJDInputChars     = 10000
	maxJobTitleChars    = 200
	codingTimeLimitMs   = 5000
	codingMemoryLimitKb = 256 * 1024

	roleTypeTechnical    = "technical"
	roleTypeNonTechnical = "non_technical"

	// MaxPlansPerDay caps how many prep plans a user can generate per day —
	// each creation is 1-2 AI calls plus a practice-session creation, same
	// cost class as the per-day caps already used by labs/practice creation
	// flows. Enforced once here so every caller (the HTTP handler and the MCP
	// tool) gets the same limit, rather than each entry point re-implementing it.
)

const MaxPlansPerDay = 5

// Sentinel errors for CreatePlan's input validation and rate limiting — kept
// as errors.Is-checkable values (rather than ad-hoc fmt.Errorf strings) so
// every caller (HTTP handler, MCP tool) can map them to its own user-facing
// message without parsing error text.
var (
	ErrInvalidMode        = errors.New("interviewprep: mode must be 'quick' or 'targeted'")
	ErrJobTitleRequired   = errors.New("interviewprep: job_title is required")
	ErrJDTextTooLong      = errors.New("interviewprep: jd_text cannot exceed 10,000 characters")
	ErrTechnologyRequired = errors.New("interviewprep: technology is required")
	ErrDailyLimitReached  = errors.New("interviewprep: daily plan limit reached")
)

type Service struct {
	repo        *Repo
	ai          ai.LLMProvider
	executor    assessment.CodeExecutor
	practiceSvc *practice.Service
	// practiceRepo is a second, read-only handle onto the practice package's own
	// tables (same pool, no shared mutable state) — needed to read back a
	// conceptual round's per-item AI feedback for the final report. practice.Service
	// only exposes session creation/answer submission, not a read API, so this
	// mirrors the same "construct a second cheap stateless client" approach used
	// for assessment.CodeExecutor rather than growing practice's public surface.
	practiceRepo *practice.Repo
	cfg          *config.Config
	// pool is used directly (not through repo) only to call srs.MaybeCreateCard,
	// a package-level helper in internal/srs that takes a pool rather than a
	// repo — the same pattern already used by the assessment package.
	pool *pgxpool.Pool
}

func NewService(repo *Repo, aiProvider ai.LLMProvider, executor assessment.CodeExecutor, practiceSvc *practice.Service, practiceRepo *practice.Repo, cfg *config.Config, pool *pgxpool.Pool) *Service {
	return &Service{
		repo:         repo,
		ai:           aiProvider,
		executor:     executor,
		practiceSvc:  practiceSvc,
		practiceRepo: practiceRepo,
		cfg:          cfg,
		pool:         pool,
	}
}

// ─── Plan creation ────────────────────────────────────────────────────────────

type extractedProfile struct {
	Role       string   `json:"role"`
	Seniority  string   `json:"seniority"`
	RoleType   string   `json:"role_type"`
	Skills     []string `json:"skills"`
	FocusAreas []string `json:"focus_areas"`
}

// CreatePlanInput carries both modes' fields. Quick plans use Technology/
// Difficulty/Category/QuestionCount; targeted plans use JobTitle/JDText (role
// type and therefore category is derived from JD extraction, not passed in).
// The caller (handler.go) is responsible for validating the fields required
// by Mode.
type CreatePlanInput struct {
	Mode          string
	JobTitle      string
	JDText        string
	Technology    string
	Difficulty    string
	Category      string
	QuestionCount int
}

// ListPlans and GetPlan thinly wrap the repo so external callers (the MCP
// tools in mcpconnect) go through Service like every other interview-prep
// operation, rather than reaching into a separate *Repo dependency for just
// these two reads.
func (s *Service) ListPlans(ctx context.Context, userID string) ([]Plan, error) {
	return s.repo.ListPlans(ctx, userID)
}

func (s *Service) GetPlan(ctx context.Context, planID, userID string) (Plan, error) {
	return s.repo.GetPlan(ctx, planID, userID)
}

// GetRoundSession and SubmitRoundAnswer expose round 1 (conceptual or
// behavioral — every plan type has one) through Service, the same as the
// coding round's SubmitCodingItem. Without these, a caller that only sees
// Plan/Round JSON has nothing but an opaque practice_session_id for round 1:
// no question text, no way to answer it, and no way to read the AI feedback
// that ultimately feeds GetReport's readiness score. The in-app frontend
// reaches the practice package directly for this (components/interview-prep/
// round-list.tsx -> getPracticeSession); this gives the same access to
// callers (like the MCP tools) that only ever go through interviewprep.Service.
func (s *Service) GetRoundSession(ctx context.Context, sessionID, userID string) (practice.PracticeSession, error) {
	return s.practiceSvc.GetSession(ctx, sessionID, userID)
}

func (s *Service) SubmitRoundAnswer(ctx context.Context, sessionID, userID string, position int, answerText string) (practice.PracticeItem, error) {
	return s.practiceSvc.SubmitAnswer(ctx, sessionID, userID, position, answerText)
}

func (s *Service) CreatePlan(ctx context.Context, userID string, orgID *string, input CreatePlanInput) (Plan, error) {
	if !s.ai.Available() {
		return Plan{}, fmt.Errorf("interviewprep: AI provider not available")
	}
	if input.Mode != ModeQuick && input.Mode != ModeTargeted {
		return Plan{}, ErrInvalidMode
	}

	count, err := s.repo.CountRecentPlans(ctx, userID)
	if err != nil {
		return Plan{}, fmt.Errorf("interviewprep: count recent plans: %w", err)
	}
	if count >= MaxPlansPerDay {
		return Plan{}, ErrDailyLimitReached
	}

	if input.Mode == ModeTargeted {
		if strings.TrimSpace(input.JobTitle) == "" {
			return Plan{}, ErrJobTitleRequired
		}
		if len(input.JDText) > maxJDInputChars {
			return Plan{}, ErrJDTextTooLong
		}
		return s.createTargetedPlan(ctx, userID, orgID, input)
	}

	if strings.TrimSpace(input.Technology) == "" {
		return Plan{}, ErrTechnologyRequired
	}
	if input.Difficulty == "" {
		input.Difficulty = "intermediate"
	}
	if input.Category != practice.CategoryTechnical && input.Category != practice.CategoryBehavioral {
		input.Category = practice.CategoryTechnical
	}
	if input.QuestionCount < 1 || input.QuestionCount > 20 {
		input.QuestionCount = 5
	}
	return s.createQuickPlan(ctx, userID, orgID, input)
}

// createQuickPlan skips JD extraction and the coding round entirely — it's
// the direct replacement for the old standalone practice.CreateSession flow,
// just wrapped in a Plan so quick and targeted sessions share one list/detail
// UI. Costs exactly one LLM call (question generation), same as before.
func (s *Service) createQuickPlan(ctx context.Context, userID string, orgID *string, input CreatePlanInput) (Plan, error) {
	category := input.Category
	if category == "" {
		category = practice.CategoryTechnical
	}

	practiceSession, err := s.practiceSvc.CreateSession(ctx, userID, orgID,
		input.Technology, input.Difficulty, category, input.QuestionCount, "")
	if err != nil {
		return Plan{}, fmt.Errorf("interviewprep: create quick session: %w", err)
	}

	roundType := RoundConceptual
	if category == practice.CategoryBehavioral {
		roundType = RoundBehavioral
	}

	technology, difficulty := input.Technology, input.Difficulty
	plan := Plan{
		UserID:     userID,
		OrgID:      orgID,
		PlanType:   ModeQuick,
		Category:   category,
		JobTitle:   input.Technology,
		Technology: &technology,
		Difficulty: &difficulty,
		Status:     StatusReady,
		AIModel:    practiceSession.AIModel,
	}
	practiceSessionID := practiceSession.ID
	rounds := []Round{
		{
			RoundType:         roundType,
			OrderIndex:        0,
			PracticeSessionID: &practiceSessionID,
			Status:            RoundActive,
		},
	}

	return s.repo.CreatePlanWithRounds(ctx, plan, rounds)
}

// createTargetedPlan builds a plan from a job title/JD. Technical roles get
// the original two-round shape (conceptual + coding). Non-technical roles
// get a single, larger behavioral round instead — there's no honest coding-
// round equivalent for a role that doesn't involve writing code, so a fake
// second round would just be padding.
func (s *Service) createTargetedPlan(ctx context.Context, userID string, orgID *string, input CreatePlanInput) (Plan, error) {
	profile, model, err := s.extractProfile(ctx, input.JobTitle, input.JDText)
	if err != nil {
		return Plan{}, err
	}

	category := practice.CategoryTechnical
	roundType := RoundConceptual
	questionCount := conceptualQuestionCount
	if profile.RoleType == roleTypeNonTechnical {
		category = practice.CategoryBehavioral
		roundType = RoundBehavioral
		questionCount = behavioralQuestionCount
	}

	// Round 1 — delegates entirely to the existing practice engine. technology
	// is the joined skill list; difficulty is the extracted seniority.
	practiceSession, err := s.practiceSvc.CreateSession(ctx, userID, orgID,
		strings.Join(profile.Skills, ", "), profile.Seniority, category, questionCount, "")
	if err != nil {
		return Plan{}, fmt.Errorf("interviewprep: create round 1: %w", err)
	}

	var jdPtr *string
	if strings.TrimSpace(input.JDText) != "" {
		jdPtr = &input.JDText
	}

	plan := Plan{
		UserID:             userID,
		OrgID:              orgID,
		PlanType:           ModeTargeted,
		Category:           category,
		JobTitle:           input.JobTitle,
		JDText:             jdPtr,
		ExtractedRole:      profile.Role,
		ExtractedSeniority: profile.Seniority,
		ExtractedSkills:    profile.Skills,
		Status:             StatusReady,
		AIModel:            &model,
	}
	practiceSessionID := practiceSession.ID
	rounds := []Round{
		{
			RoundType:         roundType,
			OrderIndex:        0,
			PracticeSessionID: &practiceSessionID,
			Status:            RoundActive,
		},
	}

	// Round 2 (coding) — technical roles only.
	if category == practice.CategoryTechnical {
		codingItems, err := s.generateCodingItems(ctx, profile)
		if err != nil {
			return Plan{}, fmt.Errorf("interviewprep: create coding round: %w", err)
		}
		rounds = append(rounds, Round{
			RoundType:  RoundCoding,
			OrderIndex: 1,
			Items:      codingItems,
			Status:     RoundPending,
		})
	}

	return s.repo.CreatePlanWithRounds(ctx, plan, rounds)
}

func (s *Service) extractProfile(ctx context.Context, jobTitle, jdText string) (extractedProfile, string, error) {
	title := ai.SanitizeTopic(jobTitle, maxJobTitleChars)
	userPrompt := "Job title: " + title
	if jd := ai.SanitizeTopic(jdText, maxJDChars); jd != "" {
		userPrompt += "\n\nJob description:\n" + jd
	}

	llmCtx, cancel := context.WithTimeout(ctx, s.cfg.LLMTimeout)
	defer cancel()

	resp, err := s.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.JDExtractionSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    512,
		Temperature:  0.3,
		JSONMode:     true,
	})
	if err != nil {
		return extractedProfile{}, "", fmt.Errorf("interviewprep: extract profile: %w", err)
	}

	var profile extractedProfile
	if err := json.Unmarshal([]byte(resp.Content), &profile); err != nil {
		return extractedProfile{}, "", fmt.Errorf("interviewprep: parse profile: %w", err)
	}
	if len(profile.Skills) == 0 {
		return extractedProfile{}, "", fmt.Errorf("interviewprep: AI returned no skills")
	}
	if !contains(validSeniorities, profile.Seniority) {
		profile.Seniority = "intermediate"
	}
	if profile.RoleType != roleTypeNonTechnical {
		profile.RoleType = roleTypeTechnical
	}
	if profile.Role == "" {
		profile.Role = jobTitle
	}
	return profile, resp.Model, nil
}

// ─── Coding round generation ──────────────────────────────────────────────────

type generatedCodingItem struct {
	Prompt      string     `json:"prompt"`
	Language    string     `json:"language"`
	StarterCode string     `json:"starter_code"`
	TestCases   []TestCase `json:"test_cases"`
	Skill       string     `json:"skill"`
}

func (s *Service) generateCodingItems(ctx context.Context, profile extractedProfile) ([]CodingItem, error) {
	userPrompt := fmt.Sprintf("Role: %s\nSeniority: %s\nSkills: %s\nFocus areas: %s",
		profile.Role, profile.Seniority, strings.Join(profile.Skills, ", "), strings.Join(profile.FocusAreas, ", "))

	llmCtx, cancel := context.WithTimeout(ctx, s.cfg.LLMTimeout)
	defer cancel()

	resp, err := s.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.CodingRoundSystemPrompt,
		UserPrompt:   userPrompt,
		// 2-3 problems, each with a full prompt, starter code, and 3+ test
		// cases, as strict JSON easily exceeds 2048 tokens for verbose
		// languages (Java, C++) — a tight budget here doesn't error, it
		// silently truncates the JSON mid-array, so generateCodingItems below
		// either fails to parse or (worse) silently returns fewer/thinner
		// problems than intended. 4096 gives real headroom.
		MaxTokens:   4096,
		Temperature: 0.6,
		JSONMode:    true,
	})
	if err != nil {
		return nil, fmt.Errorf("interviewprep: generate coding items: %w", err)
	}

	var generated []generatedCodingItem
	if err := json.Unmarshal([]byte(resp.Content), &generated); err != nil {
		return nil, fmt.Errorf("interviewprep: parse coding items: %w", err)
	}
	if len(generated) == 0 {
		return nil, fmt.Errorf("interviewprep: AI returned no coding items")
	}

	items := make([]CodingItem, 0, len(generated))
	for i, g := range generated {
		if len(g.TestCases) == 0 {
			continue
		}
		items = append(items, CodingItem{
			ID:          fmt.Sprintf("item-%d", i),
			Prompt:      g.Prompt,
			Language:    g.Language,
			StarterCode: g.StarterCode,
			TestCases:   g.TestCases,
			Skill:       g.Skill,
		})
	}
	if len(items) == 0 {
		return nil, fmt.Errorf("interviewprep: AI returned no usable coding items")
	}
	return items, nil
}

func contains(list []string, v string) bool {
	for _, s := range list {
		if s == v {
			return true
		}
	}
	return false
}

// ─── Coding round submission ──────────────────────────────────────────────────

// SubmitCodingItem runs the student's code for one item and stores the result.
// When every item in the round has been attempted, the round is marked completed.
func (s *Service) SubmitCodingItem(ctx context.Context, planID, roundID, itemID, userID, code, language string) (CodingItem, error) {
	round, err := s.repo.GetRoundForUser(ctx, roundID, planID, userID)
	if err != nil {
		return CodingItem{}, err
	}
	if round.RoundType != RoundCoding {
		return CodingItem{}, fmt.Errorf("interviewprep: round %s is not a coding round", roundID)
	}

	idx := -1
	for i, it := range round.Items {
		if it.ID == itemID {
			idx = i
			break
		}
	}
	if idx == -1 {
		return CodingItem{}, ErrNotFound
	}
	item := round.Items[idx]

	content := assessment.CodingContent{
		Prompt:        item.Prompt,
		Languages:     []string{item.Language},
		TimeLimitMs:   codingTimeLimitMs,
		MemoryLimitKb: codingMemoryLimitKb,
		TestCases:     make([]assessment.TestCase, len(item.TestCases)),
	}
	for i, tc := range item.TestCases {
		content.TestCases[i] = assessment.TestCase{
			ID:       fmt.Sprintf("%s-case-%d", item.ID, i),
			Stdin:    tc.Stdin,
			Expected: tc.Expected,
			Hidden:   tc.Hidden,
			Weight:   1,
		}
	}

	if !s.executor.Available() {
		return CodingItem{}, fmt.Errorf("interviewprep: code execution unavailable")
	}
	runResult, err := s.executor.Run(ctx, language, code, content)
	if err != nil {
		return CodingItem{}, fmt.Errorf("interviewprep: run submission: %w", err)
	}

	passed := runResult.Status == "passed"
	item.SubmittedCode = code
	item.RunResult = &CodingRunResult{
		Status:      runResult.Status,
		TestsTotal:  runResult.TestsTotal,
		TestsPassed: runResult.TestsPassed,
	}
	item.Passed = &passed
	round.Items[idx] = item

	allAttempted := true
	passedCount := 0
	for _, it := range round.Items {
		if it.Passed == nil {
			allAttempted = false
			continue
		}
		if *it.Passed {
			passedCount++
		}
	}

	var score *float64
	if allAttempted {
		pct := float64(passedCount) / float64(len(round.Items)) * 100
		score = &pct
	}

	if err := s.repo.SaveRoundItems(ctx, roundID, round.Items, allAttempted, score); err != nil {
		return CodingItem{}, err
	}
	return item, nil
}
