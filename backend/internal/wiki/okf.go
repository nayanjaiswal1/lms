// Package wiki: okf.go converts between OKF v0.2 concept documents
// (github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf/SPEC.md)
// and this package's Page/Space types, and builds the bundle-level index.md
// and log.md files SPEC.md §8/§9 describe. Kept inside internal/wiki rather
// than a standalone okf package — the markdown<->TipTap conversion at its
// core (MarkdownToTipTap/TipTapToMarkdown) now has a second caller
// (sheets problem notes, over MCP) but stays here rather than moving to its
// own package until a third caller makes the split worth it.
package wiki

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/text"
	"gopkg.in/yaml.v3"
)

// ─── Actor convention (SPEC.md §7) ─────────────────────────────────────────

// ActorForUser returns the OKF actor string for a human wiki edit.
func ActorForUser(userID string) string { return "human:" + userID }

// ActorMCP is the actor string for a page written or edited through the MCP
// connector (an agent acting on the connected user's behalf), rather than
// directly by a human in the wiki UI.
const ActorMCP = "mindforge-mcp/v1"

// ─── Frontmatter (SPEC.md §4.1, §5, §10) ───────────────────────────────────

type okfActor struct {
	By string    `yaml:"by"`
	At time.Time `yaml:"at"`
}

type okfVerification struct {
	By string    `yaml:"by"`
	At time.Time `yaml:"at"`
}

type okfSource struct {
	ID           string     `yaml:"id,omitempty"`
	Resource     string     `yaml:"resource"`
	Title        string     `yaml:"title,omitempty"`
	Author       string     `yaml:"author,omitempty"`
	UsageCount   *int       `yaml:"usage_count,omitempty"`
	LastModified *time.Time `yaml:"last_modified,omitempty"`
}

// okfFrontmatter is the full OKF v0.2 concept frontmatter (SPEC.md §4.1).
// Fields the wiki has no native column for (Resource, Tags, Sources,
// Verified, StaleAfter, and a Type override) round-trip through
// Page.OKFMetadata instead of a schema change per field.
type okfFrontmatter struct {
	Type        string            `yaml:"type"`
	Title       string            `yaml:"title,omitempty"`
	Description string            `yaml:"description,omitempty"`
	Resource    string            `yaml:"resource,omitempty"`
	Tags        []string          `yaml:"tags,omitempty"`
	Sources     []okfSource       `yaml:"sources,omitempty"`
	Generated   *okfActor         `yaml:"generated,omitempty"`
	Verified    []okfVerification `yaml:"verified,omitempty"`
	Status      string            `yaml:"status,omitempty"`
	StaleAfter  *time.Time        `yaml:"stale_after,omitempty"`
}

// statusToOKF maps the wiki's native status column (draft|published) to the
// OKF lifecycle vocabulary (draft|stable|deprecated, SPEC.md §5.4).
// "deprecated" has no native wiki status — a page is marked deprecated by
// setting status: deprecated in okf_metadata (via the OKF write path)
// without touching the native column, so it stays visible/editable in the
// wiki UI exactly as SPEC.md §5.4 intends ("kept for links and history").
func statusToOKF(nativeStatus string, meta map[string]any) string {
	if s, ok := meta["status"].(string); ok && s != "" {
		return s
	}
	if nativeStatus == "published" {
		return "stable"
	}
	return "draft"
}

// StampGenerated overwrites okfMeta's `generated` field to actor/now,
// discarding whatever the submitted document's own frontmatter declared.
// Both write paths (the raw OKF PUT endpoint, the MCP connector) call this
// unconditionally, so `generated` always reflects who/what actually
// produced the *current* content (SPEC.md §5.2) — a human who copies a
// previous get_wiki_page/GetPageOKF output, edits the body, and pastes it
// back without touching the frontmatter must not have that edit misreport
// itself under whatever `generated` happened to still be in the copy (an
// earlier agent's attribution, or a stale timestamp).
func StampGenerated(okfMeta json.RawMessage, actor string) (json.RawMessage, error) {
	m := map[string]any{}
	if len(okfMeta) > 0 {
		if err := json.Unmarshal(okfMeta, &m); err != nil {
			return nil, fmt.Errorf("okf: decode metadata: %w", err)
		}
	}
	m["generated"] = map[string]any{"by": actor, "at": time.Now().UTC().Format(time.RFC3339)}
	return json.Marshal(m)
}

