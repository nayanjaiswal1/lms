package interviewprep

import (
	"context"
	"encoding/json"
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
	maxJDChars              = 4000
	maxJobTitleChars        = 200
	codingTimeLimitMs       = 5000
	codingMemoryLimitKb     = 256 * 1024
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
	Skills     []string `json:"skills"`
	FocusAreas []string `json:"focus_areas"`
}

func (s *Service) CreatePlan(ctx context.Context, userID string, orgID *string, jobTitle, jdText string) (Plan, error) {
	if !s.ai.Available() {
		return Plan{}, fmt.Errorf("interviewprep: AI provider not available")
	}

	profile, model, err := s.extractProfile(ctx, jobTitle, jdText)
	if err != nil {
		return Plan{}, err
	}

	// Round 1 (conceptual) — delegates entirely to the existing practice engine.
	// technology is the joined skill list; difficulty is the extracted seniority.
	practiceSession, err := s.practiceSvc.CreateSession(ctx, userID, orgID,
		strings.Join(profile.Skills, ", "), profile.Seniority, conceptualQuestionCount, "")
	if err != nil {
		return Plan{}, fmt.Errorf("interviewprep: create conceptual round: %w", err)
	}

	// Round 2 (coding) — self-contained, generated here.
	codingItems, err := s.generateCodingItems(ctx, profile)
	if err != nil {
		return Plan{}, fmt.Errorf("interviewprep: create coding round: %w", err)
	}

	var jdPtr *string
	if strings.TrimSpace(jdText) != "" {
		jdPtr = &jdText
	}

	plan := Plan{
		UserID:             userID,
		OrgID:              orgID,
		JobTitle:           jobTitle,
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
			RoundType:         RoundConceptual,
			OrderIndex:        0,
			PracticeSessionID: &practiceSessionID,
			Status:            RoundActive,
		},
		{
			RoundType:  RoundCoding,
			OrderIndex: 1,
			Items:      codingItems,
			Status:     RoundPending,
		},
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
		MaxTokens:    2048,
		Temperature:  0.6,
		JSONMode:     true,
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
