package courses

import (
	"context"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

func TestModuleTranslations(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	seedModule := func(slug, status string, isPublic bool) (orgID, moduleID string) {
		courseID := seedPublicCourseFixture(t, ctx, pool, slug, status, isPublic)
		if err := pool.QueryRow(ctx, `SELECT org_id FROM courses WHERE id = $1`, courseID).Scan(&orgID); err != nil {
			t.Fatalf("load org: %v", err)
		}
		var sectionID string
		if err := pool.QueryRow(ctx,
			`INSERT INTO course_sections (course_id, title, position) VALUES ($1, 'S', 0) RETURNING id`, courseID,
		).Scan(&sectionID); err != nil {
			t.Fatalf("seed section: %v", err)
		}
		if err := pool.QueryRow(ctx,
			`INSERT INTO course_modules (course_id, section_id, title, type, position, content_body)
			 VALUES ($1, $2, 'L', 'notes', 0, 'hello') RETURNING id`, courseID, sectionID,
		).Scan(&moduleID); err != nil {
			t.Fatalf("seed module: %v", err)
		}
		return orgID, moduleID
	}

	t.Run("upsert replaces and lists by locale", func(t *testing.T) {
		orgID, moduleID := seedModule("tr-upsert", "published", true)
		if _, err := repo.UpsertModuleTranslation(ctx, orgID, moduleID, "hi", "नमस्ते"); err != nil {
			t.Fatalf("upsert hi: %v", err)
		}
		if _, err := repo.UpsertModuleTranslation(ctx, orgID, moduleID, "hi", "नमस्कार"); err != nil {
			t.Fatalf("re-upsert hi: %v", err)
		}
		if _, err := repo.UpsertModuleTranslation(ctx, orgID, moduleID, "es", "hola"); err != nil {
			t.Fatalf("upsert es: %v", err)
		}
		got, err := repo.ListModuleTranslations(ctx, orgID, moduleID)
		if err != nil {
			t.Fatalf("list: %v", err)
		}
		if len(got) != 2 || got[0].Locale != "es" || got[1].Locale != "hi" || got[1].ContentBody != "नमस्कार" {
			t.Fatalf("unexpected translations: %+v", got)
		}
	})

	t.Run("other org cannot read or write", func(t *testing.T) {
		_, moduleID := seedModule("tr-org-a", "published", true)
		otherOrg, _ := seedModule("tr-org-b", "published", true)
		if _, err := repo.UpsertModuleTranslation(ctx, otherOrg, moduleID, "hi", "x"); !errors.Is(err, ErrNotFound) {
			t.Fatalf("cross-org upsert: want ErrNotFound, got %v", err)
		}
		if _, err := repo.ListModuleTranslations(ctx, otherOrg, moduleID); !errors.Is(err, ErrNotFound) {
			t.Fatalf("cross-org list: want ErrNotFound, got %v", err)
		}
		if err := repo.DeleteModuleTranslation(ctx, otherOrg, moduleID, "hi"); !errors.Is(err, ErrNotFound) {
			t.Fatalf("cross-org delete: want ErrNotFound, got %v", err)
		}
	})

	t.Run("public read is gated by is_public and published", func(t *testing.T) {
		orgID, moduleID := seedModule("tr-visible", "published", true)
		if _, err := repo.UpsertModuleTranslation(ctx, orgID, moduleID, "hi", "x"); err != nil {
			t.Fatalf("upsert: %v", err)
		}
		got, err := repo.ListPublicModuleTranslations(ctx, "tr-visible", moduleID)
		if err != nil || len(got) != 1 {
			t.Fatalf("public list: %+v, %v", got, err)
		}

		_, privateModule := seedModule("tr-private", "published", false)
		if _, err := repo.ListPublicModuleTranslations(ctx, "tr-private", privateModule); !errors.Is(err, ErrNotFound) {
			t.Fatalf("private course: want ErrNotFound, got %v", err)
		}
		_, draftModule := seedModule("tr-draft", "draft", true)
		if _, err := repo.ListPublicModuleTranslations(ctx, "tr-draft", draftModule); !errors.Is(err, ErrNotFound) {
			t.Fatalf("draft course: want ErrNotFound, got %v", err)
		}
		// A module id from a different course must not be readable through this slug.
		if _, err := repo.ListPublicModuleTranslations(ctx, "tr-visible", privateModule); !errors.Is(err, ErrNotFound) {
			t.Fatalf("foreign module: want ErrNotFound, got %v", err)
		}
	})

	t.Run("delete removes one locale", func(t *testing.T) {
		orgID, moduleID := seedModule("tr-delete", "published", true)
		if _, err := repo.UpsertModuleTranslation(ctx, orgID, moduleID, "hi", "x"); err != nil {
			t.Fatalf("upsert: %v", err)
		}
		if err := repo.DeleteModuleTranslation(ctx, orgID, moduleID, "hi"); err != nil {
			t.Fatalf("delete: %v", err)
		}
		if err := repo.DeleteModuleTranslation(ctx, orgID, moduleID, "hi"); !errors.Is(err, ErrNotFound) {
			t.Fatalf("second delete: want ErrNotFound, got %v", err)
		}
	})
}