func decodeOKFMetadata(raw json.RawMessage) map[string]any {
	if len(raw) == 0 {
		return map[string]any{}
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		return map[string]any{}
	}
	return m
}

// ToOKFMarkdown renders a page as a conformant OKF v0.2 concept document:
// frontmatter block + markdown body. actor is the OKF actor (§7) recorded as
// generated.by; resolveLink, if non-nil, rewrites an in-app wiki link href
// into a bundle-relative path for cross-linking (§6.1) — pass nil to leave
// hrefs as absolute app URLs (still spec-conformant, just not bundle-local).
func ToOKFMarkdown(p Page, breadcrumb []BreadcrumbItem, actor string, resolveLink func(href string) string) (string, error) {
	meta := decodeOKFMetadata(p.OKFMetadata)

	fm := okfFrontmatter{
		Type:        "Wiki Page",
		Title:       p.Title,
		Generated:   &okfActor{By: actor, At: p.UpdatedAt},
		Status:      statusToOKF(p.Status, meta),
	}
	if t, ok := meta["type"].(string); ok && t != "" {
		fm.Type = t
	}
	if d, ok := meta["description"].(string); ok {
		fm.Description = d
	}
	if r, ok := meta["resource"].(string); ok {
		fm.Resource = r
	}
	if tags, ok := meta["tags"].([]any); ok {
		for _, t := range tags {
			if s, ok := t.(string); ok {
				fm.Tags = append(fm.Tags, s)
			}
		}
	}
	if raw, ok := meta["sources"]; ok {
		if b, err := json.Marshal(raw); err == nil {
			_ = json.Unmarshal(b, &fm.Sources)
		}
	}
	if raw, ok := meta["verified"]; ok {
		if b, err := json.Marshal(raw); err == nil {
			_ = json.Unmarshal(b, &fm.Verified)
		}
	}
	// A page last written through UpdatePageOKF/the MCP connector carries its
	// own producer-declared `generated` (e.g. stampAgentAttribution's
	// mindforge-mcp/v1) — that must win over the actor default derived from
	// updated_by, or every agent-authored edit would misreport itself as a
	// plain human edit on the very next read.
	if g, ok := meta["generated"].(map[string]any); ok {
		if by, ok := g["by"].(string); ok && by != "" {
			fm.Generated.By = by
		}
		if at, ok := g["at"].(string); ok {
			if t, err := time.Parse(time.RFC3339, at); err == nil {
				fm.Generated.At = t
			}
		}
	}
	if sa, ok := meta["stale_after"].(string); ok {
		if t, err := time.Parse(time.RFC3339, sa); err == nil {
			fm.StaleAfter = &t
		}
	}

	yamlBytes, err := yaml.Marshal(fm)
	if err != nil {
		return "", fmt.Errorf("okf: marshal frontmatter: %w", err)
	}

	body, err := tiptapToMarkdown(p.Content, resolveLink)
	if err != nil {
		return "", fmt.Errorf("okf: render body: %w", err)
	}

	var out strings.Builder
	out.WriteString("---\n")
	out.Write(yamlBytes)
	out.WriteString("---\n\n")
	out.WriteString(body)
	return out.String(), nil
}

