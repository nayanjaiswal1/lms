package labblock

import "testing"

func TestCheckRefDisplayTitle(t *testing.T) {
	if got := (CheckRef{}).DisplayTitle("Block title"); got != "Block title" {
		t.Errorf("no label: got %q, want the block title", got)
	}
	if got := (CheckRef{Label: "Own label"}).DisplayTitle("Block title"); got != "Own label" {
		t.Errorf("label set: got %q, want the label", got)
	}
}
