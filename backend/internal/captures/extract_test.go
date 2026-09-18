package captures

import (
	"strings"
	"testing"
)

func TestExtractHTML(t *testing.T) {
	page := `<html><head><title>  A Great Article  </title>
		<script>trackStuff();</script>
		<style>.x{color:red}</style>
	</head><body>
		<nav>Home About Contact</nav>
		<header>Site Header</header>
		<article><h1>Main Point</h1><p>This is the actual content worth reading.</p></article>
		<footer>Copyright 2024</footer>
	</body></html>`

	title, text := extractHTML(strings.NewReader(page))

	if title != "A Great Article" {
		t.Errorf("title = %q, want %q", title, "A Great Article")
	}
	if !strings.Contains(text, "Main Point") || !strings.Contains(text, "actual content worth reading") {
		t.Errorf("text missing expected article content: %q", text)
	}
	for _, chrome := range []string{"Home About Contact", "Site Header", "Copyright 2024", "trackStuff", "color:red"} {
		if strings.Contains(text, chrome) {
			t.Errorf("text should not contain chrome/script/style %q, got: %q", chrome, text)
		}
	}
}

func TestExtractHTMLNoTitle(t *testing.T) {
	title, text := extractHTML(strings.NewReader(`<html><body><p>Just a paragraph.</p></body></html>`))
	if title != "" {
		t.Errorf("title = %q, want empty", title)
	}
	if !strings.Contains(text, "Just a paragraph.") {
		t.Errorf("text = %q, want to contain the paragraph", text)
	}
}

func TestClampField(t *testing.T) {
	cases := []struct {
		in     string
		maxLen int
		want   string
	}{
		{"  hello  ", 20, "hello"},
		{"exactly ten", 5, "exact"},
		{"", 10, ""},
	}
	for _, c := range cases {
		got := clampField(c.in, c.maxLen)
		if got != c.want {
			t.Errorf("clampField(%q, %d) = %q, want %q", c.in, c.maxLen, got, c.want)
		}
	}
}
