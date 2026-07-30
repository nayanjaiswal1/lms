package gitlab

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/secrets"
)

// noopJobHandler satisfies jobs.Handler without doing anything — registered
// under jobIngestEvent so jobs.Enqueue's registry.Get lookup succeeds; these
// tests exercise HandleWebhook's token-verification and dedupe-insert logic,
// not the ingest_event job body itself (that's covered by IngestEvent's own
// dispatch, exercised indirectly via team_test.go's provisioning coverage).
type noopJobHandler struct{}

func (noopJobHandler) Handle(context.Context, jobs.Job) error { return nil }

// testVault builds a *secrets.Vault directly from a fixed, test-only 32+
// byte key. config.Load isn't called here — this test has no need for the
// rest of config.Config, and constructing it directly avoids requiring
// every other env var config.Load's startup validation demands.
func testVault(t *testing.T) *secrets.Vault {
	t.Helper()
	v, err := secrets.New(&config.Config{EncryptionKey: "gitlab-webhook-test-key-32-bytes-min"})
	if err != nil {
		t.Fatalf("build vault: %v", err)
	}
	return v
}

// seededWebhookTeam is a fully-forked project_teams row (fake GitLab project
// ID — no real GitLab instance involved) plus its org's installation, set up
// for HandleWebhook to resolve against.
type seededWebhookTeam struct {
	orgID           string
	teamID          string
	gitlabProjectID int64
}

