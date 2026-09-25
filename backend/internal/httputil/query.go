package httputil

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// URLParam reads a chi path parameter. Thin wrapper kept for call-site
// brevity so handlers don't each define their own urlParam helper.
func URLParam(r *http.Request, key string) string {
	return chi.URLParam(r, key)
}

// QueryStr returns the query parameter value, or "" when absent.
func QueryStr(r *http.Request, key string) string {
	return r.URL.Query().Get(key)
}

// QueryStrDef returns the query parameter value, or def when absent or empty.
func QueryStrDef(r *http.Request, key, def string) string {
	if v := r.URL.Query().Get(key); v != "" {
		return v
	}
	return def
}

// QueryStrPtr returns a pointer to the query parameter value, or nil when
// absent or empty (for optional filters).
func QueryStrPtr(r *http.Request, key string) *string {
	v := r.URL.Query().Get(key)
	if v == "" {
		return nil
	}
	return &v
}

// QueryInt returns the query parameter parsed as an int, or def when absent,
// empty, or unparseable. Any parsed integer (including negatives and zero)
// is returned as-is.
func QueryInt(r *http.Request, key string, def int) int {
	if v := r.URL.Query().Get(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

// QueryIntPositive returns the query parameter parsed as an int, or def when
// absent, empty, unparseable, or <= 0. Used for page sizes and limits where
// a non-positive value is never meaningful.
func QueryIntPositive(r *http.Request, key string, def int) int {
	s := r.URL.Query().Get(key)
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil || n <= 0 {
		return def
	}
	return n
}

// QueryIntNonNegative returns the query parameter parsed as an int, or def
// when absent, empty, unparseable, or negative. Zero is a valid value.
func QueryIntNonNegative(r *http.Request, key string, def int) int {
	if v := r.URL.Query().Get(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			return n
		}
	}
	return def
}

// QueryBool reports whether the query parameter is exactly "true".
func QueryBool(r *http.Request, key string) bool {
	return r.URL.Query().Get(key) == "true"
}

// QueryFloat returns the query parameter parsed as a float64, or def when
// absent, empty, or unparseable.
func QueryFloat(r *http.Request, key string, def float64) float64 {
	s := r.URL.Query().Get(key)
	if s == "" {
		return def
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return def
	}
	return f
}

// QueryFloatPositive returns the query parameter parsed as a float64, or def
// when absent, empty, unparseable, or <= 0.
func QueryFloatPositive(r *http.Request, key string, def float64) float64 {
	s := r.URL.Query().Get(key)
	if s == "" {
		return def
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil || f <= 0 {
		return def
	}
	return f
}
