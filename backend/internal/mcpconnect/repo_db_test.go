package mcpconnect

import (
	"context"
	"errors"
	"testing"

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
