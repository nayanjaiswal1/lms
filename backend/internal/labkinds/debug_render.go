package labkinds

import (
	"encoding/json"
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/mindforge/backend/internal/labblock"
)

// The debug kind's renderer contract (docs/debug-labs.md Phase 1c-ii). The
// pipeline streams one document per variant, built here, to
// /opt/mindforge/mf-build in the lab-debug image. Everything that could be a
// trust problem is finished on this side: parameters are already formatted as
// source literals (labauthor.RenderLiteral) and ticket text is already
// substituted, so the renderer only moves text around and never interprets a
// parameter.

const (
	renderSchemaVersion = 1
	defaultBaseURLHost  = "http://127.0.0.1"
	defaultPort         = 8000
	// defaultBrief is used when a recipe has no ticket block.
	defaultBrief = "Users are reporting a problem with the application. Reproduce it, find the root cause, fix it, and write up what you found."
)

var (
	placeholderRe = regexp.MustCompile(`\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z0-9_.-]+)\s*\}\}`)
	captureNames  = map[string]bool{"trace": true, "log": true, "slow_queries": true}
)

// RenderOverrides is a resolved override set: slot values are final source text.
type RenderOverrides struct {
	Dir   string            `json:"dir"`
	Slots []renderSlot      `json:"slots,omitempty"`
	Files []labblock.FileOp `json:"files,omitempty"`
}

type renderSlot struct {
	Slot  string `json:"slot"`
	Value string `json:"value,omitempty"`
	File  string `json:"file,omitempty"`
}

type renderCheat struct {
	Name      string          `json:"name"`
	Overrides RenderOverrides `json:"overrides"`
}

type renderFault struct {
	Key     string                  `json:"key"`
	Dir     string                  `json:"dir"`
	Commit  labblock.CommitTemplate `json:"commit"`
	Inject  RenderOverrides         `json:"inject"`
	Fix     RenderOverrides         `json:"fix"`
	Carrier struct {
		Feature   string          `json:"feature"`
		Overrides RenderOverrides `json:"overrides"`
	} `json:"carrier"`
	Cheats []renderCheat   `json:"cheats"`
	Chain  *labblock.Chain `json:"chain,omitempty"`
}

type renderApp struct {
	Key           string                   `json:"key"`
	Dir           string                   `json:"dir"`
	Language      string                   `json:"language"`
	Slots         []labblock.SlotDecl      `json:"slots"`
	History       []labblock.HistoryCommit `json:"history"`
	Noise         []labblock.HistoryCommit `json:"noise"`
	Features      []string                 `json:"features"`
	Protected     []string                 `json:"protected"`
	Setup         []string                 `json:"setup"`
	Ports         []int                    `json:"ports"`
	BaseURL       string                   `json:"base_url"`
	ReadinessPath string                   `json:"readiness_path"`
	TestGlobs     []string                 `json:"test_globs"`
}

type renderCheck struct {
	Key     string         `json:"key"`
	Probe   string         `json:"probe"`
	Name    string         `json:"name"`
	Message string         `json:"message"`
	Params  map[string]any `json:"params"`
	Role    string         `json:"role"`
}

type renderData struct {
	Key       string         `json:"key"`
	Dir       string         `json:"dir"`
	Generator string         `json:"generator"`
	Params    map[string]any `json:"params"`
}

type renderStub struct {
	Key     string `json:"key"`
	Dir     string `json:"dir"`
	Process string `json:"process"`
}

type renderEnv struct {
	Key        string            `json:"key"`
	Dir        string            `json:"dir"`
	Overlay    []labblock.FileOp `json:"overlay"`
	Pins       []string          `json:"pins"`
	Supervisor []string          `json:"supervisor"`
	MissingVar string            `json:"missing_var"`
}

type renderVariant struct {
	Schema      int                     `json:"schema"`
	Key         string                  `json:"key"`
	Seed        int64                   `json:"seed"`
	SeedHex     string                  `json:"seed_hex"`
	App         renderApp               `json:"app"`
	Faults      []renderFault           `json:"faults"`
	Checks      []renderCheck           `json:"checks"`
	Data        []renderData            `json:"data"`
	Stubs       []renderStub            `json:"stubs"`
	Envs        []renderEnv             `json:"envs"`
	TicketMD    string                  `json:"ticket_md"`
	RootCauseMD string                  `json:"root_cause_md"`
	HintLadder  []string                `json:"hint_ladder"`
	Rubric      labblock.RubricDefaults `json:"rubric"`
	Captures    []string                `json:"captures"`
	// Custom is set for a hand-made scenario: mf-build builds the variant from the
	// block's own workspace/solution/grader tree (scenario.json) instead of app + faults.
	Custom *renderCustomRef `json:"custom,omitempty"`
}