// seedWebhookTestTeam seeds an org + a PAT installation whose webhook secret
// is then overwritten to a known plaintext (so the test can present a
// "correct" token) + a batch/assignment/team chain with a fake forked
// gitlab_project_id. Reuses seedTeamTestOrg/seedTeamTestUser/
// seedTeamTestBatch from team_test.go (same package) rather than
// duplicating them.
func seedWebhookTestTeam(t *testing.T, pool *pgxpool.Pool, repo *Repo, vault *secrets.Vault, webhookSecret string) seededWebhookTeam {
	t.Helper()
	ctx := context.Background()

	orgID := seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)

	inst, err := repo.CreateInstallationPAT(ctx, orgID, "Default", "https://gitlab.example.com", TierFree, 1, "test-bot", []byte("fake-enc-token"), nil, nil, instructorID)
	if err != nil {
		t.Fatalf("create installation: %v", err)
	}
	secretEnc, err := vault.Encrypt([]byte(webhookSecret))
	if err != nil {
		t.Fatalf("encrypt webhook secret: %v", err)
	}
	if err := repo.SetInstallationWebhookSecret(ctx, inst.ID, secretEnc); err != nil {
		t.Fatalf("set webhook secret: %v", err)
	}

	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Webhook Test Assignment", Slug: "webhook-test-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM project_assignments WHERE id = $1`, assignment.ID) //nolint:errcheck
	})

	team, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Webhook Test Team", Slug: "webhook-test-team", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}

	gitlabProjectID := time.Now().UnixNano() % 1_000_000_000
	if err := repo.SetTeamForkResult(ctx, team.ID, gitlabProjectID, "webhook-test-group/webhook-test-team", "https://gitlab.example.com/webhook-test-group/webhook-test-team"); err != nil {
		t.Fatalf("set team fork result: %v", err)
	}

	return seededWebhookTeam{orgID: orgID, teamID: team.ID, gitlabProjectID: gitlabProjectID}
}

// TestHandleWebhook_RejectsWrongToken proves the X-Gitlab-Token
// constant-time-compare in HandleWebhook rejects a token that doesn't match
// the installation's decrypted webhook secret — and, just as importantly,
// that the mismatched delivery never gets as far as inserting a
// gitlab_webhook_events row.
func TestHandleWebhook_RejectsWrongToken(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	vault := testVault(t)
	registry := jobs.NewRegistry()
	registry.Register(jobIngestEvent, noopJobHandler{})
	notifSvc := notifications.NewService(pool, registry)
	svc := NewService(pool, &config.Config{BackendURL: "http://localhost:8080"}, vault, registry, notifSvc)
	ctx := context.Background()

	seeded := seedWebhookTestTeam(t, pool, repo, vault, "correct-webhook-secret")

	eventUUID := fmt.Sprintf("wrong-token-test-%d", time.Now().UnixNano())
	err := svc.HandleWebhook(ctx, seeded.gitlabProjectID, "Push Hook", eventUUID, "definitely-not-the-secret", []byte(`{"object_kind":"push"}`))
	if !errors.Is(err, ErrInvalidWebhookToken) {
		t.Fatalf("expected ErrInvalidWebhookToken, got: %v", err)
	}

	var count int
	if scanErr := pool.QueryRow(ctx, `SELECT COUNT(*) FROM gitlab_webhook_events WHERE org_id = $1 AND event_uuid = $2`, seeded.orgID, eventUUID).Scan(&count); scanErr != nil {
		t.Fatalf("count webhook events: %v", scanErr)
	}
	if count != 0 {
		t.Fatalf("expected no webhook event row for a rejected token, got %d", count)
	}

	// The correct secret, for contrast, is accepted (proves the rejection
	// above is really about the token value, not some other seeding mistake).
	eventUUID2 := fmt.Sprintf("right-token-test-%d", time.Now().UnixNano())
	if err := svc.HandleWebhook(ctx, seeded.gitlabProjectID, "Push Hook", eventUUID2, "correct-webhook-secret", []byte(`{"object_kind":"push"}`)); err != nil {
		t.Fatalf("expected the correct token to be accepted, got error: %v", err)
	}
	if scanErr := pool.QueryRow(ctx, `SELECT COUNT(*) FROM gitlab_webhook_events WHERE org_id = $1 AND event_uuid = $2`, seeded.orgID, eventUUID2).Scan(&count); scanErr != nil {
		t.Fatalf("count webhook events: %v", scanErr)
	}
	if count != 1 {
		t.Fatalf("expected exactly one webhook event row for the accepted delivery, got %d", count)
	}
}

// TestInsertWebhookEvent_RedeliveryIsIdempotent proves
// ON CONFLICT(org_id,event_uuid) DO NOTHING makes a redelivered webhook
// event (the same event_uuid inserted twice) result in exactly one row,
// with the second call correctly reporting "not inserted."
func TestInsertWebhookEvent_RedeliveryIsIdempotent(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	orgID := seedTeamTestOrg(t, pool)
	eventUUID := fmt.Sprintf("redelivery-test-%d", time.Now().UnixNano())
	projectID := int64(424242)
	payload := []byte(`{"object_kind":"push"}`)

	inserted1, err := repo.InsertWebhookEvent(ctx, "11111111-1111-1111-1111-111111111111", orgID, projectID, "Push Hook", eventUUID, payload)
	if err != nil {
		t.Fatalf("first insert: %v", err)
	}
	if !inserted1 {
		t.Fatal("expected the first insert to report inserted=true")
	}

	inserted2, err := repo.InsertWebhookEvent(ctx, "22222222-2222-2222-2222-222222222222", orgID, projectID, "Push Hook", eventUUID, payload)
	if err != nil {
		t.Fatalf("second (redelivered) insert: %v", err)
	}
	if inserted2 {
		t.Fatal("expected the redelivered insert to report inserted=false")
	}

	var count int
	if scanErr := pool.QueryRow(ctx, `SELECT COUNT(*) FROM gitlab_webhook_events WHERE org_id = $1 AND event_uuid = $2`, orgID, eventUUID).Scan(&count); scanErr != nil {
		t.Fatalf("count webhook events: %v", scanErr)
	}
	if count != 1 {
		t.Fatalf("expected exactly one row after a redelivered event_uuid, got %d", count)
	}
}
