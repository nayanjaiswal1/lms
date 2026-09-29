package labkinds

import (
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/mindforge/backend/internal/labblock"
)

// Debug-kind composition rules (docs/debug-labs.md Part 2 §B2 rules 3, 4, 6,
// 8 and the §B7 value-slot trust boundary). The generic engine
// (internal/labauthor) has already run stack/capability/conflict/budget/param
// checks; everything here is about faults, slots and chains.

// Issue codes local to the debug kind.
const (
	codeSlotUnknown    = "slot_unknown"
	codeCardinality    = labblock.CodeRoleCardinality
	maxFaultsPerRecipe = 3
	minRedHerringsBump = 2
)

var paramRefRe = regexp.MustCompile(`\{\{\s*params\.([A-Za-z_][A-Za-z0-9_]*)\s*\}\}`)

// customCombinesDefault is what a `custom` (hand-made scenario) block may be
// combined with when its manifest does not say otherwise.
var customCombinesDefault = []string{"ticket", "hints", "rubric"}

// ValidateRecipe implements Kind.
func (DebugKind) ValidateRecipe(r *labblock.Recipe, pv labblock.ParamValidator) []labblock.Issue {
	var issues []labblock.Issue
	apps := r.ByKind("app")
	faults := r.ByKind("fault")
	customs := r.ByKind("custom")

	// Cardinality.
	if len(customs) > 1 {
		issues = append(issues, labblock.Errf(codeCardinality, customs[1].Key, "a recipe takes at most one custom block"))
	}
	for _, k := range []string{"ticket", "hints", "rubric"} {
		if bs := r.ByKind(k); len(bs) > 1 {
			issues = append(issues, labblock.Errf(codeCardinality, bs[1].Key, fmt.Sprintf("a recipe takes at most one %s block", k)))
		}
	}
	if len(r.ByKind("ticket")) == 0 {
		issues = append(issues, labblock.Warnf(codeCardinality, "", "no ticket block: the brief will be generated from the fault symptom only"))
	}

	if len(customs) == 1 {
		allowed := customs[0].Manifest.Custom.CombinesWith
		if len(allowed) == 0 {
			allowed = customCombinesDefault
		}
		for _, b := range r.Blocks {
			if b == customs[0] {
				continue
			}
			if !contains(allowed, b.Manifest.Kind) {
				issues = append(issues, labblock.Errf(codeCardinality, b.Key,
					fmt.Sprintf("a custom scenario only combines with %s blocks", strings.Join(allowed, "/"))))
			}
		}
		return issues
	}

	if len(apps) != 1 {
		issues = append(issues, labblock.Errf(codeCardinality, "", fmt.Sprintf("a recipe needs exactly one app block (has %d)", len(apps))))
		return issues
	}
	if len(faults) == 0 {
		issues = append(issues, labblock.Errf(codeCardinality, "", "a recipe needs at least one fault"))
		return issues
	}
	app := apps[0]
	if len(faults) > maxFaultsPerRecipe {
		issues = append(issues, labblock.Errf(labblock.CodeChainTooLong, "",
			fmt.Sprintf("a recipe takes at most %d faults in v1 (has %d)", maxFaultsPerRecipe, len(faults))))
	}

	slots := map[string]labblock.SlotDecl{}
	for _, s := range app.Manifest.App.Slots {
		slots[s.Name] = s
	}
	features := map[string]bool{}
	for _, f := range app.Manifest.App.Features {
		features[f] = true
	}

	issues = append(issues, debugChains(faults)...)
	issues = append(issues, debugSlots(faults, slots)...)
	for _, f := range faults {
		issues = append(issues, debugFaultRules(r, f, app, slots, features, pv)...)
	}
	return issues
}

