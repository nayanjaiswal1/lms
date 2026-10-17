package assessment

import (
	"context"
	"slices"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestAcceptInvitation_AssignsMemberRole(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	var orgID, inviter, learner, batchID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('batch-rbac', 'Batch RBAC') RETURNING id`,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	for local, id := range map[string]*string{"batch-inviter": &inviter, "batch-learner": &learner} {
		if err := pool.QueryRow(ctx,
			`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`, local+"@"+testdomain.Domain, local,
		).Scan(id); err != nil {
			t.Fatalf("seed user: %v", err)
		}
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO batches (org_id, name, slug, created_by) VALUES ($1, 'B', 'b', $2) RETURNING id`, orgID, inviter,
	).Scan(&batchID); err != nil {
		t.Fatalf("seed batch: %v", err)
	}
	const raw = "batch-rbac-token"
	email := "batch-learner@" + testdomain.Domain
	if _, err := pool.Exec(ctx,
		`INSERT INTO batch_invitations (batch_id, org_id, email, invited_by, token_hash, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		batchID, orgID, email, inviter, hashToken(raw), time.Now().Add(time.Hour),
	); err != nil {
		t.Fatalf("seed invitation: %v", err)
	}

	if _, _, err := NewRepo(pool).AcceptInvitation(ctx, raw, learner, email); err != nil {
		t.Fatalf("accept: %v", err)
	}

	rows, err := pool.Query(ctx,
		`SELECT r.name FROM user_roles ur JOIN roles r ON r.id = ur.role_id
		 WHERE ur.user_id = $1 AND ur.org_id = $2 ORDER BY r.name`, learner, orgID)
	if err != nil {
		t.Fatalf("list roles: %v", err)
	}
	defer rows.Close()
	got := []string{}
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			t.Fatalf("scan: %v", err)
		}
		got = append(got, n)
	}
	if !slices.Equal(got, []string{"member"}) {
		t.Fatalf("roles = %v, want [member]", got)
	}
}
