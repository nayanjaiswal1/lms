package sheets

import (
	"crypto/rand"
	"encoding/hex"
	"regexp"
	"strings"
)

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

// Slugify produces a URL-safe, collision-resistant slug from arbitrary text —
// used for both sheet slugs and item topic_tags created by users (system
// seed data ships its own hand-picked topic_tags/slugs). Exported so
// mcpconnect's sheet-tracker tools can mint the same slug shape the HTTP
// handlers do instead of duplicating this.
func Slugify(s string) string {
	base := slugRe.ReplaceAllString(strings.ToLower(strings.TrimSpace(s)), "-")
	base = strings.Trim(base, "-")
	if base == "" {
		base = "sheet"
	}
	if len(base) > 60 {
		base = base[:60]
	}
	return base + "-" + randomHex(4)
}

func randomHex(n int) string {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		// crypto/rand.Read only fails if the OS entropy source is
		// unavailable, which would already be a fatal environment problem
		// elsewhere in the process; a fixed fallback keeps slug generation
		// from panicking in that scenario.
		return "0000"
	}
	return hex.EncodeToString(buf)
}
