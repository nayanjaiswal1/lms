package labauthor

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/labblock"
)

// blockingCodes are composition issues that adding more blocks can never fix:
// the wizard greys such a candidate out. Every other issue (an unmet
// requirement, missing check coverage) is a "need" a later step satisfies.
var blockingCodes = map[string]bool{
	labblock.CodeStackMismatch: true, labblock.CodeAppRange: true, labblock.CodeSlotConflict: true,
	labblock.CodeConflict: true, labblock.CodeChainInvalid: true, labblock.CodeChainTooLong: true,
	labblock.CodeUnknownKind: true, labblock.CodeBlockYanked: true, labblock.CodeBlockForeignOrg: true,
	labblock.CodeRoleCardinality: true, labblock.CodeBudget: true,
}

// Candidate is a block the builder wizard can offer at a step, judged by the
// real composition validator against the recipe as it is now.
type Candidate struct {
	Block BlockSummary `json:"block"`
	// VersionID is the pinned version when Selected, else the latest.
	VersionID  string             `json:"version_id"`
	Manifest   *labblock.Manifest `json:"manifest"`
	Selected   bool               `json:"selected"`
	Compatible bool               `json:"compatible"`
	// Blockers say why the block cannot join this recipe.
	Blockers []string `json:"blockers"`
	// Needs are requirements the block brings that later steps must satisfy.
	Needs []string `json:"needs"`
	// Suggested: adding the block satisfies a requirement the recipe has unmet.
	Suggested bool `json:"suggested"`
	// ChainAfter, set on a fault that is only blocked by sharing a slot with a
	// fault already in the recipe, is the fault key it can be added chained
	// after (compatible=true); the wizard adds it with that chain.
	ChainAfter string `json:"chain_after,omitempty"`
}

// Candidates lists the org-visible blocks of one kind for a recipe's wizard
// step. Unselected blocks are judged by validating the recipe with the
// block's latest version added; selected ones by the recipe's own analysis.
func (s *Service) Candidates(ctx context.Context, orgID, recipeID, kind string) ([]Candidate, error) {
	rc, err := s.repo.GetRecipe(ctx, orgID, recipeID)
	if err != nil {
		return nil, err
	}
	if !KindAllows(rc.LabKind, kind) {
		return nil, fmt.Errorf("%w: %s blocks are not valid in a %s recipe", ErrInvalidInput, kind, rc.LabKind)
	}
	blocks, err := s.repo.ListBlocks(ctx, orgID, BlockFilter{Kind: kind, Limit: maxPageSize})
	if err != nil {
		return nil, err
	}
	ids := versionIDs(rc.Spec)
	for _, b := range blocks {
		ids = append(ids, b.LatestVersionID)
	}
	vers, err := s.repo.ResolveVersions(ctx, orgID, ids)
	if err != nil {
		return nil, err
	}

	analyze := func(spec labblock.Spec) *Analysis {
		r, missing := BuildRecipe(rc.LabKind, orgID, spec, vers)
		if len(missing) > 0 {
			return &Analysis{Issues: missing}
		}
		return Analyze(r)
	}
	base := analyze(rc.Spec)
	baseUnmet := countCode(base.Issues, labblock.CodeUnsatisfied)
	pinned := map[string]string{} // block id -> pinned version id
	for _, ref := range rc.Spec.Blocks {
		if v, ok := vers[ref.BlockVersionID]; ok {
			pinned[v.BlockID] = ref.BlockVersionID
		}
	}

	inBase := map[string]bool{}
	for _, is := range base.Issues {
		inBase[issueKey(is)] = true
	}

	out := make([]Candidate, 0, len(blocks))
	for _, b := range blocks {
		c := Candidate{Block: b, VersionID: b.LatestVersionID, Blockers: []string{}, Needs: []string{}}
		an, added := base, false
		if id, ok := pinned[b.ID]; ok {
			c.Selected, c.VersionID = true, id
		} else {
			spec := rc.Spec
			spec.Blocks = append(append([]labblock.BlockRef(nil), rc.Spec.Blocks...), labblock.BlockRef{BlockVersionID: b.LatestVersionID})
			an, added = analyze(spec), true
			c.Suggested = countCode(an.Issues, labblock.CodeUnsatisfied) < baseUnmet
		}
		if v, ok := vers[c.VersionID]; ok {
			c.Manifest = v.Manifest
		}
		for _, is := range an.Issues {
			if is.Severity != labblock.SeverityError {
				continue
			}
			// A blocker is any blocking issue the block brings, whichever block
			// the validator reports it on (a slot conflict names the other fault).
			own := is.Block == b.Key
			brought := own || (added && !inBase[issueKey(is)])
			switch {
			case blockingCodes[is.Code] && brought:
				c.Blockers = append(c.Blockers, is.Message)
			case own:
				c.Needs = append(c.Needs, is.Message)
			}
		}
		if !c.Selected && kind == "fault" && len(c.Blockers) > 0 && onlySlotConflicts(an.Issues, b.Key, inBase) {
			c.ChainAfter = chainableAfter(rc.Spec, vers, b.LatestVersionID, analyze)
			if c.ChainAfter != "" {
				c.Blockers = []string{}
			}
		}
		c.Compatible = len(c.Blockers) == 0
		out = append(out, c)
	}
	return out, nil
}

func issueKey(is labblock.Issue) string { return is.Code + "|" + is.Block + "|" + is.Message }

func countCode(issues []labblock.Issue, code string) int {
	n := 0
	for _, is := range issues {
		if is.Code == code && is.Severity == labblock.SeverityError {
			n++
		}
	}
	return n
}

// onlySlotConflicts reports whether every blocking error the candidate brings
// is a slot conflict - the one blocker an explicit chain lifts (rule 3).
func onlySlotConflicts(issues []labblock.Issue, key string, inBase map[string]bool) bool {
	n := 0
	for _, is := range issues {
		if is.Severity != labblock.SeverityError || !blockingCodes[is.Code] || (is.Block != key && inBase[issueKey(is)]) {
			continue
		}
		if is.Code != labblock.CodeSlotConflict {
			return false
		}
		n++
	}
	return n > 0
}

// chainableAfter returns the key of a fault already in the recipe that the
// candidate version can follow without any blocking error ("" if none).
func chainableAfter(spec labblock.Spec, vers map[string]*labblock.ResolvedBlock, versionID string,
	analyze func(labblock.Spec) *Analysis) string {
	for _, ref := range spec.Blocks {
		v, ok := vers[ref.BlockVersionID]
		if !ok || v.Manifest.Kind != "fault" {
			continue
		}
		next := spec
		next.Blocks = append(append([]labblock.BlockRef(nil), spec.Blocks...),
			labblock.BlockRef{BlockVersionID: versionID, Chain: &labblock.Chain{After: v.Key, Mode: labblock.ChainMasks}})
		blocked := false
		for _, is := range analyze(next).Issues {
			if is.Severity == labblock.SeverityError && blockingCodes[is.Code] {
				blocked = true
				break
			}
		}
		if !blocked {
			return v.Key
		}
	}
	return ""
}
