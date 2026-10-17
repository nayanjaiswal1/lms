package authz

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

// List surfaces the org name and the recorded client IP (written by the orgs
// domain's audit writer) for the unified audit page, and leaves ip_address
// null for rows written without one.
func TestAuditRepoList_OrgNameAndIP(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	orgID, actorID := seedOrgAndUser(t, pool, "audit-org")
	if _, err := pool.Exec(ctx,
		`INSERT INTO audit_logs (org_id, actor_user_id, action, target_type, ip_address, created_at)
		 VALUES ($1, $2, 'member.invite', 'user', '203.0.113.7', now() - interval '1 minute')`,
		orgID, actorID); err != nil {
		t.Fatalf("seed audit row: %v", err)
	}
	repo := NewAuditRepo(pool)
	if err := repo.Write(ctx, orgID, actorID, "role.create", "role", "not-a-uuid", nil); err != nil {
		t.Fatalf("Write: %v", err)
	}

	entries, total, err := repo.List(ctx, ListAuditParams{OrgID: orgID})
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if total != 2 || len(entries) != 2 {
		t.Fatalf("got total=%d len=%d, want 2", total, len(entries))
	}
	byAction := map[string]AuditEntry{}
	for _, e := range entries {
		if e.OrgName == nil || *e.OrgName != "audit-org" {
			t.Errorf("%s: org_name = %v, want audit-org", e.Action, e.OrgName)
		}
		byAction[e.Action] = e
	}
	if ip := byAction["member.invite"].IPAddress; ip == nil || *ip != "203.0.113.7" {
		t.Errorf("member.invite ip_address = %v, want 203.0.113.7", ip)
	}
	if ip := byAction["role.create"].IPAddress; ip != nil {
		t.Errorf("role.create ip_address = %q, want nil", *ip)
	}
}