// debugChains implements rule 4: chain targets exist, modes are valid, chains
// are acyclic.
func debugChains(faults []*labblock.ResolvedBlock) []labblock.Issue {
	var issues []labblock.Issue
	after := map[string]string{}
	inRecipe := map[string]bool{}
	for _, f := range faults {
		inRecipe[f.Key] = true
	}
	for _, f := range faults {
		c := f.Manifest.Fault.Chain
		if c == nil {
			continue
		}
		if c.Mode != labblock.ChainMasks && c.Mode != labblock.ChainCompounds {
			issues = append(issues, labblock.Errf(labblock.CodeChainInvalid, f.Key, `chain.mode must be "masks" or "compounds"`))
		}
		if c.After == f.Key {
			issues = append(issues, labblock.Errf(labblock.CodeChainInvalid, f.Key, "a fault cannot chain after itself"))
			continue
		}
		if !inRecipe[c.After] {
			issues = append(issues, labblock.Errf(labblock.CodeChainInvalid, f.Key,
				fmt.Sprintf("chains after %q, which is not in this recipe", c.After)))
			continue
		}
		after[f.Key] = c.After
	}
	for _, f := range faults {
		seen := map[string]bool{f.Key: true}
		for cur := after[f.Key]; cur != ""; cur = after[cur] {
			if seen[cur] {
				issues = append(issues, labblock.Errf(labblock.CodeChainInvalid, f.Key, "fault chains form a cycle"))
				break
			}
			seen[cur] = true
		}
	}
	return issues
}

// debugSlots implements rule 3: one fault per slot, except explicit chains;
// migration slots are ordered insertion points and exempt.
func debugSlots(faults []*labblock.ResolvedBlock, slots map[string]labblock.SlotDecl) []labblock.Issue {
	var issues []labblock.Issue
	chained := func(a, b *labblock.ResolvedBlock) bool {
		ca, cb := a.Manifest.Fault.Chain, b.Manifest.Fault.Chain
		return (ca != nil && ca.After == b.Key) || (cb != nil && cb.After == a.Key)
	}
	owners := map[string][]*labblock.ResolvedBlock{}
	for _, f := range faults {
		for _, so := range f.Manifest.Fault.Inject.Slots {
			decl, ok := slots[so.Slot]
			if !ok {
				issues = append(issues, labblock.Errf(codeSlotUnknown, f.Key,
					fmt.Sprintf("overrides slot %q, which the app does not declare", so.Slot)))
				continue
			}
			if decl.Type != labblock.SlotMigration {
				owners[so.Slot] = append(owners[so.Slot], f)
			}
		}
	}
	names := make([]string, 0, len(owners))
	for n := range owners {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		fs := owners[n]
		for i := 0; i < len(fs); i++ {
			for j := i + 1; j < len(fs); j++ {
				if !chained(fs[i], fs[j]) {
					issues = append(issues, labblock.Errf(labblock.CodeSlotConflict, fs[j].Key,
						fmt.Sprintf("slot %q is also overridden by %q (only chained faults may share a slot)", n, fs[i].Key)))
				}
			}
		}
	}
	return issues
}

// debugFaultRules covers rule 6 (check + carrier coverage) and the value-slot
// trust boundary for one fault.
func debugFaultRules(r *labblock.Recipe, f, app *labblock.ResolvedBlock, slots map[string]labblock.SlotDecl, features map[string]bool, pv labblock.ParamValidator) []labblock.Issue {
	var issues []labblock.Issue
	fs := f.Manifest.Fault

	symptoms := 0
	for _, c := range fs.Checks {
		if c.Role != labblock.CheckSymptom && c.Role != labblock.CheckRegression {
			issues = append(issues, labblock.Errf(labblock.CodeCheckCoverage, f.Key, fmt.Sprintf("check %q has role %q; want symptom or regression", c.Ref, c.Role)))
			continue
		}
		if c.Role == labblock.CheckSymptom {
			symptoms++
		}
		cb := r.ByKey(c.Ref)
		if cb == nil || cb.Manifest.Kind != "check" {
			issues = append(issues, labblock.Errf(labblock.CodeUnsatisfied, f.Key, fmt.Sprintf("references check block %q, which is not in the recipe", c.Ref)))
			continue
		}
		if len(c.Params) > 0 && pv != nil {
			issues = append(issues, pv(cb, c.Params)...)
		}
	}
	if symptoms == 0 {
		issues = append(issues, labblock.Errf(labblock.CodeCheckCoverage, f.Key, "fault has no symptom check"))
	}

	switch {
	case fs.Carrier.Feature == "":
		issues = append(issues, labblock.Errf(labblock.CodeCarrierCoverage, f.Key, "fault declares no carrier feature (git revert would pass the regression suite)"))
	case !features[fs.Carrier.Feature]:
		issues = append(issues, labblock.Errf(labblock.CodeCarrierCoverage, f.Key,
			fmt.Sprintf("carrier feature %q is not covered by the app's regression suite (%s)", fs.Carrier.Feature, app.Key)))
	}

	// Value-slot trust boundary: params only enter source through `value`
	// slots, and only with a matching literal type.
	props, _ := f.Manifest.Params["properties"].(map[string]any)
	overrideSets := []labblock.Overrides{fs.Inject, fs.Fix, fs.Carrier.Overrides}
	for _, ch := range fs.Cheats {
		overrideSets = append(overrideSets, ch.Overrides)
	}
	for _, os := range overrideSets {
		for _, so := range os.Slots {
			for _, m := range paramRefRe.FindAllStringSubmatch(so.Value, -1) {
				issues = append(issues, checkParamSlot(f.Key, m[1], so.Slot, props, slots)...)
			}
		}
	}
	return issues
}

