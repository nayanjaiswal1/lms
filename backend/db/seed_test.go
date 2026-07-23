package db

import (
	"sort"
	"testing"
)

// TestSeedRankOrdering locks in the load order SeedDev depends on: base seed
// first, then generated course content, then anything else (which may
// reference IDs the generated files created).
func TestSeedRankOrdering(t *testing.T) {
	names := []string{
		"warm_pool_seed.sql",
		"java_mastery.generated.sql",
		"grant_all_roles_jaiswal.sql",
		"dev_seed.sql",
		"interview-prep-45.generated.sql",
	}
	sort.SliceStable(names, func(i, j int) bool {
		ri, rj := seedRank(names[i]), seedRank(names[j])
		if ri != rj {
			return ri < rj
		}
		return names[i] < names[j]
	})

	want := []string{
		"dev_seed.sql",
		"grant_all_roles_jaiswal.sql",
		"interview-prep-45.generated.sql",
		"java_mastery.generated.sql",
		"warm_pool_seed.sql",
	}
	for i, name := range want {
		if names[i] != name {
			t.Fatalf("position %d: got %q, want %q (full order: %v)", i, names[i], name, names)
		}
	}
}

// TestSeedFixturesEmbedded is a smoke check that every fixture file this
// package expects to auto-load actually matches one of the go:embed patterns
// — the exact class of bug this file was rewritten to make impossible.
func TestSeedFixturesEmbedded(t *testing.T) {
	required := []string{
		"fixtures/dev_seed.sql",
		"fixtures/grant_all_roles_jaiswal.sql",
	}
	for _, name := range required {
		if _, err := devSeedFS.ReadFile(name); err != nil {
			t.Fatalf("required fixture %q not embedded: %v", name, err)
		}
	}
}
