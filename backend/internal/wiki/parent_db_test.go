package wiki

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// TestCheckNewParent: a page may only be nested under another page of its own
// space that is neither itself nor one of its descendants.
func TestCheckNewParent(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	svc := NewService(repo, nil)
	ctx := context.Background()

	var orgID, userID string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('wiki-parent', 'P') RETURNING id`).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('parent@`+testdomain.Domain+`', 'P') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	space := func(slug string) Space {
		s, err := repo.CreateSpace(ctx, orgID, slug, slug, nil, nil, nil, "members", userID)
		if err != nil {
			t.Fatalf("create space: %v", err)
		}
		return s
	}
	page := func(spaceID, slug string, parent *string) Page {
		p, err := repo.CreatePage(ctx, spaceID, slug, slug, parent, nil, json.RawMessage(`{}`), slug, userID)
		if err != nil {
			t.Fatalf("create page: %v", err)
		}
		return p
	}

	main, other := space("main"), space("other")
	root := page(main.ID, "root", nil)
	child := page(main.ID, "child", &root.ID)
	grandchild := page(main.ID, "grandchild", &child.ID)
	sibling := page(main.ID, "sibling", nil)
	foreign := page(other.ID, "foreign", nil)

	for name, parentID := range map[string]string{
		"self":          root.ID,
		"child":         child.ID,
		"grandchild":    grandchild.ID,
		"another space": foreign.ID,
	} {
		if err := svc.checkNewParent(ctx, orgID, root, parentID); !errors.Is(err, ErrValidation) {
			t.Errorf("%s: err=%v, want ErrValidation", name, err)
		}
	}
	if err := svc.checkNewParent(ctx, orgID, root, sibling.ID); err != nil {
		t.Errorf("sibling: err=%v, want nil", err)
	}
}
