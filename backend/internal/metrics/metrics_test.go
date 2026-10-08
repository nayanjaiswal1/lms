package metrics

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

func TestMiddlewarePreservesFlusher(t *testing.T) {
	var flushable bool
	h := Middleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, flushable = w.(http.Flusher)
	}))
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/", nil))
	if !flushable {
		t.Fatal("metrics middleware hides http.Flusher from handlers (SSE endpoints return 500)")
	}
}

func TestRegisterPoolTwiceDoesNotPanicAndReplacesPool(t *testing.T) {
	first, second := &pgxpool.Pool{}, &pgxpool.Pool{}
	t.Cleanup(func() { RegisterPool(nil) }) // zero-value pools must never be scraped
	RegisterPool(first)
	RegisterPool(second) // a second registration would panic on the duplicate collector
	if got := currentPool.Load(); got != second {
		t.Fatalf("currentPool = %p, want the most recently registered pool %p", got, second)
	}
}
