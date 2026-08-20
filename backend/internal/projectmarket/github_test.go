package projectmarket

import "testing"

func TestGithubUsernameFrom(t *testing.T) {
	cases := map[string]string{
		"octocat":                         "octocat",
		"https://github.com/octocat":      "octocat",
		"http://github.com/octocat":       "octocat",
		"github.com/octocat":              "octocat",
		"https://www.github.com/octocat":  "octocat",
		"https://github.com/octocat/":     "octocat",
		"https://github.com/octocat/repo": "octocat",
		"":                                "",
		"   ":                             "",
	}
	for input, want := range cases {
		if got := githubUsernameFrom(input); got != want {
			t.Errorf("githubUsernameFrom(%q) = %q, want %q", input, got, want)
		}
	}
}
