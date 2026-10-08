package labauthor

import (
	"testing"

	"github.com/mindforge/backend/internal/labblock"
)

// Regression (2026-09-30): check blocks configure grader probes with
// structured params, but the schema validator rejected array/object
// properties as "not a scalar type". Both the schema and concrete values
// must be accepted.
func TestCheckBlockParams_ArrayAndObjectPropertiesAccepted(t *testing.T) {
	m := &labblock.Manifest{
		Kind: "check", ID: "probe.http",
		Params: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"steps":   map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
				"expects": map[string]any{"type": "object"},
			},
		},
	}

	if issues := validateParamsSchema(m); len(issues) != 0 {
		t.Fatalf("array/object properties rejected by schema validation: %+v", issues)
	}

	eff, err := effectiveParams(m, nil, map[string]any{
		"steps":   []any{"GET /", "GET /health"},
		"expects": map[string]any{"status": float64(200)},
	})
	if err != nil {
		t.Fatalf("effectiveParams: %v", err)
	}
	if issues := validateParamValues(m, eff); len(issues) != 0 {
		t.Fatalf("array/object values rejected: %+v", issues)
	}
}
