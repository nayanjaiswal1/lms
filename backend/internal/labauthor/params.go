package labauthor

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"
	"sync"

	"github.com/mindforge/backend/internal/labblock"
	"github.com/santhosh-tekuri/jsonschema/v6"
)

// Parameter rules (docs/debug-labs.md §B1, §B7).
//
// A block's `params` is a JSON Schema object. On top of standard JSON Schema
// the engine enforces:
//
//   - every property has a scalar type (string|integer|number|boolean); check
//     blocks may additionally declare array/object properties (probe configuration);
//   - a string property declares how it may be used via `x-mf-use`:
//     "text" (markdown/ticket only, never reaches code, maxLength <= 2000) or
//     "literal:<type>" (may be pasted into a `value` slot; maxLength <= 200;
//     <type> is one of the labblock.Lit* constants). Nothing else may put a
//     string param into source;
//   - `randomize` is {choices:[...]} or {range:{min,max,step}} (numeric only);
//     every choice/endpoint must itself satisfy the property schema;
//   - the recipe may not supply keys the schema does not declare.

const (
	maxTextParamLen    = 2000
	maxLiteralParamLen = 200
	// maxRangeAxisValues bounds how many values a numeric range contributes
	// to one variant axis (evenly spaced, endpoints included).
	maxRangeAxisValues = 8
)

// stringLiterals are the literal types a string param may declare.
var stringLiterals = map[string]bool{labblock.LitPythonStr: true, labblock.LitJSString: true, labblock.LitJSON: true}

var scalarTypes = map[string]bool{"string": true, "integer": true, "number": true, "boolean": true}

var validLiterals = map[string]bool{
	labblock.LitPythonStr: true, labblock.LitPythonInt: true, labblock.LitPythonFloat: true,
	labblock.LitPythonBool: true, labblock.LitJSON: true, labblock.LitJSString: true,
	labblock.LitJSNumber: true, labblock.LitJSBool: true,
}

// schemaCache caches compiled schemas by the sha256 of their canonical JSON:
// manifests are immutable per version, so the cache never goes stale.
var schemaCache sync.Map // string -> *jsonschema.Schema

// normalize round-trips v through JSON so every number becomes json.Number and
// every map/slice is a plain any-tree (the input shape jsonschema requires and
// the canonical-hash step wants).
func normalize(v any) (any, error) {
	raw, err := json.Marshal(v)
	if err != nil {
		return nil, fmt.Errorf("labauthor.normalize: %w", err)
	}
	return decodeNumber(raw)
}

func decodeNumber(raw []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var out any
	if err := dec.Decode(&out); err != nil {
		return nil, fmt.Errorf("labauthor.decodeNumber: %w", err)
	}
	return out, nil
}

func compileSchema(schema map[string]any) (*jsonschema.Schema, error) {
	raw, err := json.Marshal(schema)
	if err != nil {
		return nil, fmt.Errorf("labauthor.compileSchema: %w", err)
	}
	key := sha256Hex(raw)
	if c, ok := schemaCache.Load(key); ok {
		return c.(*jsonschema.Schema), nil
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("labauthor.compileSchema: %w", err)
	}
	c := jsonschema.NewCompiler()
	const loc = "mf://params.json"
	if err := c.AddResource(loc, doc); err != nil {
		return nil, fmt.Errorf("labauthor.compileSchema: %w", err)
	}
	sch, err := c.Compile(loc)
	if err != nil {
		return nil, fmt.Errorf("labauthor.compileSchema: %w", err)
	}
	schemaCache.Store(key, sch)
	return sch, nil
}

// schemaErrors flattens a jsonschema validation failure into "path: message" lines.
func schemaErrors(err error) []string {
	ve, ok := err.(*jsonschema.ValidationError)
	if !ok {
		return []string{err.Error()}
	}
	var out []string
	var walk func(u *jsonschema.OutputUnit)
	walk = func(u *jsonschema.OutputUnit) {
		if len(u.Errors) == 0 {
			if u.Error != nil {
				loc := u.InstanceLocation
				if loc == "" {
					loc = "/"
				}
				out = append(out, loc+": "+u.Error.String())
			}
			return
		}
		for i := range u.Errors {
			walk(&u.Errors[i])
		}
	}
	walk(ve.BasicOutput())
	if len(out) == 0 {
		out = []string{ve.Error()}
	}
	return out
}

// properties returns the schema's declared property schemas.
func properties(m *labblock.Manifest) map[string]map[string]any {
	out := map[string]map[string]any{}
	props, _ := m.Params["properties"].(map[string]any)
	for name, p := range props {
		if pm, ok := p.(map[string]any); ok {
			out[name] = pm
		}
	}
	return out
}

