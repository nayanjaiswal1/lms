package assessment

import (
	"crypto/rand"
	"encoding/hex"
)

// newID returns a 32-char random hex identifier. Used for client-side stable IDs
// on MCQ options and coding test cases (DB primary keys use gen_random_uuid()).
func newID() string {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		// crypto/rand failure is not recoverable at request scope; surface a
		// constant marker rather than panicking the handler goroutine.
		return "id-unavailable"
	}
	return hex.EncodeToString(buf)
}

// shortID returns an 8-char random suffix for slug disambiguation.
func shortID() string {
	return newID()[:8]
}