// FromOKFMarkdown parses an OKF concept document back into the fields
// UpdatePage understands: title and status map to their native wiki
// columns; every other frontmatter key (description, resource, tags,
// sources, verified, stale_after, a type override, and any producer
// extension key) is preserved verbatim in okfMetadata for a lossless
// round-trip (SPEC.md §4.1: "Consumers SHOULD preserve unknown keys").
func FromOKFMarkdown(md string) (title string, status *string, okfMetadata json.RawMessage, content json.RawMessage, err error) {
	fmBlock, body, ok := splitFrontmatter(md)
	if !ok {
		return "", nil, nil, nil, fmt.Errorf("okf: no frontmatter block found")
	}

	var raw map[string]any
	if err := yaml.Unmarshal([]byte(fmBlock), &raw); err != nil {
		return "", nil, nil, nil, fmt.Errorf("okf: parse frontmatter: %w", err)
	}

	if t, ok := raw["title"].(string); ok {
		title = t
	}
	delete(raw, "title")

	if s, ok := raw["status"].(string); ok {
		// Only "draft" maps to the native draft column (hidden from
		// non-managers, per filterPublished). Everything else — "stable",
		// "deprecated", or an unrecognized value — stays native "published":
		// SPEC.md §5.4 says a deprecated concept is "kept for links and
		// history," not hidden, and an unknown status must be tolerated
		// (§11), never used to silently un-publish a page.
		native := "published"
		if s == "draft" {
			native = "draft"
		}
		status = &native
		if s != "draft" && s != "stable" {
			raw["status"] = s // deprecated (or anything else): preserved for the next read's statusToOKF override
		} else {
			delete(raw, "status")
		}
	}

	metaBytes, err := json.Marshal(raw)
	if err != nil {
		return "", nil, nil, nil, fmt.Errorf("okf: re-marshal metadata: %w", err)
	}
	okfMetadata = metaBytes

	content, err = markdownToTiptap(body)
	if err != nil {
		return "", nil, nil, nil, fmt.Errorf("okf: parse body: %w", err)
	}
	return title, status, okfMetadata, content, nil
}

func splitFrontmatter(md string) (frontmatter, body string, ok bool) {
	const delim = "---"
	s := strings.TrimLeft(md, "\n")
	if !strings.HasPrefix(s, delim) {
		return "", "", false
	}
	rest := s[len(delim):]
	end := strings.Index(rest, "\n"+delim)
	if end == -1 {
		return "", "", false
	}
	frontmatter = strings.TrimPrefix(rest[:end], "\n")
	body = strings.TrimPrefix(rest[end+len(delim)+1:], "\n")
	return frontmatter, body, true
}

// ─── TipTap/ProseMirror <-> Markdown (SPEC.md §4.2) ────────────────────────
//
// ponytail: covers the block/mark vocabulary docs/wiki.md lists as common
// (headings, paragraph, bold/italic/code marks, lists, code blocks, links,
// dividers). Tables, images, callouts, and checklists pass through as their
// plain text content rather than reconstructing markdown tables/images —
// extend tiptapToMarkdown/markdownToTiptap's node switch when a real page
// exercises one of those.

func tiptapToMarkdown(content json.RawMessage, resolveLink func(string) string) (string, error) {
	var doc any
	if len(content) == 0 {
		return "", nil
	}
	if err := json.Unmarshal(content, &doc); err != nil {
		return "", err
	}
	var b strings.Builder
	writeNode(&b, doc, resolveLink, 0)
	return strings.TrimSpace(b.String()) + "\n", nil
}

// MarkdownToTipTap converts a markdown body into the same TipTap/ProseMirror
// JSON document shape the wiki editor (and anything else storing rich text
// in this shape, e.g. sheet problem notes) produces. Exported so callers
// can accept plain markdown over a token-metered channel like MCP instead
// of hand-authoring TipTap JSON node-by-node — the same reason
// create_wiki_page/update_wiki_page take OKF markdown, not raw content.
func MarkdownToTipTap(body string) (json.RawMessage, error) {
	return markdownToTiptap(body)
}

// TipTapToMarkdown converts a TipTap/ProseMirror JSON document into
// markdown — the reverse of MarkdownToTipTap, exported for the same reason.
// Internal wiki links are left unresolved (no resolveLink); a caller
// outside the wiki package has no page-relative link context to resolve
// against.
func TipTapToMarkdown(content json.RawMessage) (string, error) {
	return tiptapToMarkdown(content, nil)
}

