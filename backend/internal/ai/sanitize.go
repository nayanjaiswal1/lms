package ai

import (
	"regexp"
	"strings"
	"unicode/utf8"
)

var htmlTagRe = regexp.MustCompile(`<[^>]+>`)
var multiSpaceRe = regexp.MustCompile(`\s+`)

// SanitizeTopic prepares a user-supplied topic string for LLM consumption.
// Strips HTML tags, collapses whitespace, and caps at maxLen runes.
func SanitizeTopic(input string, maxLen int) string {
	s := htmlTagRe.ReplaceAllString(input, "")
	s = multiSpaceRe.ReplaceAllString(s, " ")
	s = strings.TrimSpace(s)
	if maxLen <= 0 {
		maxLen = 200
	}
	if utf8.RuneCountInString(s) > maxLen {
		runes := []rune(s)
		s = string(runes[:maxLen])
	}
	return s
}

// SanitizeAnswer prepares a user-supplied answer for LLM review.
// Strips HTML and caps at 5000 characters.
func SanitizeAnswer(input string) string {
	s := htmlTagRe.ReplaceAllString(input, "")
	s = strings.TrimSpace(s)
	if len(s) > 5000 {
		s = s[:5000]
	}
	return s
}
