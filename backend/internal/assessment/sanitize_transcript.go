package assessment

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/unicode/norm"
)

const maxTranscriptBytes = 8000

// injectionPattern describes a single injection detection rule.
type injectionPattern struct {
	re    *regexp.Regexp
	score int
}

var injectionPatterns = []injectionPattern{
	{regexp.MustCompile(`(?i)ignore\s+(all\s+|previous\s+|the\s+)?instructions?`), 40},
	{regexp.MustCompile(`(?i)you\s+are\s+now`), 20},
	{regexp.MustCompile(`(?i)override\s+(scoring|mode|instructions?)`), 30},
	{regexp.MustCompile(`(?i)score[\s:]+\d{1,3}`), 25},
	{regexp.MustCompile(`(?i)return\s*\{`), 20},
	{regexp.MustCompile(`(?i)composite_score`), 35},
	{regexp.MustCompile(`(?i)system[\s:]+override`), 40},
	{regexp.MustCompile(`(?i)mark\s+(as|this)\s+(correct|perfect)`), 25},
	{regexp.MustCompile(`(?i)<\/?(CANDIDATE_ANSWER|SYSTEM|QUESTION)>`), 50},
	// Base64 blob ≥ 40 chars: [A-Za-z0-9+/]{40,}={0,2}
	{regexp.MustCompile(`[A-Za-z0-9+/]{40,}={0,2}`), 15},
}

const injectionFlagThreshold = 40

// SanitizeTranscript applies the 6-layer input sanitation pipeline (Layer 1):
//   - Caps input at maxTranscriptBytes characters
//   - NFKC-normalises Unicode (homoglyph guard)
//   - Strips ASCII control characters (except newlines and tabs)
//   - Scores injection patterns; sets flagged=true when score ≥ threshold
//   - Escapes XML delimiters so they cannot break the prompt fence
//
// Returns (cleaned, flagged, injectionScore).
func SanitizeTranscript(raw string) (string, bool, int) {
	// 1. Length cap — truncate at rune boundary to avoid splitting multi-byte chars.
	if len(raw) > maxTranscriptBytes {
		raw = truncateToBytes(raw, maxTranscriptBytes)
	}

	// 2. NFKC normalise (collapses homoglyphs, compatibility forms, etc.).
	raw = norm.NFKC.String(raw)

	// 3. Strip control characters except \t (U+0009) and \n (U+000A).
	var sb strings.Builder
	sb.Grow(len(raw))
	for _, r := range raw {
		if r == '\t' || r == '\n' || !unicode.IsControl(r) {
			sb.WriteRune(r)
		}
	}
	raw = sb.String()

	// 4. Score injection patterns.
	total := 0
	for _, p := range injectionPatterns {
		if p.re.MatchString(raw) {
			total += p.score
		}
	}
	flagged := total >= injectionFlagThreshold

	// 5. Escape XML delimiters so they cannot break the prompt fence.
	//    < → ‹  > → ›  (Unicode angle quotation marks, visually similar)
	raw = strings.ReplaceAll(raw, "<", "‹")
	raw = strings.ReplaceAll(raw, ">", "›")

	return raw, flagged, total
}

// truncateToBytes cuts s to at most n bytes at a valid UTF-8 rune boundary.
func truncateToBytes(s string, n int) string {
	if len(s) <= n {
		return s
	}
	// Walk backwards from n until we're at the start of a rune.
	for n > 0 && !utf8.RuneStart(s[n]) {
		n--
	}
	return s[:n]
}
