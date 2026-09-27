package config

import "testing"

func TestIsLocalDB(t *testing.T) {
	cases := map[string]bool{
		"postgres://u:p@localhost:5432/db":                             true,
		"postgres://u:p@127.0.0.1/db":                                  true,
		"postgres://u:p@[::1]:5432/db":                                 true,
		"postgres://u:p@postgres:5432/db":                              true,
		"postgresql://u:p@ep-x-pooler.ap-southeast-1.aws.neon.tech/db": false,
		"::not a url":                                                  false,
		"":                                                             false,
	}
	for dsn, want := range cases {
		if got := (&Config{DatabaseURL: dsn}).IsLocalDB(); got != want {
			t.Errorf("IsLocalDB(%q) = %v, want %v", dsn, got, want)
		}
	}
}
