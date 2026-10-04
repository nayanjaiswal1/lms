package labauthor

import (
	"fmt"

	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labkinds"
)

// Budget limits (rule 7, docs/debug-labs.md §B2). They are properties of the
// build pipeline (sandbox setup time and bundle sizes the runtime tolerates),
// not tenant settings, so they live here as named constants.
const (
	MaxSetupSeconds   = 25
	MaxWorkspaceBytes = 2 << 20
	MaxGraderBytes    = 512 << 10
	// maxDifficultyGap is the widest difficulty spread a fault pool may have.
	maxDifficultyGap = 1
)

// Analysis is the full, side-effect-free result of validating a recipe.
type Analysis struct {
	Issues []labblock.Issue `json:"issues"`
	// Valid is true when no issue has error severity.
	Valid bool `json:"valid"`
	// RecipeHash is sha256 of the canonical resolved spec ("" if the recipe
	// could not be resolved far enough to hash).
	RecipeHash string `json:"recipe_hash"`
	// DerivedDifficulty is what the lab kind derives (rule 8); Difficulty is
	// the effective value (the author's override when set).
	DerivedDifficulty string `json:"derived_difficulty"`
	Difficulty        string `json:"difficulty"`
	// VariantCount is how many variants a build would materialise (<= 8);
	// VariantTotal is the full product before capping.
	VariantCount int `json:"variant_count"`
	VariantTotal int `json:"variant_total"`
	// Budget is the worst-case estimated resource use across pool choices.
	Budget labblock.Budget `json:"budget"`
}

// Validate is the composition validator: rules 1-8 of docs/debug-labs.md §B2
// over manifests only, in milliseconds, with no side effects.
func Validate(r *labblock.Recipe) []labblock.Issue { return Analyze(r).Issues }

// issueSet collects issues de-duplicated by (code, block, message) - the same
// finding is reported once even when several pool combinations trigger it.
type issueSet struct {
	seen map[string]bool
	list []labblock.Issue
}

func (s *issueSet) add(is ...labblock.Issue) {
	if s.seen == nil {
		s.seen = map[string]bool{}
	}
	for _, i := range is {
		k := i.Code + "\x00" + i.Block + "\x00" + i.Message
		if !s.seen[k] {
			s.seen[k] = true
			s.list = append(s.list, i)
		}
	}
}

// Analyze validates r and computes its hash, difficulty, variant count and
// budget. Order of checks: block-level (yank, org scope, kind allowed,
// section present) -> parameters -> pools -> per pool combination: stack and
// app range (1), capabilities (2), conflicts (5), budgets (7), then the lab
// kind's own rules (3, 4, 6 and difficulty 8 for debug).
func Analyze(r *labblock.Recipe) *Analysis {
	a := &Analysis{}
	var is issueSet
	defer func() {
		a.Issues = is.list
		if a.Issues == nil {
			a.Issues = []labblock.Issue{}
		}
		a.Valid = !labblock.HasErrors(a.Issues)
	}()

	kind, ok := labkinds.Get(r.LabKind)
	if !ok {
		is.add(labblock.Errf(labblock.CodeUnknownKind, "", fmt.Sprintf("unknown lab kind %q", r.LabKind)))
		return a
	}
	if len(r.Blocks) == 0 {
		is.add(labblock.Errf(labblock.CodeRoleCardinality, "", "recipe has no blocks"))
		return a
	}

	structural := false
	seenVersion := map[string]bool{}
	for _, b := range r.Blocks {
		if b.Manifest == nil {
			is.add(labblock.Errf(labblock.CodeBlockNotFound, b.Key, "block version has no manifest"))
			structural = true
			continue
		}
		if seenVersion[b.VersionID] {
			is.add(labblock.Errf(labblock.CodeRoleCardinality, b.Key, "block is listed twice"))
		}
		seenVersion[b.VersionID] = true
		if b.Yanked {
			is.add(labblock.Errf(labblock.CodeBlockYanked, b.Key, fmt.Sprintf("version %s was yanked and cannot be used in new builds", b.Version)))
		}
		if b.OrgID != nil && *b.OrgID != r.OrgID {
			is.add(labblock.Errf(labblock.CodeBlockForeignOrg, b.Key, "block belongs to another organization"))
			structural = true
		}
		if !KindAllows(r.LabKind, b.Manifest.Kind) {
			is.add(labblock.Errf(labblock.CodeUnknownKind, b.Key, fmt.Sprintf("%s blocks are not valid in a %s recipe", b.Manifest.Kind, r.LabKind)))
			structural = true
		} else if n, own := sectionCount(b.Manifest); !own || n != 1 {
			is.add(labblock.Errf(labblock.CodeManifestInvalid, b.Key, "manifest section does not match its kind"))
			structural = true
		}
	}
	if structural {
		return a
	}

	resolveParams(r, &is)
	poolIssues(r, &is)

	sets, err := activeSets(r)
	if err != nil {
		is.add(labblock.Errf(labblock.CodePoolInvalid, "", err.Error()))
		return a
	}
	pv := func(b *labblock.ResolvedBlock, values map[string]any) []labblock.Issue {
		eff, err := effectiveParams(b.Manifest, b.Params, values)
		if err != nil {
			return []labblock.Issue{labblock.Errf(labblock.CodeParamInvalid, b.Key, err.Error())}
		}
		return validateParamValues(b.Manifest, eff)
	}

	worst := -1
	for _, set := range sets {
		sub := &labblock.Recipe{LabKind: r.LabKind, OrgID: r.OrgID, Spec: r.Spec, Blocks: set}
		is.add(stackIssues(sub)...)
		is.add(checkCapabilities(set)...)
		bud := budgetOf(set)
		is.add(budgetIssues(bud)...)
		a.Budget = maxBudget(a.Budget, bud)
		is.add(kind.ValidateRecipe(sub, pv)...)
		if d := kind.DeriveDifficulty(sub); d != "" && rankOf(d) > worst {
			worst = rankOf(d)
			a.DerivedDifficulty = d
		}
	}

	a.Difficulty = a.DerivedDifficulty
	if o := r.Spec.DifficultyOverride; o != "" {
		if contains(labblock.Difficulties, o) {
			a.Difficulty = o
		} else {
			is.add(labblock.Errf(labblock.CodeManifestInvalid, "", fmt.Sprintf("difficulty_override %q is not a valid difficulty", o)))
		}
	}
	if a.DerivedDifficulty != "" {
		is.add(labblock.Issue{Code: labblock.CodeDifficultyDerived, Severity: labblock.SeverityInfo,
			Message: "derived difficulty: " + a.DerivedDifficulty})
	}

	if !labblock.HasErrors(is.list) {
		h, err := RecipeHash(r)
		if err != nil {
			is.add(labblock.Errf(labblock.CodeManifestInvalid, "", err.Error()))
			return a
		}
		a.RecipeHash = h
		variants, total, err := EnumerateVariants(r)
		if err != nil {
			is.add(labblock.Errf(labblock.CodePoolInvalid, "", err.Error()))
			return a
		}
		a.VariantCount, a.VariantTotal = len(variants), total
		if total > MaxVariants {
			is.add(labblock.Warnf(labblock.CodeVariantsCapped, "",
				fmt.Sprintf("%d variant combinations; %d evenly spaced ones will be built and verified", total, MaxVariants)))
		}
	}
	return a
}

