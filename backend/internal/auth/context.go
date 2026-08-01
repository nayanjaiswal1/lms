package auth

import (
	"context"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

type contextKey int

const claimsKey contextKey = 0

// GetClaims retrieves the validated Claims from the request context.
// Returns false if RequireAuth middleware was not applied or the token was invalid.
func GetClaims(ctx context.Context) (*Claims, bool) {
	c, ok := ctx.Value(claimsKey).(*Claims)
	return c, ok
}

// RequireClaims retrieves validated Claims from the request context, writing a 401
// response and returning false if authentication is missing.
func RequireClaims(w http.ResponseWriter, r *http.Request) (*Claims, bool) {
	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

// SetClaims stores validated Claims in a context. Called by RequireAuth middleware.
func SetClaims(ctx context.Context, claims *Claims) context.Context {
	return context.WithValue(ctx, claimsKey, claims)
}
