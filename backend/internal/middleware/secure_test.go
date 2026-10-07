package middleware

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSecureHeaders(t *testing.T) {
	h := SecureHeaders(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	assert.Equal(t, "nosniff", rec.Header().Get("X-Content-Type-Options"))
	assert.Empty(t, rec.Header().Get("Strict-Transport-Security"))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("X-Forwarded-Proto", "https")
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	assert.Equal(t, hstsValue, rec.Header().Get("Strict-Transport-Security"))
}

func TestMaxBody(t *testing.T) {
	read := func(ct, body string) error {
		var err error
		h := MaxBody(4)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
			_, err = io.ReadAll(r.Body)
		}))
		req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(body))
		req.Header.Set("Content-Type", ct)
		h.ServeHTTP(httptest.NewRecorder(), req)
		return err
	}
	require.NoError(t, read("application/json", "1234"))
	require.Error(t, read("application/json", "12345"))
	require.NoError(t, read("multipart/form-data; boundary=x", "way more than four bytes"))
}
