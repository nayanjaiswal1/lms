package mcpconnect

import (
	"crypto/sha256"
	"encoding/base64"
)

// verifyPKCE implements the S256 code-challenge method (RFC 7636): the token
// endpoint recomputes the challenge from the verifier the client presents and
// compares it to the one recorded at /oauth/authorize. This is what stops an
// attacker who intercepts the authorization code (e.g. via a logged redirect)
// from exchanging it themselves — they'd need the verifier, which never
// leaves the client. Plain (unhashed) challenges are not accepted.
func verifyPKCE(codeVerifier, codeChallenge string) bool {
	if codeVerifier == "" || codeChallenge == "" {
		return false
	}
	sum := sha256.Sum256([]byte(codeVerifier))
	computed := base64.RawURLEncoding.EncodeToString(sum[:])
	return computed == codeChallenge
}
