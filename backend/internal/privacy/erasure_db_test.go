package privacy

import (
	"context"
	"github.com/mindforge/backend/internal/testdomain"
	"io"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

type fakeStore struct{ deleted []string }

func (f *fakeStore) Upload(context.Context, string, string, io.Reader, int64) (string, error) {
	return "", nil
}
func (f *fakeStore) Download(context.Context, string) ([]byte, error) { return nil, nil }
func (f *fakeStore) Delete(_ context.Context, key string) error {
	f.deleted = append(f.deleted, key)
	return nil
}
func (f *fakeStore) PresignedPost(context.Context, string, string, int64) (string, map[string]string, error) {
	return "", nil, nil
}
func (f *fakeStore) PresignedGetURL(context.Context, string, time.Duration) (string, error) {
	return "", nil
}

// Erasure must remove personal content (diary, captures + blobs, MCP action
// log), keep the retained records, and the export must list the same content.
func TestErasure_RemovesPersonalContentKeepsRetained(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	store := &fakeStore{}
	repo := NewRepo(pool, store)

	var userID, orgID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('erase@`+testdomain.Domain+`', 'Erase Me') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('erase-org', 'Erase Org') RETURNING id`).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	for _, q := range []string{
		`INSERT INTO diary_entries (user_id, content) VALUES ($1, 'private diary')`,
		`INSERT INTO captures (user_id, type, storage_key, status) VALUES ($1, 'image', 'captures/u/abc.png', 'ready')`,
		`INSERT INTO legal_acceptances (user_id, doc_type, version) VALUES ($1, 'terms', 'v1')`,
	} {
		if _, err := pool.Exec(ctx, q, userID); err != nil {
			t.Fatalf("seed %q: %v", q, err)
		}
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO audit_logs (org_id, actor_user_id, action, source) VALUES ($1, $2, 'mcp.tool', 'mcp')`, orgID, userID); err != nil {
		t.Fatalf("seed audit: %v", err)
	}

	exported, err := repo.ExportData(ctx, userID)
	if err != nil {
		t.Fatalf("export: %v", err)
	}
	for _, section := range []string{"diary_entries", "captures"} {
		if rows, _ := exported[section].([]map[string]any); len(rows) != 1 {
			t.Fatalf("export is missing section %q: %v", section, exported[section])
		}
	}

	if err := repo.AnonymizeAndDeletePII(ctx, userID); err != nil {
		t.Fatalf("erase: %v", err)
	}

	count := func(q string) int {
		var n int
		if err := pool.QueryRow(ctx, q, userID).Scan(&n); err != nil {
			t.Fatalf("count %q: %v", q, err)
		}
		return n
	}
	if n := count(`SELECT count(*) FROM diary_entries WHERE user_id = $1`); n != 0 {
		t.Errorf("diary rows survived erasure: %d", n)
	}
	if n := count(`SELECT count(*) FROM captures WHERE user_id = $1`); n != 0 {
		t.Errorf("capture rows survived erasure: %d", n)
	}
	if n := count(`SELECT count(*) FROM audit_logs WHERE source = 'mcp' AND actor_user_id = $1`); n != 0 {
		t.Errorf("mcp action log survived erasure: %d", n)
	}
	if n := count(`SELECT count(*) FROM legal_acceptances WHERE user_id = $1`); n != 1 {
		t.Errorf("retained consent record was deleted: %d", n)
	}
	if len(store.deleted) != 1 || store.deleted[0] != "captures/u/abc.png" {
		t.Errorf("capture blob not deleted: %v", store.deleted)
	}
}
