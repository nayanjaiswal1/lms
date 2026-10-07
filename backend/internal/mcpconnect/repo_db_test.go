package mcpconnect

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// TestRegisterAndGetClient exercises RegisterClient/GetClient (repo.go)
// against a real database — the Dynamic-Client-Registration round trip
// through mcp_clients, including the not-found path, isn't reachable from
// action_log_test.go's pure-Go isRevertible check.
func TestRegisterAndGetClient(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	redirectURIs := []string{"https://client.example.com/callback"}
	created, err := repo.RegisterClient(ctx, "client-abc123", "Example MCP Client", redirectURIs)
	if err != nil {
		t.Fatalf("RegisterClient: %v", err)
	}
	if created.ClientID != "client-abc123" || created.ClientName != "Example MCP Client" {
		t.Fatalf("unexpected client returned: %+v", created)
	}
	if created.CreatedAt.IsZero() {
		t.Error("expected CreatedAt to be populated by RETURNING")
	}

	got, err := repo.GetClient(ctx, "client-abc123")
	if err != nil {
		t.Fatalf("GetClient: %v", err)
	}
	if got.ClientName != "Example MCP Client" {
		t.Errorf("expected client_name %q, got %q", "Example MCP Client", got.ClientName)
	}
	if len(got.RedirectURIs) != 1 || got.RedirectURIs[0] != redirectURIs[0] {
		t.Errorf("expected redirect_uris %v, got %v", redirectURIs, got.RedirectURIs)
	}

	if _, err := repo.GetClient(ctx, "does-not-exist"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected ErrNotFound for unregistered client, got %v", err)
	}
}

// TestRefreshRotationCASAndReuse covers M-25: a rotation is compare-and-set on
// the presented hash, and replaying a rotated-out hash revokes the connection.
func TestRefreshRotationCASAndReuse(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	var orgID, userID string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('MCP Org', 'mcp-org') RETURNING id`).Scan(&orgID); err != nil {
		t.Fatalf("insert org: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('mcp@example.com', 'MCP User') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, 'student', 'active')`, orgID, userID); err != nil {
		t.Fatalf("insert member: %v", err)
	}
	if _, err := repo.RegisterClient(ctx, "cid", "Client", []string{"https://client.example.com/cb"}); err != nil {
		t.Fatalf("RegisterClient: %v", err)
	}
	exp := time.Now().Add(time.Hour)
	connID, err := repo.UpsertConnection(ctx, orgID, userID, "cid", []string{ScopeCoursesRead}, "h1", exp)
	if err != nil {
		t.Fatalf("UpsertConnection: %v", err)
	}

	if err := repo.RotateRefreshToken(ctx, connID, "h1", "h2", exp); err != nil {
		t.Fatalf("first rotation: %v", err)
	}
	// A second rotation presenting the stale hash loses the compare-and-set.
	if err := repo.RotateRefreshToken(ctx, connID, "h1", "h3", exp); !errors.Is(err, ErrInvalidGrant) {
		t.Fatalf("stale rotation: want ErrInvalidGrant, got %v", err)
	}
	// Replaying the rotated-out hash revokes the connection.
	revoked, err := repo.RevokeOnRefreshReuse(ctx, "h1")
	if err != nil || !revoked {
		t.Fatalf("RevokeOnRefreshReuse: revoked=%v err=%v", revoked, err)
	}
	if _, err := repo.GetConnectionByRefreshHash(ctx, "h2"); !errors.Is(err, ErrInvalidGrant) {
		t.Fatalf("revoked connection must not resolve, got %v", err)
	}
}
