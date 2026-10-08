package auth

import (
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/mindforge/backend/internal/config"
)

const testJWTSecret = "unit-test-secret-unit-test-secret"

func jwtCfg(ttl time.Duration) *config.Config {
	return &config.Config{JWTSecret: testJWTSecret, AccessTokenTTL: ttl}
}

func mustToken(t *testing.T, cfg *config.Config) string {
	t.Helper()
	tok, err := CreateAccessToken(cfg, Claims{UserID: "user-1", OrgID: "org-1", OrgRole: "admin", SessionVersion: 3})
	if err != nil {
		t.Fatalf("CreateAccessToken: %v", err)
	}
	return tok
}

func TestParseTokenAcceptsValidToken(t *testing.T) {
	cfg := jwtCfg(time.Hour)
	got, err := ParseToken(cfg, mustToken(t, cfg))
	if err != nil {
		t.Fatalf("ParseToken: %v", err)
	}
	if got.UserID != "user-1" || got.OrgID != "org-1" || got.OrgRole != "admin" || got.SessionVersion != 3 || got.ID == "" {
		t.Fatalf("claims round-trip mismatch: %+v", got)
	}
}

func TestParseTokenRejectsExpired(t *testing.T) {
	cfg := jwtCfg(-time.Minute)
	if _, err := ParseToken(cfg, mustToken(t, cfg)); err == nil || !strings.Contains(err.Error(), "expired") {
		t.Fatalf("want expired error, got %v", err)
	}
}

func TestParseTokenRejectsWrongKey(t *testing.T) {
	signer := jwtCfg(time.Hour)
	verifier := &config.Config{JWTSecret: "a-different-secret-a-different-secret", AccessTokenTTL: time.Hour}
	if _, err := ParseToken(verifier, mustToken(t, signer)); err == nil {
		t.Fatal("token signed with another key was accepted")
	}
}

func TestParseTokenRejectsWrongAlgorithms(t *testing.T) {
	cfg := jwtCfg(time.Hour)
	claims := Claims{UserID: "attacker", RegisteredClaims: jwt.RegisteredClaims{ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))}}

	none, err := jwt.NewWithClaims(jwt.SigningMethodNone, claims).SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("sign none: %v", err)
	}
	hs512, err := jwt.NewWithClaims(jwt.SigningMethodHS512, claims).SignedString([]byte(testJWTSecret))
	if err != nil {
		t.Fatalf("sign hs512: %v", err)
	}
	for name, tok := range map[string]string{"alg none": none, "HS512 with the right key": hs512} {
		t.Run(name, func(t *testing.T) {
			if _, err := ParseToken(cfg, tok); err == nil {
				t.Fatalf("%s token was accepted", name)
			}
		})
	}
}

func TestParseTokenRejectsTamperedClaims(t *testing.T) {
	cfg := jwtCfg(time.Hour)
	parts := strings.Split(mustToken(t, cfg), ".")
	// Re-encode the payload with an escalated role but keep the old signature.
	forged := jwt.NewWithClaims(jwt.SigningMethodHS256, Claims{UserID: "user-1", OrgRole: "owner"})
	forgedStr, err := forged.SignedString([]byte("not-the-secret-not-the-secret-xx"))
	if err != nil {
		t.Fatalf("sign forged: %v", err)
	}
	forgedPayload := strings.Split(forgedStr, ".")[1]
	tampered := strings.Join([]string{parts[0], forgedPayload, parts[2]}, ".")
	if _, err := ParseToken(cfg, tampered); err == nil {
		t.Fatal("token with tampered payload was accepted")
	}
	if _, err := ParseToken(cfg, "not.a.jwt"); err == nil {
		t.Fatal("garbage token was accepted")
	}
}
