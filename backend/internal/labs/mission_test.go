package labs

import (
	"errors"
	"strings"
	"testing"
)

func TestDebugUISwitchResolvesToOldUnlessExplicitlyNew(t *testing.T) {
	str := func(s string) *string { return &s }
	cases := []struct {
		name    string
		raw     *string
		hasKind bool
		wantUI  string
		wantOn  bool
	}{
		{"absent key stays old", nil, true, DebugUIOld, false},
		{"empty value stays old", str(""), true, DebugUIOld, false},
		{"unknown value stays old", str("beta"), true, DebugUIOld, false},
		{"explicit old", str(DebugUIOld), true, DebugUIOld, false},
		{"explicit new on a kind lab", str(DebugUINew), true, DebugUINew, true},
		{"new never applies to a lab without a kind", str(DebugUINew), false, DebugUINew, false},
	}
	for _, c := range cases {
		ui := resolveDebugUI(c.raw)
		if ui != c.wantUI {
			t.Errorf("%s: resolveDebugUI = %q, want %q", c.name, ui, c.wantUI)
		}
		if got := missionOn(c.hasKind, ui); got != c.wantOn {
			t.Errorf("%s: missionOn = %v, want %v", c.name, got, c.wantOn)
		}
	}
}

func TestNormalizeActivity(t *testing.T) {
	long := strings.Repeat("a", ActivityMaxDetail+1)
	bad := [][]ActivityEventInput{
		nil,
		{{Type: "keystroke"}},
		{{Type: ActivityFileOpen, Detail: "  "}},
		{{Type: ActivityFileOpen, Detail: long}},
		make([]ActivityEventInput, ActivityMaxBatch+1),
	}
	for i, in := range bad {
		if _, err := normalizeActivity(in); !errors.Is(err, ErrInvalidActivity) {
			t.Errorf("bad batch %d: err = %v, want ErrInvalidActivity", i, err)
		}
	}

	out, err := normalizeActivity([]ActivityEventInput{
		{Type: ActivityFileOpen, Detail: " src/app.py ", Value: 9},
		{Type: ActivityPaste, Detail: "secret", Value: -5},
		{Type: ActivityTabAway, Value: ActivityMaxValue * 2},
	})
	if err != nil {
		t.Fatalf("valid batch: %v", err)
	}
	want := []ActivityEventInput{
		{Type: ActivityFileOpen, Detail: "src/app.py", Value: 0},
		{Type: ActivityPaste, Detail: "", Value: 0},
		{Type: ActivityTabAway, Detail: "", Value: ActivityMaxValue},
	}
	for i := range want {
		if out[i] != want[i] {
			t.Errorf("event %d = %+v, want %+v", i, out[i], want[i])
		}
	}
}