type renderCustomRef struct {
	Dir  string `json:"dir"`
	Root string `json:"root"`
}

// RenderSpec implements Kind.
func (DebugKind) RenderSpec(in RenderInput) (json.RawMessage, error) {
	var active []*labblock.ResolvedBlock
	for _, b := range in.Recipe.Blocks {
		if in.ActiveIDs[b.VersionID] {
			active = append(active, b)
		}
	}
	sub := &labblock.Recipe{LabKind: in.Recipe.LabKind, OrgID: in.Recipe.OrgID, Spec: in.Recipe.Spec, Blocks: active}
	if customs := sub.ByKind("custom"); len(customs) > 0 {
		return renderCustom(in, sub, customs[0])
	}
	apps := sub.ByKind("app")
	if len(apps) != 1 {
		return nil, fmt.Errorf("debug render: variant needs exactly one app block, has %d", len(apps))
	}
	app := apps[0]
	appSec := app.Manifest.App

	params := func(b *labblock.ResolvedBlock) map[string]any {
		out := map[string]any{}
		for k, v := range b.Params {
			out[k] = v
		}
		for k, v := range in.AxisParams[b.Key] {
			out[k] = v
		}
		return out
	}

	v := renderVariant{
		Schema: renderSchemaVersion, Key: in.VariantKey, Seed: in.Seed, SeedHex: fmt.Sprintf("%016x", uint64(in.Seed)),
		Faults: []renderFault{}, Checks: []renderCheck{}, Data: []renderData{}, Stubs: []renderStub{}, Envs: []renderEnv{},
		Captures: []string{}, HintLadder: []string{},
	}
	port := defaultPort
	if len(appSec.Ports) > 0 {
		port = appSec.Ports[0]
	}
	readiness := appSec.ReadinessPath
	if readiness == "" {
		readiness = "/"
	}
	globs := appSec.TestGlobs
	if len(globs) == 0 {
		globs = DefaultTestGlobs
	}
	v.App = renderApp{
		Key: app.Key, Dir: in.BlockDirs[app.VersionID], Language: appSec.Language, Slots: nonNilSlots(appSec.Slots),
		History: nonNilHist(appSec.History), Noise: nonNilHist(appSec.Noise), Features: nonNil(appSec.Features),
		Protected: nonNil(appSec.Protected), Setup: nonNil(appSec.Setup), Ports: appSec.Ports,
		BaseURL: fmt.Sprintf("%s:%d", defaultBaseURLHost, port), ReadinessPath: readiness, TestGlobs: globs,
	}
	if v.App.Ports == nil {
		v.App.Ports = []int{port}
	}
	slotDecl := map[string]labblock.SlotDecl{}
	for _, s := range appSec.Slots {
		slotDecl[s.Name] = s
	}

	faults := orderFaults(sub.ByKind("fault"))
	total := len(faults)
	var rootCauses, rubricPts, misconceptions []string
	faultParams := make([]map[string]any, total)
	for i, f := range faults {
		fp := params(f)
		faultParams[i] = fp
		fs := f.Manifest.Fault
		rf := renderFault{Key: f.Key, Dir: in.BlockDirs[f.VersionID], Commit: fs.Commit, Chain: fs.Chain, Cheats: []renderCheat{}}
		var err error
		if rf.Inject, err = resolveOverrides(in, f, fs.Inject, fp, slotDecl); err != nil {
			return nil, err
		}
		if rf.Fix, err = resolveOverrides(in, f, fs.Fix, fp, slotDecl); err != nil {
			return nil, err
		}
		rf.Carrier.Feature = fs.Carrier.Feature
		if rf.Carrier.Overrides, err = resolveOverrides(in, f, fs.Carrier.Overrides, fp, slotDecl); err != nil {
			return nil, err
		}
		for _, c := range fs.Cheats {
			ro, err := resolveOverrides(in, f, c.Overrides, fp, slotDecl)
			if err != nil {
				return nil, err
			}
			rf.Cheats = append(rf.Cheats, renderCheat{Name: c.Name, Overrides: ro})
		}
		v.Faults = append(v.Faults, rf)

		text, err := substituteText(fs.RootCause, nil, fp)
		if err != nil {
			return nil, fmt.Errorf("debug render: fault %s root_cause: %w", f.Key, err)
		}
		if total > 1 {
			text = fmt.Sprintf("## Issue %d\n\n%s", i+1, text)
		}
		rootCauses = append(rootCauses, text)
		rubricPts = append(rubricPts, fs.Rubric.KeyPoints...)
		misconceptions = append(misconceptions, fs.Rubric.Misconceptions...)

		// Checks referenced by this fault.
		seen := map[string]int{}
		for _, cr := range fs.Checks {
			cb := sub.ByKey(cr.Ref)
			if cb == nil {
				return nil, fmt.Errorf("debug render: fault %s references missing check %s", f.Key, cr.Ref)
			}
			merged := params(cb)
			for k, val := range cr.Params {
				resolved, err := resolveParamRef(val, fp)
				if err != nil {
					return nil, fmt.Errorf("debug render: fault %s check %s param %s: %w", f.Key, cr.Ref, k, err)
				}
				merged[k] = resolved
			}
			name := IssueCheckPrefix(i, total) + cr.DisplayTitle(cb.Manifest.Title)
			if n := seen[name]; n > 0 {
				name = fmt.Sprintf("%s (%d)", name, n+1)
			}
			seen[name]++
			v.Checks = append(v.Checks, renderCheck{
				Key: cb.Key, Probe: cb.Manifest.Check.Probe, Name: name, Message: cb.Manifest.Check.FailureMessage,
				Params: merged, Role: cr.Role,
			})
		}
	}
	// Check blocks no fault references are extra recipe-level regression checks.
	referenced := map[string]bool{}
	for _, f := range faults {
		for _, cr := range f.Manifest.Fault.Checks {
			referenced[cr.Ref] = true
		}
	}
	for _, cb := range sub.ByKind("check") {
		if !referenced[cb.Key] {
			v.Checks = append(v.Checks, renderCheck{Key: cb.Key, Probe: cb.Manifest.Check.Probe, Name: cb.Manifest.Title,
				Message: cb.Manifest.Check.FailureMessage, Params: params(cb), Role: labblock.CheckRegression})
		}
	}

	for _, d := range sub.ByKind("data") {
		v.Data = append(v.Data, renderData{Key: d.Key, Dir: in.BlockDirs[d.VersionID], Generator: d.Manifest.Data.Generator, Params: params(d)})
	}
	for _, st := range sub.ByKind("stub") {
		v.Stubs = append(v.Stubs, renderStub{Key: st.Key, Dir: in.BlockDirs[st.VersionID], Process: st.Manifest.Stub.Process})
	}
	for _, e := range sub.ByKind("env") {
		es := e.Manifest.Env
		v.Envs = append(v.Envs, renderEnv{Key: e.Key, Dir: in.BlockDirs[e.VersionID], Overlay: nonNilFiles(es.Overlay),
			Pins: nonNil(es.Pins), Supervisor: nonNil(es.Supervisor), MissingVar: es.MissingVar})
	}

	// Ticket, hints, rubric.
	ticket, err := renderTicket(in, sub, faults, faultParams)
	if err != nil {
		return nil, err
	}
	v.TicketMD = ticket
	for _, m := range placeholderRe.FindAllStringSubmatch(ticket, -1) {
		if m[1] == "captured" && !contains(v.Captures, m[2]) {
			v.Captures = append(v.Captures, m[2])
		}
	}
	sort.Strings(v.Captures)
	v.RootCauseMD = strings.Join(rootCauses, "\n\n")
	v.HintLadder = mergeHints(sub, faults)
	v.Rubric = labblock.RubricDefaults{KeyPoints: append([]string{}, rubricPts...), Misconceptions: append([]string{}, misconceptions...)}
	if rb := sub.ByKind("rubric"); len(rb) > 0 {
		v.Rubric.KeyPoints = append(v.Rubric.KeyPoints, rb[0].Manifest.Rubric.KeyPoints...)
		v.Rubric.Misconceptions = append(v.Rubric.Misconceptions, rb[0].Manifest.Rubric.Misconceptions...)
	}
	return json.Marshal(v)
}