func sortedNames[V any](m map[string]V) []string {
	names := make([]string, 0, len(m))
	for n := range m {
		names = append(names, n)
	}
	sort.Strings(names)
	return names
}

// paramUse parses `x-mf-use`: ("text", "") or ("literal", "<lit>"); ("", "") if absent/invalid.
func paramUse(p map[string]any) (use, lit string) {
	s, _ := p["x-mf-use"].(string)
	switch {
	case s == "text":
		return "text", ""
	case strings.HasPrefix(s, "literal:"):
		return "literal", strings.TrimPrefix(s, "literal:")
	}
	return "", ""
}

func numOf(v any) (float64, bool) {
	switch n := v.(type) {
	case json.Number:
		f, err := n.Float64()
		return f, err == nil
	case float64:
		return n, true
	case int:
		return float64(n), true
	case int64:
		return float64(n), true
	}
	return 0, false
}

// validateParamsSchema checks a manifest's params schema at sync/authoring time.
func validateParamsSchema(m *labblock.Manifest) []labblock.Issue {
	if len(m.Params) == 0 {
		return nil
	}
	bad := func(msg string) []labblock.Issue {
		return []labblock.Issue{labblock.Errf(labblock.CodeManifestInvalid, m.ID, "params: "+msg)}
	}
	if t, _ := m.Params["type"].(string); t != "object" {
		return bad(`schema must have "type": "object"`)
	}
	if _, err := compileSchema(m.Params); err != nil {
		return bad("invalid JSON Schema: " + err.Error())
	}
	var issues []labblock.Issue
	props := properties(m)
	for _, name := range sortedNames(props) {
		p := props[name]
		prefix := "params." + name + ": "
		fail := func(msg string) {
			issues = append(issues, labblock.Errf(labblock.CodeManifestInvalid, m.ID, prefix+msg))
		}
		typ, _ := p["type"].(string)
		// A check block's params are a grader probe's JSON configuration (steps,
		// expectations, SQL lists): structured values are allowed there. They
		// only ever reach grader.json read by the root-owned probe library,
		// never source code, so the string-use rules below do not apply.
		if m.Kind == "check" && (typ == "array" || typ == "object") {
			if _, ok := p["randomize"]; ok {
				fail("structured check params cannot be randomized")
			}
			continue
		}
		if !scalarTypes[typ] {
			fail("type must be one of string|integer|number|boolean")
			continue
		}
		if typ == "string" {
			use, lit := paramUse(p)
			maxLen, hasMax := numOf(p["maxLength"])
			switch {
			case use == "text":
				if !hasMax || maxLen > maxTextParamLen {
					fail(fmt.Sprintf("text string params need maxLength <= %d", maxTextParamLen))
				}
			case use == "literal":
				if !stringLiterals[lit] {
					fail(`string params may only declare x-mf-use "literal:python_str|js_string|json"`)
				} else if !hasMax || maxLen > maxLiteralParamLen {
					fail(fmt.Sprintf("literal string params need maxLength <= %d", maxLiteralParamLen))
				}
			default:
				fail(`string params must declare x-mf-use: "text" or "literal:<type>"`)
			}
		}
		if raw, ok := p["randomize"]; ok {
			for _, is := range validateRandomize(name, typ, p, raw) {
				issues = append(issues, labblock.Errf(labblock.CodeManifestInvalid, m.ID, prefix+is))
			}
		}
	}
	return issues
}

// randomize is a parsed `randomize` clause.
type randomize struct {
	choices        []any
	min, max, step float64
	isRange        bool
}

func parseRandomize(typ string, raw any) (*randomize, error) {
	obj, ok := raw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("randomize must be an object")
	}
	if ch, has := obj["choices"]; has {
		arr, ok := ch.([]any)
		if !ok || len(arr) < 2 {
			return nil, fmt.Errorf("randomize.choices needs at least 2 values")
		}
		return &randomize{choices: arr}, nil
	}
	rg, has := obj["range"].(map[string]any)
	if !has {
		return nil, fmt.Errorf("randomize needs choices or range")
	}
	if typ != "integer" && typ != "number" {
		return nil, fmt.Errorf("randomize.range is only valid for integer/number params")
	}
	lo, ok1 := numOf(rg["min"])
	hi, ok2 := numOf(rg["max"])
	st, ok3 := numOf(rg["step"])
	if !ok1 || !ok2 || !ok3 || lo >= hi || st <= 0 {
		return nil, fmt.Errorf("randomize.range needs numeric min < max and step > 0")
	}
	return &randomize{isRange: true, min: lo, max: hi, step: st}, nil
}

