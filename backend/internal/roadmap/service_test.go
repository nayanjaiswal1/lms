package roadmap

import (
	"context"
	"testing"
)

// ponytail: DB test infra now exists via internal/testdb (see repo_db_test.go
// in this package) — this file predates it and stays pure-Go on purpose,
// covering the two riskiest non-DB branches: title defaulting and the
// AI-output sanitization ladder that matchModules runs before anything
// touches the catalog tables.

func TestDefaultTitle(t *testing.T) {
	cases := []struct {
		name       string
		targetRole string
		goal       string
		want       string
	}{
		{"uses target role when set", "Backend Engineer", "get good at go", "Roadmap: Backend Engineer"},
		{"truncates long goal", "", "this is a very long goal description that definitely exceeds sixty characters in length", "Roadmap: this is a very long goal description that definitely exceed…"},
		{"uses short goal verbatim", "", "learn DSA", "Roadmap: learn DSA"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := defaultTitle(tc.targetRole, tc.goal); got != tc.want {
				t.Errorf("defaultTitle(%q, %q) = %q, want %q", tc.targetRole, tc.goal, got, tc.want)
			}
		})
	}
}

func TestMatchModulesSanitizesWithoutOrgContext(t *testing.T) {
	// orgID == nil means no catalog to check against — matchOne is never
	// called, so this exercises the sanitization ladder without a DB.
	in := []generatedModule{
		{Title: "Intro to Go", Description: "learn the basics", ModuleType: "course", EstimatedMinutes: 45},
		{Title: "Weird Type", Description: "", ModuleType: "not_a_real_type", EstimatedMinutes: 0},
	}

	out, err := matchModules(context.Background(), nil, nil, in)
	if err != nil {
		t.Fatalf("matchModules returned error: %v", err)
	}
	if len(out) != 2 {
		t.Fatalf("expected 2 modules, got %d", len(out))
	}

	if out[0].ModuleType != ModuleTypeCourse {
		t.Errorf("expected module_type %q, got %q", ModuleTypeCourse, out[0].ModuleType)
	}
	if out[0].Description == nil || *out[0].Description != "learn the basics" {
		t.Errorf("expected description to be set")
	}
	if out[0].EstimatedMinutes == nil || *out[0].EstimatedMinutes != 45 {
		t.Errorf("expected estimated_minutes 45, got %v", out[0].EstimatedMinutes)
	}
	if out[0].ResourceType != nil {
		t.Errorf("expected no resource match without org context, got %v", *out[0].ResourceType)
	}

	if out[1].ModuleType != ModuleTypeReading {
		t.Errorf("expected invalid module_type to fall back to %q, got %q", ModuleTypeReading, out[1].ModuleType)
	}
	if out[1].Description != nil {
		t.Errorf("expected nil description for empty input, got %v", *out[1].Description)
	}
	if out[1].EstimatedMinutes != nil {
		t.Errorf("expected nil estimated_minutes for zero input, got %v", *out[1].EstimatedMinutes)
	}
}

func TestTruncate(t *testing.T) {
	if got := truncate("short", 200); got != "short" {
		t.Errorf("expected unchanged short string, got %q", got)
	}
	long := make([]byte, 250)
	for i := range long {
		long[i] = 'a'
	}
	if got := truncate(string(long), 200); len(got) != 200 {
		t.Errorf("expected truncated length 200, got %d", len(got))
	}
}
