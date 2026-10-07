package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1" //nolint:gosec // RFC 6238 default HMAC; authenticator apps expect SHA-1
	"crypto/subtle"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"net/url"
	"strings"
	"time"
)

// RFC 6238 parameters. These are the values every authenticator app assumes
// when the otpauth URI does not override them.
const (
	totpPeriod        = 30
	totpDigits        = 6
	totpSkewSteps     = 1 // accept the previous and next step for clock drift
	totpSecretBytes   = 20
	recoveryCodeCount = 10
	recoveryCodeChars = 10
	mfaIssuer         = "MindForge"
)

var base32NoPad = base32.StdEncoding.WithPadding(base32.NoPadding)

// totpCode computes the RFC 4226 HOTP value for one RFC 6238 time step.
func totpCode(secret []byte, step int64) string {
	var counter [8]byte
	binary.BigEndian.PutUint64(counter[:], uint64(step))
	mac := hmac.New(sha1.New, secret) //nolint:gosec // see import
	mac.Write(counter[:])
	sum := mac.Sum(nil)
	off := sum[len(sum)-1] & 0x0f
	bin := binary.BigEndian.Uint32(sum[off:off+4]) & 0x7fffffff
	return fmt.Sprintf("%0*d", totpDigits, bin%1_000_000)
}

// verifyTOTP returns the matching time step when code is valid at now and that
// step is newer than lastStep. Requiring step > lastStep makes an accepted code
// single-use, so a shoulder-surfed or phished code cannot be replayed.
func verifyTOTP(secret []byte, code string, now time.Time, lastStep int64) (int64, bool) {
	code = strings.TrimSpace(code)
	if len(code) != totpDigits {
		return 0, false
	}
	cur := now.Unix() / totpPeriod
	for s := cur - totpSkewSteps; s <= cur+totpSkewSteps; s++ {
		if s > lastStep && subtle.ConstantTimeCompare([]byte(totpCode(secret, s)), []byte(code)) == 1 {
			return s, true
		}
	}
	return 0, false
}

// looksLikeTOTP distinguishes an authenticator code from a recovery code.
func looksLikeTOTP(code string) bool {
	code = strings.TrimSpace(code)
	if len(code) != totpDigits {
		return false
	}
	for _, c := range code {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

func newTOTPSecret() ([]byte, error) {
	secret := make([]byte, totpSecretBytes)
	if _, err := rand.Read(secret); err != nil {
		return nil, fmt.Errorf("generate totp secret: %w", err)
	}
	return secret, nil
}

// totpURI is the otpauth:// provisioning URI authenticator apps import.
func totpURI(secret []byte, account string) string {
	label := url.PathEscape(mfaIssuer + ":" + account)
	q := url.Values{}
	q.Set("secret", base32NoPad.EncodeToString(secret))
	q.Set("issuer", mfaIssuer)
	q.Set("digits", fmt.Sprint(totpDigits))
	q.Set("period", fmt.Sprint(totpPeriod))
	return "otpauth://totp/" + label + "?" + q.Encode()
}

// newRecoveryCodes returns recoveryCodeCount fresh codes (shown once, in
// "xxxxx-xxxxx" form) and their storage hashes.
func newRecoveryCodes() (plain, hashes []string, err error) {
	for range recoveryCodeCount {
		raw := make([]byte, 8)
		if _, err := rand.Read(raw); err != nil {
			return nil, nil, fmt.Errorf("generate recovery code: %w", err)
		}
		c := strings.ToLower(base32NoPad.EncodeToString(raw))[:recoveryCodeChars]
		plain = append(plain, c[:5]+"-"+c[5:])
		hashes = append(hashes, hashRecoveryCode(c))
	}
	return plain, hashes, nil
}

// hashRecoveryCode normalises user input (case, dashes, spaces) before hashing.
func hashRecoveryCode(code string) string {
	code = strings.NewReplacer("-", "", " ", "").Replace(strings.ToLower(strings.TrimSpace(code)))
	return HashToken(code)
}
