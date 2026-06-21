package auth

import "context"

type contextKey int

const claimsKey contextKey = 0

// GetClaims retrieves the validated Claims from the request context.
// Returns false if RequireAuth middleware was not applied or the token was invalid.
func GetClaims(ctx context.Context) (*Claims, bool) {
	c, ok := ctx.Value(claimsKey).(*Claims)
	return c, ok
}

// SetClaims stores validated Claims in a context. Called by RequireAuth middleware.
func SetClaims(ctx context.Context, claims *Claims) context.Context {
	return context.WithValue(ctx, claimsKey, claims)
}