func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
func nonNilSlots(s []labblock.SlotDecl) []labblock.SlotDecl {
	if s == nil {
		return []labblock.SlotDecl{}
	}
	return s
}
func nonNilHist(s []labblock.HistoryCommit) []labblock.HistoryCommit {
	if s == nil {
		return []labblock.HistoryCommit{}
	}
	return s
}
func nonNilFiles(s []labblock.FileOp) []labblock.FileOp {
	if s == nil {
		return []labblock.FileOp{}
	}
	return s
}

// orderFaults returns faults in chain order: a fault comes after the one it
// chains after; ties break by block key so the order is deterministic.
func orderFaults(faults []*labblock.ResolvedBlock) []*labblock.ResolvedBlock {
	sorted := append([]*labblock.ResolvedBlock(nil), faults...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].Key < sorted[j].Key })
	var out []*labblock.ResolvedBlock
	placed := map[string]bool{}
	for len(out) < len(sorted) {
		progressed := false
		for _, f := range sorted {
			if placed[f.Key] {
				continue
			}
			if c := f.Manifest.Fault.Chain; c != nil && !placed[c.After] {
				continue
			}
			out = append(out, f)
			placed[f.Key] = true
			progressed = true
		}
		if !progressed { // cycle: validation rejects these; keep the loop finite
			break
		}
	}
	return out
}

