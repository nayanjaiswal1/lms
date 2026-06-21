package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/mindforge/backend/internal/config"
)

// Claims is the JWT payload for MindForge access tokens.
type Claims struct {
	UserID         string `json:"user_id"`
	OrgID          string `json:"org_id"`
	OrgRole        string `json:"org_role"`
	AuthMethod     string `json:"auth_method"`
	SessionVersion int    `json:"sv"`
	jwt.RegisteredClaims
}

// CreateAccessToken mints a new HS256-signed access token.
// jti is a fresh UUID-like random hex string; exp = now + ACCESS_TOKEN_TTL.
func CreateAccessToken(cfg *config.Config, claims Claims) (string, error) {
	jti, err := randomHex(16)
	if err != nil {
		return "", fmt.Errorf("auth: generate jti: %w", err)
	}

	now := time.Now()
	claims.RegisteredClaims = jwt.RegisteredClaims{
		ID:        jti,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(cfg.AccessTokenTTL)),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(cfg.JWTSecret))
	if err != nil {
		return "", fmt.Errorf("auth: sign access token: %w", err)
	}
	return signed, nil
}

// CreateRefreshToken generates a cryptographically random refresh token.
// raw is returned to the client via a cookie.
// hash (SHA-256 of raw) is stored in the database.
func CreateRefreshToken() (raw string, hash string, err error) {
	buf := make([]byte, 32)
	if _, err = rand.Read(buf); err != nil {
		return "", "", fmt.Errorf("auth: generate refresh token bytes: %w", err)
	}
	raw = hex.EncodeToString(buf)
	sum := sha256.Sum256([]byte(raw))
	hash = hex.EncodeToString(sum[:])
	return raw, hash, nil
}

// ParseToken parses and validates a JWT string, pinning the algorithm to HS256.
// Returns Claims on success; wraps the underlying jwt error on failure.
func ParseToken(cfg *config.Config, tokenStr string) (*Claims, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("auth: unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(cfg.JWTSecret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil {
		return nil, fmt.Errorf("auth: parse token: %w", err)
	}
	if !token.Valid {
		return nil, fmt.Errorf("auth: invalid token")
	}
	return claims, nil
}

// HashToken returns the hex-encoded SHA-256 hash of a raw token string.
func HashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

// CreateCSRFToken returns a CSRF token of the form "<random>.<hmac>", where hmac
// is HMAC-SHA256(CookieSecret, random). Signing lets the server reject forged or
// injected csrf_token cookies (e.g. set by an attacker from a sibling subdomain),
// closing the classic unsigned double-submit weakness.
func CreateCSRFToken(cfg *config.Config) (string, error) {
	rnd, err := randomHex(32)
	if err != nil {
		return "", fmt.Errorf("auth: generate csrf token: %w", err)
	}
	return rnd + "." + csrfSignature(cfg, rnd), nil
}

// ValidCSRFToken reports whether token is a "<random>.<hmac>" pair whose signature
// matches CookieSecret, using a constant-time comparison.
func ValidCSRFToken(cfg *config.Config, token string) bool {
	rnd, sig, ok := strings.Cut(token, ".")
	if !ok || rnd == "" || sig == "" {
		return false
	}
	return hmac.Equal([]byte(sig), []byte(csrfSignature(cfg, rnd)))
}

func csrfSignature(cfg *config.Config, rnd string) string {
	mac := hmac.New(sha256.New, []byte(cfg.CookieSecret))
	mac.Write([]byte(rnd))
	return hex.EncodeToString(mac.Sum(nil))
}

// ─── helpers ──────────────────────────────────────────────────────────────────

func randomHex(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
