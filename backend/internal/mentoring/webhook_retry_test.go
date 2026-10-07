package mentoring

import (
	"context"
	"errors"
	"net/http"
	"testing"
)

// flakyPacks fails the first failFor calls, then confirms.
type flakyPacks struct{ failFor, calls int }

func (f *flakyPacks) ConfirmPackPurchase(context.Context, string, string, string, int, string, bool) (bool, error) {
	f.calls++
	if f.calls <= f.failFor {
		return true, errors.New("injected db failure")
	}
	return true, nil
}

func (f *flakyPacks) ReversePackPurchase(context.Context, string, string, int) (bool, error) {
	return false, nil
}

// A failed confirm must answer non-2xx and leave the event unprocessed, and
// the gateway's redelivery of the same event must re-run it (not be deduped).
func TestHandleWebhook_FailedConfirmIsRetriedOnRedelivery(t *testing.T) {
	pool := testPool(t)
	svc := webhookTestService(pool)
	packs := &flakyPacks{failFor: 1}
	svc.packs = packs
	ctx := context.Background()

	body := stubWebhookBodyJSON(t, "evt_retry_"+t.Name(), "pack_ref_retry_"+t.Name(), "succeeded", 500)
	t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM payment_events WHERE event_id = $1`, "evt_retry_"+t.Name()) }) //nolint:errcheck

	if err := svc.HandleWebhook(ctx, "stub", body, http.Header{}); err == nil {
		t.Fatal("first delivery: expected error so the gateway retries")
	}
	var processed bool
	var errMsg *string
	if err := pool.QueryRow(ctx, `SELECT processed_at IS NOT NULL, error FROM payment_events WHERE event_id = $1`, "evt_retry_"+t.Name()).Scan(&processed, &errMsg); err != nil {
		t.Fatalf("read event: %v", err)
	}
	if processed || errMsg == nil {
		t.Fatalf("after failure want unprocessed with error, got processed=%v error=%v", processed, errMsg)
	}

	if err := svc.HandleWebhook(ctx, "stub", body, http.Header{}); err != nil {
		t.Fatalf("redelivery: %v", err)
	}
	if err := pool.QueryRow(ctx, `SELECT processed_at IS NOT NULL FROM payment_events WHERE event_id = $1`, "evt_retry_"+t.Name()).Scan(&processed); err != nil || !processed {
		t.Fatalf("after redelivery want processed, got %v (err %v)", processed, err)
	}
	if packs.calls != 2 {
		t.Fatalf("confirmer calls = %d, want 2", packs.calls)
	}
}
