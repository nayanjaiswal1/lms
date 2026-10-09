package workspace

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// The owner route validates before any GitLab side effect: bad shape and the
// staff-only transfer mode are rejected as field errors.
func TestValidateOwnerHandoff(t *testing.T) {
	cases := []struct {
		name, mode string
		ns         int64
		field      string
	}{
		{"invalid mode", "copy", 5, "mode"},
		{"empty mode", "", 5, "mode"},
		{"missing namespace", gitlab.HandoffModeFork, 0, "target_namespace_id"},
		{"negative namespace", gitlab.HandoffModeFork, -3, "target_namespace_id"},
		{"transfer is staff-only", gitlab.HandoffModeTransfer, 5, "mode"},
	}
	for _, c := range cases {
		var fe *FieldError
		err := validateOwnerHandoff("u1", c.mode, c.ns)
		if !errors.As(err, &fe) || fe.Fields[c.field] == "" {
			t.Errorf("%s: err = %v, want field error on %q", c.name, err, c.field)
		}
	}
	if err := validateOwnerHandoff("u1", gitlab.HandoffModeFork, 5); err != nil {
		t.Errorf("valid fork rejected: %v", err)
	}
}

// An anonymous submit for an email already tied to an account must neither
// overwrite that row nor reveal it; the account's own apply may adopt an
// unclaimed anonymous row.
func TestUpsertInterest_AnonymousCannotOverwriteAccountRow(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	sfx := time.Now().UnixNano()

	var orgID, userID, projectID string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('Int Org', $1) RETURNING id`, fmt.Sprintf("int-org-%d", sfx)).Scan(&orgID); err != nil {
		t.Fatalf("org: %v", err)
	}
	email := fmt.Sprintf("int-%d@%s", sfx, testdomain.Domain)
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1,'Int User') RETURNING id`, email).Scan(&userID); err != nil {
		t.Fatalf("user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO workspace_projects (org_id, title, requirement, team_size_min, team_size_max, key_prefix, project_status, share_token, created_by)
		 VALUES ($1,'Int Project',repeat('r',60),2,5,'INT','recruiting',$2,$3) RETURNING id`,
		orgID, fmt.Sprintf("int-token-%d-aaaaaaaaaaaaaaaa", sfx), userID).Scan(&projectID); err != nil {
		t.Fatalf("project: %v", err)
	}
	msg := func(s string) *string { return &s }
	read := func() (message string, owner *string) {
		if err := pool.QueryRow(ctx, `SELECT message, user_id FROM project_interests WHERE project_id=$1 AND email=$2`, projectID, email).Scan(&message, &owner); err != nil {
			t.Fatalf("read row: %v", err)
		}
		return
	}

	if ok, err := repo.UpsertInterest(ctx, pool, projectID, nil, "Anon", email, nil, nil, msg("anon 1"), ReapplyCooldown); err != nil || !ok {
		t.Fatalf("first anon upsert = %v, %v", ok, err)
	}
	if ok, err := repo.UpsertInterest(ctx, pool, projectID, &userID, "Int User", email, nil, nil, msg("mine"), ReapplyCooldown); err != nil || !ok {
		t.Fatalf("account adopt = %v, %v", ok, err)
	}
	if m, owner := read(); m != "mine" || owner == nil || *owner != userID {
		t.Fatalf("after adopt: message=%q owner=%v", m, owner)
	}
	if ok, err := repo.UpsertInterest(ctx, pool, projectID, nil, "Attacker", email, nil, nil, msg("overwritten"), ReapplyCooldown); err != nil || ok {
		t.Fatalf("anon over account row = %v, %v; want false, nil", ok, err)
	}
	if m, _ := read(); m != "mine" {
		t.Fatalf("anonymous submit overwrote the account's row: %q", m)
	}
}
