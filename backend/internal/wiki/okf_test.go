package wiki

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

// TestOKFRoundTrip exercises every block/mark tiptapToMarkdown and
// markdownToTiptap both claim to handle: heading, bold/italic/code marks, a
// bulleted list, a code block, and a link. Markdown -> TipTap -> Markdown
// should be stable (semantically, not necessarily byte-identical).
func TestOKFRoundTrip(t *testing.T) {
	const md = "# Title\n\nSome **bold** and *italic* and `code` text with a [link](https://example.com).\n\n- item one\n- item two\n\n```go\nfmt.Println(\"hi\")\n```\n"

	content, err := markdownToTiptap(md)
	if err != nil {
		t.Fatalf("markdownToTiptap: %v", err)
	}

	rendered, err := tiptapToMarkdown(content, nil)
	if err != nil {
		t.Fatalf("tiptapToMarkdown: %v", err)
	}

	for _, want := range []string{"# Title", "**bold**", "*italic*", "`code`", "[link](https://example.com)", "- item one", "- item two", "```go", "fmt.Println"} {
		if !strings.Contains(rendered, want) {
			t.Errorf("round-tripped markdown missing %q, got:\n%s", want, rendered)
		}
	}
}

func TestOKFFrontmatterRoundTrip(t *testing.T) {
	p := Page{
		Title:     "Customer Orders",
		Status:    "published",
		UpdatedAt: time.Date(2026, 6, 20, 22, 53, 5, 0, time.UTC),
		Content:   json.RawMessage(`{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"hello"}]}]}`),
	}

	out, err := ToOKFMarkdown(p, nil, ActorForUser("u1"), nil)
	if err != nil {
		t.Fatalf("ToOKFMarkdown: %v", err)
	}
	for _, want := range []string{"type: Wiki Page", "title: Customer Orders", "status: stable", "generated:", "human:u1"} {
		if !strings.Contains(out, want) {
			t.Errorf("frontmatter missing %q, got:\n%s", want, out)
		}
	}

	title, status, meta, content, err := FromOKFMarkdown(out)
	if err != nil {
		t.Fatalf("FromOKFMarkdown: %v", err)
	}
	if title != p.Title {
		t.Errorf("title = %q, want %q", title, p.Title)
	}
	if status == nil || *status != "published" {
		t.Errorf("status = %v, want published", status)
	}
	if len(content) == 0 {
		t.Error("content is empty")
	}
	_ = meta // extension fields (none set in this fixture) preserved separately
}

// TestOKFAgentAttributionSurvivesReRead guards against ToOKFMarkdown
// silently discarding a stored `generated` override in favor of the
// caller's default actor — the whole point of stampAgentAttribution
// (mcpconnect/tools.go) is that an agent-authored edit reads back as such,
// not as a plain human edit by whoever's account made the MCP call.
func TestOKFAgentAttributionSurvivesReRead(t *testing.T) {
	meta, err := json.Marshal(map[string]any{
		"generated": map[string]any{"by": ActorMCP, "at": "2026-06-20T22:53:05Z"},
	})
	if err != nil {
		t.Fatal(err)
	}
	p := Page{
		Title:       "Agent-written page",
		Status:      "published",
		UpdatedAt:   time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		Content:     json.RawMessage(`{"type":"doc","content":[{"type":"paragraph"}]}`),
		OKFMetadata: meta,
	}

	// The default actor here deliberately differs from what's stored, so a
	// pass-through bug (ignoring OKFMetadata) is unambiguous.
	out, err := ToOKFMarkdown(p, nil, ActorForUser("some-other-human"), nil)
	if err != nil {
		t.Fatalf("ToOKFMarkdown: %v", err)
	}
	if !strings.Contains(out, ActorMCP) {
		t.Errorf("frontmatter should attribute generated.by to %q, got:\n%s", ActorMCP, out)
	}
	if strings.Contains(out, "some-other-human") {
		t.Errorf("frontmatter should not fall back to the default actor when a generated override is stored, got:\n%s", out)
	}
}

// TestOKFDeprecatedStatusStaysPublished guards against status: deprecated
// mapping to the native "draft" column, which would hide the page from
// non-managers — SPEC.md §5.4 says deprecated content is "kept for links
// and history," not un-published.
func TestOKFDeprecatedStatusStaysPublished(t *testing.T) {
	md := "---\ntype: Wiki Page\ntitle: Old process\nstatus: deprecated\n---\n\nSuperseded.\n"
	_, status, meta, _, err := FromOKFMarkdown(md)
	if err != nil {
		t.Fatalf("FromOKFMarkdown: %v", err)
	}
	if status == nil || *status != "published" {
		t.Errorf("native status = %v, want published (deprecated must stay visible)", status)
	}
	var m map[string]any
	if err := json.Unmarshal(meta, &m); err != nil {
		t.Fatal(err)
	}
	if m["status"] != "deprecated" {
		t.Errorf("okf_metadata status = %v, want \"deprecated\" preserved for the next read", m["status"])
	}
}
