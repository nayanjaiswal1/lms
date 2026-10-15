package config

import "testing"

func TestShouldSeedDev(t *testing.T) {
	const local = "postgres://u:p@localhost:5432/db"
	const remote = "postgresql://u:p@ep-x-pooler.ap-southeast-1.aws.neon.tech/db"
	cases := []struct {
		name string
		cfg  Config
		want bool
	}{
		{"dev + local db", Config{Env: "development", DatabaseURL: local}, true},
		{"dev + remote db, no opt-in", Config{Env: "development", DatabaseURL: remote}, false},
		{"dev + remote db, opted in", Config{Env: "development", DatabaseURL: remote, SeedRemoteDevDB: true}, true},
		{"production ignores opt-in", Config{Env: "production", DatabaseURL: remote, SeedRemoteDevDB: true}, false},
		{"staging ignores opt-in", Config{Env: "staging", DatabaseURL: local, SeedRemoteDevDB: true}, false},
	}
	for _, c := range cases {
		if got := c.cfg.ShouldSeedDev(); got != c.want {
			t.Errorf("%s: ShouldSeedDev() = %v, want %v", c.name, got, c.want)
		}
	}
}

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
