package mcpconnect

import (
	"os"
	"strings"
	"testing"
)

// docs/ai-connector.md's tool table must list every registered tool with its
// scope and permission, so the doc cannot silently drift from tools.go.
func TestToolsDocumented(t *testing.T) {
	doc, err := os.ReadFile("../../../docs/ai-connector.md")
	if err != nil {
		t.Fatalf("read doc: %v", err)
	}
	for _, tl := range tools {
		perm := "`" + tl.Permission + "`"
		switch tl.Permission {
		case permActiveMember:
			perm = "any active member"
		case "content.wiki":
			perm = "`content.wiki` or project-workspace member"
		}
		row := "| `" + tl.Name + "` | `" + tl.Scope + "` | " + perm + " | "
		if !strings.Contains(string(doc), row) {
			t.Errorf("docs/ai-connector.md tool table is missing or wrong for %q (want a row starting %q)", tl.Name, row)
		}
	}
}
