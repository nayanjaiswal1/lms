package wiki

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// Tenant B must not read, modify, move or delete tenant A's space or page by id.
func TestWiki_TenantIsolation(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	var orgA, orgB, userID string
	for slug, dst := range map[string]*string{"wiki-a": &orgA, "wiki-b": &orgB} {
		if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug).Scan(dst); err != nil {
			t.Fatalf("seed org %s: %v", slug, err)
		}
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('wiki@`+testdomain.Domain+`', 'Wiki') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}

	space, err := repo.CreateSpace(ctx, orgA, "Secret", "secret", nil, nil, nil, "members", userID)
	if err != nil {
		t.Fatalf("create space: %v", err)
	}
	page, err := repo.CreatePage(ctx, space.ID, "Original", "original", nil, nil, json.RawMessage(`{}`), "original", userID)
	if err != nil {
		t.Fatalf("create page: %v", err)
	}

	if _, err := repo.GetSpaceByID(ctx, orgB, space.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("GetSpaceByID org B: err=%v, want ErrNotFound", err)
	}
	if _, err := repo.GetSpaceBySlug(ctx, orgB, "secret"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("GetSpaceBySlug org B: err=%v, want ErrNotFound", err)
	}
	if spaces, err := repo.ListSpaces(ctx, orgB); err != nil || len(spaces) != 0 {
		t.Fatalf("ListSpaces org B = %d err=%v, want 0", len(spaces), err)
	}
	hijack := "Hijacked"
	if _, err := repo.UpdateSpace(ctx, orgB, space.ID, UpdateSpaceRequest{Name: &hijack}); !errors.Is(err, ErrNotFound) {
		t.Fatalf("UpdateSpace org B: err=%v, want ErrNotFound", err)
	}
	if err := repo.DeleteSpace(ctx, orgB, space.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("DeleteSpace org B: err=%v, want ErrNotFound", err)
	}
	if _, err := repo.GetPage(ctx, orgB, page.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("GetPage org B: err=%v, want ErrNotFound", err)
	}
	if _, err := repo.UpdatePage(ctx, orgB, page.ID, &hijack, nil, nil, nil, nil, nil, nil, nil, userID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("UpdatePage org B: err=%v, want ErrNotFound", err)
	}
	if _, err := repo.MovePage(ctx, orgB, page.ID, nil, 9); !errors.Is(err, ErrNotFound) {
		t.Fatalf("MovePage org B: err=%v, want ErrNotFound", err)
	}
	if err := repo.DeletePage(ctx, orgB, page.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("DeletePage org B: err=%v, want ErrNotFound", err)
	}

	// Org A's rows are untouched by every attempt above.
	gotSpace, err := repo.GetSpaceByID(ctx, orgA, space.ID)
	if err != nil || gotSpace.Name != "Secret" {
		t.Fatalf("org A space = %+v err=%v, want name Secret", gotSpace, err)
	}
	gotPage, err := repo.GetPage(ctx, orgA, page.ID)
	if err != nil || gotPage.Title != "Original" || gotPage.Version != page.Version || gotPage.OrderIndex != page.OrderIndex {
		t.Fatalf("org A page = %+v err=%v, want unchanged", gotPage, err)
	}
}