// resolveOverrides pre-renders a fault's override set: `{{params.x}}` tokens in
// slot values become source literals typed by the slot's declared literal.
func resolveOverrides(in RenderInput, f *labblock.ResolvedBlock, o labblock.Overrides, params map[string]any, slots map[string]labblock.SlotDecl) (RenderOverrides, error) {
	out := RenderOverrides{Dir: in.BlockDirs[f.VersionID], Files: o.Files}
	for _, so := range o.Slots {
		rs := renderSlot{Slot: so.Slot, File: so.File}
		if so.Value != "" {
			decl, ok := slots[so.Slot]
			if !ok {
				return out, fmt.Errorf("debug render: fault %s overrides unknown slot %s", f.Key, so.Slot)
			}
			var err error
			rs.Value = paramRefRe.ReplaceAllStringFunc(so.Value, func(tok string) string {
				if err != nil {
					return tok
				}
				name := paramRefRe.FindStringSubmatch(tok)[1]
				val, ok := params[name]
				if !ok {
					err = fmt.Errorf("debug render: fault %s slot %s references unset param %s", f.Key, so.Slot, name)
					return tok
				}
				var lit string
				lit, err = in.Literal(decl.Literal, val)
				return lit
			})
			if err != nil {
				return out, err
			}
		}
		out.Slots = append(out.Slots, rs)
	}
	return out, nil
}

// resolveParamRef turns a check-ref param of the exact form "{{params.x}}" into
// the fault's typed param value; every other value passes through unchanged.
func resolveParamRef(v any, params map[string]any) (any, error) {
	s, ok := v.(string)
	if !ok {
		return v, nil
	}
	m := paramRefRe.FindStringSubmatch(s)
	if m == nil || m[0] != strings.TrimSpace(s) {
		return v, nil
	}
	val, ok := params[m[1]]
	if !ok {
		return nil, fmt.Errorf("references unset param %s", m[1])
	}
	return val, nil
}

// substituteText fills `{{symptom.x}}` (from symptom) and `{{params.x}}` (from
// params) in Markdown text. `{{captured.*}}` placeholders are kept for the
// verification step; anything else unresolved is an error.
func substituteText(text string, symptom map[string]string, params map[string]any) (string, error) {
	var firstErr error
	out := placeholderRe.ReplaceAllStringFunc(text, func(tok string) string {
		m := placeholderRe.FindStringSubmatch(tok)
		switch m[1] {
		case "captured":
			if !captureNames[m[2]] && firstErr == nil {
				firstErr = fmt.Errorf("unknown capture placeholder %s (want trace, log or slow_queries)", tok)
			}
			return tok
		case "symptom":
			if val, ok := symptom[m[2]]; ok {
				return val
			}
		case "params":
			if val, ok := params[m[2]]; ok {
				return fmt.Sprint(val)
			}
		}
		if firstErr == nil {
			firstErr = fmt.Errorf("unresolved placeholder %s", tok)
		}
		return tok
	})
	return out, firstErr
}