func writeNode(b *strings.Builder, node any, resolveLink func(string) string, listDepth int) {
	m, ok := node.(map[string]any)
	if !ok {
		return
	}
	children, _ := m["content"].([]any)
	nodeType, _ := m["type"].(string)

	switch nodeType {
	case "doc":
		writeChildren(b, children, resolveLink, listDepth)
	case "paragraph":
		writeInline(b, children, resolveLink)
		b.WriteString("\n\n")
	case "heading":
		level := 1
		if attrs, ok := m["attrs"].(map[string]any); ok {
			if lv, ok := attrs["level"].(float64); ok {
				level = int(lv)
			}
		}
		b.WriteString(strings.Repeat("#", level) + " ")
		writeInline(b, children, resolveLink)
		b.WriteString("\n\n")
	case "bulletList":
		for _, c := range children {
			b.WriteString(strings.Repeat("  ", listDepth) + "- ")
			writeListItem(b, c, resolveLink, listDepth)
		}
		b.WriteString("\n")
	case "orderedList":
		for i, c := range children {
			b.WriteString(fmt.Sprintf("%s%d. ", strings.Repeat("  ", listDepth), i+1))
			writeListItem(b, c, resolveLink, listDepth)
		}
		b.WriteString("\n")
	case "codeBlock":
		lang := ""
		if attrs, ok := m["attrs"].(map[string]any); ok {
			if l, ok := attrs["language"].(string); ok {
				lang = l
			}
		}
		b.WriteString("```" + lang + "\n")
		writeInline(b, children, nil)
		b.WriteString("\n```\n\n")
	case "blockquote":
		var inner strings.Builder
		writeChildren(&inner, children, resolveLink, listDepth)
		for _, line := range strings.Split(strings.TrimRight(inner.String(), "\n"), "\n") {
			b.WriteString("> " + line + "\n")
		}
		b.WriteString("\n")
	case "horizontalRule":
		b.WriteString("---\n\n")
	case "hardBreak":
		b.WriteString("  \n")
	default:
		// Tables, images, callouts, checklists, and anything else fall back
		// to their plain inline text content — see ponytail note above.
		writeInline(b, children, resolveLink)
		if len(children) > 0 {
			b.WriteString("\n\n")
		}
	}
}

func writeChildren(b *strings.Builder, children []any, resolveLink func(string) string, listDepth int) {
	for _, c := range children {
		writeNode(b, c, resolveLink, listDepth)
	}
}

func writeListItem(b *strings.Builder, node any, resolveLink func(string) string, listDepth int) {
	m, ok := node.(map[string]any)
	if !ok {
		return
	}
	children, _ := m["content"].([]any)
	var inner strings.Builder
	writeChildren(&inner, children, resolveLink, listDepth+1)
	b.WriteString(strings.TrimSpace(inner.String()) + "\n")
}

func writeInline(b *strings.Builder, nodes []any, resolveLink func(string) string) {
	for _, n := range nodes {
		m, ok := n.(map[string]any)
		if !ok {
			continue
		}
		nodeType, _ := m["type"].(string)
		if nodeType == "image" {
			attrs, _ := m["attrs"].(map[string]any)
			src, _ := attrs["src"].(string)
			alt, _ := attrs["alt"].(string)
			b.WriteString(fmt.Sprintf("![%s](%s)", alt, src))
			continue
		}
		text, _ := m["text"].(string)
		if text == "" {
			// A non-text inline node (e.g. an unmodeled embed) — recurse
			// into any nested content rather than dropping it silently.
			if children, ok := m["content"].([]any); ok {
				writeInline(b, children, resolveLink)
			}
			continue
		}

		var href string
		bold, italic, code, strike := false, false, false, false
		if marks, ok := m["marks"].([]any); ok {
			for _, mk := range marks {
				mkm, ok := mk.(map[string]any)
				if !ok {
					continue
				}
				switch mkm["type"] {
				case "bold":
					bold = true
				case "italic":
					italic = true
				case "code":
					code = true
				case "strike":
					strike = true
				case "link":
					if attrs, ok := mkm["attrs"].(map[string]any); ok {
						href, _ = attrs["href"].(string)
					}
				}
			}
		}

		if code {
			text = "`" + text + "`"
		}
		if bold {
			text = "**" + text + "**"
		}
		if italic {
			text = "*" + text + "*"
		}
		if strike {
			text = "~~" + text + "~~"
		}
		if href != "" {
			if resolveLink != nil {
				href = resolveLink(href)
			}
			text = fmt.Sprintf("[%s](%s)", text, href)
		}
		b.WriteString(text)
	}
}