// values enumerates the axis values: the choices verbatim, or the range
// discretised by step (evenly thinned to maxRangeAxisValues, endpoints kept).
func (r *randomize) values(typ string) []any {
	if !r.isRange {
		return r.choices
	}
	n := int(math.Floor((r.max-r.min)/r.step+1e-9)) + 1
	vals := make([]float64, 0, n)
	for i := 0; i < n; i++ {
		vals = append(vals, r.min+float64(i)*r.step)
	}
	if len(vals) > maxRangeAxisValues {
		thin := make([]float64, 0, maxRangeAxisValues)
		for i := 0; i < maxRangeAxisValues; i++ {
			thin = append(thin, vals[i*(len(vals)-1)/(maxRangeAxisValues-1)])
		}
		vals = thin
	}
	out := make([]any, len(vals))
	for i, f := range vals {
		if typ == "integer" {
			out[i] = json.Number(strconv.FormatInt(int64(math.Round(f)), 10))
		} else {
			out[i] = json.Number(strconv.FormatFloat(f, 'g', -1, 64))
		}
	}
	return out
}

// validateRandomize returns problem descriptions (without prefix).
func validateRandomize(name, typ string, prop map[string]any, raw any) []string {
	r, err := parseRandomize(typ, raw)
	if err != nil {
		return []string{err.Error()}
	}
	propSchema := map[string]any{}
	for k, v := range prop {
		if k != "randomize" {
			propSchema[k] = v
		}
	}
	sch, err := compileSchema(propSchema)
	if err != nil {
		return []string{"invalid property schema: " + err.Error()}
	}
	var out []string
	for _, v := range r.values(typ) {
		nv, err := normalize(v)
		if err != nil {
			out = append(out, err.Error())
			continue
		}
		if verr := sch.Validate(nv); verr != nil {
			out = append(out, fmt.Sprintf("randomize value %v violates the schema: %s", v, strings.Join(schemaErrors(verr), "; ")))
		}
	}
	return out
}

// effectiveParams returns defaults <- preset values <- explicit params, with
// every number normalised to json.Number. Unknown preset keys are ignored
// here (validateParams rejects the merged object).
func effectiveParams(m *labblock.Manifest, preset, explicit map[string]any) (map[string]any, error) {
	out := map[string]any{}
	for name, p := range properties(m) {
		if d, ok := p["default"]; ok {
			out[name] = d
		}
	}
	for k, v := range preset {
		out[k] = v
	}
	for k, v := range explicit {
		out[k] = v
	}
	n, err := normalize(out)
	if err != nil {
		return nil, err
	}
	return n.(map[string]any), nil
}

// validateParamValues validates effective params against the block's schema
// and rejects keys the schema does not declare.
func validateParamValues(m *labblock.Manifest, eff map[string]any) []labblock.Issue {
	if len(m.Params) == 0 {
		if len(eff) > 0 {
			return []labblock.Issue{labblock.Errf(labblock.CodeParamInvalid, m.ID, "block declares no parameters")}
		}
		return nil
	}
	sch, err := compileSchema(m.Params)
	if err != nil {
		return []labblock.Issue{labblock.Errf(labblock.CodeManifestInvalid, m.ID, err.Error())}
	}
	var issues []labblock.Issue
	props := properties(m)
	for _, k := range sortedNames(eff) {
		if _, ok := props[k]; !ok {
			issues = append(issues, labblock.Errf(labblock.CodeParamInvalid, m.ID, "unknown parameter "+strconv.Quote(k)))
		}
	}
	if verr := sch.Validate(eff); verr != nil {
		for _, msg := range schemaErrors(verr) {
			issues = append(issues, labblock.Errf(labblock.CodeParamInvalid, m.ID, msg))
		}
	}
	return issues
}

// axis is one variant dimension: a parameter of a block with `randomize` that
// the recipe leaves unpinned.
type axis struct {
	BlockKey string
	Param    string
	Values   []any
}

func paramAxes(b *labblock.ResolvedBlock) []axis {
	var axes []axis
	props := properties(b.Manifest)
	for _, name := range sortedNames(props) {
		raw, ok := props[name]["randomize"]
		if !ok {
			continue
		}
		if _, pinned := b.Ref.Params[name]; pinned {
			continue
		}
		typ, _ := props[name]["type"].(string)
		r, err := parseRandomize(typ, raw)
		if err != nil {
			continue // reported by validateParamsSchema at sync time
		}
		axes = append(axes, axis{BlockKey: b.Key, Param: name, Values: r.values(typ)})
	}
	return axes
}
