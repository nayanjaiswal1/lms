package roadmap

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// matchThreshold is the minimum pg_trgm similarity score for a catalog match
// to be trusted. Below this, the module is left unmatched rather than linked
// to a plausibly-wrong resource — an unmatched checklist item is harmless, a
// wrong link sends the learner to the wrong content.
const matchThreshold = 0.3

// ParseAndMatchGenerated unmarshals the AI's JSON roadmap response, validates
// it, and resolves every module against the real content catalog. Returns the
// fully positioned Phase tree ready for Repo.ReplaceGeneratedTree. Used by the
// async job handler (jobs/handlers/llm.go) after the AI call completes.
func ParseAndMatchGenerated(ctx context.Context, pool *pgxpool.Pool, orgID *string, raw []byte) ([]Phase, error) {
	var gen generatedRoadmap
	if err := json.Unmarshal(raw, &gen); err != nil {
		return nil, fmt.Errorf("roadmap: parse AI response: %w", err)
	}
	if len(gen.Phases) == 0 {
		return nil, fmt.Errorf("roadmap: AI returned no phases")
	}

	phases := make([]Phase, 0, len(gen.Phases))
	for pi, gp := range gen.Phases {
		phase := Phase{Title: truncate(gp.Title, 200), Position: pi}
		if gp.Description != "" {
			d := gp.Description
			phase.Description = &d
		}
		if gp.EstimatedWeeks > 0 {
			w := gp.EstimatedWeeks
			phase.EstimatedWeeks = &w
		}

		milestones := make([]Milestone, 0, len(gp.Milestones))
		for mi, gm := range gp.Milestones {
			milestone := Milestone{Title: truncate(gm.Title, 200), Position: mi}
			if gm.Description != "" {
				d := gm.Description
				milestone.Description = &d
			}
			if gm.EstimatedHours > 0 {
				hrs := gm.EstimatedHours
				milestone.EstimatedHours = &hrs
			}

			modules, err := matchModules(ctx, pool, orgID, gm.Modules)
			if err != nil {
				return nil, err
			}
			milestone.Modules = modules
			milestones = append(milestones, milestone)
		}
		phase.Milestones = milestones
		phases = append(phases, phase)
	}
	return phases, nil
}

// RematchForOrg re-resolves every module in phases against orgID's own
// visibility scope, discarding whatever resource links the source tree had.
// Used when forking a public roadmap: courses/labs/questions are org-scoped
// catalogs, so a resource_id that was visible to the original creator's org
// may not exist or be visible to the forking user's org — carrying it over
// verbatim would risk linking to content the new user can't access. Re-
// matching by title against the new org is the same trusted path generation
// already uses, just re-run with a different scope.
func RematchForOrg(ctx context.Context, pool *pgxpool.Pool, orgID *string, phases []Phase) ([]Phase, error) {
	out := make([]Phase, len(phases))
	for pi, p := range phases {
		newMilestones := make([]Milestone, len(p.Milestones))
		for mi, m := range p.Milestones {
			gms := make([]generatedModule, len(m.Modules))
			for i, mod := range m.Modules {
				var desc string
				if mod.Description != nil {
					desc = *mod.Description
				}
				var mins int
				if mod.EstimatedMinutes != nil {
					mins = *mod.EstimatedMinutes
				}
				gms[i] = generatedModule{Title: mod.Title, Description: desc, ModuleType: mod.ModuleType, EstimatedMinutes: mins}
			}
			matched, err := matchModules(ctx, pool, orgID, gms)
			if err != nil {
				return nil, err
			}
			m.Modules = matched
			newMilestones[mi] = m
		}
		p.Milestones = newMilestones
		out[pi] = p
	}
	return out, nil
}

// matchModules resolves each generated module against real MindForge content
// (courses, labs, coding questions) when the module_type has a catalog to
// check and the roadmap has an org context to scope visibility by. Modules
// with no confident match, or no org context, are returned unmatched — the
// AI is never allowed to supply a resource itself (see RoadmapSystemPrompt).
func matchModules(ctx context.Context, pool *pgxpool.Pool, orgID *string, modules []generatedModule) ([]Module, error) {
	out := make([]Module, 0, len(modules))
	for i, gm := range modules {
		modType := gm.ModuleType
		if !validModuleTypes[modType] {
			modType = ModuleTypeReading
		}

		mod := Module{
			Title:      truncate(gm.Title, 200),
			ModuleType: modType,
			Position:   i,
		}
		if gm.Description != "" {
			desc := gm.Description
			mod.Description = &desc
		}
		if gm.EstimatedMinutes > 0 {
			mins := gm.EstimatedMinutes
			mod.EstimatedMinutes = &mins
		}

		if orgID != nil && *orgID != "" {
			resType, resID, err := matchOne(ctx, pool, *orgID, modType, gm.Title)
			if err != nil {
				return nil, err
			}
			if resType != "" {
				mod.ResourceType = &resType
				mod.ResourceID = &resID
			}
		}

		out = append(out, mod)
	}
	return out, nil
}

func matchOne(ctx context.Context, pool *pgxpool.Pool, orgID, moduleType, title string) (string, string, error) {
	var query string
	var resourceType string

	switch moduleType {
	case ModuleTypeCourse:
		query = `SELECT id FROM courses
		         WHERE status = 'published' AND (is_public OR org_id = $2)
		           AND similarity(title, $1) > $3
		         ORDER BY similarity(title, $1) DESC LIMIT 1`
		resourceType = ResourceTypeCourse
	case ModuleTypeLab:
		query = `SELECT id FROM lab_definitions
		         WHERE is_published AND org_id = $2
		           AND similarity(title, $1) > $3
		         ORDER BY similarity(title, $1) DESC LIMIT 1`
		resourceType = ResourceTypeLab
	case ModuleTypeDSAProblem:
		query = `SELECT id FROM questions
		         WHERE status = 'active' AND type = 'coding' AND org_id = $2
		           AND similarity(title, $1) > $3
		         ORDER BY similarity(title, $1) DESC LIMIT 1`
		resourceType = ResourceTypeQuestion
	default:
		// project, reading, quiz — no catalog to match against.
		return "", "", nil
	}

	var id string
	err := pool.QueryRow(ctx, query, title, orgID, matchThreshold).Scan(&id)
	if err != nil {
		if err == pgx.ErrNoRows {
			return "", "", nil
		}
		return "", "", fmt.Errorf("roadmap: match %s %q: %w", moduleType, title, err)
	}
	return resourceType, id, nil
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}
