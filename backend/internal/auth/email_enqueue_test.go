package auth

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

func TestAccountNoticeEmailsEnqueueIdempotently(t *testing.T) {
	pool := testdb.New(t)
	h := &Handler{pool: pool}
	ctx := context.Background()
	for _, typ := range []string{emailTypeDuplicateRegistration, emailTypePasskeyCloneAlert} {
		for i := 0; i < 2; i++ {
			if err := h.enqueueAuthEmail(ctx, typ, "u@x.com", "", "key:"+typ); err != nil {
				t.Fatal(err)
			}
		}
		var n int
		if err := pool.QueryRow(ctx,
			`SELECT count(*) FROM jobs WHERE handler = 'email.send' AND payload->>'type' = $1 AND idempotency_key = $2`,
			typ, "key:"+typ).Scan(&n); err != nil || n != 1 {
			t.Fatalf("%s: jobs=%d err=%v, want exactly 1", typ, n, err)
		}
	}
}