// renderTicket builds the final TICKET.md text (captured placeholders intact).
func renderTicket(in RenderInput, sub *labblock.Recipe, faults []*labblock.ResolvedBlock, faultParams []map[string]any) (string, error) {
	symptom := map[string]string{}
	params := map[string]any{}
	for i := len(faults) - 1; i >= 0; i-- { // earlier faults win on a name clash
		for k, val := range faults[i].Manifest.Fault.Symptom.Vars {
			symptom[k] = val
		}
		for k, val := range faultParams[i] {
			params[k] = val
		}
	}
	// A symptom var may itself reference params.
	for k, val := range symptom {
		resolved, err := substituteText(val, nil, params)
		if err != nil {
			return "", fmt.Errorf("debug render: symptom var %s: %w", k, err)
		}
		symptom[k] = resolved
	}

	tickets := sub.ByKind("ticket")
	var body, severity, persona string
	var herrings []string
	if len(tickets) == 0 {
		var b strings.Builder
		b.WriteString(defaultBrief + "\n")
		keys := make([]string, 0, len(symptom))
		for k := range symptom {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			fmt.Fprintf(&b, "\n- %s: %s", k, symptom[k])
		}
		body = b.String()
	} else {
		ts := tickets[0].Manifest.Ticket
		body = ts.TemplateMD
		if ts.TemplateFile != "" {
			raw, err := in.ReadFile(tickets[0].VersionID, ts.TemplateFile)
			if err != nil {
				return "", fmt.Errorf("debug render: ticket template %s: %w", ts.TemplateFile, err)
			}
			body = string(raw)
		}
		severity, persona, herrings = ts.Severity, ts.Persona, ts.RedHerrings
	}
	text, err := substituteText(body, symptom, params)
	if err != nil {
		return "", fmt.Errorf("debug render: ticket: %w", err)
	}
	var head strings.Builder
	if severity != "" {
		fmt.Fprintf(&head, "Severity: %s\n", severity)
	}
	if persona != "" {
		fmt.Fprintf(&head, "Reporter: %s\n", persona)
	}
	if head.Len() > 0 {
		head.WriteString("\n")
	}
	text = head.String() + strings.TrimSpace(text) + "\n"
	if len(herrings) > 0 {
		text += "\n### Other observations from the reporter\n\n"
		for _, h := range herrings {
			hs, err := substituteText(h, symptom, params)
			if err != nil {
				return "", fmt.Errorf("debug render: red herring: %w", err)
			}
			text += "- " + hs + "\n"
		}
	}
	return text, nil
}

// mergeHints returns the hint ladder: a hints block wins; otherwise the faults'
// own ladders merged level by level ("Issue N: ..." when there are several).
func mergeHints(sub *labblock.Recipe, faults []*labblock.ResolvedBlock) []string {
	if hb := sub.ByKind("hints"); len(hb) > 0 {
		return append([]string{}, hb[0].Manifest.Hints.Ladder...)
	}
	if len(faults) == 1 {
		return append([]string{}, faults[0].Manifest.Fault.Hints...)
	}
	levels := 0
	for _, f := range faults {
		if n := len(f.Manifest.Fault.Hints); n > levels {
			levels = n
		}
	}
	out := []string{}
	for l := 0; l < levels; l++ {
		var parts []string
		for i, f := range faults {
			if l < len(f.Manifest.Fault.Hints) {
				parts = append(parts, fmt.Sprintf("Issue %d: %s", i+1, f.Manifest.Fault.Hints[l]))
			}
		}
		out = append(out, strings.Join(parts, "\n\n"))
	}
	return out
}

// renderCustom is the render spec of a hand-made scenario (`custom` block): the
// block carries the whole scenario under custom.root (see mf-build custom.py);
// only the ticket, hints and rubric blocks of the recipe are merged in.
func renderCustom(in RenderInput, sub *labblock.Recipe, c *labblock.ResolvedBlock) (json.RawMessage, error) {
	v := renderVariant{
		Schema: renderSchemaVersion, Key: in.VariantKey, Seed: in.Seed, SeedHex: fmt.Sprintf("%016x", uint64(in.Seed)),
		Faults: []renderFault{}, Checks: []renderCheck{}, Data: []renderData{}, Stubs: []renderStub{}, Envs: []renderEnv{},
		Captures: []string{}, HintLadder: mergeHints(sub, nil),
		App: renderApp{Slots: []labblock.SlotDecl{}, History: []labblock.HistoryCommit{}, Noise: []labblock.HistoryCommit{},
			Features: []string{}, Protected: []string{}, Setup: []string{}, Ports: []int{}, TestGlobs: []string{}},
		Custom: &renderCustomRef{Dir: in.BlockDirs[c.VersionID], Root: strings.Trim(c.Manifest.Custom.Root, "/")},
		Rubric: labblock.RubricDefaults{KeyPoints: []string{}, Misconceptions: []string{}},
	}
	ticket, err := renderTicket(in, sub, nil, nil)
	if err != nil {
		return nil, err
	}
	v.TicketMD = ticket
	for _, m := range placeholderRe.FindAllStringSubmatch(ticket, -1) {
		if m[1] == "captured" && !contains(v.Captures, m[2]) {
			v.Captures = append(v.Captures, m[2])
		}
	}
	sort.Strings(v.Captures)
	if rb := sub.ByKind("rubric"); len(rb) > 0 {
		v.Rubric = rb[0].Manifest.Rubric.RubricDefaults
		v.Rubric.KeyPoints = nonNil(v.Rubric.KeyPoints)
		v.Rubric.Misconceptions = nonNil(v.Rubric.Misconceptions)
	}
	return json.Marshal(v)
}
