package interviewprep

import (
	"reflect"
	"testing"
)

func boolPtr(b bool) *bool { return &b }

func TestSplitSkills(t *testing.T) {
	codingItems := []CodingItem{
		{Skill: "Go", Passed: boolPtr(true)},
		{Skill: "SQL", Passed: boolPtr(false)},
		{Skill: "Concurrency", Passed: nil}, // never attempted counts as weak
	}
	conceptualSkills := []string{"System Design", "Go"} // "Go" already strong from coding, must not duplicate

	// conceptualPct=75 (>=60) puts conceptual-only skills in strong.
	strong, weak := splitSkills(codingItems, 75, conceptualSkills)

	wantStrong := []string{"Go", "System Design"}
	if !reflect.DeepEqual(strong, wantStrong) {
		t.Errorf("strong = %v, want %v", strong, wantStrong)
	}
	wantWeak := []string{"SQL", "Concurrency"}
	if !reflect.DeepEqual(weak, wantWeak) {
		t.Errorf("weak = %v, want %v", weak, wantWeak)
	}
}

func TestSplitSkills_LowConceptualScoreMarksWeak(t *testing.T) {
	strong, weak := splitSkills(nil, 40, []string{"Kubernetes"})
	if len(strong) != 0 {
		t.Errorf("strong = %v, want empty", strong)
	}
	if !reflect.DeepEqual(weak, []string{"Kubernetes"}) {
		t.Errorf("weak = %v, want [Kubernetes]", weak)
	}
}

func TestRound1(t *testing.T) {
	cases := []struct {
		in   float64
		want float64
	}{
		{72.34, 72.3},
		{72.36, 72.4},
		{0, 0},
		{100, 100},
	}
	for _, c := range cases {
		if got := round1(c.in); got != c.want {
			t.Errorf("round1(%v) = %v, want %v", c.in, got, c.want)
		}
	}
}
