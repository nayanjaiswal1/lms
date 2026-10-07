package profile

import (
	"context"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/certificates"
	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// An org admin may read a member's profile, but never a user of another org.
func TestGetUserProfile_AdminScopedToOwnOrg(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	svc := NewService(NewRepo(pool), nil, nil, certificates.NewRepo(pool))

	seedUser := func(email string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, $1) RETURNING id`, email).Scan(&id); err != nil {
			t.Fatalf("seed user: %v", err)
		}
		return id
	}
	seedOrg := func(slug string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug).Scan(&id); err != nil {
			t.Fatalf("seed org: %v", err)
		}
		return id
	}
	join := func(orgID, userID, role string) {
		if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, $3)`, orgID, userID, role); err != nil {
			t.Fatalf("seed member: %v", err)
		}
	}

	orgA, orgB := seedOrg("org-a"), seedOrg("org-b")
	admin, insider, outsider := seedUser("admin@a.test"), seedUser("in@a.test"), seedUser("out@b.test")
	join(orgA, admin, "admin")
	join(orgA, insider, "learner")
	join(orgB, outsider, "learner")

	if _, err := svc.GetUserProfile(ctx, admin, "", "admin", orgA, insider); err != nil {
		t.Fatalf("same-org read should succeed: %v", err)
	}
	if _, err := svc.GetUserProfile(ctx, admin, "", "admin", orgA, outsider); !errors.Is(err, ErrNotFound) {
		t.Fatalf("cross-org read must be ErrNotFound, got %v", err)
	}
}
