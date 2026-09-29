package labauthor

import (
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labkinds"
)

const (
	maxTemplateLen = 20000
	maxLadderItem  = 2000
	hintLadderLen  = 3
)

var blockIDRe = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)+(:[A-Za-z0-9_.-]+)?$`)

// AllBlockKinds is the union of every registered lab kind's BlockKinds() and
// the shared kinds (preset). Block kinds are validated in Go, never by a DB
// enum, so a new lab kind adds its own without a migration.
func AllBlockKinds() []string {
	set := map[string]bool{labblock.KindPreset: true}
	for _, k := range labkinds.Default.All() {
		for _, bk := range k.BlockKinds() {
			set[bk] = true
		}
	}
	return sortedNames(set)
}

// KindAllows reports whether a recipe of labKind may contain blocks of
// blockKind.
func KindAllows(labKind, blockKind string) bool {
	if blockKind == labblock.KindPreset {
		return true
	}
	k, ok := labkinds.Get(labKind)
	return ok && contains(k.BlockKinds(), blockKind)
}

// IsTextKind reports whether blockKind may be authored by an org instructor.
func IsTextKind(blockKind string) bool { return contains(labblock.TextKinds, blockKind) }

// sectionCount returns how many kind sections m carries and whether the one
// named after m.Kind is among them.
func sectionCount(m *labblock.Manifest) (n int, own bool) {
	present := map[string]bool{
		"app": m.App != nil, "fault": m.Fault != nil, "data": m.Data != nil, "stub": m.Stub != nil,
		"env": m.Env != nil, "check": m.Check != nil, "ticket": m.Ticket != nil, "hints": m.Hints != nil,
		"rubric": m.Rubric != nil, "preset": m.Preset != nil, "custom": m.Custom != nil,
	}
	for _, p := range present {
		if p {
			n++
		}
	}
	return n, present[m.Kind]
}

// ValidateManifest checks one block manifest structurally: identity fields,
// enum-like fields, capability tokens, the params schema (incl. string-param
// use rules and randomize), and the kind section. It does not check the
// payload directory (see sync.go) or cross-block rules (see Validate).
func ValidateManifest(m *labblock.Manifest) []labblock.Issue {
	var issues []labblock.Issue
	fail := func(msg string) {
		issues = append(issues, labblock.Errf(labblock.CodeManifestInvalid, m.ID, msg))
	}
	if !contains(AllBlockKinds(), m.Kind) {
		issues = append(issues, labblock.Errf(labblock.CodeUnknownKind, m.ID, fmt.Sprintf("unknown block kind %q", m.Kind)))
		return issues
	}
	if !blockIDRe.MatchString(m.ID) {
		fail(fmt.Sprintf("id %q must be a dotted, lowercase, namespaced key like dj.perf.n-plus-one-list", m.ID))
	}
	if _, err := labblock.ParseVersion(m.Version); err != nil {
		fail("version: " + err.Error())
	}
	if !contains(labblock.Stacks, m.Stack) {
		fail(fmt.Sprintf("stack %q must be one of %s", m.Stack, strings.Join(labblock.Stacks, "|")))
	}
	if strings.TrimSpace(m.Title) == "" || strings.TrimSpace(m.Summary) == "" {
		fail("title and summary are required")
	}
	if m.Difficulty != "" && !contains(labblock.Difficulties, m.Difficulty) {
		fail(fmt.Sprintf("difficulty %q must be one of %s", m.Difficulty, strings.Join(labblock.Difficulties, "|")))
	}
	if m.Kind == "fault" && (m.Difficulty == "" || m.Category == "") {
		fail("faults require category and difficulty")
	}
	for _, t := range m.Conflicts {
		// a conflict names a capability token or another block's key.
		if !validToken(t) && !blockIDRe.MatchString(t) {
			fail(fmt.Sprintf("conflict %q is neither a capability token nor a block key", t))
		}
	}
	for _, t := range append(append([]string(nil), m.Requires...), m.Provides...) {
		if !validToken(t) {
			fail(fmt.Sprintf("%q is not a capability token (slot:|cap:|data:|svc:|env:)", t))
		}
	}
	if m.Budget.SetupSeconds < 0 || m.Budget.WorkspaceBytes < 0 || m.Budget.GraderBytes < 0 {
		fail("budget values must be >= 0")
	}
	issues = append(issues, validateParamsSchema(m)...)

	n, own := sectionCount(m)
	if !own || n != 1 {
		fail(fmt.Sprintf("a %s block must carry exactly one section, named %q", m.Kind, m.Kind))
		return issues
	}
	for _, msg := range validateSection(m) {
		fail(msg)
	}
	return issues
}

func validateSection(m *labblock.Manifest) []string {
	var p []string
	add := func(f string, a ...any) { p = append(p, fmt.Sprintf(f, a...)) }
	switch m.Kind {
	case "app":
		a := m.App
		if a.Language != "python" && a.Language != "js" {
			add("app.language must be python or js")
		}
		if len(a.Features) == 0 {
			add("app.features must list the feature tags the regression suite covers")
		}
		seen := map[string]bool{}
		for _, s := range a.Slots {
			switch {
			case s.Name == "" || seen[s.Name]:
				add("app.slots: empty or duplicate slot name %q", s.Name)
			case !contains([]string{labblock.SlotRegion, labblock.SlotValue, labblock.SlotFile, labblock.SlotMigration}, s.Type):
				add("app.slots.%s: type %q is not region|value|file|migration", s.Name, s.Type)
			case s.Type == labblock.SlotValue && !validLiterals[s.Literal]:
				add("app.slots.%s: value slots must declare a known literal type", s.Name)
			}
			seen[s.Name] = true
		}
	case "fault":
		f := m.Fault
		if len(f.Inject.Slots)+len(f.Inject.Files)+len(f.Inject.Migrations) == 0 {
			add("fault.inject is empty")
		}
		if len(f.Fix.Slots)+len(f.Fix.Files)+len(f.Fix.Migrations) == 0 {
			add("fault.fix is empty")
		}
		if f.Commit.Message == "" {
			add("fault.commit.message is required")
		}
		if len(f.Rubric.KeyPoints) == 0 {
			add("fault.rubric.key_points is required")
		}
		for _, sets := range []labblock.Overrides{f.Inject, f.Fix, f.Carrier.Overrides} {
			for _, s := range sets.Slots {
				if (s.Value == "") == (s.File == "") {
					add("fault slot override %q needs exactly one of value or file", s.Slot)
				}
			}
		}
	case "data":
		if m.Data.Generator == "" {
			add("data.generator is required")
		}
	case "stub":
		if m.Stub.Process == "" {
			add("stub.process is required")
		}
	case "check":
		c := m.Check
		if !contains(labblock.ProbeKinds, c.Probe) || c.Entry == "" || c.FailureMessage == "" {
			add("check needs probe (%s), entry and failure_message", strings.Join(labblock.ProbeKinds, "|"))
		}
	case "ticket":
		t := m.Ticket
		if (t.TemplateMD == "") == (t.TemplateFile == "") {
			add("ticket needs exactly one of template_md or template_file")
		}
		if len(t.TemplateMD) > maxTemplateLen {
			add("ticket.template_md exceeds %d characters", maxTemplateLen)
		}
	case "hints":
		if len(m.Hints.Ladder) != hintLadderLen {
			add("hints.ladder must have exactly %d levels", hintLadderLen)
		}
		for _, h := range m.Hints.Ladder {
			if strings.TrimSpace(h) == "" || len(h) > maxLadderItem {
				add("hints.ladder entries must be non-empty and under %d characters", maxLadderItem)
			}
		}
	case "rubric":
		if len(m.Rubric.KeyPoints) == 0 {
			add("rubric.key_points is required")
		}
	case "preset":
		if m.Preset.Target == "" || len(m.Preset.Values) == 0 {
			add("preset needs a target block key and at least one value")
		}
	case "custom":
		if m.Custom.Root == "" {
			add("custom.root is required")
		}
	}
	sort.Strings(p)
	return p
}
