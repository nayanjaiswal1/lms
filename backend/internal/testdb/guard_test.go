package testdb

import "testing"

func TestCheckTestDBURL(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://u:p@localhost:5432/app")
	cases := []struct {
		url string
		ok  bool
	}{
		{"postgres://u:p@localhost:5433/postgres", true},
		{"postgres://u:p@ep-x.ap-southeast-1.aws.neon.tech/neondb", false},
		{"postgres://u:p@localhost:5432/app", false},
		{"://bad", false},
	}
	for _, c := range cases {
		if err := checkTestDBURL(c.url); (err == nil) != c.ok {
			t.Errorf("checkTestDBURL(%q) err=%v, want ok=%v", c.url, err, c.ok)
		}
	}
}
