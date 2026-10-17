package orgs

import (
	"context"
	"slices"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func rbacSeedUser(t *testing.T, pool *pgxpool.Pool, local string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`, local+"@"+testdomain.Domain, local,
	).Scan(&id); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return id
}

func rbacRoles(t *testing.T, pool *pgxpool.Pool, orgID, userID string) []string {
	t.Helper()
	rows, err := pool.Query(context.Background(),
		`SELECT r.name FROM user_roles ur JOIN roles r ON r.id = ur.role_id
		 WHERE ur.user_id = $1 AND ur.org_id = $2 ORDER BY r.name`, userID, orgID)
	if err != nil {
		t.Fatalf("list roles: %v", err)
	}
	defer rows.Close()
	names := []string{}
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			t.Fatalf("scan role: %v", err)
		}
		names = append(names, n)
	}
	return names
}

func assertRBACRoles(t *testing.T, pool *pgxpool.Pool, orgID, userID string, want ...string) {
	t.Helper()
	if want == nil {
		want = []string{}
	}
	if got := rbacRoles(t, pool, orgID, userID); !slices.Equal(got, want) {
		t.Fatalf("roles = %v, want %v", got, want)
	}
}

func memberRowID(t *testing.T, pool *pgxpool.Pool, orgID, userID string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`SELECT id FROM org_members WHERE org_id = $1 AND user_id = $2`, orgID, userID,
	).Scan(&id); err != nil {
		t.Fatalf("member row: %v", err)
	}
	return id
}

// createJoinToken inserts an invite for email/role and returns its raw token.
func createJoinToken(t *testing.T, pool *pgxpool.Pool, orgID, inviterID, email, role string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO org_invites (org_id, email, role, invited_by_user_id, token_hash, expires_at)
		 VALUES ($1, $2, $3, $4, gen_random_uuid()::text, $5) RETURNING id`,
		orgID, email, role, inviterID, time.Now().Add(time.Hour),
	).Scan(&id); err != nil {
		t.Fatalf("seed invite: %v", err)
	}
	token := id + ":" + "abcdef"
	if _, err := pool.Exec(context.Background(),
		`UPDATE org_invites SET token_hash = $2 WHERE id = $1`, id, hashInviteToken(token),
	); err != nil {
		t.Fatalf("set invite hash: %v", err)
	}
	return token
}

func TestMembershipRBAC_CreateJoinUpdateRemove(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	owner := rbacSeedUser(t, pool, "rbac-owner")
	org, err := NewOrgService(pool, nil, nil).Create(ctx, owner, CreateOrgRequest{Name: "RBAC Org", Slug: "rbac-org"})
	if err != nil {
		t.Fatalf("create org: %v", err)
	}
	assertRBACRoles(t, pool, org.ID, owner, "tenant_admin")

	// Invite acceptance by a new member grants the invite's mapped role.
	invites := NewInviteService(pool, nil)
	learner := rbacSeedUser(t, pool, "rbac-learner")
	if _, err := invites.Join(ctx, JoinOrgRequest{Token: createJoinToken(t, pool, org.ID, owner, "rbac-learner@"+testdomain.Domain, RoleLearner)}, learner); err != nil {
		t.Fatalf("join learner: %v", err)
	}
	assertRBACRoles(t, pool, org.ID, learner, "member")

	// A suspended admin re-activated through a learner invite takes the
	// invite's label, so tenant_admin is swapped for member.
	suspended := rbacSeedUser(t, pool, "rbac-suspended")
	if _, err := pool.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, 'admin', 'suspended')`, org.ID, suspended,
	); err != nil {
		t.Fatalf("seed suspended admin: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id) SELECT $1, id, $2 FROM roles WHERE name = 'tenant_admin' AND is_system`,
		suspended, org.ID,
	); err != nil {
		t.Fatalf("seed tenant_admin: %v", err)
	}
	if _, err := invites.Join(ctx, JoinOrgRequest{Token: createJoinToken(t, pool, org.ID, owner, "rbac-suspended@"+testdomain.Domain, RoleLearner)}, suspended); err != nil {
		t.Fatalf("join suspended: %v", err)
	}
	assertRBACRoles(t, pool, org.ID, suspended, "member")

	// Label change swaps the mapped role and keeps roles added via RBAC.
	if _, err := pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id) SELECT $1, id, $2 FROM roles WHERE name = 'viewer' AND is_system`,
		learner, org.ID,
	); err != nil {
		t.Fatalf("grant viewer: %v", err)
	}
	members := NewMemberService(pool, nil)
	learnerRow := memberRowID(t, pool, org.ID, learner)
	instructor := RoleInstructor
	if _, err := members.Update(ctx, org.ID, owner, RoleOwner, learnerRow, UpdateMemberRequest{Role: &instructor}); err != nil {
		t.Fatalf("update to instructor: %v", err)
	}
	assertRBACRoles(t, pool, org.ID, learner, "instructor", "viewer")

	// owner -> admin keeps tenant_admin (needs a second owner for the last-owner guard).
	second := rbacSeedUser(t, pool, "rbac-owner2")
	if _, err := pool.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, 'owner', 'active')`, org.ID, second,
	); err != nil {
		t.Fatalf("seed second owner: %v", err)
	}
	admin := RoleAdmin
	if _, err := members.Update(ctx, org.ID, second, RoleOwner, memberRowID(t, pool, org.ID, owner), UpdateMemberRequest{Role: &admin}); err != nil {
		t.Fatalf("update owner to admin: %v", err)
	}
	assertRBACRoles(t, pool, org.ID, owner, "tenant_admin")

	// Removal clears every role in the org.
	if err := members.Remove(ctx, org.ID, second, RoleOwner, learnerRow); err != nil {
		t.Fatalf("remove: %v", err)
	}
	assertRBACRoles(t, pool, org.ID, learner)
}