// markdownToTiptap parses an OKF concept's markdown body with goldmark and
// walks the AST into the same ProseMirror JSON shape the wiki editor
// produces, covering the node/mark vocabulary tiptapToMarkdown emits.
func markdownToTiptap(body string) (json.RawMessage, error) {
	src := []byte(body)
	root := goldmark.DefaultParser().Parse(text.NewReader(src))

	var content []any
	for c := root.FirstChild(); c != nil; c = c.NextSibling() {
		if n := astToTiptap(c, src); n != nil {
			content = append(content, n)
		}
	}
	if content == nil {
		content = []any{map[string]any{"type": "paragraph"}}
	}
	doc := map[string]any{"type": "doc", "content": content}
	return json.Marshal(doc)
}

func astToTiptap(n ast.Node, src []byte) any {
	switch n.Kind() {
	case ast.KindHeading:
		h := n.(*ast.Heading)
		return map[string]any{
			"type":    "heading",
			"attrs":   map[string]any{"level": h.Level},
			"content": inlineToTiptap(n, src),
		}
	case ast.KindParagraph, ast.KindTextBlock:
		// TextBlock is goldmark's node for a tight list item's text (no
		// blank line around it) — treated the same as a loose Paragraph.
		return map[string]any{"type": "paragraph", "content": inlineToTiptap(n, src)}
	case ast.KindFencedCodeBlock, ast.KindCodeBlock:
		lang := ""
		if fcb, ok := n.(*ast.FencedCodeBlock); ok && fcb.Info != nil {
			lang = strings.Fields(string(fcb.Info.Text(src)))[0:1][0]
		}
		var code strings.Builder
		lines := n.Lines()
		for i := 0; i < lines.Len(); i++ {
			l := lines.At(i)
			code.Write(l.Value(src))
		}
		return map[string]any{
			"type":    "codeBlock",
			"attrs":   map[string]any{"language": lang},
			"content": []any{map[string]any{"type": "text", "text": strings.TrimRight(code.String(), "\n")}},
		}
	case ast.KindList:
		list := n.(*ast.List)
		var items []any
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			var itemContent []any
			for gc := c.FirstChild(); gc != nil; gc = gc.NextSibling() {
				if node := astToTiptap(gc, src); node != nil {
					itemContent = append(itemContent, node)
				}
			}
			items = append(items, map[string]any{"type": "listItem", "content": itemContent})
		}
		nodeType := "bulletList"
		if list.IsOrdered() {
			nodeType = "orderedList"
		}
		return map[string]any{"type": nodeType, "content": items}
	case ast.KindBlockquote:
		var quoted []any
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			if node := astToTiptap(c, src); node != nil {
				quoted = append(quoted, node)
			}
		}
		return map[string]any{"type": "blockquote", "content": quoted}
	case ast.KindThematicBreak:
		return map[string]any{"type": "horizontalRule"}
	default:
		return nil
	}
}

func inlineToTiptap(block ast.Node, src []byte) []any {
	var out []any
	for c := block.FirstChild(); c != nil; c = c.NextSibling() {
		out = append(out, inlineNodeToTiptap(c, src, nil)...)
	}
	if out == nil {
		out = []any{}
	}
	return out
}

