package middleware

import (
	"context"
	"net/http"
	"testing"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// TestRequireOrgRoleCrossOrgCtxIgnored: an OrgCtx for another org (where the
// caller is owner) must not grant a role in the JWT's org (where they are a
// plain mentor); the role is re-read from the database for claims.OrgID.
func TestRequireOrgRoleCrossOrgCtxIgnored(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	var orgA, orgB, userID string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('Org A', 'cross-a') RETURNING id`).Scan(&orgA); err != nil {
		t.Fatalf("insert org A: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('Org B', 'cross-b') RETURNING id`).Scan(&orgB); err != nil {
		t.Fatalf("insert org B: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('cross@`+testdomain.Domain+`', 'Cross User') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	for org, role := range map[string]string{orgA: RoleOwner, orgB: RoleMentor} {
		if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, $3, 'active')`, org, userID, role); err != nil {
			t.Fatalf("insert member (%s): %v", role, err)
		}
	}

	reqCtx := auth.SetClaims(ctx, &auth.Claims{UserID: userID, OrgID: orgB})
	reqCtx = context.WithValue(reqCtx, orgKey, &OrgCtx{OrgID: orgA, CallerRole: RoleOwner})

	code, reached := serve(t, RequireOrgRole(pool, RoleOwner), reqCtx)
	if code != http.StatusForbidden || reached {
		t.Fatalf("got %d reached=%v, want 403 not reached", code, reached)
	}
}
