package orgs

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/testdb"
)

func TestResendResetsEmailStatusAndQueuesEmail(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	var org, owner string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('O','o-invtest') RETURNING id`).Scan(&org); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('own@mindforge.test','O') RETURNING id`).Scan(&owner); err != nil {
		t.Fatal(err)
	}
	svc := NewInviteService(pool, &config.Config{})
	inv, _, err := svc.Create(ctx, org, owner, RoleOwner, CreateInviteRequest{Email: "a@x.com", Role: "learner"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `UPDATE org_invites SET email_status='failed', email_error='boom' WHERE id=$1`, inv.ID); err != nil {
		t.Fatal(err)
	}
	page, err := svc.List(ctx, org, "all", "", 10)
	if err != nil || len(page.Invites) != 1 || page.Invites[0].EmailStatus != "failed" || page.Invites[0].EmailError == nil {
		t.Fatalf("list should expose failed status: %+v %v", page, err)
	}

	if _, _, err := svc.Resend(ctx, org, owner, RoleOwner, inv.ID); err != nil {
		t.Fatal(err)
	}
	var st string
	var jobs int
	pool.QueryRow(ctx, `SELECT email_status FROM org_invites WHERE id=$1`, inv.ID).Scan(&st)
	pool.QueryRow(ctx, `SELECT count(*) FROM jobs WHERE handler='email.send' AND payload->>'type'='org_invite' AND org_id=$1`, org).Scan(&jobs)
	if st != "pending" || jobs != 1 {
		t.Fatalf("after resend status=%s jobs=%d, want pending/1", st, jobs)
	}
}