func inlineNodeToTiptap(n ast.Node, src []byte, marks []any) []any {
	switch v := n.(type) {
	case *ast.Text:
		return []any{map[string]any{"type": "text", "text": string(v.Segment.Value(src)), "marks": marks}}
	case *ast.CodeSpan:
		text := ""
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			if t, ok := c.(*ast.Text); ok {
				text += string(t.Segment.Value(src))
			}
		}
		return []any{map[string]any{"type": "text", "text": text, "marks": append(marks, map[string]any{"type": "code"})}}
	case *ast.Emphasis:
		markType := "italic"
		if v.Level == 2 {
			markType = "bold"
		}
		childMarks := append(append([]any{}, marks...), map[string]any{"type": markType})
		var out []any
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			out = append(out, inlineNodeToTiptap(c, src, childMarks)...)
		}
		return out
	case *ast.Link:
		childMarks := append(append([]any{}, marks...), map[string]any{
			"type":  "link",
			"attrs": map[string]any{"href": string(v.Destination)},
		})
		var out []any
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			out = append(out, inlineNodeToTiptap(c, src, childMarks)...)
		}
		return out
	case *ast.Image:
		alt := ""
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			if t, ok := c.(*ast.Text); ok {
				alt += string(t.Segment.Value(src))
			}
		}
		return []any{map[string]any{
			"type":  "image",
			"attrs": map[string]any{"src": string(v.Destination), "alt": alt},
		}}
	default:
		var out []any
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			out = append(out, inlineNodeToTiptap(c, src, marks)...)
		}
		return out
	}
}

// ─── Bundle files (SPEC.md §8, §9) ─────────────────────────────────────────

// okfFilename maps a page slug to its bundle filename, avoiding a collision
// with the two reserved names SPEC.md §3.1 forbids for concept documents
// (index.md, log.md) — a page literally slugged "index" or "log" would
// otherwise silently overwrite the bundle's own directory listing/log.
func okfFilename(slug string) string {
	if slug == "index" || slug == "log" {
		return slug + "-page.md"
	}
	return slug + ".md"
}

// BuildOKFIndex renders a space's page tree as an index.md directory
// listing for progressive disclosure (§8). No frontmatter — only a
// bundle-root index.md may carry okf_version, and a space here is never the
// bundle root (the org's whole set of spaces would be).
func BuildOKFIndex(spaceName string, tree []PageTreeNode) string {
	var b strings.Builder
	b.WriteString("# " + spaceName + "\n\n")
	writeIndexLevel(&b, tree)
	return b.String()
}

func writeIndexLevel(b *strings.Builder, nodes []PageTreeNode) {
	for _, n := range nodes {
		b.WriteString(fmt.Sprintf("* [%s](%s)\n", n.Title, okfFilename(n.Slug)))
	}
	for _, n := range nodes {
		if len(n.Children) == 0 {
			continue
		}
		b.WriteString("\n# " + n.Title + "\n\n")
		writeIndexLevel(b, n.Children)
	}
}

// BuildOKFLog renders one dated entry per page's most recent update as a
// space's log.md (§9). ponytail: one entry per page's current state, not
// full multi-version history — extend to walk content_versions per page if
// a fuller change log is needed.
func BuildOKFLog(pages []Page) string {
	byDate := map[string][]Page{}
	for _, p := range pages {
		d := p.UpdatedAt.Format("2006-01-02")
		byDate[d] = append(byDate[d], p)
	}
	dates := make([]string, 0, len(byDate))
	for d := range byDate {
		dates = append(dates, d)
	}
	sort.Sort(sort.Reverse(sort.StringSlice(dates)))

	var b strings.Builder
	b.WriteString("# Directory Update Log\n\n")
	for _, d := range dates {
		b.WriteString("## " + d + "\n")
		for _, p := range byDate[d] {
			verb := "Update"
			if p.Version <= 1 {
				verb = "Creation"
			}
			b.WriteString(fmt.Sprintf("* **%s**: [%s](%s)\n", verb, p.Title, okfFilename(p.Slug)))
		}
		b.WriteString("\n")
	}
	return b.String()
}
