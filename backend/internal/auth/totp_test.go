package auth

import (
	"strings"
	"testing"
	"time"
)

// RFC 6238 Appendix B SHA-1 vectors (8-digit values truncated to our 6 digits).
func TestTOTPCodeRFC6238(t *testing.T) {
	secret := []byte("12345678901234567890")
	cases := map[int64]string{
		59:         "287082",
		1111111109: "081804",
		1234567890: "005924",
		2000000000: "279037",
	}
	for unix, want := range cases {
		if got := totpCode(secret, unix/totpPeriod); got != want {
			t.Errorf("t=%d: got %s want %s", unix, got, want)
		}
	}
}

func TestVerifyTOTPSkewAndReplay(t *testing.T) {
	secret := []byte("12345678901234567890")
	now := time.Unix(1111111109, 0)
	step := now.Unix() / totpPeriod

	got, ok := verifyTOTP(secret, totpCode(secret, step), now, 0)
	if !ok || got != step {
		t.Fatalf("current step rejected: %d %v", got, ok)
	}
	if _, ok := verifyTOTP(secret, totpCode(secret, step), now, step); ok {
		t.Error("replay of an already-used step accepted")
	}
	if _, ok := verifyTOTP(secret, totpCode(secret, step-1), now, 0); !ok {
		t.Error("previous step within skew rejected")
	}
	if _, ok := verifyTOTP(secret, totpCode(secret, step-2), now, 0); ok {
		t.Error("step outside skew accepted")
	}
	if _, ok := verifyTOTP(secret, "12345", now, 0); ok {
		t.Error("short code accepted")
	}
}

func TestRecoveryCodes(t *testing.T) {
	plain, hashes, err := newRecoveryCodes()
	if err != nil || len(plain) != recoveryCodeCount || len(hashes) != recoveryCodeCount {
		t.Fatalf("generate: %v %d %d", err, len(plain), len(hashes))
	}
	seen := map[string]bool{}
	for i, p := range plain {
		if len(p) != recoveryCodeChars+1 || p[5] != '-' {
			t.Errorf("bad format %q", p)
		}
		if hashRecoveryCode(strings.ToUpper(p)) != hashes[i] || hashRecoveryCode(strings.ReplaceAll(p, "-", "")) != hashes[i] {
			t.Errorf("normalisation mismatch for %q", p)
		}
		if seen[hashes[i]] {
			t.Errorf("duplicate code %q", p)
		}
		seen[hashes[i]] = true
	}
	if looksLikeTOTP(plain[0]) || !looksLikeTOTP(" 123456 ") || looksLikeTOTP("12345a") {
		t.Error("looksLikeTOTP misclassified")
	}
}

func TestTOTPURI(t *testing.T) {
	u := totpURI([]byte("12345678901234567890"), "a@b.com")
	if !strings.HasPrefix(u, "otpauth://totp/MindForge:a@b.com?") || !strings.Contains(u, "secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ") {
		t.Errorf("unexpected uri %s", u)
	}
}