func rankOf(d string) int {
	for i, x := range labblock.Difficulties {
		if x == d {
			return i
		}
	}
	return -1
}

// resolveParams fills each block's effective params (defaults <- matching
// preset <- explicit) and validates them against the block's JSON Schema.
func resolveParams(r *labblock.Recipe, is *issueSet) {
	presets := map[string][]*labblock.ResolvedBlock{}
	for _, b := range r.ByKind(labblock.KindPreset) {
		presets[b.Manifest.Preset.Target] = append(presets[b.Manifest.Preset.Target], b)
	}
	for target, ps := range presets {
		switch {
		case r.ByKey(target) == nil:
			is.add(labblock.Warnf(labblock.CodeParamInvalid, ps[0].Key, fmt.Sprintf("preset targets %q, which is not in the recipe", target)))
		case len(ps) > 1:
			is.add(labblock.Errf(labblock.CodeParamInvalid, ps[1].Key, fmt.Sprintf("more than one preset targets %q", target)))
		}
	}
	for _, b := range r.Blocks {
		if b.Manifest.Kind == labblock.KindPreset {
			b.Params = map[string]any{}
			continue
		}
		var preset map[string]any
		if ps := presets[b.Key]; len(ps) > 0 {
			preset = ps[0].Manifest.Preset.Values
		}
		eff, err := effectiveParams(b.Manifest, preset, b.Ref.Params)
		if err != nil {
			is.add(labblock.Errf(labblock.CodeParamInvalid, b.Key, err.Error()))
			continue
		}
		b.Params = eff
		is.add(validateParamValues(b.Manifest, eff)...)
	}
}

// poolIssues checks fault pools (docs/debug-labs.md §B6): >= 2 members, all of
// one kind and category, difficulty within +-1.
func poolIssues(r *labblock.Recipe, is *issueSet) {
	pools := map[string][]*labblock.ResolvedBlock{}
	for _, b := range r.Blocks {
		if b.Ref.Pool != "" {
			pools[b.Ref.Pool] = append(pools[b.Ref.Pool], b)
		}
	}
	for _, name := range sortedNames(pools) {
		ms := pools[name]
		if len(ms) < 2 {
			is.add(labblock.Errf(labblock.CodePoolInvalid, ms[0].Key, fmt.Sprintf("pool %q needs at least 2 members", name)))
			continue
		}
		lo, hi := 99, -1
		for _, m := range ms[1:] {
			if m.Manifest.Kind != ms[0].Manifest.Kind {
				is.add(labblock.Errf(labblock.CodePoolInvalid, m.Key, fmt.Sprintf("pool %q mixes block kinds", name)))
			}
			if m.Manifest.Category != ms[0].Manifest.Category {
				is.add(labblock.Errf(labblock.CodePoolInvalid, m.Key, fmt.Sprintf("pool %q members must share a category", name)))
			}
		}
		for _, m := range ms {
			if v := rankOf(m.Manifest.Difficulty); v >= 0 {
				lo, hi = min(lo, v), max(hi, v)
			}
		}
		if hi >= 0 && hi-lo > maxDifficultyGap {
			is.add(labblock.Errf(labblock.CodePoolInvalid, ms[0].Key, fmt.Sprintf("pool %q members must be within %d difficulty level of each other", name, maxDifficultyGap)))
		}
	}
}

