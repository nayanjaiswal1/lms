package main

import (
	"net/http"
	"strings"
	"testing"
)

func TestAllowRewrittenInlineScripts(t *testing.T) {
	h := http.Header{}
	h.Set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'sha256-old'")
	doc := `<script>var a=1</script><script>var u='/p/x/stable-1'</script>`
	allowRewrittenInlineScripts(h, doc, "/p/x")
	got := h.Get("Content-Security-Policy")
	if strings.Count(got, "'sha256-") != 2 { // old + exactly one new (only the rewritten script)
		t.Fatalf("want one added hash, got %q", got)
	}
}
