package metrics

import (
	"net/http"
	"net/http/httptest"
	"testing"
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

func TestRegisterPoolTwiceDoesNotPanic(t *testing.T) {
	RegisterPool(nil)
	RegisterPool(nil)
}