// stackIssues implements rule 1: every block's stack equals the app's stack or
// "any", and the app's version satisfies the recipe's app range.
func stackIssues(r *labblock.Recipe) []labblock.Issue {
	apps := r.ByKind("app")
	if len(apps) == 0 {
		return nil
	}
	app := apps[0]
	var out []labblock.Issue
	for _, b := range r.Blocks {
		if s := b.Manifest.Stack; s != "any" && s != app.Manifest.Stack {
			out = append(out, labblock.Errf(labblock.CodeStackMismatch, b.Key,
				fmt.Sprintf("stack %q does not match the app's stack %q", s, app.Manifest.Stack)))
		}
	}
	if rng := r.Spec.AppRange; rng != "" {
		rg, err := labblock.ParseRange(rng)
		v, verr := labblock.ParseVersion(app.Version)
		switch {
		case err != nil:
			out = append(out, labblock.Errf(labblock.CodeAppRange, app.Key, "invalid app_range: "+err.Error()))
		case verr != nil || !rg.Contains(v):
			out = append(out, labblock.Errf(labblock.CodeAppRange, app.Key, fmt.Sprintf("app version %s is outside the required range %s", app.Version, rng)))
		}
	}
	return out
}

func budgetOf(set []*labblock.ResolvedBlock) labblock.Budget {
	var b labblock.Budget
	for _, blk := range set {
		b.SetupSeconds += blk.Manifest.Budget.SetupSeconds
		b.WorkspaceBytes += blk.Manifest.Budget.WorkspaceBytes
		b.GraderBytes += blk.Manifest.Budget.GraderBytes
	}
	return b
}

func maxBudget(a, b labblock.Budget) labblock.Budget {
	return labblock.Budget{
		SetupSeconds:   max(a.SetupSeconds, b.SetupSeconds),
		WorkspaceBytes: max(a.WorkspaceBytes, b.WorkspaceBytes),
		GraderBytes:    max(a.GraderBytes, b.GraderBytes),
	}
}

// budgetIssues implements rule 7.
func budgetIssues(b labblock.Budget) []labblock.Issue {
	var out []labblock.Issue
	if b.SetupSeconds > MaxSetupSeconds {
		out = append(out, labblock.Errf(labblock.CodeBudget, "", fmt.Sprintf("estimated setup %ds exceeds %ds", b.SetupSeconds, MaxSetupSeconds)))
	}
	if b.WorkspaceBytes > MaxWorkspaceBytes {
		out = append(out, labblock.Errf(labblock.CodeBudget, "", fmt.Sprintf("estimated workspace %d bytes exceeds %d", b.WorkspaceBytes, MaxWorkspaceBytes)))
	}
	if b.GraderBytes > MaxGraderBytes {
		out = append(out, labblock.Errf(labblock.CodeBudget, "", fmt.Sprintf("estimated grader bundle %d bytes exceeds %d", b.GraderBytes, MaxGraderBytes)))
	}
	return out
}

// BuildRecipe joins a spec's block refs to their stored versions. versions is
// keyed by block_version_id and must contain only rows the caller's org may
// see (platform + own-org); a ref with no row becomes a block_not_found issue,
// which also covers another org's block (its existence is never revealed).
func BuildRecipe(labKind, orgID string, spec labblock.Spec, versions map[string]*labblock.ResolvedBlock) (*labblock.Recipe, []labblock.Issue) {
	r := &labblock.Recipe{LabKind: labKind, OrgID: orgID, Spec: spec}
	var issues []labblock.Issue
	for _, ref := range spec.Blocks {
		v, ok := versions[ref.BlockVersionID]
		if !ok {
			issues = append(issues, labblock.Errf(labblock.CodeBlockNotFound, ref.BlockVersionID, "block version not found or not visible to your organization"))
			continue
		}
		cp := *v
		cp.Ref = ref
		cp.Params = nil
		if ref.Chain != nil && v.Manifest.Fault != nil {
			// The recipe's chain replaces the manifest's, on private copies
			// (the resolved manifest is shared with other recipes).
			m, f := *v.Manifest, *v.Manifest.Fault
			f.Chain = ref.Chain
			m.Fault = &f
			cp.Manifest = &m
		}
		r.Blocks = append(r.Blocks, &cp)
	}
	return r, issues
}
