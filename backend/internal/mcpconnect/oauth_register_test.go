package mcpconnect

import (
	"strings"
	"testing"
)

func TestValidRedirectURI(t *testing.T) {
	cases := map[string]bool{
		"https://claude.ai/api/mcp/auth_callback": true,
		"http://localhost:6274/callback":          true,
		"http://127.0.0.1:9/cb":                   true,
		"http://evil.example/cb":                  false,
		"javascript:alert(1)":                     false,
		"data:text/html,x":                        false,
		"https://a.example/cb#frag":               false,
		"https://user:pw@a.example/cb":            false,
		"/relative":                               false,
	}
	for in, want := range cases {
		if got := validRedirectURI(in); got != want {
			t.Errorf("validRedirectURI(%q) = %v, want %v", in, got, want)
		}
	}
}

func TestCleanClientName(t *testing.T) {
	if got := cleanClientName("  \x00Claude\n "); got != "Claude" {
		t.Errorf("control chars not stripped: %q", got)
	}
	if got := cleanClientName(strings.Repeat("a", 300)); len([]rune(got)) != maxClientNameLen {
		t.Errorf("name not capped: %d", len(got))
	}
	if got := cleanClientName(""); got != defaultClientName {
		t.Errorf("empty name should default, got %q", got)
	}
}

func TestScopeReapprovalHelpers(t *testing.T) {
	if got := addedScopes([]string{"a", "b", "c"}, []string{"a"}); len(got) != 2 || got[0] != "b" {
		t.Errorf("addedScopes = %v", got)
	}
	if got, err := grantedSubset([]string{"a", "b"}, nil); err != nil || len(got) != 2 {
		t.Errorf("nil selection = %v, %v", got, err)
	}
	if got, err := grantedSubset([]string{"a", "b"}, []string{"b"}); err != nil || len(got) != 1 {
		t.Errorf("opt-out = %v, %v", got, err)
	}
	if _, err := grantedSubset([]string{"a"}, []string{}); err == nil {
		t.Error("empty selection accepted")
	}
	if _, err := grantedSubset([]string{"a"}, []string{"z"}); err == nil {
		t.Error("unrequested scope accepted")
	}
}
