package assessment

import (
	"context"
	"testing"
	"time"
)

// TestTestTemplate_CreateAndList exercises the reusable offline-test
// template repo methods end to end: creating a template, listing it back for
// the org, and confirming it stays org-scoped.
func TestTestTemplate_CreateAndList(t *testing.T) {
	repo, orgID := seedCohortOrg(t)
	ctx := context.Background()
	creator := seedUser(t, repo.pool, orgID)

	tmpl, err := repo.CreateTestTemplate(ctx, orgID, "Unit Test 1", 50, creator)
	if err != nil {
		t.Fatalf("create test template: %v", err)
	}
	if tmpl.Name != "Unit Test 1" || tmpl.MaxScore != 50 || tmpl.OrgID != orgID {
		t.Fatalf("unexpected template: %+v", tmpl)
	}

	templates, err := repo.ListTestTemplates(ctx, orgID)
	if err != nil {
		t.Fatalf("list test templates: %v", err)
	}
	found := false
	for _, tt := range templates {
		if tt.ID == tmpl.ID {
			found = true
		}
	}
	if !found {
		t.Fatalf("created template %s not found in list %+v", tmpl.ID, templates)
	}

	// A second, unrelated org must never see the first org's templates.
	otherRepo, otherOrgID := seedCohortOrg(t)
	otherTemplates, err := otherRepo.ListTestTemplates(ctx, otherOrgID)
	if err != nil {
		t.Fatalf("list test templates (other org): %v", err)
	}
	for _, tt := range otherTemplates {
		if tt.ID == tmpl.ID {
			t.Fatalf("template %s leaked into unrelated org %s", tmpl.ID, otherOrgID)
		}
	}
}

// TestTestTemplate_InvalidMaxScoreRejected proves the max_score > 0 CHECK
// constraint (007_offline_test_templates.sql) surfaces as ErrInvalidScore.
func TestTestTemplate_InvalidMaxScoreRejected(t *testing.T) {
	repo, orgID := seedCohortOrg(t)
	ctx := context.Background()
	creator := seedUser(t, repo.pool, orgID)

	if _, err := repo.CreateTestTemplate(ctx, orgID, "Bad Template", 0, creator); err != ErrInvalidScore {
		t.Fatalf("expected ErrInvalidScore for max_score=0, got %v", err)
	}
}

// TestCreateOfflineTestScores_WithTemplateID proves a valid templateID is
// recorded on the newly created offline assessment, and that a templateID
// from another org is rejected rather than silently ignored or cross-tenant
// leaked.
func TestCreateOfflineTestScores_WithTemplateID(t *testing.T) {
	repo, orgID := seedCohortOrg(t)
	ctx := context.Background()
	creator := seedUser(t, repo.pool, orgID)
	student := seedUser(t, repo.pool, orgID)
	batch := seedBatch(t, repo, orgID, creator)

	tmpl, err := repo.CreateTestTemplate(ctx, orgID, "Midterm", 100, creator)
	if err != nil {
		t.Fatalf("create test template: %v", err)
	}

	testDate, err := time.Parse("2006-01-02", "2026-03-01")
	if err != nil {
		t.Fatalf("parse test date: %v", err)
	}
	testID, err := repo.CreateOfflineTestScores(ctx, orgID, batch.ID, "Midterm", testDate, 100, creator,
		[]OfflineTestScoreEntry{{UserID: student, Score: 88}}, &tmpl.ID)
	if err != nil {
		t.Fatalf("create offline test scores: %v", err)
	}

	var gotTemplateID *string
	if err := repo.pool.QueryRow(ctx, `SELECT test_template_id FROM assessments WHERE id = $1`, testID).Scan(&gotTemplateID); err != nil {
		t.Fatalf("read back test_template_id: %v", err)
	}
	if gotTemplateID == nil || *gotTemplateID != tmpl.ID {
		t.Fatalf("expected test_template_id %s, got %v", tmpl.ID, gotTemplateID)
	}

	// A template from a different org must be rejected, not silently linked.
	otherRepo, otherOrgID := seedCohortOrg(t)
	otherCreator := seedUser(t, otherRepo.pool, otherOrgID)
	otherTmpl, err := otherRepo.CreateTestTemplate(ctx, otherOrgID, "Other Org Template", 100, otherCreator)
	if err != nil {
		t.Fatalf("create test template (other org): %v", err)
	}
	if _, err := repo.CreateOfflineTestScores(ctx, orgID, batch.ID, "Cross-Org Test", testDate, 100, creator,
		[]OfflineTestScoreEntry{{UserID: student, Score: 50}}, &otherTmpl.ID); err != ErrNotFound {
		t.Fatalf("expected ErrNotFound for cross-org template, got %v", err)
	}
}