func checkParamSlot(faultKey, param, slot string, props map[string]any, slots map[string]labblock.SlotDecl) []labblock.Issue {
	unsafe := func(msg string) []labblock.Issue {
		return []labblock.Issue{labblock.Errf(labblock.CodeParamLiteral, faultKey, msg)}
	}
	decl, ok := slots[slot]
	if !ok {
		return nil // reported by debugSlots
	}
	p, ok := props[param].(map[string]any)
	if !ok {
		return unsafe(fmt.Sprintf("slot %q references undeclared param %q", slot, param))
	}
	if decl.Type != labblock.SlotValue {
		return unsafe(fmt.Sprintf("param %q is interpolated into %s slot %q; params may only enter source through value slots", param, decl.Type, slot))
	}
	typ, _ := p["type"].(string)
	use, _ := p["x-mf-use"].(string)
	paramLit := strings.TrimPrefix(use, "literal:")
	if typ == "string" && !strings.HasPrefix(use, "literal:") {
		return unsafe(fmt.Sprintf("string param %q lacks x-mf-use literal:<type> and cannot be placed in slot %q", param, slot))
	}
	if !literalAccepts(decl.Literal, typ, paramLit) {
		return unsafe(fmt.Sprintf("param %q (%s %s) does not fit slot %q, which takes a %s literal", param, typ, paramLit, slot, decl.Literal))
	}
	return nil
}

// literalAccepts reports whether a param of JSON type paramType (and, for
// strings, declared literal paramLit) may be rendered into a slot whose
// declared literal type is slotLit.
func literalAccepts(slotLit, paramType, paramLit string) bool {
	if slotLit == "" {
		return false
	}
	switch paramType {
	case "string":
		return paramLit == slotLit
	case "integer":
		return contains([]string{labblock.LitPythonInt, labblock.LitPythonFloat, labblock.LitJSNumber, labblock.LitJSON}, slotLit)
	case "number":
		return contains([]string{labblock.LitPythonFloat, labblock.LitJSNumber, labblock.LitJSON}, slotLit)
	case "boolean":
		return contains([]string{labblock.LitPythonBool, labblock.LitJSBool, labblock.LitJSON}, slotLit)
	}
	return false
}

// DeriveDifficulty implements Kind (rule 8): the hardest fault, +1 for a
// `masks` chain, +1 for two or more red herrings, clamped to the top level.
func (DebugKind) DeriveDifficulty(r *labblock.Recipe) string {
	faults := r.ByKind("fault")
	if len(faults) == 0 {
		return ""
	}
	rank := func(d string) int {
		for i, x := range labblock.Difficulties {
			if x == d {
				return i
			}
		}
		return 0
	}
	level := 0
	masks := false
	for _, f := range faults {
		if v := rank(f.Manifest.Difficulty); v > level {
			level = v
		}
		if c := f.Manifest.Fault.Chain; c != nil && c.Mode == labblock.ChainMasks {
			masks = true
		}
	}
	if masks {
		level++
	}
	herrings := 0
	for _, t := range r.ByKind("ticket") {
		herrings += len(t.Manifest.Ticket.RedHerrings)
	}
	if herrings >= minRedHerringsBump {
		level++
	}
	if level >= len(labblock.Difficulties) {
		level = len(labblock.Difficulties) - 1
	}
	return labblock.Difficulties[level]
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}
